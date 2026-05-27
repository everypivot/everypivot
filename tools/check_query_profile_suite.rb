#!/usr/bin/env ruby

require 'json'
require 'date'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'yaml'

repo_root = Pathname(__dir__).join('..').expand_path
generator_path = repo_root.join('tools', 'generate_query_profile_demo.rb')
stix_generator_path = repo_root.join('tools', 'generate_stix_mapping_profile_demo.rb')

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
  errors << "#{target_label}: fixture must declare expected_result_targets" unless fixture.key?('expected_result_targets')
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
  expected_source_forms = form_list(pattern['source'])
  expected_target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
  expected_source_negative_lists = negative_lists_for_forms(pattern.dig('constraints', 'negative_nodes'), expected_source_forms)
  expected_target_negative_lists = negative_lists_for_forms(pattern.dig('constraints', 'negative_nodes'), expected_target_forms)
  full_source_suppression_fixture =
    expected_result_targets.empty? &&
    expected_suppressed_targets.any? &&
    expected_source_negative_lists.any? &&
    expected_target_negative_lists.empty?
  if expected_result_targets.empty? && !full_source_suppression_fixture
    errors << "#{target_label}: expected_result_targets may be empty only for a source-side full-block suppression fixture"
  end
  free_text = Array(pattern['hazards']) + Array(fixture['blocked_assertions'])
  expected_suppressed_targets.each do |suppressed_id|
    if free_text.any? { |text| text.to_s.include?(suppressed_id) }
      errors << "#{target_label}: suppressed target id #{suppressed_id} appears in hazards or blocked_assertions, which can mask smoke-test leaks"
    end
  end
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
    if expected_result_targets.empty? && expected_suppressed_targets.any?
      unless simplifications.any? { |note| note.include?('source-side negative-node suppression') && note.include?('behaviourally exercised') }
        errors << "#{target_label}: target must document source-side negative-list behavioural proof"
      end
    elsif !simplifications.any? { |note| note.include?('source-side negative-node suppression') && note.include?('clause presence only') }
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

def nested_keys(value)
  case value
  when Hash
    value.flat_map { |key, nested_value| [key.to_s] + nested_keys(nested_value) }
  when Array
    value.flat_map { |nested_value| nested_keys(nested_value) }
  else
    []
  end
end

def stix_target_ids(entries, included:)
  Array(entries).select { |entry| entry.is_a?(Hash) && entry['include'] == included }.map { |entry| entry['id'] }.compact.sort
end

def expected_ids(values)
  Array(values).map { |entry| entry.is_a?(Hash) ? entry['id'] : entry }.compact.sort
end

