#!/usr/bin/env ruby

require 'json'
require 'pathname'
require 'yaml'

require_relative 'json_schema_validator'

library_root = if ARGV[0] && !ARGV[0].start_with?('--')
  Pathname(ARGV.shift).expand_path
else
  Pathname(__dir__).join('..', 'graph-pivots').expand_path
end

strict_metadata = ARGV.delete('--strict-metadata')
schema_path = Pathname(__dir__).join('..', 'schemas', 'pivot_pattern.schema.json').expand_path

unless library_root.directory?
  warn "Pivot library path not found: #{library_root}"
  exit 2
end

unless schema_path.file?
  warn "Schema file not found: #{schema_path}"
  exit 2
end

begin
  schema = JSON.parse(File.read(schema_path))
rescue JSON::ParserError => e
  warn "Schema parse failed: #{e.message}"
  exit 2
end

schema_validator = EveryPivot::JsonSchemaValidator.new(schema)
prefix_map = {
  'OSINT' => 'OSINT_',
  'CTI' => 'CTI_',
  'FIN' => 'FIN_',
  'CROSS' => 'CROSS_',
  'HUMINT_SIGINT' => 'HUM_',
  'SUPPLY' => 'SUPPLY_',
  'IO' => 'IO_',
  'AITS' => 'AITS_',
  'ADTECH' => 'ADTECH_'
}
metadata_requirements = {
  'validated' => %w[precision_tier robustness_class hazards capability_requirements review],
  'working_set' => %w[precision_tier robustness_class hazards],
  'deferred' => []
}

errors = []
warnings = []
count = 0

def lane_for(file, library_root)
  rel = file.relative_path_from(library_root).each_filename.to_a
  return 'validated' if rel.first == 'validated' || rel.length == 1
  return 'working_set' if rel.first == 'working-set'
  return 'deferred' if rel.first == 'deferred'
  'other'
end

def add_message(bucket, file, message)
  bucket << "#{file}: #{message}"
end

def present_metadata?(value)
  return false if value.nil?
  return !value.empty? if value.respond_to?(:empty?)

  true
end

Dir.glob(library_root.join('**', '*.yaml').to_s).sort.each do |path|
  file = Pathname(path)
  count += 1

  begin
    data = YAML.safe_load(File.read(path), aliases: false)
  rescue StandardError => e
    add_message(errors, file.relative_path_from(library_root), "YAML parse failed: #{e.message}")
    next
  end

  unless data.is_a?(Hash)
    add_message(errors, file.relative_path_from(library_root), 'top-level YAML document must be a mapping')
    next
  end

  schema_validator.validate(data).each do |message|
    add_message(errors, file.relative_path_from(library_root), message)
  end

  lane = lane_for(file, library_root)
  basename = file.basename('.yaml').to_s

  if data['id'] && data['id'] != basename
    add_message(errors, file.relative_path_from(library_root), "filename must match `id` (`#{basename}` != `#{data['id']}`)")
  end

  if data['category']
    expected_prefix = prefix_map[data['category']]
    if expected_prefix.nil?
      add_message(warnings, file.relative_path_from(library_root), "unknown category `#{data['category']}` for prefix validation")
    elsif data['id'] && !data['id'].start_with?(expected_prefix)
      add_message(errors, file.relative_path_from(library_root), "`id` should start with `#{expected_prefix}` for category `#{data['category']}`")
    end
  end

  if data['version'] && data['version'] !~ /^\d+\.\d+\.\d+$/
    add_message(warnings, file.relative_path_from(library_root), "`version` should be SemVer-like (for example `1.0.0`)")
  end

  if data.key?('validation_state')
    if lane != 'other' && data['validation_state'] != lane
      add_message(errors, file.relative_path_from(library_root), "`validation_state` should match lane `#{lane}`")
    end
  end

  next unless metadata_requirements.key?(lane)

  metadata_requirements[lane].each do |field|
    next if present_metadata?(data[field])

    message = "missing recommended metadata field `#{field}` for lane `#{lane}`"
    if strict_metadata
      add_message(errors, file.relative_path_from(library_root), message)
    else
      add_message(warnings, file.relative_path_from(library_root), message)
    end
  end
end

puts "Validated #{count} pivot pattern files under #{library_root}"

unless warnings.empty?
  puts
  puts 'Warnings:'
  warnings.each { |message| puts "  - #{message}" }
end

unless errors.empty?
  puts
  puts 'Errors:'
  errors.each { |message| puts "  - #{message}" }
  exit 1
end

exit 0
