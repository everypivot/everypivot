#!/usr/bin/env ruby

require 'date'
require 'digest/sha1'
require 'json'
require 'optparse'
require 'pathname'
require 'yaml'

STIX_SCO_DET_ID_NAMESPACE = '00abedb4-aa42-466c-9c01-fed23315a9b7'

def array_value(value)
  value.is_a?(Array) ? value : []
end

def hash_value(value)
  value.is_a?(Hash) ? value : {}
end

def compact_unique(values)
  values.compact.map(&:to_s).map(&:strip).reject(&:empty?).uniq
end

def form_list(value)
  value.to_s.split('|').map(&:strip).reject(&:empty?)
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

def opencti_stix_profile?(profile)
  profile.dig('backend', 'name') == 'opencti' &&
    profile.dig('backend', 'object_model') == 'stix_2_1' &&
    profile.dig('backend', 'artifact_type') == 'stix_bundle'
end

def find_profile_target(repo_root, pattern_id, requested_profile_path)
  profile_paths = requested_profile_path ? [requested_profile_path] : query_profile_paths(repo_root)
  matches = []

  profile_paths.each do |profile_path|
    profile = YAML.safe_load(profile_path.read, aliases: false)
    next unless opencti_stix_profile?(profile)

    profile_targets(profile).each do |target|
      matches << [profile_path, profile, target] if target['pattern_id'] == pattern_id
    end
  end

  if matches.empty?
    warn "No OpenCTI/STIX mapping profile target found for pattern #{pattern_id}"
    exit 2
  end

  if matches.length > 1
    profile_ids = matches.map { |profile_path, profile, _target| "#{profile['profile_id']} (#{profile_path})" }
    warn "Multiple OpenCTI/STIX mapping profile targets found for pattern #{pattern_id}: #{profile_ids.join(', ')}"
    exit 2
  end

  matches.first
end

def stix_timestamp(value)
  text = value.to_s
  return text if text.match?(/\A\d{4}-\d{2}-\d{2}T/)

  Date.iso8601(text).strftime('%Y-%m-%dT00:00:00.000Z')
end

def sorted_json_value(value)
  case value
  when Hash
    value.keys.sort.each_with_object({}) { |key, result| result[key] = sorted_json_value(value[key]) }
  when Array
    value.map { |entry| sorted_json_value(entry) }
  else
    value
  end
end

def canonical_json(value)
  JSON.generate(sorted_json_value(value))
end

def uuid_bytes(uuid)
  uuid.delete('-').scan(/../).map { |pair| pair.to_i(16) }.pack('C*')
end

def uuid_v5(namespace, name)
  bytes = Digest::SHA1.digest(uuid_bytes(namespace) + name.to_s.b)
  octets = bytes.bytes.first(16)
  octets[6] = (octets[6] & 0x0f) | 0x50
  octets[8] = (octets[8] & 0x3f) | 0x80
  hex = octets.pack('C*').unpack1('H*')
  [
    hex[0, 8],
    hex[8, 4],
    hex[12, 4],
    hex[16, 4],
    hex[20, 12]
  ].join('-')
end

def chosen_hash(hash_dict)
  hashes = hash_value(hash_dict)
  %w[MD5 SHA-1 SHA-256 SHA3-256 SHA3-512 SHA-512 SSDEEP TLSH].each do |key|
    return { key => hashes[key] } if hashes.key?(key)
  end
  nil
end

def deterministic_file_ref(entry)
  contributing = {}
  hash_value = chosen_hash(entry['hashes'])
  contributing['hashes'] = hash_value if hash_value
  contributing['name'] = entry['name'] unless entry['name'].to_s.empty?
  "file--#{uuid_v5(STIX_SCO_DET_ID_NAMESPACE, canonical_json(contributing))}"
end

def validate_file_ref!(entry, label)
  expected = deterministic_file_ref(entry)
  return expected if entry['stix_ref'] == expected

  warn "#{label} stix_ref must be deterministic UUIDv5 #{expected}; got #{entry['stix_ref'].inspect}"
  exit 2
end

def extension_definition_ref(fixture)
  fixture.dig('stix', 'extension_definition_ref')
end

def extension_definition_config(profile)
  hash_value(profile.dig('stix_model', 'extension_definition'))
end

def add_everypivot_extension(object, fixture)
  extension_ref = extension_definition_ref(fixture)
  return object if extension_ref.to_s.empty?
  return object unless object.keys.any? { |key| key.start_with?('x_everypivot_') }

  extensions = {
    extension_ref => {
      'extension_type' => 'toplevel-property-extension'
    }
  }

  object.merge('extensions' => extensions)
end

def source_or_target_file_object(entry, profile, pattern, fixture)
  object = {
    'type' => 'file',
    'spec_version' => profile.dig('stix_model', 'spec_version') || '2.1',
    'id' => deterministic_file_ref(entry),
    'hashes' => hash_value(entry['hashes'])
  }
  object['name'] = entry['name'] unless entry['name'].to_s.empty?
  object
end

