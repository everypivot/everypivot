#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'pathname'
require 'yaml'
require_relative 'sail_bridge'
require_relative 'utf8_text'

json_output = ARGV.include?('--json')
begin
  tool_directory = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: 'tool directory'))
  ARGV.replace(ARGV.each_with_index.map do |value, index|
    EveryPivot::Utf8Text.decode(value, path: "command-line argument #{index + 1}")
  end)
  strict_incomplete = false
  current_distribution = false
  OptionParser.new do |parser|
    parser.banner = 'Usage: check_sail_bridge.rb [LIBRARY_DIR] [--json] [--strict-incomplete] [--current-distribution]'
    parser.on('--json', 'Emit stable bridge compatibility JSON') { json_output = true }
    parser.on('--strict-incomplete', 'Fail on unresolved legacy bridge coverage') { strict_incomplete = true }
    parser.on('--current-distribution', 'Require current v1.5/v1.6 assessment distribution eligibility') { current_distribution = true }
  end.parse!
  raise ArgumentError, 'Expected at most one pivot library directory' if ARGV.length > 1
  root = ARGV.empty? ? tool_directory.join('..', 'graph-pivots').expand_path : Pathname(ARGV.first).expand_path
  raise ArgumentError, "Pivot library path not found: #{root}" unless root.directory?
  checker = EveryPivot::SailBridge.new
  paths = Dir.glob(root.join('**', '*.yaml').to_s).sort
  raise ArgumentError, "No pivot YAML files found under #{root}" if paths.empty?
  findings = paths.map do |path|
    data = YAML.safe_load(EveryPivot::Utf8Text.read(path), aliases: false)
    checker.check(data, path: Pathname(path).relative_path_from(root).to_s)
  end
  counts = EveryPivot::SailBridge::STATUSES.to_h { |status| [status, findings.count { |row| row['status'] == status }] }
  counts['total'] = findings.length
  counts['deprecated'] = findings.count { |row| row['warnings'].any? { |entry| entry['code'] == 'deprecated_structural_object_role' } }
  distribution_counts = {
    'eligible' => findings.count { |row| row['distribution']['eligible'] },
    'not_eligible' => findings.count { |row| !row['distribution']['eligible'] },
    'legacy_diagnostic' => findings.count { |row| row['distribution']['classification'] == 'legacy_diagnostic' },
    'current_candidate_compatible' => findings.count { |row| row['distribution']['eligible'] && row['status'] == 'candidate_compatible' }
  }
  report = {'counts_scope' => 'semantic_compatibility_only', 'distribution_counts' => distribution_counts, 'report_version' => 1, 'contract' => checker.contract_info, 'counts' => counts, 'findings' => findings}
  if json_output
    puts JSON.pretty_generate(report)
  else
    puts "SAIL v0.4 DRAFT semantic bridge compatibility (not active current coverage): #{counts.map { |key, value| "#{key}=#{value}" }.join(', ')}"
    findings.each do |row|
      (row['errors'] + row['warnings'] + row['distribution']['errors']).each { |entry| puts "#{row['path']}: #{entry['code']}: #{entry['message']}" }
    end
    puts "Current distribution: #{distribution_counts.map { |key, value| "#{key}=#{value}" }.join(', ')}"
    puts 'Compatibility checks do not evaluate evidence or accept analytical conclusions.'
  end
  exit(counts['incompatible'].positive? || (strict_incomplete && counts['incomplete'].positive?) ||
       (current_distribution && distribution_counts['not_eligible'].positive?) ? 1 : 0)
rescue EveryPivot::Utf8Text::Error, EveryPivot::SailBridge::ContractError, ArgumentError, OptionParser::ParseError, Psych::Exception, SystemCallError => e
  code = if e.is_a?(EveryPivot::SailBridge::ContractError)
    'contract_unavailable'
  elsif e.is_a?(EveryPivot::Utf8Text::Error)
    'encoding_error'
  else
    'input_error'
  end
  if json_output
    puts JSON.pretty_generate({'report_version' => 1, 'contract' => {'status' => 'unavailable'}, 'error' => {'code' => code, 'message' => e.message}, 'counts' => {}, 'findings' => []})
  else
    warn "#{code}: #{e.message}"
  end
  exit 2
end
