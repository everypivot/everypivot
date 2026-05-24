#!/usr/bin/env ruby

require 'open3'
require 'json'
require 'pathname'
require 'rbconfig'
require 'yaml'

EVIDENCE_FORMAT = 'everypivot.traversal_evidence_pack'
FIXTURE_ROLES = %w[
  positive
  weak_positive
  cautionary_positive
  cautionary_negative
  negative
  suppression
  high_cardinality
].freeze
BLOCKING_ROLES = %w[cautionary_negative negative suppression].freeze

def pattern_ids(repo_root, lane)
  Dir.glob(repo_root.join('graph-pivots', lane, '*.yaml').to_s).each_with_object({}) do |path, ids|
    data = YAML.safe_load(File.read(path), aliases: false)
    ids[data['id']] = Pathname(path) if data.is_a?(Hash) && data['id']
  end
end

def evidence_target_ids(values)
  Array(values).map { |value| value.is_a?(Hash) ? value['id'] : value }.compact
end

def validate_evidence_examples(repo_root)
  failures = []
  examples = Dir.glob(repo_root.join('fixtures', 'examples', '*.evidence.json').to_s).sort
  validated_patterns = pattern_ids(repo_root, 'validated')
  role_coverage = Hash.new { |hash, key| hash[key] = [] }
  weak_corroboration_example = false
  suppression_or_high_cardinality = false

  if examples.empty?
    failures << {
      id: 'evidence_examples',
      failures: ['no traversal evidence examples found under fixtures/examples/*.evidence.json'],
      output: ''
    }
    return [failures, 0]
  end

  examples.each do |path|
    file = Pathname(path)
    relative_file = file.relative_path_from(repo_root)
    errors = []
    data = nil

    begin
      data = JSON.parse(File.read(file))
    rescue JSON::ParserError => e
      errors << "JSON parse failed: #{e.message}"
    end

    unless data.is_a?(Hash)
      errors << 'top-level JSON document must be an object'
      failures << { id: relative_file.to_s, failures: errors, output: '' }
      puts "FAIL #{relative_file}"
      next
    end

    fixture_id = data['fixture_id'].to_s
    pattern_id = data['pattern_id'].to_s
    roles = Array(data['fixture_roles'])
    source_node = data['source_node'].is_a?(Hash) ? data['source_node'] : {}
    nodes = Array(data['nodes'])
    edges = Array(data['edges'])
    traversals = Array(data['expected_traversals'])
    node_ids = nodes.map { |node| node['id'] if node.is_a?(Hash) }.compact

    errors << 'format must be everypivot.traversal_evidence_pack' unless data['format'] == EVIDENCE_FORMAT
    errors << 'format_version must be 1' unless data['format_version'] == 1
    errors << 'fixture_id is required' if fixture_id.empty?
    errors << 'pattern_id must reference a validated pattern' unless validated_patterns.key?(pattern_id)
    errors << 'fixture_roles must contain at least one role' if roles.empty?

    unknown_roles = roles - FIXTURE_ROLES
    errors << "unknown fixture_roles: #{unknown_roles.join(', ')}" if unknown_roles.any?

    errors << 'source_node must be an object' unless data['source_node'].is_a?(Hash)
    errors << 'source_node.id must appear in nodes[]' unless node_ids.include?(source_node['id'])
    errors << 'nodes must contain at least one node object' if nodes.empty?
    errors << 'edges must contain at least one edge object' if edges.empty?
    errors << 'expected_traversals must contain at least one traversal' if traversals.empty?
    errors << 'blocked_assertions must contain at least one statement' if Array(data['blocked_assertions']).empty?

    edges.each_with_index do |edge, index|
      unless edge.is_a?(Hash)
        errors << "edges[#{index}] must be an object"
        next
      end

      %w[from to relation].each do |field|
        errors << "edges[#{index}].#{field} is required" if edge[field].to_s.empty?
      end
      errors << "edges[#{index}].from does not reference nodes[]" unless node_ids.include?(edge['from'])
      errors << "edges[#{index}].to does not reference nodes[]" unless node_ids.include?(edge['to'])
    end

    traversals.each_with_index do |traversal, index|
      unless traversal.is_a?(Hash)
        errors << "expected_traversals[#{index}] must be an object"
        next
      end

      role = traversal['role'].to_s
      errors << "expected_traversals[#{index}].role must be one of #{FIXTURE_ROLES.join(', ')}" unless FIXTURE_ROLES.include?(role)
      errors << "expected_traversals[#{index}].role must be listed in fixture_roles" if FIXTURE_ROLES.include?(role) && !roles.include?(role)
      errors << "expected_traversals[#{index}].start does not reference nodes[]" unless node_ids.include?(traversal['start'])
      errors << "expected_traversals[#{index}].blocked_assertions must not be empty" if Array(traversal['blocked_assertions']).empty?

      included_targets = evidence_target_ids(traversal['included_targets'])
      suppressed_targets = evidence_target_ids(traversal['suppressed_targets'])
      candidate_targets = evidence_target_ids(traversal['candidate_targets'])
      (included_targets + suppressed_targets + candidate_targets).each do |target_id|
        errors << "expected_traversals[#{index}] target #{target_id.inspect} does not reference nodes[]" unless node_ids.include?(target_id)
      end

      if role == 'positive' && included_targets.empty?
        errors << "expected_traversals[#{index}] positive example must include at least one target"
      end

      if BLOCKING_ROLES.include?(role) && suppressed_targets.empty? && candidate_targets.empty?
        errors << "expected_traversals[#{index}] #{role} example must include suppressed_targets or candidate_targets"
      end
    end

    traversal_roles = traversals.map { |traversal| traversal['role'] if traversal.is_a?(Hash) }.compact
    missing_traversal_roles = roles - traversal_roles
    if missing_traversal_roles.any?
      errors << "fixture_roles missing expected_traversals coverage: #{missing_traversal_roles.join(', ')}"
    end

    role_coverage[pattern_id].concat(roles)
    suppression_or_high_cardinality ||= roles.any? { |role| %w[suppression high_cardinality].include?(role) }
    assertion_text = (
      Array(data['blocked_assertions']) +
      traversals.flat_map { |traversal| traversal.is_a?(Hash) ? Array(traversal['blocked_assertions']) : [] }
    ).join("\n")
    weak_corroboration_example ||= roles.include?('weak_positive') && assertion_text.match?(/corroborat/i)

    if errors.empty?
      puts "PASS #{fixture_id}"
    else
      failures << { id: fixture_id.empty? ? relative_file.to_s : fixture_id, failures: errors, output: '' }
      puts "FAIL #{fixture_id.empty? ? relative_file : fixture_id}"
    end
  end

  covered_patterns = role_coverage.select do |_pattern_id, roles|
    roles.include?('positive') && roles.any? { |role| BLOCKING_ROLES.include?(role) }
  end
  if covered_patterns.length < 2
    failures << {
      id: 'evidence_role_coverage',
      failures: ['at least two validated patterns must have both positive and negative/suppression evidence coverage'],
      output: role_coverage.transform_values { |roles| roles.uniq.sort }.inspect
    }
  end

  unless weak_corroboration_example
    failures << {
      id: 'weak_positive_corroboration',
      failures: ['at least one weak_positive example must explain why corroboration is required'],
      output: ''
    }
  end

  unless suppression_or_high_cardinality
    failures << {
      id: 'suppression_or_high_cardinality',
      failures: ['at least one evidence example must cover suppression or high-cardinality handling'],
      output: ''
    }
  end

  [failures, examples.length]
end

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

evidence_failures, evidence_count = validate_evidence_examples(repo_root)
failures.concat(evidence_failures)

if failures.empty?
  puts
  puts "Validated #{cases.length} fixture cases from #{manifest_path.relative_path_from(repo_root)}"
  puts "Validated #{evidence_count} traversal evidence examples from fixtures/examples"
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
