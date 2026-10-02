#!/usr/bin/env ruby

require 'json'
require 'pathname'
require 'yaml'

require_relative 'json_schema_validator'
require_relative 'sail_bridge'
require_relative 'pattern_identity'
require_relative 'utf8_text'
require_relative 'semantic_contract'

begin
  tool_directory = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: 'tool directory'))
  ARGV.replace(ARGV.each_with_index.map do |value, index|
    EveryPivot::Utf8Text.decode(value, path: "command-line argument #{index + 1}")
  end)
rescue EveryPivot::Utf8Text::Error => e
  warn "Validator argument error: #{e.message}"
  exit 2
end

library_root = if ARGV[0] && !ARGV[0].start_with?('--')
  Pathname(ARGV.shift).expand_path
else
  tool_directory.join('..', 'graph-pivots').expand_path
end

strict_metadata = ARGV.delete('--strict-metadata')
strict_bridge = ARGV.delete('--strict-bridge')
current_distribution = ARGV.delete('--current-distribution')
unless ARGV.empty?
  warn "Unknown arguments: #{ARGV.join(' ')}"
  exit 2
end
schema_path = tool_directory.join('..', 'schemas', 'pivot_pattern.schema.json').expand_path

unless library_root.directory?
  warn "Pivot library path not found: #{library_root}"
  exit 2
end

unless schema_path.file?
  warn "Schema file not found: #{schema_path}"
  exit 2
end

begin
  schema = JSON.parse(EveryPivot::Utf8Text.read(schema_path))
rescue EveryPivot::Utf8Text::Error, SystemCallError => e
  warn "Schema read failed: #{e.message}"
  exit 2
rescue JSON::ParserError => e
  warn "Schema parse failed: #{e.message}"
  exit 2
end

schema_validator = EveryPivot::JsonSchemaValidator.new(schema)
begin
  bridge_validator = EveryPivot::SailBridge.new
rescue EveryPivot::SailBridge::ContractError => e
  warn e.message
  exit 2
end
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
identity_validator = EveryPivot::PatternIdentity.new
bridge_counts = EveryPivot::SailBridge::STATUSES.to_h { |status| [status, 0] }
distribution_counts = {'eligible' => 0, 'legacy_diagnostic' => 0, 'not_eligible' => 0, 'current_candidate_compatible' => 0}

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
    data = YAML.safe_load(EveryPivot::Utf8Text.read(path), aliases: false)
  rescue EveryPivot::Utf8Text::Error => e
    add_message(errors, file.relative_path_from(library_root), e.message)
    next
  rescue Psych::Exception, SystemCallError => e
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

  if data['pattern_schema_version'].to_s == '1.6' || data.key?('execution')
    begin
      unless data['pattern_schema_version'].to_s == '1.6'
        raise EveryPivot::SemanticContract::InvalidContract, 'execution references require explicit authoring v1.6 migration'
      end
      EveryPivot::SemanticContract.load_reference(data['execution'], data, root: tool_directory.join('..').expand_path.to_s)
    rescue EveryPivot::SemanticContract::InvalidContract, EveryPivot::SemanticContract::UnsupportedContract => e
      add_message(errors, file.relative_path_from(library_root), "Execution contract: #{e.message}")
    end
  end

  bridge = bridge_validator.check(data, path: file.relative_path_from(library_root).to_s)
  bridge_counts[bridge['status']] += 1
  distribution = bridge['distribution']
  distribution_counts[distribution['eligible'] ? 'eligible' : 'not_eligible'] += 1
  distribution_counts['legacy_diagnostic'] += 1 if distribution['classification'] == 'legacy_diagnostic'
  distribution_counts['current_candidate_compatible'] += 1 if distribution['eligible'] && bridge['status'] == 'candidate_compatible'
  distribution['errors'].each do |entry|
    add_message(current_distribution ? errors : warnings, file.relative_path_from(library_root), "Distribution #{entry['code']}: #{entry['message']}")
  end
  bridge['errors'].each do |entry|
    add_message(errors, file.relative_path_from(library_root), "SAIL #{entry['code']}: #{entry['message']}")
  end
  bridge['warnings'].each do |entry|
    add_message(warnings, file.relative_path_from(library_root), "SAIL #{entry['code']}: #{entry['message']}")
  end
  if strict_bridge && bridge['status'] == 'incomplete'
    add_message(errors, file.relative_path_from(library_root), 'SAIL incomplete bridge compatibility is forbidden by --strict-bridge')
  end

  lane = lane_for(file, library_root)
  basename = file.basename('.yaml').to_s

  identity_validator.check(data, path: file.relative_path_from(library_root).to_s, basename: basename, lane: lane).each do |message|
    add_message(errors, file.relative_path_from(library_root), message)
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
puts "SAIL semantic bridge compatibility (not active current coverage): #{bridge_counts.map { |status, total| "#{status}=#{total}" }.join(', ')}"
puts "Current distribution: #{distribution_counts.map { |status, total| "#{status}=#{total}" }.join(', ')}"
puts 'Bridge compatibility does not evaluate evidence or accept analytical conclusions.'

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
