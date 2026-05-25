#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'pathname'
require 'yaml'

def array_value(value)
  value.is_a?(Array) ? value : []
end

def hash_value(value)
  value.is_a?(Hash) ? value : {}
end

def compact_unique(values)
  values.compact.map(&:to_s).map(&:strip).reject(&:empty?).uniq
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
  values = array_value(negative_nodes).each_with_object([]) do |node, lists|
    entry = hash_value(node)
    lists << entry['list'] if form_set.include?(entry['form'].to_s)
  end
  compact_unique(values)
end

def repo_path(repo_root, value)
  path = Pathname(value.to_s)
  path.absolute? ? path : repo_root.join(path)
end

def find_pattern(repo_root, pattern_id)
  Dir.glob(repo_root.join('graph-pivots', '*', "#{pattern_id}.yaml").to_s).first
end

def query_profile_paths(repo_root)
  Dir.glob(repo_root.join('adapters', 'query-profiles', '*.yml').to_s).sort.map { |path| Pathname(path) }
end

def profile_targets(profile)
  array_value(profile['targets'])
end

def find_profile_target(repo_root, pattern_id, requested_profile_path)
  profile_paths = requested_profile_path ? [requested_profile_path] : query_profile_paths(repo_root)
  matches = []

  profile_paths.each do |profile_path|
    profile = YAML.safe_load(profile_path.read, aliases: false)
    profile_targets(profile).each do |target|
      matches << [profile_path, profile, target] if target['pattern_id'] == pattern_id
    end
  end

  if matches.empty?
    warn "No query profile target found for pattern #{pattern_id}"
    exit 2
  end

  if matches.length > 1
    profile_ids = matches.map { |profile_path, profile, _target| "#{profile['profile_id']} (#{profile_path})" }
    warn "Multiple query profile targets found for pattern #{pattern_id}: #{profile_ids.join(', ')}"
    exit 2
  end

  matches.first
end

options = {
  repo_root: Pathname(__dir__).join('..').expand_path,
  pattern_id: 'OSINT_SSH_HOSTKEY_CLUSTER',
  profile: nil,
  fixture_graph: nil,
  output: nil
}

OptionParser.new do |parser|
  parser.banner = 'Usage: generate_query_profile_demo.rb [options]'

  parser.on('--repo-root PATH', 'Repository root') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end

  parser.on('--pattern-id ID', 'Pattern id to render') do |value|
    options[:pattern_id] = value
  end

  parser.on('--profile PATH', 'Query profile YAML path') do |value|
    options[:profile] = Pathname(value)
  end

  parser.on('--fixture-graph PATH', 'Synthetic fixture graph JSON path') do |value|
    options[:fixture_graph] = Pathname(value)
  end

  parser.on('--output PATH', 'Write generated Cypher to this path instead of stdout') do |value|
    options[:output] = Pathname(value)
  end
end.parse!

repo_root = options[:repo_root]
requested_profile_path = options[:profile] && repo_path(repo_root, options[:profile])
profile_path, profile, target = find_profile_target(repo_root, options[:pattern_id], requested_profile_path)
fixture_path = options[:fixture_graph] ? repo_path(repo_root, options[:fixture_graph]) : repo_path(repo_root, target['fixture_graph_location'])
output_path = options[:output] && repo_path(repo_root, options[:output])
pattern_path = find_pattern(repo_root, options[:pattern_id])

unless pattern_path
  warn "Pattern not found: #{options[:pattern_id]}"
  exit 2
end

fixture = JSON.parse(fixture_path.read)
pattern = YAML.safe_load(Pathname(pattern_path).read, aliases: false)

unless profile.dig('backend', 'name') == 'neo4j' && profile.dig('backend', 'query_language') == 'cypher'
  warn "Unsupported profile backend/query language: #{profile_path}"
  exit 2
end

unless fixture['pattern_id'] == pattern['id'] && fixture['profile_id'] == profile['profile_id']
  warn "Fixture graph does not match profile #{profile['profile_id']} and pattern #{pattern['id']}"
  exit 2
end

unless Array(profile.dig('scope', 'lanes')).include?(pattern['validation_state'])
  warn "Pattern #{pattern['id']} lane #{pattern['validation_state']} is not in profile scope #{profile['profile_id']}"
  exit 2
end

target_label = "#{profile['profile_id']}/#{target['pattern_id']}"
shape = hash_value(target['supported_pattern_shape'])
unless shape['hop_count'] == 1 && %w[out in].include?(shape['hop_direction']) && shape['temporal_window_required'] == true
  warn "Target #{target_label} must declare the currently supported shape: one inbound or outbound hop with a temporal window"
  exit 2
end

hops = array_value(pattern['hops'])
unless hops.length == shape['hop_count']
  warn "Target #{target_label} supports #{shape['hop_count']} hop(s); #{pattern['id']} has #{hops.length}"
  exit 2
