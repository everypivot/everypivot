#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'pathname'
require 'rubygems/package'
require 'stringio'
require 'time'
require 'yaml'
require 'zlib'
require_relative 'sail_bridge'
require_relative 'json_schema_validator'
require_relative 'pattern_identity'
require_relative 'utf8_text'
require_relative 'semantic_contract'

def compact_text(value)
  return nil if value.nil?

  value.to_s.gsub(/\s+/, ' ').strip
end

def semantic_execution(data, contract)
  checked_input = data.select { |key, _| %w[id version pattern_schema_version target execution].include?(key) }
  valid = !contract.nil?
  diagnostic = {
    'status' => valid ? 'contract_valid' : 'not_declared',
    'checked_input' => checked_input,
    'runtime_acceptance' => 'not_evaluated',
    'coverage' => {
      'reference_digest_verified' => valid,
      'pattern_identity_verified' => valid,
      'contract_shape_and_bindings_validated' => valid,
      'runtime_executed' => false,
      'evidence_acceptance_evaluated' => false,
      'assessment_acceptance_evaluated' => false
    }
  }
  return diagnostic unless valid

  diagnostic.merge!(
    'contract_id' => contract['contract'], 'contract_version' => contract['version'],
    'reference_sha256' => data['execution']['sha256'],
    'summary' => {
      'parameters' => contract['parameters'],
      'branches' => contract['branches'].map do |branch|
        item = branch.select { |key, _| %w[id description time_bindings knowledge knowledge_checks finding].include?(key) }
        item['bindings'] = branch['bindings'].map { |binding| binding.select { |key, _| %w[name kind types optional].include?(key) } }
        item['result'] = branch['result'].select { |key, _| %w[mode form binding identity].include?(key) }
        item['policies'] = branch.fetch('policies', []).map { |policy| policy.select { |key, _| %w[id revision scope reason default_enabled enabled_parameter].include?(key) } }
        item
      end
    }
  )
  diagnostic
end

HIGH_CARDINALITY_CAP_THRESHOLD = 100_000

def array_value(value)
  value.is_a?(Array) ? value : []
end

def hash_value(value)
  value.is_a?(Hash) ? value : {}
end

def controls_summary(data)
  constraints = hash_value(data['constraints'])
  temporal = hash_value(constraints['temporal'])
  degree_caps = hash_value(constraints['degree_caps'])
  negative_nodes = array_value(constraints['negative_nodes'])
  provenance = hash_value(constraints['provenance'])

  summary = {}
  summary['temporal_window_days'] = temporal['window_days'] if temporal['window_days']
  summary['degree_caps'] = degree_caps unless degree_caps.empty?
  summary['negative_nodes'] = negative_nodes unless negative_nodes.empty?
  summary['negative_node_count'] = negative_nodes.length
  summary['provenance'] = provenance unless provenance.empty?
  summary
end

def capability_counts(requirements)
  requirements = hash_value(requirements)

  {
    'required' => array_value(requirements['required']).length,
    'optional' => array_value(requirements['optional']).length
  }
end

def high_cardinality_reasons(data, controls)
  reasons = []
  degree_caps = hash_value(controls['degree_caps'])
  max_degree_cap = degree_caps.values.compact.map(&:to_i).max

  if data['deferred_reason'] == 'high_cardinality'
    reasons << 'deferred_reason_high_cardinality'
  end

  if max_degree_cap && max_degree_cap >= HIGH_CARDINALITY_CAP_THRESHOLD
    reasons << 'large_degree_cap'
  end

  reasons
end

def high_cardinality_warnings(data, controls, reasons)
  return [] if reasons.empty?

  warnings = []
  warnings << 'missing_hazard_text' if array_value(data['hazards']).empty?
  warnings << 'missing_degree_caps' if hash_value(controls['degree_caps']).empty?
  warnings << 'missing_negative_nodes' if array_value(controls['negative_nodes']).empty?
  warnings
end

def presentation_summary(data, controls)
  hazards = array_value(data['hazards'])
  capabilities = capability_counts(data['capability_requirements'])
  reasons = high_cardinality_reasons(data, controls)
  warnings = high_cardinality_warnings(data, controls, reasons)

  {
    'hazard_count' => hazards.length,
    'capability_counts' => capabilities,
    'review_status' => hash_value(data['review']).empty? ? 'not_reviewed' : 'reviewed',
    'high_cardinality' => {
      'applies' => !reasons.empty?,
      'state' => reasons.empty? ? 'not_flagged' : (warnings.empty? ? 'controls_published' : 'needs_attention'),
      'reasons' => reasons,
      'warnings' => warnings
    }
  }
