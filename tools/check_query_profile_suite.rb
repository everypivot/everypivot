#!/usr/bin/env ruby

require 'json'
require 'date'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'yaml'

repo_root = Pathname(__dir__).join('..').expand_path
profile_path = repo_root.join('adapters', 'query-profiles', 'neo4j_cypher_v0.yml')
pattern_path = repo_root.join('graph-pivots', 'validated', 'OSINT_SSH_HOSTKEY_CLUSTER.yaml')
fixture_path = repo_root.join('fixtures', 'query-profiles', 'neo4j', 'osint_ssh_hostkey_cluster.graph.json')
fixture_load_path = repo_root.join('fixtures', 'query-profiles', 'neo4j', 'osint_ssh_hostkey_cluster.load.cypher')
generated_path = repo_root.join('adapters', 'neo4j', 'generated', 'OSINT_SSH_HOSTKEY_CLUSTER.cypher')
generator_path = repo_root.join('tools', 'generate_query_profile_demo.rb')

def load_yaml(path, errors)
  YAML.safe_load(path.read, aliases: false)
rescue StandardError => e
  errors << "#{path}: YAML parse failed: #{e.message}"
  {}
end

def load_json(path, errors)
  JSON.parse(path.read)
rescue StandardError => e
  errors << "#{path}: JSON parse failed: #{e.message}"
  {}
end

def node_ids(nodes)
  Array(nodes).map { |node| node['id'] if node.is_a?(Hash) }.compact
end

def cypher_string(value)
  escaped = value.to_s.each_char.map do |char|
    case char
    when '\\'
      '\\\\'
    when "'"
      "\\'"
    when '"'
      '\\"'
    when "\n"
      '\\n'
    when "\r"
      '\\r'
    when "\t"
      '\\t'
    when "\b"
      '\\b'
    when "\f"
      '\\f'
    else
      char.ord < 0x20 ? format('\\u%04X', char.ord) : char
    end
  end.join
  "'#{escaped}'"
end

def cypher_list(values)
  "[#{values.map { |value| cypher_string(value) }.join(', ')}]"
end

def form_list(value)
  value.to_s.split('|').map(&:strip).reject(&:empty?)
end