end

hop = hops.first || {}
unless hop['direction'] == shape['hop_direction']
  warn "Target #{target_label} supports #{shape['hop_direction'].inspect} hops; #{pattern['id']} uses #{hop['direction'].inspect}"
  exit 2
end

constraints = hash_value(pattern['constraints'])
window_days = hash_value(constraints['temporal'])['window_days']
if shape['temporal_window_required'] && !(window_days.is_a?(Integer) && window_days.positive?)
  warn "Target #{target_label} requires constraints.temporal.window_days"
  exit 2
end
source_forms = form_list(pattern['source'])
target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
negative_nodes = array_value(constraints['negative_nodes'])
source_negative_lists = negative_lists_for_forms(negative_nodes, source_forms)
target_negative_lists = negative_lists_for_forms(negative_nodes, target_forms)
negative_lists = compact_unique(source_negative_lists + target_negative_lists)
relationship = relation_type(hop['via'], profile.dig('graph_model', 'relationship_type_strategy'))
node_label = profile.dig('graph_model', 'node_label') || 'EveryPivotNode'
id_property = profile.dig('graph_model', 'id_property') || 'id'
form_property = profile.dig('graph_model', 'form_property') || 'form'
negative_node_list_property = profile.dig('graph_model', 'negative_node_list_property') || 'negative_node_list'
seen_property = profile.dig('graph_model', 'relationship_seen_property') || 'seen'
result_alias = profile.dig('outputs', 'result_alias') || 'everypivot_traversal'
parameters = hash_value(fixture['parameters'])
blocked_assertions = compact_unique(array_value(fixture['blocked_assertions']))
hazards = compact_unique(array_value(pattern['hazards']))
match_clause = if hop['direction'] == 'in'
                 "MATCH (source:#{node_label} {#{id_property}: source_id})<-[edge:#{relationship}]-(target:#{node_label})"
               else
                 "MATCH (source:#{node_label} {#{id_property}: source_id})-[edge:#{relationship}]->(target:#{node_label})"
               end
evidence_path = if hop['direction'] == 'in'
                  "[target.#{id_property}, type(edge), source.#{id_property}]"
                else
                  "[source.#{id_property}, type(edge), target.#{id_property}]"
                end

lines = []
lines << '// Generated by tools/generate_query_profile_demo.rb. Do not edit by hand.'
lines << "// Query profile: #{profile['profile_id']}"
lines << "// Pattern: #{pattern['id']}"
lines << '// Boundary: adapter metadata translates traversal mechanics only; pattern YAML remains backend-neutral.'
lines << '// Caveats and blocked assertions are returned with each traversal result.'
lines << ''
lines << ":param source_id => #{cypher_string(parameters['source_id'])};"
lines << ":param as_of => #{cypher_string(parameters['as_of'])};"
lines << ''
lines << 'WITH'
lines << '  $source_id AS source_id,'
lines << '  date($as_of) AS as_of,'
lines << "  #{cypher_list(hazards)} AS pattern_hazards,"
lines << "  #{cypher_list(blocked_assertions)} AS blocked_assertions"
lines << match_clause
lines << "WHERE source.#{form_property} IN #{cypher_list(source_forms)}"
lines << "  AND target.#{form_property} IN #{cypher_list(target_forms)}"
lines << "  AND date(edge.#{seen_property}) >= as_of - duration({days: #{window_days}})"
if source_negative_lists.any?
  lines << "  AND (source.#{negative_node_list_property} IS NULL OR NOT source.#{negative_node_list_property} IN #{cypher_list(source_negative_lists)})"
end
if target_negative_lists.any?
  lines << "  AND (target.#{negative_node_list_property} IS NULL OR NOT target.#{negative_node_list_property} IN #{cypher_list(target_negative_lists)})"
end
lines << 'RETURN {'
lines << "  pattern_id: #{cypher_string(pattern['id'])},"
lines << "  query_profile_id: #{cypher_string(profile['profile_id'])},"
lines << "  source: source.#{id_property},"
lines << "  target: target.#{id_property},"
lines << "  relation: #{cypher_string(hop['via'])},"
lines << "  evidence_paths: [#{evidence_path}],"
lines << '  features: {'
lines << '    path_length: 1,'
lines << "    temporal_window_days: #{window_days},"
lines << "    negative_node_lists_applied: #{cypher_list(negative_lists)}"
lines << '  },'
lines << '  caveats: pattern_hazards,'
lines << '  blocked_assertions: blocked_assertions'
lines << "} AS #{result_alias}"
lines << "ORDER BY target.#{id_property};"
query = lines.join("\n") + "\n"

if output_path
  output_path.dirname.mkpath
  output_path.write(query)
else
  print query
end
