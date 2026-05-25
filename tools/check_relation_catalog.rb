#!/usr/bin/env ruby

require 'pathname'
require 'set'
require 'yaml'

repo_root = Pathname(__dir__).join('..').expand_path
library_root = if ARGV[0] && !ARGV[0].start_with?('--')
  Pathname(ARGV.shift).expand_path
else
  repo_root.join('graph-pivots')
end
catalog_path = repo_root.join('docs', 'RELATION_CATALOG.md')

unless library_root.directory?
  warn "Pivot library path not found: #{library_root}"
  exit 2
end

unless catalog_path.file?
  warn "Relation catalog not found: #{catalog_path}"
  exit 2
end

SECTION_MAP = {
  'Source forms' => :source,
  'Target forms' => :target,
  'Hop relation values' => :via,
  'Hop forms' => :form
}.freeze

DEPRECATION_SECTION_MAP = {
  'Deprecated source forms' => :source,
  'Deprecated target forms' => :target,
  'Deprecated hop relation values' => :via,
  'Deprecated hop forms' => :form
}.freeze

SNAPSHOT_COUNT_PATTERNS = {
  patterns: /^- (?<count>\d+) patterns\.$/,
  source: /^- (?<count>\d+) distinct `source` values\.$/,
  target: /^- (?<count>\d+) distinct `target` values\.$/,
  via: /^- (?<count>\d+) distinct `hops\[\]\.via` values\.$/,
  form: /^- (?<count>\d+) distinct `hops\[\]\.form` values\.$/
}.freeze

def same_path?(left, right)
  left.realpath == right.realpath
rescue Errno::ENOENT
  left.expand_path == right.expand_path
end

catalog_values = Hash.new { |hash, key| hash[key] = Set.new }
deprecated_values = Hash.new { |hash, key| hash[key] = Set.new }
snapshot_counts = {}
current_inventory_section = nil
current_deprecation_section = nil

File.readlines(catalog_path).each do |line|
  SNAPSHOT_COUNT_PATTERNS.each do |kind, pattern|
    match = line.match(pattern)
    snapshot_counts[kind] = match[:count].to_i if match
  end

  if line =~ %r{<summary>([^<]+)</summary>}
    summary = Regexp.last_match(1)
    current_inventory_section = SECTION_MAP[summary]
    current_deprecation_section = DEPRECATION_SECTION_MAP[summary]
    next
  end

  if line.start_with?('</details>')
    current_inventory_section = nil
    current_deprecation_section = nil
  end

  if current_inventory_section
    match = line.match(/^- `([^`]+)` \(\d+\)$/)
    catalog_values[current_inventory_section] << match[1] if match
  elsif current_deprecation_section
    match = line.match(/^- `([^`]+)`(?:\s|$)/)
    deprecated_values[current_deprecation_section] << match[1] if match
  end
end

missing_sections = SECTION_MAP.values.reject { |section| catalog_values[section].any? }
unless missing_sections.empty?
  warn "Relation catalog inventory missing sections: #{missing_sections.join(', ')}"
  exit 2
end

observed = Hash.new { |hash, key| hash[key] = [] }
observed_values = Hash.new { |hash, key| hash[key] = Set.new }
pattern_count = 0

Dir.glob(library_root.join('**', '*.yaml').to_s).sort.each do |path|
  file = Pathname(path)
  relative = file.relative_path_from(library_root)
  pattern_count += 1

  begin
    data = YAML.safe_load(File.read(file), aliases: false)
  rescue StandardError => e
    observed[:parse_error] << "#{relative}: YAML parse failed: #{e.message}"
    next
  end

  next unless data.is_a?(Hash)

  if data['source']
    observed[:source] << [relative, data['source']]
    observed_values[:source] << data['source']
  end
  if data['target']
    observed[:target] << [relative, data['target']]
    observed_values[:target] << data['target']
  end
  Array(data['hops']).each_with_index do |hop, index|
    next unless hop.is_a?(Hash)

    if hop['via']
      observed[:via] << [relative, hop['via'], index]
      observed_values[:via] << hop['via']
    end
    if hop['form']
      observed[:form] << [relative, hop['form'], index]
      observed_values[:form] << hop['form']
    end
  end
end

warnings = []

observed[:parse_error].each { |message| warnings << message }

%i[source target via form].each do |kind|
  observed[kind].each do |entry|
    file, value, index = entry
    field = case kind
            when :source then 'source'
            when :target then 'target'
            when :via then "hops[#{index}].via"
            when :form then "hops[#{index}].form"
            end
    if deprecated_values[kind].include?(value)
      warnings << "#{file}: #{field} value `#{value}` is deprecated in docs/RELATION_CATALOG.md"
    end
    next if catalog_values[kind].include?(value)

    warnings << "#{file}: #{field} value `#{value}` is not in docs/RELATION_CATALOG.md inventory"
  end
end

if same_path?(library_root, repo_root.join('graph-pivots'))
  if snapshot_counts[:patterns] && snapshot_counts[:patterns] != pattern_count
    warnings << "docs/RELATION_CATALOG.md snapshot pattern count is #{snapshot_counts[:patterns]}, observed #{pattern_count}"
  end

  %i[source target via form].each do |kind|
    expected_count = snapshot_counts[kind]
    next unless expected_count

    actual_count = observed_values[kind].length
    next if expected_count == actual_count

    warnings << "docs/RELATION_CATALOG.md snapshot #{kind} count is #{expected_count}, observed #{actual_count}"
  end
end

if warnings.empty?
  puts "Relation catalog warnings: none for #{library_root}"
else
  puts "Relation catalog warnings for #{library_root}:"
  warnings.each { |message| puts "  - #{message}" }
end

exit 0
