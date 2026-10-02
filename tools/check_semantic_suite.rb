#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'digest'
require 'open3'
require 'rbconfig'
require 'time'
require_relative 'utf8_text'

json_output = ARGV.delete('--json')
unless ARGV.empty?
  warn 'Usage: check_semantic_suite.rb [--json]'
  exit 2
end
root = File.expand_path('..', __dir__)
tests = Dir.glob(File.join(__dir__, 'test_semantic_*.rb')).sort
if tests.empty?
  warn 'No semantic tests are packaged; refusing an empty acceptance pass'
  exit 2
end
records = tests.map do |path|
  start = Time.now.utc.iso8601
  stdout, stderr, status = Open3.capture3(RbConfig.ruby, path, chdir: root)
  count = stdout.match(/(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips/)
  counts = count && %w[tests assertions failures errors skips].zip(count.captures.map(&:to_i)).to_h
  passed = status.success? && counts && counts['tests'].positive? && counts.values_at('failures', 'errors', 'skips').all?(&:zero?)
  record = {'oracle' => File.basename(path), 'command' => [RbConfig.ruby, path], 'started_utc' => start,
            'ended_utc' => Time.now.utc.iso8601, 'exit_code' => status.exitstatus,
            'oracle_sha256' => Digest::SHA256.file(path).hexdigest, 'counts' => counts, 'passed' => !!passed,
            'stdout_sha256' => Digest::SHA256.hexdigest(stdout), 'stderr_sha256' => Digest::SHA256.hexdigest(stderr)}
  record['stdout'] = stdout
  record['stderr'] = stderr
  puts "#{File.basename(path)}: #{passed ? 'PASS' : 'FAIL'} #{counts.inspect}" unless json_output
  record
end
report = {'suite' => 'everypivot.semantic_suite', 'runtime' => RUBY_DESCRIPTION,
          'passed' => records.all? { |r| r['passed'] }, 'oracles' => records,
          'native_runtime_executed' => false, 'assessment_acceptance_evaluated' => false,
          'scope' => 'Packaged synthetic foundation and explicitly named family tests only; no external source completeness or native acceptance.'}
puts JSON.pretty_generate(report) if json_output
exit(report['passed'] ? 0 : 1)