def relation_type(relation, strategy)
  case strategy
  when 'uppercase_relation'
    relation.to_s.upcase.gsub(/[^A-Z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
  else
    relation.to_s
  end
end

def top_level_return_fields(query, result_alias)
  match = query.match(/RETURN \{\n(?<body>.*?)\n\} AS #{Regexp.escape(result_alias)}/m)
  return [] unless match

  match[:body].lines.each_with_object([]) do |line, fields|
    field = line[/^  ([a-z_]+):/, 1]
    fields << field if field
  end
end

def fixture_targets(pattern, profile, fixture, errors)
  hop = Array(pattern['hops']).first || {}
  source_id = fixture.dig('parameters', 'source_id')
  as_of = Date.iso8601(fixture.dig('parameters', 'as_of').to_s)
  window_days = pattern.dig('constraints', 'temporal', 'window_days')
  unless window_days.is_a?(Integer) && window_days.positive?
    errors << 'fixture traversal requires a positive pattern temporal window_days'
    return [[], []]
  end

  earliest_seen = as_of - window_days
  negative_lists = Array(pattern.dig('constraints', 'negative_nodes')).each_with_object([]) do |node, lists|
    list = node['list'] if node.is_a?(Hash)
    lists << list unless list.to_s.empty?
  end
  relationship_type = relation_type(hop['via'], profile.dig('graph_model', 'relationship_type_strategy'))
  nodes_by_id = Array(fixture['nodes']).each_with_object({}) do |node, nodes|
    nodes[node['id']] = node if node.is_a?(Hash)
  end
  source = nodes_by_id[source_id]
  source_forms = form_list(pattern['source'])
  target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
  included = []
  suppressed = []

  unless source && source_forms.include?(source['form'])
    errors << 'fixture source node does not match pattern source form'
    return [included, suppressed]
  end

  Array(fixture['relationships']).each do |relationship|
    next unless relationship['from'] == source_id
    next unless relationship['type'] == relationship_type

    target = nodes_by_id[relationship['to']]
    next unless target && target_forms.include?(target['form'])

    seen = Date.iso8601(relationship.dig('properties', 'seen').to_s)
    negative_list = target[profile.dig('graph_model', 'negative_node_list_property') || 'negative_node_list']
    stale = seen < earliest_seen
    suppressed_by_list = !negative_list.to_s.empty? && negative_lists.include?(negative_list)

    if stale || suppressed_by_list
      suppressed << target['id']
    else
      included << target['id']
    end
  rescue Date::Error => e
    errors << "fixture relationship date parse failed: #{e.message}"
  end

  [included.uniq.sort, suppressed.uniq.sort]
rescue Date::Error => e
  errors << "fixture parameter date parse failed: #{e.message}"
  [[], []]
end

errors = []

profile = load_yaml(profile_path, errors)
pattern = load_yaml(pattern_path, errors)
fixture = load_json(fixture_path, errors)

errors << 'profile_id must be neo4j_cypher_v0' unless profile['profile_id'] == 'neo4j_cypher_v0'
errors << 'profile backend.name must be neo4j' unless profile.dig('backend', 'name') == 'neo4j'
errors << 'profile backend.query_language must be cypher' unless profile.dig('backend', 'query_language') == 'cypher'
errors << 'profile must be marked as a pilot' unless profile['status'] == 'pilot'
errors << 'profile scope must include OSINT_SSH_HOSTKEY_CLUSTER' unless Array(profile.dig('scope', 'pattern_ids')).include?('OSINT_SSH_HOSTKEY_CLUSTER')
errors << 'profile pilot must declare one-hop support' unless profile.dig('pilot_constraints', 'supported_pattern_shape', 'hop_count') == 1
errors << 'profile pilot must declare outbound-only support' unless profile.dig('pilot_constraints', 'supported_pattern_shape', 'hop_direction') == 'out'
errors << 'profile pilot must require temporal windows' unless profile.dig('pilot_constraints', 'supported_pattern_shape', 'temporal_window_required') == true
errors << 'profile must document scalar negative-node-list simplification' unless profile.dig('graph_model', 'negative_node_list_cardinality') == 'scalar_pilot_simplification'

adapterish_root_fields = %w[adapter adapters backend query_profile query_profiles generated_query neo4j cypher]
present_adapterish_root_fields = adapterish_root_fields.select { |field| pattern.key?(field) }
if present_adapterish_root_fields.any?
  errors << "pattern YAML contains adapter/query profile root fields: #{present_adapterish_root_fields.join(', ')}"
end

errors << 'pattern id mismatch' unless pattern['id'] == 'OSINT_SSH_HOSTKEY_CLUSTER'
errors << 'pattern must remain in the validated lane for this pilot' unless pattern['validation_state'] == 'validated'
errors << 'profile pilot supports exactly one hop' unless Array(pattern['hops']).length == 1
errors << 'profile pilot supports only outbound hops' unless Array(pattern['hops']).first&.fetch('direction', nil) == 'out'
errors << 'profile pilot requires temporal window_days' unless pattern.dig('constraints', 'temporal', 'window_days').is_a?(Integer)
errors << 'fixture format must be everypivot.query_profile_fixture_graph' unless fixture['format'] == 'everypivot.query_profile_fixture_graph'
errors << 'fixture format_version must be 1' unless fixture['format_version'] == 1
errors << 'fixture profile_id mismatch' unless fixture['profile_id'] == profile['profile_id']
errors << 'fixture pattern_id mismatch' unless fixture['pattern_id'] == pattern['id']
errors << 'fixture must include blocked assertions' if Array(fixture['blocked_assertions']).empty?
errors << 'fixture must include expected result targets' if Array(fixture['expected_result_targets']).empty?
errors << 'fixture must include expected suppressed targets' if Array(fixture['expected_suppressed_targets']).empty?

ids = node_ids(fixture['nodes'])
Array(fixture['relationships']).each_with_index do |relationship, index|
  unless relationship.is_a?(Hash)
    errors << "fixture relationships[#{index}] must be an object"
    next
  end

  errors << "fixture relationships[#{index}].from does not reference nodes[]" unless ids.include?(relationship['from'])
  errors << "fixture relationships[#{index}].to does not reference nodes[]" unless ids.include?(relationship['to'])
  errors << "fixture relationships[#{index}].type must be PRESENTED_BY" unless relationship['type'] == 'PRESENTED_BY'
  errors << "fixture relationships[#{index}].properties.seen is required" if relationship.dig('properties', 'seen').to_s.empty?
end

included_targets, suppressed_targets = fixture_targets(pattern, profile, fixture, errors)
expected_result_targets = Array(fixture['expected_result_targets']).sort
expected_suppressed_targets = Array(fixture['expected_suppressed_targets']).map { |target| target.is_a?(Hash) ? target['id'] : target }.compact.sort
if included_targets != expected_result_targets
  errors << "fixture traversal returned #{included_targets.inspect}; expected #{expected_result_targets.inspect}"
end
if suppressed_targets != expected_suppressed_targets
  errors << "fixture traversal suppressed #{suppressed_targets.inspect}; expected #{expected_suppressed_targets.inspect}"
end

stdout, stderr, status = Open3.capture3(
  RbConfig.ruby,
  generator_path.to_s,
  '--repo-root', repo_root.to_s,
  '--pattern-id', 'OSINT_SSH_HOSTKEY_CLUSTER'
)
unless status.success?
  errors << "generator failed: #{[stdout, stderr].reject(&:empty?).join("\n")}"
end

generated = generated_path.file? ? generated_path.read : ''
fixture_load = fixture_load_path.file? ? fixture_load_path.read : ''
errors << "missing generated query: #{generated_path}" if generated.empty?
errors << "missing fixture loader: #{fixture_load_path}" if fixture_load.empty?
errors << 'generated query is stale; regenerate with tools/generate_query_profile_demo.rb' if status.success? && stdout != generated

if fixture_load_path.to_s != repo_root.join(profile.dig('boundary', 'fixture_load_location').to_s).to_s
  errors << 'profile fixture_load_location does not match committed loader path'
end

unless fixture_load.empty?
  errors << 'fixture loader must delete only fixture-scoped nodes' unless fixture_load.include?('MATCH (n:EveryPivotNode {fixture_id: $fixture_id})')
  errors << 'fixture loader must return loaded node count' unless fixture_load.include?('fixture_nodes_loaded')
  errors << 'fixture loader must return loaded relationship count' unless fixture_load.include?('fixture_relationships_loaded')

  ids.each do |id|
    errors << "fixture loader missing node id: #{id}" unless fixture_load.include?(id)
  end

  Array(fixture['relationships']).each do |relationship|
    errors << "fixture loader missing relationship type: #{relationship['type']}" unless fixture_load.include?("[:#{relationship['type']}")
  end
end

Array(pattern['hazards']).each do |hazard|
  errors << "generated query missing pattern hazard: #{hazard}" unless generated.include?(cypher_string(hazard))
end

Array(fixture['blocked_assertions']).each do |assertion|
  errors << "generated query missing blocked assertion: #{assertion}" unless generated.include?(cypher_string(assertion))
end

Array(pattern.dig('constraints', 'negative_nodes')).each do |negative_node|
  list = negative_node['list']
  errors << "generated query missing negative-node list: #{list}" unless list.to_s.empty? || generated.include?(list)
end

hop = Array(pattern['hops']).first || {}
window_days = pattern.dig('constraints', 'temporal', 'window_days')
errors << "generated query missing temporal window #{window_days}" unless generated.include?("duration({days: #{window_days}})")
source_forms = form_list(pattern['source'])
target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
negative_property = profile.dig('graph_model', 'negative_node_list_property') || 'negative_node_list'
form_property = profile.dig('graph_model', 'form_property') || 'form'
seen_property = profile.dig('graph_model', 'relationship_seen_property') || 'seen'
negative_lists = Array(pattern.dig('constraints', 'negative_nodes')).each_with_object([]) do |node, lists|
  list = node['list'] if node.is_a?(Hash)
  lists << list unless list.to_s.empty?
end
expected_source_clause = "WHERE source.#{form_property} IN #{cypher_list(source_forms)}"
expected_target_clause = "  AND target.#{form_property} IN #{cypher_list(target_forms)}"
expected_temporal_clause = "  AND date(edge.#{seen_property}) >= as_of - duration({days: #{window_days}})"
expected_suppression_clause = "  AND (target.#{negative_property} IS NULL OR NOT target.#{negative_property} IN #{cypher_list(negative_lists)})"
{
  'source-form clause' => expected_source_clause,
  'target-form clause' => expected_target_clause,
  'temporal-window clause' => expected_temporal_clause,
  'negative-list suppression clause' => expected_suppression_clause
}.each do |label, clause|
  errors << "generated query missing #{label}: #{clause}" unless generated.include?(clause)
end

result_alias = profile.dig('outputs', 'result_alias') || 'everypivot_traversal'
fields = top_level_return_fields(generated, result_alias)
allowed_fields = Array(profile.dig('outputs', 'allowed_top_level_fields'))
forbidden_fields = Array(profile.dig('outputs', 'forbidden_top_level_fields'))

errors << 'generated query return map could not be parsed' if fields.empty?
unexpected_fields = fields - allowed_fields
missing_fields = allowed_fields - fields
forbidden_present = fields & forbidden_fields
errors << "generated query returns unexpected fields: #{unexpected_fields.join(', ')}" if unexpected_fields.any?
errors << "generated query missing allowed fields: #{missing_fields.join(', ')}" if missing_fields.any?
errors << "generated query returns forbidden fields: #{forbidden_present.join(', ')}" if forbidden_present.any?

forbidden_fields.each do |field|
  if generated.match?(/^\s+#{Regexp.escape(field)}\s*:/)
    errors << "generated query contains forbidden output key #{field}"
  end
end

if errors.empty?
  puts 'PASS neo4j_cypher_v0 profile metadata'
  puts 'PASS OSINT_SSH_HOSTKEY_CLUSTER query profile fixture graph and loader'
  puts 'PASS generated Neo4j/Cypher query freshness and semantic boundary checks'
  exit 0
end

puts 'Query profile suite failures:'
errors.each { |error| puts "  - #{error}" }
exit 1
