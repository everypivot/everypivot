#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'
require 'pathname'
require 'yaml'
require_relative 'sail_bridge'

json_output = ARGV.include?('--json')
begin
  strict_incomplete = false
  OptionParser.new do |parser|
    parser.banner = 'Usage: check_sail_bridge.rb [LIBRARY_DIR] [--json] [--strict-incomplete]'
    parser.on('--json', 'Emit stable bridge compatibility JSON') { json_output = true }
    parser.on('--strict-incomplete', 'Fail on unresolved legacy bridge coverage') { strict_incomplete = true }
  end.parse!
  raise ArgumentError, 'Expected at most one pivot library directory' if ARGV.length > 1
  root = ARGV.empty? ? Pathname(__dir__).join('..', 'graph-pivots').expand_path : Pathname(ARGV.first).expand_path
  raise ArgumentError, "Pivot library path not found: #{root}" unless root.directory?
  checker = EveryPivot::SailBridge.new
  paths = Dir.glob(root.join('**', '*.yaml').to_s).sort
  raise ArgumentError, "No pivot YAML files found under #{root}" if paths.empty?
  findings = paths.map do |path|
    data = YAML.safe_load(File.read(path), aliases: false)
    checker.check(data, path: Pathname(path).relative_path_from(root).to_s)
  end
  counts = EveryPivot::SailBridge::STATUSES.to_h { |status| [status, findings.count { |row| row['status'] == status }] }
  counts['total'] = findings.length
  counts['deprecated'] = findings.count { |row| row['warnings'].any? { |entry| entry['code'] == 'deprecated_structural_object_role' } }
  report = {'report_version' => 1, 'contract' => checker.contract_info, 'counts' => counts, 'findings' => findings}
  if json_output
    puts JSON.pretty_generate(report)
  else
    puts "SAIL v0.4 DRAFT bridge compatibility: #{counts.map { |key, value| "#{key}=#{value}" }.join(', ')}"
    findings.each do |row|
      (row['errors'] + row['warnings']).each { |entry| puts "#{row['path']}: #{entry['code']}: #{entry['message']}" }
    end
    puts 'Compatibility checks do not evaluate evidence or accept analytical conclusions.'
  end
  exit(counts['incompatible'].positive? || (strict_incomplete && counts['incomplete'].positive?) ? 1 : 0)
rescue EveryPivot::SailBridge::ContractError, ArgumentError, OptionParser::ParseError, Psych::Exception, SystemCallError => e
  code = e.is_a?(EveryPivot::SailBridge::ContractError) ? 'contract_unavailable' : 'input_error'
  if json_output
    puts JSON.pretty_generate({'report_version' => 1, 'contract' => {'status' => 'unavailable'}, 'error' => {'code' => code, 'message' => e.message}, 'counts' => {}, 'findings' => []})
  else
    warn "#{code}: #{e.message}"
  end
  exit 2
end
