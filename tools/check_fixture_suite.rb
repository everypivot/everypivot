#!/usr/bin/env ruby

require 'open3'
require 'pathname'
require 'rbconfig'
require 'yaml'

repo_root = Pathname(__dir__).join('..').expand_path
manifest_path = if ARGV[0]
  Pathname(ARGV[0]).expand_path
else
  repo_root.join('fixtures', 'validator_suite.yml')
end

unless manifest_path.file?
  warn "Fixture manifest not found: #{manifest_path}"
  exit 2
end

validator_path = repo_root.join('tools', 'validate_pivots.rb')
manifest = YAML.safe_load(File.read(manifest_path), aliases: false)
cases = Array(manifest['cases'])

failures = []

cases.each do |fixture_case|
  case_id = fixture_case.fetch('id')
  root = repo_root.join(fixture_case.fetch('root'))
  command = [RbConfig.ruby, validator_path.to_s, root.to_s]
  command << '--strict-metadata' if fixture_case['strict_metadata']

  stdout, stderr, status = Open3.capture3(*command, chdir: repo_root.to_s)
  combined = [stdout, stderr].reject(&:empty?).join("\n")
  expected_exit = fixture_case.fetch('expect_exit')

  case_failures = []
  if status.exitstatus != expected_exit
    case_failures << "expected exit #{expected_exit}, got #{status.exitstatus}"
  end

  Array(fixture_case['expect_output']).each do |fragment|
    next if combined.include?(fragment)

    case_failures << "missing output fragment #{fragment.inspect}"
  end

  if case_failures.empty?
    puts "PASS #{case_id}"
  else
    failures << {
      id: case_id,
      failures: case_failures,
      output: combined
    }
    puts "FAIL #{case_id}"
  end
end

if failures.empty?
  puts
  puts "Validated #{cases.length} fixture cases from #{manifest_path.relative_path_from(repo_root)}"
  exit 0
end

puts
puts 'Fixture suite failures:'
failures.each do |failure|
  puts "- #{failure[:id]}"
  failure[:failures].each { |message| puts "  #{message}" }
  puts "  output:"
  failure[:output].lines.each { |line| puts "    #{line.chomp}" }
end

exit 1
