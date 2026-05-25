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

def find_pattern(repo_root, pattern_id)
  Dir.glob(repo_root.join('graph-pivots', '*', "#{pattern_id}.yaml").to_s).first
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
    options[:profile] = Pathname(value).expand_path
  end

  parser.on('--fixture-graph PATH', 'Synthetic fixture graph JSON path') do |value|
    options[:fixture_graph] = Pathname(value).expand_path
  end

  parser.on('--output PATH', 'Write generated Cypher to this path instead of stdout') do |value|
    options[:output] = Pathname(value).expand_path
  end
end.parse!

repo_root = options[:repo_root]
profile_path = options[:profile] || repo_root.join('adapters', 'query-profiles', 'neo4j_cypher_v0.yml')
fixture_path = options[:fixture_graph] || repo_root.join('fixtures', 'query-profiles', 'neo4j', 'osint_ssh_hostkey_cluster.graph.json')
pattern_path = find_pattern(repo_root, options[:pattern_id])

unless pattern_path
  warn "Pattern not found: #{options[:pattern_id]}"
  exit 2
end

profile = YAML.safe_load(profile_path.read, aliases: false)
fixture = JSON.parse(fixture_path.read)
pattern = YAML.safe_load(Pathname(pattern_path).read, aliases: false)

unless profile.dig('backend', 'name') == 'neo4j' && profile.dig('backend', 'query_language') == 'cypher'
  warn "Unsupported profile backend/query language: #{profile_path}"
  exit 2
end

unless Array(profile.dig('scope', 'pattern_ids')).include?(pattern['id'])
  warn "Pattern #{pattern['id']} is not in profile scope #{profile['profile_id']}"
  exit 2
end

unless fixture['pattern_id'] == pattern['id'] && fixture['profile_id'] == profile['profile_id']
  warn "Fixture graph does not match profile #{profile['profile_id']} and pattern #{pattern['id']}"
  exit 2
end

hops = array_value(pattern['hops'])
unless hops.length == 1
  warn "Profile #{profile['profile_id']} supports exactly one hop for this pilot; #{pattern['id']} has #{hops.length}"
  exit 2
end

hop = hops.first || {}
unless hop['direction'] == 'out'
  warn "Profile #{profile['profile_id']} supports only outbound hops for this pilot; #{pattern['id']} uses #{hop['direction'].inspect}"
  exit 2
end

constraints = hash_value(pattern['constraints'])
negative_lists = compact_unique(array_value(constraints['negative_nodes']).map { |node| hash_value(node)['list'] })
window_days = hash_value(constraints['temporal'])['window_days']
unless window_days.is_a?(Integer) && window_days.positive?
  warn "Profile #{profile['profile_id']} requires constraints.temporal.window_days for this pilot"
  exit 2
end
source_forms = form_list(pattern['source'])
target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
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
lines << "MATCH (source:#{node_label} {#{id_property}: source_id})-[edge:#{relationship}]->(target:#{node_label})"
lines << "WHERE source.#{form_property} IN #{cypher_list(source_forms)}"
lines << "  AND target.#{form_property} IN #{cypher_list(target_forms)}"
lines << "  AND date(edge.#{seen_property}) >= as_of - duration({days: #{window_days}})"
lines << "  AND (target.#{negative_node_list_property} IS NULL OR NOT target.#{negative_node_list_property} IN #{cypher_list(negative_lists)})"
lines << 'RETURN {'
lines << "  pattern_id: #{cypher_string(pattern['id'])},"
lines << "  query_profile_id: #{cypher_string(profile['profile_id'])},"
lines << "  source: source.#{id_property},"
lines << "  target: target.#{id_property},"
lines << "  relation: #{cypher_string(hop['via'])},"
lines << "  evidence_paths: [[source.#{id_property}, type(edge), target.#{id_property}]],"
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

if options[:output]
  options[:output].dirname.mkpath
  options[:output].write(query)
else
  print query
end
