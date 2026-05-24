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

catalog_values = Hash.new { |hash, key| hash[key] = Set.new }
current_section = nil

File.readlines(catalog_path).each do |line|
  if line =~ %r{<summary>([^<]+)</summary>}
    current_section = SECTION_MAP[Regexp.last_match(1)]
    next
  end

  current_section = nil if line.start_with?('</details>')
  next unless current_section

  match = line.match(/^- `([^`]+)` \(\d+\)$/)
  catalog_values[current_section] << match[1] if match
end

missing_sections = SECTION_MAP.values.reject { |section| catalog_values[section].any? }
unless missing_sections.empty?
  warn "Relation catalog inventory missing sections: #{missing_sections.join(', ')}"
  exit 2
end

observed = Hash.new { |hash, key| hash[key] = [] }

Dir.glob(library_root.join('**', '*.yaml').to_s).sort.each do |path|
  file = Pathname(path)
  relative = file.relative_path_from(library_root)

  begin
    data = YAML.safe_load(File.read(file), aliases: false)
  rescue StandardError => e
    observed[:parse_error] << "#{relative}: YAML parse failed: #{e.message}"
    next
  end

  next unless data.is_a?(Hash)

  observed[:source] << [relative, data['source']] if data['source']
  observed[:target] << [relative, data['target']] if data['target']
  Array(data['hops']).each_with_index do |hop, index|
    next unless hop.is_a?(Hash)

    observed[:via] << [relative, hop['via'], index] if hop['via']
    observed[:form] << [relative, hop['form'], index] if hop['form']
  end
end

warnings = []

observed[:parse_error].each { |message| warnings << message }

%i[source target via form].each do |kind|
  observed[kind].each do |entry|
    file, value, index = entry
    next if catalog_values[kind].include?(value)

    field = case kind
            when :source then 'source'
            when :target then 'target'
            when :via then "hops[#{index}].via"
            when :form then "hops[#{index}].form"
            end
    warnings << "#{file}: #{field} value `#{value}` is not in docs/RELATION_CATALOG.md inventory"
  end
end

if warnings.empty?
  puts "Relation catalog warnings: none for #{library_root}"
else
  puts "Relation catalog warnings for #{library_root}:"
  warnings.each { |message| puts "  - #{message}" }
end

exit 0
