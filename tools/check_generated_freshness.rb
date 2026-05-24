#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'pathname'
require 'rbconfig'
require 'digest'
require 'rubygems/package'
require 'tmpdir'
require 'zlib'

def parse_json(path, errors)
  JSON.parse(path.read)
rescue Errno::ENOENT
  errors << "Missing #{path}"
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
  repo_root: Pathname(__dir__).join('..').expand_path
}

OptionParser.new do |parser|
  parser.banner = 'Usage: check_generated_freshness.rb [options]'

  parser.on('--repo-root PATH', 'Repository root to check') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end
end.parse!

repo_root = options[:repo_root]
errors = []
registry = parse_json(repo_root.join('artifacts', 'registry-index.json'), errors)

release = registry['release']
published_at = registry['published_at']
errors << 'artifacts/registry-index.json is missing release' if release.to_s.empty?
errors << 'artifacts/registry-index.json is missing published_at' if published_at.to_s.empty?

unless errors.empty?
  warn 'Generated data freshness check failed:'
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

Dir.mktmpdir('everypivot-generated-freshness') do |tmp|
  tmp_root = Pathname(tmp)
  output = tmp_root.join('registry-index.json')
  site_data_root = tmp_root.join('site-data')
  builder = repo_root.join('tools', 'build_registry_index.rb')

  ok = system(
    RbConfig.ruby,
    builder.to_s,
    '--repo-root', repo_root.to_s,
    '--release', release,
    '--published-at', published_at,
    '--output', output.to_s,
    '--site-data-root', site_data_root.to_s
  )

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
    compare_file(errors, relative_path, repo_root.join(relative_path), regenerated_path)
  end

  {
    'artifacts/patterns.tar.gz' => tmp_root.join('patterns.tar.gz'),
    'artifacts/fixtures.tar.gz' => tmp_root.join('fixtures.tar.gz')
  }.each do |relative_path, regenerated_path|
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
