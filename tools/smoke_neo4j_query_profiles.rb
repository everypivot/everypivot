#!/usr/bin/env ruby

require 'json'
require 'open3'
require 'optparse'
require 'pathname'
require 'tempfile'
require 'yaml'

def load_yaml(path)
  YAML.safe_load(path.read, aliases: false)
end

def load_json(path)
  JSON.parse(path.read)
end

def repo_path(repo_root, value)
  path = Pathname(value.to_s)
  path.absolute? ? path : repo_root.join(path)
end

def query_profile_paths(repo_root, requested_profile)
  return [repo_path(repo_root, requested_profile)] if requested_profile

  Dir.glob(repo_root.join('adapters', 'query-profiles', '*.yml').to_s)
     .sort
     .map { |path| Pathname(path) }
end

def command_has_format?(args)
  args.each_with_index.any? do |arg, index|
    arg == '--format' || arg.start_with?('--format=') || arg == '-format'
  end
end

def command_has_file_argument?(args)
  args.any? { |arg| arg == '--file' || arg.start_with?('--file=') || arg == '-f' }
end

def run_cypher_file(cypher_shell, cypher_args, path, force_plain: false)
  args = cypher_args.dup
  args = ['--format', 'plain'] + args if force_plain && !command_has_format?(args)
  Open3.capture3(cypher_shell, *args, '--file', path.to_s)
rescue Errno::ENOENT
  ['cypher-shell executable not found', '', nil]
end

def run_cypher_text(cypher_shell, cypher_args, text)
  Tempfile.create(['everypivot-neo4j-smoke', '.cypher']) do |file|
    file.write(text)
    file.flush
    return run_cypher_file(cypher_shell, cypher_args, Pathname(file.path))
  end
end

def target_ids(entries)
  Array(entries).map { |entry| entry.is_a?(Hash) ? entry['id'] : entry }.compact
end

options = {
  repo_root: Pathname(__dir__).join('..').expand_path,
  cypher_shell: ENV.fetch('CYPHER_SHELL', 'cypher-shell'),
  profile: nil,
  pattern_ids: [],
  reset_fixtures: false
}

parser = OptionParser.new do |opts|
  opts.banner = 'Usage: smoke_neo4j_query_profiles.rb [options] -- [cypher-shell args]'

  opts.on('--repo-root PATH', 'Repository root to check') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end

  opts.on('--profile PATH', 'Run one query profile YAML file') do |value|
    options[:profile] = value
  end

  opts.on('--pattern-id ID', 'Run one declared profile target; repeatable') do |value|
    options[:pattern_ids] << value
  end

  opts.on('--cypher-shell PATH', 'cypher-shell executable path') do |value|
    options[:cypher_shell] = value
  end

  opts.on('--reset-fixtures', 'Delete all EveryPivotNode nodes before loading fixtures') do
    options[:reset_fixtures] = true
  end

  opts.on('-h', '--help', 'Print help') do
    puts opts
    exit 0
  end
end

parser.order!(ARGV)
ARGV.shift if ARGV.first == '--'
cypher_args = ARGV
repo_root = options[:repo_root]
errors = []
checked = []

if command_has_file_argument?(cypher_args)
  warn 'Neo4j query-profile smoke failures:'
  warn '  - pass connection/authentication options after --, not --file/-f; this helper owns fixture and query files'
  exit 2
end

profile_paths = query_profile_paths(repo_root, options[:profile])
errors << 'no query profiles found under adapters/query-profiles/' if profile_paths.empty?

if options[:reset_fixtures]
  stdout, stderr, status = run_cypher_text(options[:cypher_shell], cypher_args, "MATCH (n:EveryPivotNode)\nDETACH DELETE n;\n")
  unless status&.success?
    details = [stdout, stderr].reject(&:empty?).join("\n")
    warn 'Neo4j query-profile smoke failures:'
    warn "  - fixture reset failed: #{details}"
    exit 1
  end
end

profile_paths.each do |profile_path|
  profile = load_yaml(profile_path)
  profile_id = profile['profile_id']

  Array(profile['targets']).each do |target|
    pattern_id = target['pattern_id'].to_s
    next if options[:pattern_ids].any? && !options[:pattern_ids].include?(pattern_id)

    fixture_path = repo_path(repo_root, target['fixture_graph_location'])
    loader_path = repo_path(repo_root, target['fixture_load_location'])
    query_path = repo_path(repo_root, target['generated_query_location'])
    label = "#{profile_id}/#{pattern_id}"

    [fixture_path, loader_path, query_path].each do |path|
      errors << "#{label}: missing #{path}" unless path.file?
    end
    next unless fixture_path.file? && loader_path.file? && query_path.file?

    fixture = load_json(fixture_path)

    stdout, stderr, status = run_cypher_file(options[:cypher_shell], cypher_args, loader_path)
    unless status&.success?
      details = [stdout, stderr].reject(&:empty?).join("\n")
      errors << "#{label}: fixture loader failed: #{details}"
      next
    end

    stdout, stderr, status = run_cypher_file(options[:cypher_shell], cypher_args, query_path, force_plain: true)
    unless status&.success?
      details = [stdout, stderr].reject(&:empty?).join("\n")
      errors << "#{label}: generated query failed: #{details}"
      next
    end

    target_ids(fixture['expected_result_targets']).each do |expected_id|
      errors << "#{label}: query output missing expected target #{expected_id}" unless stdout.include?(expected_id)
    end

    target_ids(fixture['expected_suppressed_targets']).each do |suppressed_id|
      errors << "#{label}: query output included suppressed target #{suppressed_id}" if stdout.include?(suppressed_id)
    end

    checked << label
  rescue JSON::ParserError, Psych::Exception => e
    errors << "#{label}: parse failed: #{e.message}"
  end
end

if checked.empty? && errors.empty?
  errors << 'no query profile targets matched the requested filters'
end

if errors.empty?
  checked.each { |label| puts "PASS #{label} live Neo4j smoke returned expected unsuppressed targets" }
  exit 0
end

warn 'Neo4j query-profile smoke failures:'
errors.each { |error| warn "  - #{error}" }
exit 1