def stix_id_version?(id, version)
  uuid = id.to_s.split('--', 2)[1]
  return false unless uuid

  uuid.match?(/\A[0-9a-f]{8}-[0-9a-f]{4}-#{version}[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/i)
end

def check_stix_target(repo_root, generator_path, profile_path, profile, target, errors)
  target_label = "#{profile['profile_id']}/#{target['pattern_id']}"
  pattern_path = find_pattern(repo_root, target['pattern_id'].to_s)
  unless pattern_path
    errors << "#{target_label}: pattern not found"
    return nil
  end

  fixture_location = target['fixture_mapping_location']
  generated_location = target['generated_bundle_location']
  if [fixture_location, generated_location].any? { |location| location.to_s.empty? }
    errors << "#{target_label}: target must declare generated_bundle_location and fixture_mapping_location"
    return nil
  end

  pattern = load_yaml(pattern_path, errors)
  fixture_path = repo_path(repo_root, fixture_location)
  generated_path = repo_path(repo_root, generated_location)
  fixture = load_json(fixture_path, errors)

  adapterish_root_fields = %w[adapter adapters backend query_profile query_profiles generated_query neo4j cypher opencti stix]
  present_adapterish_root_fields = adapterish_root_fields.select { |field| pattern.key?(field) }
  if present_adapterish_root_fields.any?
    errors << "#{target_label}: pattern YAML contains adapter/query profile root fields: #{present_adapterish_root_fields.join(', ')}"
  end

  errors << "#{target_label}: pattern id mismatch" unless pattern['id'] == target['pattern_id']
  errors << "#{target_label}: pattern lane must be in profile scope" unless Array(profile.dig('scope', 'lanes')).include?(pattern['validation_state'])
  errors << "#{target_label}: backend.name must be opencti" unless profile.dig('backend', 'name') == 'opencti'
  errors << "#{target_label}: backend.object_model must be stix_2_1" unless profile.dig('backend', 'object_model') == 'stix_2_1'
  errors << "#{target_label}: backend.artifact_type must be stix_bundle" unless profile.dig('backend', 'artifact_type') == 'stix_bundle'
  errors << "#{target_label}: backend.integration_kind must be none" unless profile.dig('backend', 'integration_kind') == 'none'
  errors << "#{target_label}: live OpenCTI connector boundary must be false" unless profile.dig('boundary', 'live_opencti_connector') == false
  extension_config = profile.dig('stix_model', 'extension_definition').is_a?(Hash) ? profile.dig('stix_model', 'extension_definition') : {}
  %w[name description schema_url].each do |field|
    errors << "#{target_label}: stix_model.extension_definition.#{field} is required" if extension_config[field].to_s.empty?
  end

  shape = target['supported_mapping_shape'].is_a?(Hash) ? target['supported_mapping_shape'] : {}
  errors << "#{target_label}: target must declare supported_mapping_shape.hop_count" unless shape['hop_count'].is_a?(Integer)
  errors << "#{target_label}: target must declare supported_mapping_shape.hop_direction" if shape['hop_direction'].to_s.empty?
  errors << "#{target_label}: target must declare supported_mapping_shape.temporal_window_required" unless [true, false].include?(shape['temporal_window_required'])
  errors << "#{target_label}: current STIX mapper supports exactly one hop" unless shape['hop_count'] == 1
  errors << "#{target_label}: current STIX mapper supports only inbound or outbound hops" unless %w[out in].include?(shape['hop_direction'])
  errors << "#{target_label}: current STIX mapper requires temporal windows" unless shape['temporal_window_required'] == true
  errors << "#{target_label}: pattern hop count does not match target shape" unless Array(pattern['hops']).length == shape['hop_count']
  errors << "#{target_label}: pattern hop direction does not match target shape" unless Array(pattern['hops']).first&.fetch('direction', nil) == shape['hop_direction']
  if shape['temporal_window_required']
    errors << "#{target_label}: target requires temporal window_days" unless pattern.dig('constraints', 'temporal', 'window_days').is_a?(Integer)
  end

  hop = Array(pattern['hops']).first || {}
  source_forms = form_list(pattern['source'])
  target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
  errors << "#{target_label}: supported source_form does not match pattern source" unless source_forms.include?(shape['source_form'])
  errors << "#{target_label}: supported target_form does not match pattern target form" unless target_forms.include?(shape['target_form'])

  simplifications = Array(target['mapping_simplifications']).map(&:to_s)
  errors << "#{target_label}: target must document x_imphash custom hash-key mapping" unless simplifications.any? { |note| note.include?('x_imphash') && note.include?('custom hash key') }
  errors << "#{target_label}: target must document EveryPivot relation handling" unless simplifications.any? { |note| note.include?('x_everypivot_relation') && note.include?('related-to') }
  errors << "#{target_label}: target must document suppressed-target relationship omission" unless simplifications.any? { |note| note.include?('Suppressed targets') && note.include?('not emitted as STIX relationship objects') }
  errors << "#{target_label}: target must document no live OpenCTI integration" unless simplifications.any? { |note| note.include?('not a live OpenCTI connector') }
  errors << "#{target_label}: target must document STIX UUIDv5 custom-hash exclusion" unless simplifications.any? { |note| note.include?('UUIDv5') && note.include?('x_imphash') && note.include?('not used as UUID inputs') }
  errors << "#{target_label}: target must document File SCO custom-property boundary" unless simplifications.any? { |note| note.include?('custom properties') && note.include?('observed-data') && note.include?('relationship') && note.include?('note') }
  errors << "#{target_label}: target must document observed-data source/target bundling simplification" unless simplifications.any? { |note| note.include?('source and target file SCOs') && note.include?('observed-data') }
  errors << "#{target_label}: target must document degree cap/top path limitation" unless simplifications.any? { |note| note.include?('degree_caps') && note.include?('outputs.top_paths') && note.include?('not enforced') }

  errors << "#{target_label}: fixture format must be everypivot.stix_mapping_fixture" unless fixture['format'] == 'everypivot.stix_mapping_fixture'
  errors << "#{target_label}: fixture format_version must be 1" unless fixture['format_version'] == 1
  errors << "#{target_label}: fixture profile_id mismatch" unless fixture['profile_id'] == profile['profile_id']
  errors << "#{target_label}: fixture pattern_id mismatch" unless fixture['pattern_id'] == pattern['id']
  errors << "#{target_label}: fixture must include blocked assertions" if Array(fixture['blocked_assertions']).empty?
  errors << "#{target_label}: fixture must declare expected_relationship_targets" unless fixture.key?('expected_relationship_targets')
  errors << "#{target_label}: fixture must include expected suppressed targets" if Array(fixture['expected_suppressed_targets']).empty?

  source = fixture['source'].is_a?(Hash) ? fixture['source'] : {}
  targets = Array(fixture['targets'])
  extension_ref = fixture.dig('stix', 'extension_definition_ref')
  errors << "#{target_label}: fixture stix.extension_definition_ref is required" if extension_ref.to_s.empty?
  errors << "#{target_label}: fixture source id must match parameters.source_id" unless source['id'] == fixture.dig('parameters', 'source_id')
  errors << "#{target_label}: fixture source form does not match pattern source" unless source_forms.include?(source['form'])
  errors << "#{target_label}: fixture source stix_ref is required" if source['stix_ref'].to_s.empty?
  errors << "#{target_label}: fixture source stix_ref must be a UUIDv5 file SCO id" unless stix_id_version?(source['stix_ref'], 5)
  errors << "#{target_label}: fixture must include at least one target" if targets.empty?

  targets.each_with_index do |entry, index|
    unless entry.is_a?(Hash)
      errors << "#{target_label}: fixture targets[#{index}] must be an object"
      next
    end

    errors << "#{target_label}: fixture targets[#{index}].id is required" if entry['id'].to_s.empty?
    errors << "#{target_label}: fixture targets[#{index}].stix_ref is required" if entry['stix_ref'].to_s.empty?
    errors << "#{target_label}: fixture targets[#{index}].stix_ref must be a UUIDv5 file SCO id" unless stix_id_version?(entry['stix_ref'], 5)
    errors << "#{target_label}: fixture targets[#{index}].form does not match pattern target form" unless target_forms.include?(entry['form'])
    errors << "#{target_label}: fixture targets[#{index}].include must be boolean" unless [true, false].include?(entry['include'])
    errors << "#{target_label}: fixture targets[#{index}].seen is required" if entry['seen'].to_s.empty?
    if entry['include'] == true
      errors << "#{target_label}: included fixture targets[#{index}] must declare observed_data_ref" if entry['observed_data_ref'].to_s.empty?
      errors << "#{target_label}: included fixture targets[#{index}] must declare relationship_ref" if entry['relationship_ref'].to_s.empty?
    else
      errors << "#{target_label}: suppressed fixture targets[#{index}] must declare suppression_reason" if entry['suppression_reason'].to_s.empty?
    end
  end

  expected_relationship_targets = Array(fixture['expected_relationship_targets']).sort
  expected_suppressed_targets = expected_ids(fixture['expected_suppressed_targets'])
  included_targets = stix_target_ids(targets, included: true)
  suppressed_targets = stix_target_ids(targets, included: false)
  errors << "#{target_label}: fixture included targets #{included_targets.inspect}; expected #{expected_relationship_targets.inspect}" unless included_targets == expected_relationship_targets
  errors << "#{target_label}: fixture suppressed targets #{suppressed_targets.inspect}; expected #{expected_suppressed_targets.inspect}" unless suppressed_targets == expected_suppressed_targets
  errors << "#{target_label}: STIX mapping fixture must emit at least one relationship target" if expected_relationship_targets.empty?

  begin
    as_of = Date.iso8601(fixture.dig('parameters', 'as_of').to_s)
    window_days = pattern.dig('constraints', 'temporal', 'window_days')
    earliest_seen = as_of - window_days
    targets.each_with_index do |entry, index|
      seen = Date.iso8601(entry['seen'].to_s)
      stale = seen < earliest_seen
      if entry['include'] == true && stale
        errors << "#{target_label}: fixture targets[#{index}] is included despite being outside the temporal window"
      end
      if entry['include'] == false && !stale && entry['suppression_reason'].to_s.empty?
        errors << "#{target_label}: fixture targets[#{index}] is suppressed without a declared reason"
      end
    end
  rescue Date::Error => e
    errors << "#{target_label}: fixture date parse failed: #{e.message}"
  end

  stdout, stderr, status = Open3.capture3(
    RbConfig.ruby,
    generator_path.to_s,
    '--repo-root', repo_root.to_s,
    '--profile', profile_path.to_s,
    '--fixture-mapping', fixture_path.to_s,
    '--pattern-id', pattern['id']
  )
  unless status.success?
    errors << "#{target_label}: STIX mapping generator failed: #{[stdout, stderr].reject(&:empty?).join("\n")}"
  end

  generated = generated_path.file? ? generated_path.read : ''
  errors << "#{target_label}: missing generated STIX bundle: #{generated_path}" if generated.empty?
  errors << "#{target_label}: generated STIX bundle is stale; regenerate with tools/generate_stix_mapping_profile_demo.rb" if status.success? && stdout != generated

  bundle = generated.empty? ? {} : load_json(generated_path, errors)
  errors << "#{target_label}: generated bundle type must be bundle" unless bundle['type'] == 'bundle'
  errors << "#{target_label}: generated bundle id mismatch" unless bundle['id'] == fixture.dig('stix', 'bundle_id')
  objects = Array(bundle['objects'])
  errors << "#{target_label}: generated bundle must contain objects" if objects.empty?

  allowed_types = Array(profile.dig('outputs', 'allowed_object_types'))
  object_types = objects.map { |object| object['type'] if object.is_a?(Hash) }.compact
  unexpected_types = object_types.uniq - allowed_types
  errors << "#{target_label}: generated bundle has unexpected object types: #{unexpected_types.join(', ')}" if unexpected_types.any?
  object_ids = objects.map { |object| object['id'] if object.is_a?(Hash) }.compact
  id_counts = Hash.new(0)
  object_ids.each { |id| id_counts[id] += 1 }
  duplicate_ids = id_counts.select { |_id, count| count > 1 }.keys
  errors << "#{target_label}: generated bundle has duplicate object ids: #{duplicate_ids.join(', ')}" if duplicate_ids.any?

  forbidden_properties = Array(profile.dig('outputs', 'forbidden_properties'))
  forbidden_present = nested_keys(bundle) & forbidden_properties
  errors << "#{target_label}: generated bundle contains forbidden properties: #{forbidden_present.uniq.sort.join(', ')}" if forbidden_present.any?

  required_custom_properties = Array(profile.dig('outputs', 'required_custom_properties'))
  required_custom_properties.each do |property|
    unless objects.any? { |object| object.is_a?(Hash) && object.key?(property) }
      errors << "#{target_label}: generated bundle missing required custom property #{property}"
    end
  end

  files = objects.select { |object| object.is_a?(Hash) && object['type'] == 'file' }
  relationships = objects.select { |object| object.is_a?(Hash) && object['type'] == 'relationship' }
  observed = objects.select { |object| object.is_a?(Hash) && object['type'] == 'observed-data' }
  notes = objects.select { |object| object.is_a?(Hash) && object['type'] == 'note' }
  extension_definitions = objects.select { |object| object.is_a?(Hash) && object['type'] == 'extension-definition' }
  extension_definition_ids = extension_definitions.map { |object| object['id'] }
  errors << "#{target_label}: generated bundle missing extension-definition #{extension_ref}" unless extension_definition_ids.include?(extension_ref)

  toplevel_extension = extension_definitions.find { |object| object['id'] == extension_ref } || {}
  unless Array(toplevel_extension['extension_types']).include?('toplevel-property-extension')
    errors << "#{target_label}: EveryPivot extension-definition must declare toplevel-property-extension"
  end
  errors << "#{target_label}: EveryPivot extension-definition name mismatch" unless toplevel_extension['name'] == extension_config['name']
  errors << "#{target_label}: EveryPivot extension-definition description mismatch" unless toplevel_extension['description'] == extension_config['description']
  errors << "#{target_label}: EveryPivot extension-definition schema URL mismatch" unless toplevel_extension['schema'] == extension_config['schema_url']

  custom_properties = objects.flat_map do |object|
    object.is_a?(Hash) ? object.keys.select { |key| key.start_with?('x_everypivot_') } : []
  end.uniq.sort
  missing_extension_properties = custom_properties - Array(toplevel_extension['extension_properties'])
  if missing_extension_properties.any?
    errors << "#{target_label}: EveryPivot extension-definition missing properties: #{missing_extension_properties.join(', ')}"
  end
  extension_schema_path = repo_root.join('adapters', 'opencti', 'schemas', 'x_everypivot_toplevel_extension.schema.json')
  extension_schema = load_json(extension_schema_path, errors)
  schema_properties = extension_schema['properties'].is_a?(Hash) ? extension_schema['properties'].keys.sort : []
  extension_properties = Array(toplevel_extension['extension_properties']).sort
  errors << "#{target_label}: EveryPivot extension schema $id mismatch" unless extension_schema['$id'] == toplevel_extension['schema']
  unless schema_properties == extension_properties
    errors << "#{target_label}: EveryPivot extension schema properties #{schema_properties.inspect}; expected #{extension_properties.inspect}"
  end

  expected_file_refs = ([source['stix_ref']] + targets.select { |entry| entry.is_a?(Hash) && entry['include'] == true }.map { |entry| entry['stix_ref'] }).sort
  file_refs = files.map { |object| object['id'] }.compact.sort
  errors << "#{target_label}: generated file SCO refs #{file_refs.inspect}; expected #{expected_file_refs.inspect}" unless file_refs == expected_file_refs
  files.each_with_index do |file, index|
    errors << "#{target_label}: generated file[#{index}].id must be a UUIDv5 SCO id" unless stix_id_version?(file['id'], 5)
    custom_file_properties = file.keys.select { |key| key.start_with?('x_everypivot_') }
    errors << "#{target_label}: generated file[#{index}] must not carry EveryPivot custom properties: #{custom_file_properties.join(', ')}" if custom_file_properties.any?
    errors << "#{target_label}: generated file[#{index}] must not carry EveryPivot extension markers" if file.key?('extensions')
  end

  (objects - extension_definitions - files).each_with_index do |object, index|
    next unless object.is_a?(Hash) && object.keys.any? { |key| key.start_with?('x_everypivot_') }

    extensions = object['extensions'].is_a?(Hash) ? object['extensions'] : {}
    unless extensions.dig(extension_ref, 'extension_type') == 'toplevel-property-extension'
      errors << "#{target_label}: generated #{object['type']}[#{index}] missing EveryPivot toplevel-property-extension marker"
    end
  end

  relationship_target_ids = relationships.map { |object| object['x_everypivot_target_id'] }.compact.sort
  observed_target_ids = observed.map { |object| object['x_everypivot_target_id'] }.compact.sort
  errors << "#{target_label}: generated relationship targets #{relationship_target_ids.inspect}; expected #{expected_relationship_targets.inspect}" unless relationship_target_ids == expected_relationship_targets
  errors << "#{target_label}: generated observed-data targets #{observed_target_ids.inspect}; expected #{expected_relationship_targets.inspect}" unless observed_target_ids == expected_relationship_targets
  suppressed_stix_refs = targets.select { |entry| entry.is_a?(Hash) && entry['include'] == false }.map { |entry| entry['stix_ref'] }.compact.sort
  leaked_suppressed_refs = file_refs & suppressed_stix_refs
  leaked_suppressed_ids = (relationship_target_ids + observed_target_ids) & expected_suppressed_targets
  leaked_suppressed = (leaked_suppressed_refs + leaked_suppressed_ids).uniq
  errors << "#{target_label}: suppressed targets emitted as STIX objects or relationships: #{leaked_suppressed.join(', ')}" if leaked_suppressed.any?

  relationships.each_with_index do |relationship, index|
    errors << "#{target_label}: relationship[#{index}].relationship_type must be #{profile.dig('stix_model', 'relationship_type')}" unless relationship['relationship_type'] == profile.dig('stix_model', 'relationship_type')
    errors << "#{target_label}: relationship[#{index}] missing EveryPivot relation #{hop['via']}" unless relationship['x_everypivot_relation'] == hop['via']
    errors << "#{target_label}: relationship[#{index}] source_ref mismatch" unless relationship['source_ref'] == source['stix_ref']
  end

  note = notes.first || {}
  errors << "#{target_label}: generated bundle must contain exactly one note object" unless notes.length == 1
  Array(pattern['hazards']).each do |hazard|
    unless Array(note['x_everypivot_hazards']).include?(hazard) && note['content'].to_s.include?(hazard)
      errors << "#{target_label}: generated note missing pattern hazard: #{hazard}"
    end
  end
  Array(fixture['blocked_assertions']).each do |assertion|
    unless Array(note['x_everypivot_blocked_assertions']).include?(assertion) && note['content'].to_s.include?(assertion)
      errors << "#{target_label}: generated note missing blocked assertion: #{assertion}"
    end
  end
  note_suppressed_targets = expected_ids(note['x_everypivot_suppressed_targets'])
  errors << "#{target_label}: generated note suppressed targets #{note_suppressed_targets.inspect}; expected #{expected_suppressed_targets.inspect}" unless note_suppressed_targets == expected_suppressed_targets
  errors << "#{target_label}: generated note must state live OpenCTI connector boundary" unless note['content'].to_s.include?('no live OpenCTI connector')

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
  errors << "#{profile_id}: profile must be marked as a pilot" unless profile['status'] == 'pilot'
  errors << "#{profile_id}: pattern YAML neutrality flag must be true" unless profile.dig('boundary', 'pattern_yaml_remains_backend_neutral') == true

  backend_name = profile.dig('backend', 'name')
  case backend_name
  when 'neo4j'
    errors << "#{profile_id}: backend.query_language must be cypher" unless profile.dig('backend', 'query_language') == 'cypher'
    errors << "#{profile_id}: profile must document scalar negative-node-list simplification" unless profile.dig('graph_model', 'negative_node_list_cardinality') == 'scalar_pilot_simplification'
  when 'opencti'
    errors << "#{profile_id}: backend.object_model must be stix_2_1" unless profile.dig('backend', 'object_model') == 'stix_2_1'
    errors << "#{profile_id}: backend.artifact_type must be stix_bundle" unless profile.dig('backend', 'artifact_type') == 'stix_bundle'
    errors << "#{profile_id}: backend.integration_kind must be none" unless profile.dig('backend', 'integration_kind') == 'none'
  else
    errors << "#{profile_id}: unsupported backend.name #{backend_name.inspect}"
  end

  targets = Array(profile['targets'])
  errors << "#{profile_id}: profile must declare at least one target" if targets.empty?
  targets.each do |target|
    unless target.is_a?(Hash)
      errors << "#{profile_id}: profile target must be an object"
      next
    end

    checked = case backend_name
              when 'neo4j'
                check_target(repo_root, generator_path, path, profile, target, errors)
              when 'opencti'
                check_stix_target(repo_root, stix_generator_path, path, profile, target, errors)
              end
    checked_targets << checked if checked
  end
end

if errors.empty?
  puts "PASS discovered #{profile_paths.length} adapter/query profile(s)"
  checked_targets.each { |target| puts "PASS #{target} fixture, generated artifact, and semantic boundary checks" }
  exit 0
end

puts 'Query profile suite failures:'
errors.each { |error| puts "  - #{error}" }
exit 1