end

def derived_variant_name(output_path, prefix, extension)
  suffix = output_path.basename.to_s.sub(/^registry-index/, '').sub(/\.json$/, '')
  suffix = '' if suffix == '.json'
  "#{prefix}#{suffix}#{extension}"
end

def preview_output?(output_path)
  output_path.basename.to_s.match?(/\.(preview|example)\.json$/)
end

def registry_js_variable(_output_path)
  '__EVERYPIVOT_REGISTRY__'
end

def schema_js_variable(_output_path)
  '__EVERYPIVOT_SCHEMA__'
end

def artifact_reference(repo_root, path, fallback_dir: 'artifacts')
  relative_path = path.expand_path.relative_path_from(repo_root.expand_path).to_s
  return File.join(fallback_dir, path.basename.to_s) if relative_path == '..' || relative_path.start_with?("../")

  relative_path
rescue ArgumentError
  File.join(fallback_dir, path.basename.to_s)
end

def relative_tree_entries(repo_root, relative_path)
  target = repo_root.join(relative_path)
  return [] unless target.exist?

  entries = [relative_path]
  return entries unless target.directory?

  Dir.chdir(repo_root) do
    Dir.glob("#{relative_path}/**/*", File::FNM_DOTMATCH).sort.each do |entry|
      segments = Pathname(entry).each_filename.to_a
      next if segments.any? { |segment| segment.start_with?('.') && segment != '.gitignore' }

      entries << entry
    end
  end

  entries.uniq
end

def ensure_parent_directories(tar, seen, repo_root, relative_path)
  parents = Pathname(relative_path).each_filename.to_a[0..-2]
  current = []

  parents.each do |segment|
    current << segment
    directory = current.join('/')
    next if seen[directory]

    tar.mkdir(directory, repo_root.join(directory).stat.mode & 0o777)
    seen[directory] = true
  end
end

LEGAL_BUNDLE_FILES = %w[LICENSE LICENSE-CODE LICENSE-DATA NOTICE TRADEMARK.md].freeze

def license_block
  {
    'copyright' => '© 2026 EveryPivot Project',
    'copyright_holder_notice' =>
      'The named copyright holder and trademark owner is identified in ' \
      'LICENSE, NOTICE, and TRADEMARK.md. "EveryPivot Project" is the ' \
      'designated attribution party for redistribution under CC BY 4.0 ' \
      '§3(a)(1)(A)(i).',
    'code' => {
      'spdx' => 'Apache-2.0',
      'url' => 'LICENSE-CODE',
      'applies_to' => %w[schemas/ tools/ site/ docs/ adapters/]
    },
    'corpus' => {
      'spdx' => 'CC-BY-4.0',
      'url' => 'LICENSE-DATA',
      'applies_to' => %w[graph-pivots/ fixtures/]
    },
    'attribution_required' =>
      'Pattern definitions and tooling from EveryPivot (EveryPivot Project), ' \
      'used under Apache-2.0 (code) and CC BY 4.0 (patterns).',
    'notice_url' => 'NOTICE',
    'license_summary_url' => 'LICENSE',
    'trademark' => {
      'mark' => 'EveryPivot',
      'symbol' => '™',
      'policy_url' => 'TRADEMARK.md',
      'owner_notice' => 'See TRADEMARK.md for the named trademark owner.',
      'note' => 'EveryPivot is a trademark. The license grants above do not ' \
                'include any right to use the EveryPivot name, logo, or ' \
                'other trademarks to identify your own products, services, ' \
                'forks, or competing registries.'
    }
  }
end

def write_tar_gz(archive_path, repo_root, relative_paths)
  archive_path.dirname.mkpath
  buffer = StringIO.new

  Gem::Package::TarWriter.new(buffer) do |tar|
    seen = {}

    relative_paths.each do |relative_path|
      normalized = relative_path.sub(%r{\A\./}, '')
      next if normalized.empty? || seen[normalized]

      ensure_parent_directories(tar, seen, repo_root, normalized)

      absolute_path = repo_root.join(normalized)
      mode = absolute_path.stat.mode & 0o777

      if absolute_path.directory?
        tar.mkdir(normalized, mode)
      else
        tar.add_file(normalized, mode) do |tar_file|
          tar_file.write(File.binread(absolute_path))
        end
      end

      seen[normalized] = true
    end
  end

  buffer.rewind

  File.open(archive_path, 'wb') do |file|
    Zlib::GzipWriter.wrap(file) do |gzip|
      gzip.write(buffer.string)
    end
  end
