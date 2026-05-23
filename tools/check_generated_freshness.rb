#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'pathname'
require 'rbconfig'
require 'tmpdir'

def parse_json(path, errors)
  JSON.parse(path.read)
rescue Errno::ENOENT
  errors << "Missing #{path}"
  {}
rescue JSON::ParserError => e
  errors << "Invalid JSON in #{path}: #{e.message}"
  {}
end

def compare_file(errors, label, expected, actual)
  unless expected.file?
    errors << "Missing committed #{label}: #{expected}"
    return
  end

  unless actual.file?
    errors << "Generated #{label} was not produced: #{actual}"
    return
  end

  return if expected.binread == actual.binread

  errors << "#{label} is stale; committed #{expected} differs from regenerated #{actual}"
end

options = {
  repo_root: Pathname(__dir__).join('..').expand_path
}

OptionParser.new do |parser|
  parser.banner = 'Usage: check_generated_freshness.rb [options]'

  parser.on('--repo-root PATH', 'Repository root to check') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end
end.parse!

repo_root = options[:repo_root]
errors = []
registry = parse_json(repo_root.join('artifacts', 'registry-index.json'), errors)

release = registry['release']
published_at = registry['published_at']
errors << 'artifacts/registry-index.json is missing release' if release.to_s.empty?
errors << 'artifacts/registry-index.json is missing published_at' if published_at.to_s.empty?

unless errors.empty?
  warn 'Generated data freshness check failed:'
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

Dir.mktmpdir('everypivot-generated-freshness') do |tmp|
  tmp_root = Pathname(tmp)
  output = tmp_root.join('registry-index.json')
  site_data_root = tmp_root.join('site-data')
  builder = repo_root.join('tools', 'build_registry_index.rb')

  ok = system(
    RbConfig.ruby,
    builder.to_s,
    '--repo-root', repo_root.to_s,
    '--release', release,
    '--published-at', published_at,
    '--output', output.to_s,
    '--site-data-root', site_data_root.to_s
  )

  unless ok
    warn 'Generated data freshness check failed: registry build command failed'
    exit 1
  end

  {
    'artifacts/registry-index.json' => output,
    'artifacts/release-manifest.json' => tmp_root.join('release-manifest.json'),
    'site/data/registry-index.json' => site_data_root.join('registry-index.json'),
    'site/data/registry-index.js' => site_data_root.join('registry-index.js'),
    'site/data/pattern-sources.js' => site_data_root.join('pattern-sources.js'),
    'site/data/pivot-pattern.schema.json' => site_data_root.join('pivot-pattern.schema.json'),
    'site/data/pivot-pattern.schema.js' => site_data_root.join('pivot-pattern.schema.js')
  }.each do |relative_path, regenerated_path|
    compare_file(errors, relative_path, repo_root.join(relative_path), regenerated_path)
  end
end

if errors.any?
  warn 'Generated data freshness check failed:'
  errors.each { |error| warn "  - #{error}" }
  warn 'Regenerate committed public data with tools/build_registry_index.rb using the current release metadata.'
  exit 1
end

puts "Generated data fresh for #{release} (#{published_at})"