def observed_data_object(source, target, profile, pattern, fixture, hop, window_days)
  seen_at = stix_timestamp(target['seen'])
  object = {
    'type' => 'observed-data',
    'spec_version' => profile.dig('stix_model', 'spec_version') || '2.1',
    'id' => target['observed_data_ref'],
    'created' => fixture['created'],
    'modified' => fixture['created'],
    'first_observed' => seen_at,
    'last_observed' => seen_at,
    'number_observed' => 1,
    'object_refs' => [
      deterministic_file_ref(source),
      deterministic_file_ref(target)
    ],
    'x_everypivot_profile_id' => profile['profile_id'],
    'x_everypivot_pattern_id' => pattern['id'],
    'x_everypivot_fixture_id' => fixture['fixture_id'],
    'x_everypivot_source_id' => source['id'],
    'x_everypivot_target_id' => target['id'],
    'x_everypivot_relation' => hop['via'],
    'x_everypivot_evidence_path' => [
      source['id'],
      hop['via'],
      target['id']
    ],
    'x_everypivot_features' => {
      'path_length' => 1,
      'temporal_window_days' => window_days,
      'source' => target['source']
    }
  }
  add_everypivot_extension(object, fixture)
end

def relationship_object(source, target, profile, pattern, fixture, hop)
  object = {
    'type' => 'relationship',
    'spec_version' => profile.dig('stix_model', 'spec_version') || '2.1',
    'id' => target['relationship_ref'],
    'created' => fixture['created'],
    'modified' => fixture['created'],
    'relationship_type' => profile.dig('stix_model', 'relationship_type') || 'related-to',
    'source_ref' => deterministic_file_ref(source),
    'target_ref' => deterministic_file_ref(target),
    'start_time' => stix_timestamp(target['seen']),
    'description' => "EveryPivot relation #{hop['via']} mapped as STIX related-to for this bounded profile; EveryPivot semantics remain in pattern YAML.",
    'x_everypivot_profile_id' => profile['profile_id'],
    'x_everypivot_pattern_id' => pattern['id'],
    'x_everypivot_fixture_id' => fixture['fixture_id'],
    'x_everypivot_source_id' => source['id'],
    'x_everypivot_target_id' => target['id'],
    'x_everypivot_relation' => hop['via'],
    'x_everypivot_boundary' => 'Generated mapping artifact only; not a live OpenCTI connector, importer, synchronizer, or runtime assessment.'
  }
  add_everypivot_extension(object, fixture)
end

def note_object(source, included_targets, observed_refs, relationship_refs, profile, pattern, fixture)
  hazards = compact_unique(array_value(pattern['hazards']))
  blocked_assertions = compact_unique(array_value(fixture['blocked_assertions']))
  suppressed_targets = array_value(fixture['expected_suppressed_targets'])
  object_refs = [
    deterministic_file_ref(source),
    *included_targets.map { |target| deterministic_file_ref(target) },
    *observed_refs,
    *relationship_refs
  ].compact.uniq

  content_lines = []
  content_lines << "Pattern hazards:"
  hazards.each { |hazard| content_lines << "- #{hazard}" }
  content_lines << ''
  content_lines << 'Blocked assertions:'
  blocked_assertions.each { |assertion| content_lines << "- #{assertion}" }
  content_lines << ''
  content_lines << 'Boundary: generated STIX bundle only; no live OpenCTI connector, importer, score, workflow state, or final assessment.'

  object = {
    'type' => 'note',
    'spec_version' => profile.dig('stix_model', 'spec_version') || '2.1',
    'id' => fixture.dig('stix', 'note_ref'),
    'created' => fixture['created'],
    'modified' => fixture['created'],
    'abstract' => "EveryPivot #{pattern['id']} mapping caveats",
    'content' => content_lines.join("\n"),
    'object_refs' => object_refs,
    'x_everypivot_profile_id' => profile['profile_id'],
    'x_everypivot_pattern_id' => pattern['id'],
    'x_everypivot_fixture_id' => fixture['fixture_id'],
    'x_everypivot_hazards' => hazards,
    'x_everypivot_blocked_assertions' => blocked_assertions,
    'x_everypivot_suppressed_targets' => suppressed_targets,
    'x_everypivot_boundary' => 'Suppressed traversal candidates are documented as fixture metadata only and are not emitted as STIX relationship objects.'
  }
  add_everypivot_extension(object, fixture)
end

def toplevel_extension_definition_object(profile, fixture, objects)
  custom_properties = objects.flat_map do |object|
    object.keys.select { |key| key.start_with?('x_everypivot_') }
  end.uniq.sort
  extension_config = extension_definition_config(profile)

  {
    'type' => 'extension-definition',
    'spec_version' => profile.dig('stix_model', 'spec_version') || '2.1',
    'id' => extension_definition_ref(fixture),
    'created' => fixture['created'],
    'modified' => fixture['created'],
    'name' => extension_config['name'],
    'description' => extension_config['description'],
    'schema' => extension_config['schema_url'],
    'version' => profile['version'].to_s,
    'extension_types' => [
      'toplevel-property-extension'
    ],
    'extension_properties' => custom_properties
  }
end