end

# Ruby's command-line strings can be ASCII-8BIT under the C locale. Paths and
# release labels enter textual manifests, so validate their UTF-8 bytes before
# deriving names or writing archives. Decoding does not transcode the bytes.
begin
  ARGV.replace(ARGV.each_with_index.map do |value, index|
    EveryPivot::Utf8Text.decode(value, path: "command-line argument #{index + 1}")
  end)
  tool_directory = EveryPivot::Utf8Text.decode(__dir__, path: 'tool directory')
rescue EveryPivot::Utf8Text::Error => e
  warn "Registry argument error: #{e.message}"
  exit 2
end

options = {
  repo_root: Pathname(tool_directory).join('..').expand_path,
  release: 'v0.6.0',
  published_at: Time.now.utc.strftime('%F'),
  output: nil,
  site_data_root: nil,
  channel: 'stable'
}

OptionParser.new do |parser|
  parser.banner = 'Usage: build_registry_index.rb [options]'

  parser.on('--repo-root PATH', 'Path to the public EveryPivot repo root') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end

  parser.on('--release TAG', 'Release tag to embed in the index') do |value|
    options[:release] = value
  end

  parser.on('--published-at DATE', 'Published date to embed in the index') do |value|
    options[:published_at] = value
  end

  parser.on('--output PATH', 'Output path for registry-index.json') do |value|
    options[:output] = Pathname(value).expand_path
  end

  parser.on('--site-data-root PATH', 'Optional path for browser-friendly preview data sidecars') do |value|
    options[:site_data_root] = Pathname(value).expand_path
  end

  parser.on('--preview', 'Mark this index as a preview snapshot') do
    options[:channel] = 'preview'
  end

  parser.on('--edge', 'Mark this index as an edge snapshot') do
    options[:channel] = 'edge'
  end
end.parse!

repo_root = options[:repo_root]
graph_root = repo_root.join('graph-pivots')
schema_path = repo_root.join('schemas', 'pivot_pattern.schema.json')
default_output = repo_root.join('artifacts', 'registry-index.json')
output_path = options[:output] || default_output
release_manifest_path = output_path.dirname.join(derived_variant_name(output_path, 'release-manifest', '.json'))
patterns_bundle_path = output_path.dirname.join(derived_variant_name(output_path, 'patterns', '.tar.gz'))
fixtures_bundle_path = output_path.dirname.join(derived_variant_name(output_path, 'fixtures', '.tar.gz'))
preview_paths = preview_output?(output_path)

unless graph_root.directory?
  warn "graph-pivots directory not found under #{repo_root}"
  exit 2
end

lane_dirs = {
  'validated' => 'validated',
  'working-set' => 'working_set',
  'deferred' => 'deferred'
}

patterns = []
begin
  schema_text = EveryPivot::Utf8Text.read(schema_path)
  schema = JSON.parse(schema_text)
  unless schema.is_a?(Hash) && schema['type'] == 'object' &&
         schema['properties'].is_a?(Hash) && schema['required'].is_a?(Array) &&
         schema['required'].any? && schema['additionalProperties'] == false
    raise ArgumentError, 'pattern schema must declare its object properties, required fields, and additionalProperties: false'
  end
  schema_validator = EveryPivot::JsonSchemaValidator.new(schema)
rescue EveryPivot::Utf8Text::Error, SystemCallError, JSON::ParserError, ArgumentError => e
  warn "Pattern schema unavailable: #{e.message}"
  exit 2
end
begin
  bridge_validator = EveryPivot::SailBridge.new(repo_root: repo_root)
rescue EveryPivot::SailBridge::ContractError => e
  warn "Assessment contract unavailable: #{e.message}"
  exit 2
end
validation_errors = []
identity_validator = EveryPivot::PatternIdentity.new
bridge_counts = Hash.new(0)
pattern_sources = {}
counts = {
  'validated' => 0,
  'working_set' => 0,
  'deferred' => 0
}

all_pattern_paths = Dir.glob(graph_root.join('**', '*.yaml').to_s).sort
validation_errors << 'graph-pivots contains no pattern YAML files' if all_pattern_paths.empty?
all_pattern_paths.each do |path|
  file = Pathname(path)
  unless file.parent.parent == graph_root && lane_dirs.key?(file.parent.basename.to_s)
    validation_errors << "#{file.relative_path_from(repo_root)}: pattern is outside a supported lane directory"
  end
end

