#!/usr/bin/env ruby

require 'json'
require 'date'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'yaml'

repo_root = Pathname(__dir__).join('..').expand_path
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

def negative_lists_for_forms(negative_nodes, forms)
  form_set = forms.map(&:to_s)
  Array(negative_nodes).each_with_object([]) do |node, lists|
    next unless node.is_a?(Hash)

    list = node['list']
    lists << list if form_set.include?(node['form'].to_s) && !list.to_s.empty?
  end.uniq
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
  relationship_type = relation_type(hop['via'], profile.dig('graph_model', 'relationship_type_strategy'))
  nodes_by_id = Array(fixture['nodes']).each_with_object({}) do |node, nodes|
    nodes[node['id']] = node if node.is_a?(Hash)
  end
  source = nodes_by_id[source_id]
  source_forms = form_list(pattern['source'])
  target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
  negative_nodes = Array(pattern.dig('constraints', 'negative_nodes'))
  source_negative_lists = negative_lists_for_forms(negative_nodes, source_forms)
  target_negative_lists = negative_lists_for_forms(negative_nodes, target_forms)
  included = []
  suppressed = []

  unless source && source_forms.include?(source['form'])
    errors << 'fixture source node does not match pattern source form'
    return [included, suppressed]
  end

  Array(fixture['relationships']).each do |relationship|
    next unless relationship['type'] == relationship_type

    target_id = if hop['direction'] == 'in'
                  next unless relationship['to'] == source_id

                  relationship['from']
                else
                  next unless relationship['from'] == source_id

                  relationship['to']
                end
    target = nodes_by_id[target_id]
    next unless target && target_forms.include?(target['form'])

    seen = Date.iso8601(relationship.dig('properties', 'seen').to_s)
    negative_property = profile.dig('graph_model', 'negative_node_list_property') || 'negative_node_list'
    source_negative_list = source[negative_property]
    target_negative_list = target[negative_property]
    stale = seen < earliest_seen
    suppressed_by_list =
      (!source_negative_list.to_s.empty? && source_negative_lists.include?(source_negative_list)) ||
      (!target_negative_list.to_s.empty? && target_negative_lists.include?(target_negative_list))

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

def repo_path(repo_root, value)
  path = Pathname(value.to_s)
  path.absolute? ? path : repo_root.join(path)
end

def query_profile_paths(repo_root)
  Dir.glob(repo_root.join('adapters', 'query-profiles', '*.yml').to_s).sort.map { |path| Pathname(path) }
end

def unsupported_query_profile_paths(repo_root)
  query_profile_root = repo_root.join('adapters', 'query-profiles')
  unsupported = []
  unsupported.concat(Dir.glob(query_profile_root.join('*.yaml').to_s))
  unsupported.concat(Dir.glob(query_profile_root.join('*', '**', '*.yml').to_s))
  unsupported.concat(Dir.glob(query_profile_root.join('*', '**', '*.yaml').to_s))
  unsupported.sort.map { |path| Pathname(path).relative_path_from(repo_root).to_s }
end

def profile_targets(profile)
  Array(profile['targets'])
end

def find_pattern(repo_root, pattern_id)
  path = Dir.glob(repo_root.join('graph-pivots', '*', "#{pattern_id}.yaml").to_s).first
  Pathname(path) if path
end

