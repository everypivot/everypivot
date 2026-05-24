#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'pathname'
require 'rubygems/package'
require 'stringio'
require 'time'
require 'yaml'
require 'zlib'

def compact_text(value)
  return nil if value.nil?

  value.to_s.gsub(/\s+/, ' ').strip
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
      'applies_to' => %w[schemas/ tools/ site/ docs/]
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

options = {
  repo_root: Pathname(__dir__).join('..').expand_path,
  release: 'v0.1.2',
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
pattern_sources = {}
counts = {
  'validated' => 0,
  'working_set' => 0,
  'deferred' => 0
}

lane_dirs.each do |folder, lane_name|
  lane_path = graph_root.join(folder)
  next unless lane_path.directory?

  Dir.glob(lane_path.join('*.yaml').to_s).sort.each do |path|
    raw_yaml = File.read(path)
    data = YAML.safe_load(raw_yaml, aliases: false)
    next unless data.is_a?(Hash)

    counts[lane_name] += 1
    rel_path = Pathname(path).relative_path_from(repo_root).to_s
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
    entry['target'] = compact_text(data['target']) if data['target']
    entry['datasets'] = data['datasets'] if data['datasets'].is_a?(Array)
    entry['hop_count'] = data['hops'].length if data['hops'].is_a?(Array)
    entry['assessment'] = data['assessment'] if data['assessment'].is_a?(Hash)
    entry['hazards'] = data['hazards'] if data['hazards'].is_a?(Array) && !data['hazards'].empty?
    entry['capability_requirements'] = data['capability_requirements'] if data['capability_requirements'].is_a?(Hash) && !data['capability_requirements'].empty?
    entry['review'] = data['review'] if data['review'].is_a?(Hash) && !data['review'].empty?
    entry['controls'] = controls_summary(data)
    entry['presentation'] = presentation_summary(data, entry['controls'])

    patterns << entry
    pattern_sources[data['id']] = raw_yaml if data['id']
  end
end

legal_files_present = LEGAL_BUNDLE_FILES.select { |name| repo_root.join(name).file? }

write_tar_gz(
  patterns_bundle_path,
  repo_root,
  legal_files_present + relative_tree_entries(repo_root, 'graph-pivots')
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
      'patterns' => '/site/patterns.html'
    }
  elsif options[:channel] == 'edge'
    {
      'homepage' => '/edge/',
      'patterns' => '/edge/patterns'
    }
  else
    release_prefix = "/releases/#{options[:release]}"
    {
      'homepage' => "#{release_prefix}/",
      'patterns' => "#{release_prefix}/patterns"
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

schema_versions = {}
if schema_path.file?
  begin
    schema = JSON.parse(File.read(schema_path))
    schema_versions['pivot_pattern'] = schema['title']&.split&.last&.sub(/^v/i, '') || 'unknown'
  rescue JSON::ParserError
    schema_versions['pivot_pattern'] = 'unreadable'
  end
end

index = {
  'registry' => 'everypivot',
  'release' => options[:release],
  'published_at' => options[:published_at],
  'channel' => options[:channel],
  'license' => license_block,
  'schema_versions' => schema_versions,
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
    schema_text = File.read(schema_path)

    site_data_root
      .join(schema_sidecar_json)
      .write(schema_text)

    site_data_root
      .join(schema_sidecar_js)
      .write("window.#{schema_js_variable(output_path)} = #{schema_text};\n")
  end
end

puts "Wrote #{patterns.length} pattern entries to #{output_path}"