lane_dirs.each do |folder, lane_name|
  lane_path = graph_root.join(folder)
  next unless lane_path.directory?

  Dir.glob(lane_path.join('*.yaml').to_s).sort.each do |path|
    rel_path = Pathname(path).relative_path_from(repo_root).to_s
    begin
      raw_yaml = EveryPivot::Utf8Text.read(path)
      data = YAML.safe_load(raw_yaml, aliases: false)
    rescue EveryPivot::Utf8Text::Error => e
      validation_errors << "#{rel_path}: #{e.message}"
      next
    rescue Psych::Exception, SystemCallError => e
      validation_errors << "#{rel_path}: YAML read/parse failed: #{e.message}"
      next
    end
    unless data.is_a?(Hash)
      validation_errors << "#{rel_path}: top-level pattern must be a mapping"
      next
    end
    validation_errors.concat(identity_validator.check(data, path: rel_path,
      basename: Pathname(path).basename('.yaml').to_s, lane: lane_name))
    bridge = bridge_validator.check(data, path: rel_path)
    bridge['distribution']['errors'].each do |error|
      validation_errors << "#{rel_path}: #{error['code']}: #{error['message']}"
    end
    schema_errors = schema_validator.validate(data)
    unless schema_errors.empty?
      validation_errors.concat(schema_errors.map { |error| "#{rel_path}: #{error}" })
      next
    end

    execution_contract = nil
    if data['pattern_schema_version'].to_s == '1.6'
      begin
        execution_contract = EveryPivot::SemanticContract.load_reference(data['execution'], data, root: repo_root)
      rescue EveryPivot::SemanticContract::InvalidContract, EveryPivot::SemanticContract::UnsupportedContract => e
        validation_errors << "#{rel_path}: execution contract: #{e.message}"
        next
      end
    end

    counts[lane_name] += 1
    unless bridge['distribution']['eligible']
      validation_errors << "#{rel_path}: #{bridge['status']} assessment bridge"
      (bridge['errors'] + bridge['warnings']).each do |error|
        validation_errors << "#{rel_path}: #{error['code']}: #{error['message']}"
      end
      next
    end
    bridge_counts[bridge['status']] += 1
    summary = compact_text(data['description'])

    entry = {
      'id' => data['id'],
      'lane' => lane_name,
      'category' => data['category'],
      'version' => data['version'],
      'path' => rel_path,
      'summary' => summary
    }

    entry['pattern_schema_version'] = data['pattern_schema_version'] if data['pattern_schema_version']
    entry['precision_tier'] = data['precision_tier'] if data['precision_tier']
    entry['deferred_reason'] = data['deferred_reason'] if lane_name == 'deferred' && data['deferred_reason']
    entry['robustness_class'] = data['robustness_class'] if data['robustness_class']
    entry['name'] = data['name'] if data['name']
    entry['description'] = summary if summary
    entry['source'] = compact_text(data['source']) if data['source']
    entry['target'] = data['target'] if data['target']
    # Exact checked input must retain authoring bytes for fields that bind the
    # semantic declaration; whitespace normalization would stale that check.
    entry['execution'] = data['execution'] if execution_contract
    entry['semantic_execution'] = semantic_execution(data, execution_contract)
    entry['datasets'] = data['datasets'] if data['datasets'].is_a?(Array)
    entry['hop_count'] = data['hops'].length if data['hops'].is_a?(Array)
    entry['assessment'] = data['assessment'] if data['assessment'].is_a?(Hash)
    entry['assessment_mode'] = data['assessment_mode'] if data['assessment_mode']
    entry['assessment_requirements'] = data['assessment_requirements'] if data['assessment_requirements']
    entry['assessment_compatibility'] = {
      'status' => bridge['status'],
      'contract_version' => bridge_validator.contract_info['version'],
      'manifest_sha256' => bridge_validator.contract_info['manifest_sha256'],
      'checked_input' => data.select { |key, _value| %w[pattern_schema_version assessment_mode assessment assessment_requirements].include?(key) },
      'coverage' => bridge['coverage'],
      'warnings' => bridge['warnings']
    }
    entry['hazards'] = data['hazards'] if data['hazards'].is_a?(Array) && !data['hazards'].empty?
    entry['capability_requirements'] = data['capability_requirements'] if data['capability_requirements'].is_a?(Hash) && !data['capability_requirements'].empty?
    entry['review'] = data['review'] if data['review'].is_a?(Hash) && !data['review'].empty?
    entry['controls'] = controls_summary(data)
    entry['presentation'] = presentation_summary(data, entry['controls'])

    patterns << entry
    pattern_sources[data['id']] = raw_yaml if data['id']
  end
end