options = {
  repo_root: Pathname(__dir__).join('..').expand_path,
  pattern_id: 'CTI_SAMPLE_IMPHASH_CLUSTER',
  profile: nil,
  fixture_mapping: nil,
  output: nil
}

OptionParser.new do |parser|
  parser.banner = 'Usage: generate_stix_mapping_profile_demo.rb [options]'

  parser.on('--repo-root PATH', 'Repository root') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end

  parser.on('--pattern-id ID', 'Pattern id to render') do |value|
    options[:pattern_id] = value
  end

  parser.on('--profile PATH', 'OpenCTI/STIX mapping profile YAML path') do |value|
    options[:profile] = Pathname(value)
  end

  parser.on('--fixture-mapping PATH', 'Synthetic STIX mapping fixture JSON path') do |value|
    options[:fixture_mapping] = Pathname(value)
  end

  parser.on('--output PATH', 'Write generated STIX bundle JSON to this path instead of stdout') do |value|
    options[:output] = Pathname(value)
  end
end.parse!

repo_root = options[:repo_root]
requested_profile_path = options[:profile] && repo_path(repo_root, options[:profile])
profile_path, profile, target = find_profile_target(repo_root, options[:pattern_id], requested_profile_path)
fixture_path = options[:fixture_mapping] ? repo_path(repo_root, options[:fixture_mapping]) : repo_path(repo_root, target['fixture_mapping_location'])
output_path = options[:output] && repo_path(repo_root, options[:output])
pattern_path = find_pattern(repo_root, options[:pattern_id])

unless pattern_path
  warn "Pattern not found: #{options[:pattern_id]}"
  exit 2
end

fixture = JSON.parse(fixture_path.read)
pattern = YAML.safe_load(Pathname(pattern_path).read, aliases: false)

unless fixture['pattern_id'] == pattern['id'] && fixture['profile_id'] == profile['profile_id']
  warn "Fixture mapping does not match profile #{profile['profile_id']} and pattern #{pattern['id']}"
  exit 2
end

unless Array(profile.dig('scope', 'lanes')).include?(pattern['validation_state'])
  warn "Pattern #{pattern['id']} lane #{pattern['validation_state']} is not in profile scope #{profile['profile_id']}"
  exit 2
end

shape = hash_value(target['supported_mapping_shape'])
hops = array_value(pattern['hops'])
hop = hash_value(hops.first)
unless shape['hop_count'] == 1 && shape['hop_direction'] == hop['direction'] && hops.length == 1
  warn "Target #{profile['profile_id']}/#{target['pattern_id']} must map exactly the declared one-hop direction"
  exit 2
end

window_days = pattern.dig('constraints', 'temporal', 'window_days')
if shape['temporal_window_required'] && !(window_days.is_a?(Integer) && window_days.positive?)
  warn "Target #{profile['profile_id']}/#{target['pattern_id']} requires constraints.temporal.window_days"
  exit 2
end

source = hash_value(fixture['source'])
targets = array_value(fixture['targets'])
source_forms = form_list(pattern['source'])
target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
if extension_definition_ref(fixture).to_s.empty?
  warn 'Fixture must declare stix.extension_definition_ref for EveryPivot custom properties'
  exit 2
end
extension_config = extension_definition_config(profile)
%w[name description schema_url].each do |field|
  next unless extension_config[field].to_s.empty?

  warn "Profile must declare stix_model.extension_definition.#{field}"
  exit 2
end

unless source_forms.include?(source['form'])
  warn "Fixture source form #{source['form'].inspect} does not match pattern source forms #{source_forms.inspect}"
  exit 2
end

validate_file_ref!(source, 'Fixture source')

targets.each do |target_entry|
  next if target_forms.include?(target_entry['form'])

  warn "Fixture target form #{target_entry['form'].inspect} does not match pattern target forms #{target_forms.inspect}"
  exit 2
end
targets.each_with_index do |target_entry, index|
  validate_file_ref!(target_entry, "Fixture target[#{index}]")
end

included_targets = targets.select { |target_entry| target_entry['include'] == true }
objects = []
objects << source_or_target_file_object(source, profile, pattern, fixture)
included_targets.each do |target_entry|
  objects << source_or_target_file_object(target_entry, profile, pattern, fixture)
end

observed_refs = []
relationship_refs = []
included_targets.each do |target_entry|
  observed_refs << target_entry['observed_data_ref']
  relationship_refs << target_entry['relationship_ref']
  objects << observed_data_object(source, target_entry, profile, pattern, fixture, hop, window_days)
  objects << relationship_object(source, target_entry, profile, pattern, fixture, hop)
end
objects << note_object(source, included_targets, observed_refs, relationship_refs, profile, pattern, fixture)
objects.unshift(toplevel_extension_definition_object(profile, fixture, objects))

bundle = {
  'type' => profile.dig('stix_model', 'bundle_type') || 'bundle',
  'id' => fixture.dig('stix', 'bundle_id'),
  'objects' => objects
}

json = JSON.pretty_generate(bundle) + "\n"

if output_path
  output_path.dirname.mkpath
  output_path.write(json)
else
  print json
end
