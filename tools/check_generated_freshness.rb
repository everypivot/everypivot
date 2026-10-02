#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'pathname'
require 'rbconfig'
require 'digest'
require 'rubygems/package'
require 'tmpdir'
require 'zlib'
require_relative 'utf8_text'

def parse_json(path, errors)
  JSON.parse(EveryPivot::Utf8Text.read(path))
rescue Errno::ENOENT
  errors << "Missing #{path}"
  {}
rescue EveryPivot::Utf8Text::Error => e
  errors << e.message
  {}
rescue JSON::ParserError => e
  errors << "Invalid JSON in #{path}: #{e.message}"
  {}
end

def compare_file(errors, label, expected, actual)
  unless expected.file?
    errors << "Missing committed #{label}: #{expected}"
    return
  end

  unless actual.file?
    errors << "Generated #{label} was not produced: #{actual}"
    return
  end

  return if expected.binread == actual.binread

  errors << "#{label} is stale; committed #{expected} differs from regenerated #{actual}"
end

def tar_gz_manifest(path, errors, label)
  unless path.file?
    errors << "Missing #{label}: #{path}"
    return []
  end

  entries = []
  Zlib::GzipReader.open(path.to_s) do |gzip|
    Gem::Package::TarReader.new(gzip) do |tar|
      tar.each do |entry|
        item = {
          'path' => entry.full_name,
          'type' => entry.directory? ? 'directory' : 'file',
          'mode' => entry.header.mode
        }

        if entry.file?
          contents = entry.read
          item['size'] = contents.bytesize
          item['sha256'] = Digest::SHA256.hexdigest(contents)
        end

        entries << item
      end
    end
  end

  entries.sort_by { |entry| [entry['path'], entry['type']] }
rescue Zlib::GzipFile::Error, Gem::Package::TarInvalidError, EOFError => e
  errors << "Invalid tar.gz for #{label}: #{e.message}"
  []
end

def compare_tar_gz_content(errors, label, expected, actual)
  expected_manifest = tar_gz_manifest(expected, errors, "committed #{label}")
  actual_manifest = tar_gz_manifest(actual, errors, "regenerated #{label}")
  return if expected_manifest == actual_manifest

  expected_by_key = expected_manifest.to_h { |entry| [[entry['path'], entry['type']], entry] }
  actual_by_key = actual_manifest.to_h { |entry| [[entry['path'], entry['type']], entry] }
  missing = expected_by_key.keys - actual_by_key.keys
  extra = actual_by_key.keys - expected_by_key.keys
  changed = (expected_by_key.keys & actual_by_key.keys).select do |key|
    expected_by_key[key] != actual_by_key[key]
  end

  details = []
  details << "missing regenerated entries: #{missing.map(&:first).sort.first(5).join(', ')}" if missing.any?
  details << "extra regenerated entries: #{extra.map(&:first).sort.first(5).join(', ')}" if extra.any?
  details << "changed entries: #{changed.map(&:first).sort.first(5).join(', ')}" if changed.any?
  errors << "#{label} content is stale; #{details.join('; ')}"
end

options = {
  repo_root: Pathname(EveryPivot::Utf8Text.decode(__dir__, path: __FILE__)).join('..').expand_path,
  preview: false
}

OptionParser.new do |parser|
  parser.banner = 'Usage: check_generated_freshness.rb [options]'

  parser.on('--repo-root PATH', 'Repository root to check') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end
  parser.on('--preview', 'Check candidate preview artifacts instead of the stable release snapshot') do
    options[:preview] = true
  end
end.parse!

repo_root = options[:repo_root]
errors = []
suffix = options[:preview] ? '.preview' : ''
registry_name = "registry-index#{suffix}.json"
registry = parse_json(repo_root.join('artifacts', registry_name), errors)

release = registry['release']
published_at = registry['published_at']
errors << "#{registry_name} is missing release" if release.to_s.empty?
errors << "#{registry_name} is missing published_at" if published_at.to_s.empty?
expected_channel = options[:preview] ? 'preview' : 'stable'
errors << "#{registry_name} must use channel #{expected_channel}" unless registry['channel'] == expected_channel

unless errors.empty?
  warn 'Generated data freshness check failed:'
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

Dir.mktmpdir('everypivot-generated-freshness') do |tmp|
  tmp_root = Pathname(tmp)
  output = tmp_root.join(registry_name)
  site_data_root = tmp_root.join('site-data')
  builder = repo_root.join('tools', 'build_registry_index.rb')

  command = [
    RbConfig.ruby,
    builder.to_s,
    '--repo-root', repo_root.to_s,
    '--release', release,
    '--published-at', published_at,
    '--output', output.to_s,
    '--site-data-root', site_data_root.to_s
  ]
  command << '--preview' if options[:preview]
  ok = system(*command)

  unless ok
    warn 'Generated data freshness check failed: registry build command failed'
    exit 1
  end

  {
    'artifacts/registry-index.json' => output,
    'artifacts/release-manifest.json' => tmp_root.join('release-manifest.json'),
    'site/data/registry-index.json' => site_data_root.join('registry-index.json'),
    'site/data/registry-index.js' => site_data_root.join('registry-index.js'),
    'site/data/pattern-sources.js' => site_data_root.join('pattern-sources.js'),
    'site/data/pivot-pattern.schema.json' => site_data_root.join('pivot-pattern.schema.json'),
    'site/data/pivot-pattern.schema.js' => site_data_root.join('pivot-pattern.schema.js')
  }.each do |relative_path, regenerated_path|
    relative_path = relative_path.sub(/\.(json|js)$/, "#{suffix}.\\1")
    regenerated_path = Pathname(regenerated_path.to_s.sub(/\.(json|js)$/, "#{suffix}.\\1")) unless regenerated_path == output
    compare_file(errors, relative_path, repo_root.join(relative_path), regenerated_path)
  end

  {
    'artifacts/patterns.tar.gz' => tmp_root.join('patterns.tar.gz'),
    'artifacts/fixtures.tar.gz' => tmp_root.join('fixtures.tar.gz')
  }.each do |relative_path, regenerated_path|
    relative_path = relative_path.sub(/\.tar\.gz$/, "#{suffix}.tar.gz")
    regenerated_path = Pathname(regenerated_path.to_s.sub(/\.tar\.gz$/, "#{suffix}.tar.gz"))
    compare_tar_gz_content(errors, relative_path, repo_root.join(relative_path), regenerated_path)
  end
end

if errors.any?
  warn 'Generated data freshness check failed:'
  errors.each { |error| warn "  - #{error}" }
  warn 'Regenerate committed public data with tools/build_registry_index.rb using the current release metadata.'
  exit 1
end

puts "Generated data fresh for #{release} (#{published_at})"