validation_errors << 'No valid patterns are available for registry generation' if patterns.empty?
unless validation_errors.empty?
  warn 'Registry generation refused invalid patterns or unresolved/incompatible assessment metadata:'
  validation_errors.each { |error| warn "  - #{error}" }
  exit 1
end

legal_files_present = LEGAL_BUNDLE_FILES.select { |name| repo_root.join(name).file? }

write_tar_gz(
  patterns_bundle_path,
  repo_root,
  legal_files_present + relative_tree_entries(repo_root, 'graph-pivots') + relative_tree_entries(repo_root, 'schemas') + relative_tree_entries(repo_root, 'contracts')
)
write_tar_gz(
  fixtures_bundle_path,
  repo_root,
  legal_files_present + relative_tree_entries(repo_root, 'fixtures')
)

release_manifest = {
  'release' => options[:release],
  'channel' => options[:channel],
  'published_at' => options[:published_at],
  'site' => if preview_paths || options[:channel] == 'preview'
    {
      'homepage' => '/site/index.html',
      'patterns' => '/site/index.html'
    }
  elsif options[:channel] == 'edge'
    {
      'homepage' => '/edge/',
      'patterns' => '/edge/'
    }
  else
    {
      'homepage' => '/',
      'patterns' => '/'
    }
  end,
  'downloads' => [
    {
      'name' => 'registry-index',
      'path' => artifact_reference(repo_root, output_path)
    },
    {
      'name' => 'patterns-bundle',
      'path' => artifact_reference(repo_root, patterns_bundle_path)
    },
    {
      'name' => 'fixtures-bundle',
      'path' => artifact_reference(repo_root, fixtures_bundle_path)
    },
    {
      'name' => 'schema',
      'path' => schema_path.relative_path_from(repo_root).to_s
    },
    {
      'name' => 'validator',
      'path' => 'tools/validate_pivots.rb'
    }
  ],
  'counts' => counts,
  'license' => license_block
}

release_manifest_path.write(JSON.pretty_generate(release_manifest) + "\n")

schema_versions = {'pivot_pattern' => schema['title']&.split&.last&.sub(/^v/i, '') || 'unknown'}

index = {
  'registry' => 'everypivot',
  'release' => options[:release],
  'published_at' => options[:published_at],
  'channel' => options[:channel],
  'license' => license_block,
  'schema_versions' => schema_versions,
  'assessment_contract' => bridge_validator.contract_info,
  'assessment_coverage' => bridge_counts,
  'counts' => counts,
  'patterns' => patterns,
  'artifacts' => {
    'schema' => schema_path.relative_path_from(repo_root).to_s,
    'patterns_bundle' => artifact_reference(repo_root, patterns_bundle_path),
    'fixtures_bundle' => artifact_reference(repo_root, fixtures_bundle_path),
    'release_manifest' => artifact_reference(repo_root, release_manifest_path),
    'license_summary' => 'LICENSE',
    'license_code' => 'LICENSE-CODE',
    'license_data' => 'LICENSE-DATA',
    'notice' => 'NOTICE',
    'trademark_policy' => 'TRADEMARK.md'
  }
}

output_path.dirname.mkpath
output_path.write(JSON.pretty_generate(index) + "\n")

if options[:site_data_root]
  site_data_root = options[:site_data_root]
  site_data_root.mkpath
  registry_sidecar_json = derived_variant_name(output_path, 'registry-index', '.json')
  registry_sidecar_js = derived_variant_name(output_path, 'registry-index', '.js')
  pattern_sources_sidecar_js = derived_variant_name(output_path, 'pattern-sources', '.js')
  schema_sidecar_json = derived_variant_name(output_path, 'pivot-pattern.schema', '.json')
  schema_sidecar_js = derived_variant_name(output_path, 'pivot-pattern.schema', '.js')

  site_data_root
    .join(registry_sidecar_json)
    .write(JSON.pretty_generate(index) + "\n")

  site_data_root
    .join(registry_sidecar_js)
    .write("window.#{registry_js_variable(output_path)} = #{JSON.pretty_generate(index)};\n")

  site_data_root
    .join(pattern_sources_sidecar_js)
    .write("window.__EVERYPIVOT_PATTERN_SOURCES__ = #{JSON.pretty_generate(pattern_sources)};\n")

  if schema_path.file?
    site_data_root
      .join(schema_sidecar_json)
      .write(schema_text)

    site_data_root
      .join(schema_sidecar_js)
      .write("window.#{schema_js_variable(output_path)} = #{schema_text};\n")
  end
end

puts "Wrote #{patterns.length} pattern entries to #{output_path}"