def check_target(repo_root, generator_path, profile_path, profile, target, errors)
  target_label = "#{profile['profile_id']}/#{target['pattern_id']}"
  pattern_path = find_pattern(repo_root, target['pattern_id'].to_s)
  unless pattern_path
    errors << "#{target_label}: pattern not found"
    return nil
  end

  fixture_location = target['fixture_graph_location']
  generated_location = target['generated_query_location']
  fixture_load_location = target['fixture_load_location']
  if [fixture_location, generated_location, fixture_load_location].any? { |location| location.to_s.empty? }
    errors << "#{target_label}: target must declare generated_query_location, fixture_graph_location, and fixture_load_location"
    return nil
  end

  pattern = load_yaml(pattern_path, errors)
  fixture_path = repo_path(repo_root, fixture_location)
  fixture_load_path = repo_path(repo_root, fixture_load_location)
  generated_path = repo_path(repo_root, generated_location)
  fixture = load_json(fixture_path, errors)

  adapterish_root_fields = %w[adapter adapters backend query_profile query_profiles generated_query neo4j cypher]
  present_adapterish_root_fields = adapterish_root_fields.select { |field| pattern.key?(field) }
  if present_adapterish_root_fields.any?
    errors << "#{target_label}: pattern YAML contains adapter/query profile root fields: #{present_adapterish_root_fields.join(', ')}"
  end

  errors << "#{target_label}: pattern id mismatch" unless pattern['id'] == target['pattern_id']
  errors << "#{target_label}: pattern lane must be in profile scope" unless Array(profile.dig('scope', 'lanes')).include?(pattern['validation_state'])
  shape = target['supported_pattern_shape'].is_a?(Hash) ? target['supported_pattern_shape'] : {}
  errors << "#{target_label}: target must declare supported_pattern_shape.hop_count" unless shape['hop_count'].is_a?(Integer)
  errors << "#{target_label}: target must declare supported_pattern_shape.hop_direction" if shape['hop_direction'].to_s.empty?
  errors << "#{target_label}: target must declare supported_pattern_shape.temporal_window_required" unless [true, false].include?(shape['temporal_window_required'])
  errors << "#{target_label}: current generator supports exactly one hop" unless shape['hop_count'] == 1
  errors << "#{target_label}: current generator supports only inbound or outbound hops" unless %w[out in].include?(shape['hop_direction'])
  errors << "#{target_label}: current generator requires temporal windows" unless shape['temporal_window_required'] == true
  errors << "#{target_label}: pattern hop count does not match target shape" unless Array(pattern['hops']).length == shape['hop_count']
  errors << "#{target_label}: pattern hop direction does not match target shape" unless Array(pattern['hops']).first&.fetch('direction', nil) == shape['hop_direction']
  if shape['temporal_window_required']
    errors << "#{target_label}: target requires temporal window_days" unless pattern.dig('constraints', 'temporal', 'window_days').is_a?(Integer)
  end
  simplifications = Array(target['graph_simplifications']).map(&:to_s)
  errors << "#{target_label}: target must document scalar negative-node-list simplification" unless simplifications.any? { |note| note.include?('negative_node_list is a scalar property') }
  errors << "#{target_label}: target must document temporal.order enforcement limitation" unless simplifications.any? { |note| note.include?('temporal.order') && note.include?('not enforced') }
  errors << "#{target_label}: target must document degree cap/top path enforcement limitation" unless simplifications.any? { |note| note.include?('degree_caps') && note.include?('outputs.top_paths') && note.include?('not enforced') }
  errors << "#{target_label}: fixture format must be everypivot.query_profile_fixture_graph" unless fixture['format'] == 'everypivot.query_profile_fixture_graph'
  errors << "#{target_label}: fixture format_version must be 1" unless fixture['format_version'] == 1
  errors << "#{target_label}: fixture profile_id mismatch" unless fixture['profile_id'] == profile['profile_id']
  errors << "#{target_label}: fixture pattern_id mismatch" unless fixture['pattern_id'] == pattern['id']
  errors << "#{target_label}: fixture must include blocked assertions" if Array(fixture['blocked_assertions']).empty?
  errors << "#{target_label}: fixture must include expected result targets" if Array(fixture['expected_result_targets']).empty?
  errors << "#{target_label}: fixture must include expected suppressed targets" if Array(fixture['expected_suppressed_targets']).empty?

  hop = Array(pattern['hops']).first || {}
  relationship_type = relation_type(hop['via'], profile.dig('graph_model', 'relationship_type_strategy'))
  errors << "#{target_label}: fixture graph_model relationship_type must be #{relationship_type}" unless fixture.dig('graph_model', 'relationship_type') == relationship_type

  ids = node_ids(fixture['nodes'])
  Array(fixture['relationships']).each_with_index do |relationship, index|
    unless relationship.is_a?(Hash)
      errors << "#{target_label}: fixture relationships[#{index}] must be an object"
      next
    end

    errors << "#{target_label}: fixture relationships[#{index}].from does not reference nodes[]" unless ids.include?(relationship['from'])
    errors << "#{target_label}: fixture relationships[#{index}].to does not reference nodes[]" unless ids.include?(relationship['to'])
    errors << "#{target_label}: fixture relationships[#{index}].type must be #{relationship_type}" unless relationship['type'] == relationship_type
    errors << "#{target_label}: fixture relationships[#{index}].properties.seen is required" if relationship.dig('properties', 'seen').to_s.empty?
  end

  included_targets, suppressed_targets = fixture_targets(pattern, profile, fixture, errors)
  expected_result_targets = Array(fixture['expected_result_targets']).sort
  expected_suppressed_targets = Array(fixture['expected_suppressed_targets']).map { |entry| entry.is_a?(Hash) ? entry['id'] : entry }.compact.sort
  if included_targets != expected_result_targets
    errors << "#{target_label}: fixture traversal returned #{included_targets.inspect}; expected #{expected_result_targets.inspect}"
  end
  if suppressed_targets != expected_suppressed_targets
    errors << "#{target_label}: fixture traversal suppressed #{suppressed_targets.inspect}; expected #{expected_suppressed_targets.inspect}"
  end

  stdout, stderr, status = Open3.capture3(
    RbConfig.ruby,
    generator_path.to_s,
    '--repo-root', repo_root.to_s,
    '--profile', profile_path.to_s,
    '--fixture-graph', fixture_path.to_s,
    '--pattern-id', pattern['id']
  )
  unless status.success?
    errors << "#{target_label}: generator failed: #{[stdout, stderr].reject(&:empty?).join("\n")}"
  end

  generated = generated_path.file? ? generated_path.read : ''
  fixture_load = fixture_load_path.file? ? fixture_load_path.read : ''
  errors << "#{target_label}: missing generated query: #{generated_path}" if generated.empty?
  errors << "#{target_label}: missing fixture loader: #{fixture_load_path}" if fixture_load.empty?
  errors << "#{target_label}: generated query is stale; regenerate with tools/generate_query_profile_demo.rb" if status.success? && stdout != generated

  unless fixture_load.empty?
    errors << "#{target_label}: fixture loader must delete only fixture-scoped nodes" unless fixture_load.include?('MATCH (n:EveryPivotNode {fixture_id: $fixture_id})')
    errors << "#{target_label}: fixture loader must return loaded node count" unless fixture_load.include?('fixture_nodes_loaded')
    errors << "#{target_label}: fixture loader must return loaded relationship count" unless fixture_load.include?('fixture_relationships_loaded')

    ids.each do |id|
      errors << "#{target_label}: fixture loader missing node id: #{id}" unless fixture_load.include?(id)
    end

    Array(fixture['relationships']).each do |relationship|
      errors << "#{target_label}: fixture loader missing relationship type: #{relationship['type']}" unless fixture_load.include?("[:#{relationship['type']}")
    end
  end

  Array(pattern['hazards']).each do |hazard|
    errors << "#{target_label}: generated query missing pattern hazard: #{hazard}" unless generated.include?(cypher_string(hazard))
  end

  Array(fixture['blocked_assertions']).each do |assertion|
    errors << "#{target_label}: generated query missing blocked assertion: #{assertion}" unless generated.include?(cypher_string(assertion))
  end

  Array(pattern.dig('constraints', 'negative_nodes')).each do |negative_node|
    list = negative_node['list']
    errors << "#{target_label}: generated query missing negative-node list: #{list}" unless list.to_s.empty? || generated.include?(list)
  end

  window_days = pattern.dig('constraints', 'temporal', 'window_days')
  errors << "#{target_label}: generated query missing temporal window #{window_days}" unless generated.include?("duration({days: #{window_days}})")
  source_forms = form_list(pattern['source'])
  target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
  negative_property = profile.dig('graph_model', 'negative_node_list_property') || 'negative_node_list'
  form_property = profile.dig('graph_model', 'form_property') || 'form'
  seen_property = profile.dig('graph_model', 'relationship_seen_property') || 'seen'
  source_negative_lists = negative_lists_for_forms(pattern.dig('constraints', 'negative_nodes'), source_forms)
  target_negative_lists = negative_lists_for_forms(pattern.dig('constraints', 'negative_nodes'), target_forms)
  negative_lists = (source_negative_lists + target_negative_lists).uniq
  relationship = relation_type(hop['via'], profile.dig('graph_model', 'relationship_type_strategy'))
  if source_negative_lists.any? && target_negative_lists.empty?
    unless simplifications.any? { |note| note.include?('source-side negative-node suppression') && note.include?('clause presence only') }
      errors << "#{target_label}: target must document source-side negative-list behavioural proof limitation"
    end
  end
  node_label = profile.dig('graph_model', 'node_label') || 'EveryPivotNode'
  id_property = profile.dig('graph_model', 'id_property') || 'id'
  expected_match_clause = if hop['direction'] == 'in'
                            "MATCH (source:#{node_label} {#{id_property}: source_id})<-[edge:#{relationship}]-(target:#{node_label})"
                          else
                            "MATCH (source:#{node_label} {#{id_property}: source_id})-[edge:#{relationship}]->(target:#{node_label})"
                          end
  expected_source_clause = "WHERE source.#{form_property} IN #{cypher_list(source_forms)}"
  expected_target_clause = "  AND target.#{form_property} IN #{cypher_list(target_forms)}"
  expected_temporal_clause = "  AND date(edge.#{seen_property}) >= as_of - duration({days: #{window_days}})"
  expected_clauses = {
    'match clause' => expected_match_clause,
    'source-form clause' => expected_source_clause,
    'target-form clause' => expected_target_clause,
    'temporal-window clause' => expected_temporal_clause
  }
  if source_negative_lists.any?
    expected_clauses['source negative-list suppression clause'] =
      "  AND (source.#{negative_property} IS NULL OR NOT source.#{negative_property} IN #{cypher_list(source_negative_lists)})"
  end
  if target_negative_lists.any?
    expected_clauses['target negative-list suppression clause'] =
      "  AND (target.#{negative_property} IS NULL OR NOT target.#{negative_property} IN #{cypher_list(target_negative_lists)})"
  end
  expected_clauses.each do |label, clause|
    errors << "#{target_label}: generated query missing #{label}: #{clause}" unless generated.include?(clause)
  end

  result_alias = profile.dig('outputs', 'result_alias') || 'everypivot_traversal'
  fields = top_level_return_fields(generated, result_alias)
  allowed_fields = Array(profile.dig('outputs', 'allowed_top_level_fields'))
  forbidden_fields = Array(profile.dig('outputs', 'forbidden_top_level_fields'))

  errors << "#{target_label}: generated query return map could not be parsed" if fields.empty?
  unexpected_fields = fields - allowed_fields
  missing_fields = allowed_fields - fields
  forbidden_present = fields & forbidden_fields
  errors << "#{target_label}: generated query returns unexpected fields: #{unexpected_fields.join(', ')}" if unexpected_fields.any?
  errors << "#{target_label}: generated query missing allowed fields: #{missing_fields.join(', ')}" if missing_fields.any?
  errors << "#{target_label}: generated query returns forbidden fields: #{forbidden_present.join(', ')}" if forbidden_present.any?

  forbidden_fields.each do |field|
    if generated.match?(/^\s+#{Regexp.escape(field)}\s*:/)
      errors << "#{target_label}: generated query contains forbidden output key #{field}"
    end
  end

  target_label
end

errors = []
checked_targets = []
profile_paths = query_profile_paths(repo_root)
errors << 'no query profiles found under adapters/query-profiles/' if profile_paths.empty?
unsupported_profiles = unsupported_query_profile_paths(repo_root)
if unsupported_profiles.any?
  errors << "unsupported query profile locations or extensions: #{unsupported_profiles.join(', ')}"
end

profile_paths.each do |path|
  profile = load_yaml(path, errors)
  profile_id = profile['profile_id'].to_s
  errors << "#{path}: profile_id is required" if profile_id.empty?
  errors << "#{profile_id}: backend.name must be neo4j" unless profile.dig('backend', 'name') == 'neo4j'
  errors << "#{profile_id}: backend.query_language must be cypher" unless profile.dig('backend', 'query_language') == 'cypher'
  errors << "#{profile_id}: profile must be marked as a pilot" unless profile['status'] == 'pilot'
  errors << "#{profile_id}: profile must document scalar negative-node-list simplification" unless profile.dig('graph_model', 'negative_node_list_cardinality') == 'scalar_pilot_simplification'
  errors << "#{profile_id}: pattern YAML neutrality flag must be true" unless profile.dig('boundary', 'pattern_yaml_remains_backend_neutral') == true

  targets = Array(profile['targets'])
  errors << "#{profile_id}: profile must declare at least one target" if targets.empty?
  targets.each do |target|
    unless target.is_a?(Hash)
      errors << "#{profile_id}: profile target must be an object"
      next
    end

    checked = check_target(repo_root, generator_path, path, profile, target, errors)
    checked_targets << checked if checked
  end
end

if errors.empty?
  puts "PASS discovered #{profile_paths.length} query profile(s)"
  checked_targets.each { |target| puts "PASS #{target} fixture graph, loader, generated query, and semantic boundary checks" }
  exit 0
end

puts 'Query profile suite failures:'
errors.each { |error| puts "  - #{error}" }
exit 1
