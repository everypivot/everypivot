#!/usr/bin/env ruby

require 'json'
require 'optparse'
require 'pathname'

def read_text(path, errors)
  path.read
rescue Errno::ENOENT
  errors << "Missing #{path}"
  ''
end

def parse_json(path, errors)
  JSON.parse(path.read)
rescue Errno::ENOENT
  errors << "Missing #{path}"
  {}
rescue JSON::ParserError => e
  errors << "Invalid JSON in #{path}: #{e.message}"
  {}
end

def parse_registry_js(path, errors)
  text = read_text(path, errors)
  prefix = 'window.__EVERYPIVOT_REGISTRY__ = '

  unless text.start_with?(prefix)
    errors << "#{path} does not start with #{prefix.inspect}"
    return {}
  end

  JSON.parse(text.delete_prefix(prefix).sub(/;\s*\z/, ''))
rescue JSON::ParserError => e
  errors << "Invalid embedded registry JSON in #{path}: #{e.message}"
  {}
end

def first_match(text, pattern)
  match = text.match(pattern)
  match && match[1]
end

def expect_equal(errors, label, actual, expected)
  return if actual == expected

  errors << "#{label}: expected #{expected.inspect}, got #{actual.inspect}"
end

def count_summary(data)
  counts = data['counts'].is_a?(Hash) ? data['counts'] : {}
  {
    'validated' => counts['validated'],
    'working_set' => counts['working_set'],
    'deferred' => counts['deferred'],
    'total' => data['patterns'].is_a?(Array) ? data['patterns'].length : counts.values.compact.map(&:to_i).sum
  }
end

def homepage_snapshot(text, errors)
  noscript = text[/<noscript\b[^>]*>(.*?)<\/noscript>/mi, 1].to_s
  snapshot = {
    'release' => first_match(text, /<span id="release">([^<]+)<\/span>/),
    'schema' => first_match(text, /<span id="schema">([^<]+)<\/span>/),
    'published_at' => first_match(text, /<span id="published">([^<]+)<\/span>/),
    'counts' => {
      'validated' => first_match(text, /<b id="c-validated">([0-9]+)<\/b>/)&.to_i,
      'working_set' => first_match(text, /<b id="c-working">([0-9]+)<\/b>/)&.to_i,
      'deferred' => first_match(text, /<b id="c-deferred">([0-9]+)<\/b>/)&.to_i,
      'total' => first_match(text, /<b id="c-total">([0-9]+)<\/b>/)&.to_i
    },
    'noscript' => {
      'release' => first_match(noscript, /Release ([^,\s]+), published [0-9]{4}-[0-9]{2}-[0-9]{2}/),
      'published_at' => first_match(noscript, /Release [^,\s]+, published ([0-9]{4}-[0-9]{2}-[0-9]{2})/),
      'counts' => {
        'validated' => first_match(noscript, /<b>([0-9]+)<\/b>\s+validated/)&.to_i,
        'working_set' => first_match(noscript, /<b>([0-9]+)<\/b>\s+working set/)&.to_i,
        'deferred' => first_match(noscript, /<b>([0-9]+)<\/b>\s+deferred/)&.to_i,
        'total' => first_match(noscript, /<b>([0-9]+)<\/b>\s+total/)&.to_i
      }
    }
  }

  %w[release schema published_at].each do |field|
    errors << "Homepage is missing #{field}" if snapshot[field].nil?
  end

  snapshot['counts'].each do |lane, count|
    errors << "Homepage is missing #{lane} count" if count.nil?
  end

  snapshot
end

options = {
  repo_root: Pathname(__dir__).join('..').expand_path
}

OptionParser.new do |parser|
  parser.banner = 'Usage: check_site_snapshot.rb [options]'

  parser.on('--repo-root PATH', 'Repository root to check') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end
end.parse!

repo_root = options[:repo_root]
errors = []

artifact_registry = parse_json(repo_root.join('artifacts', 'registry-index.json'), errors)
artifact_manifest = parse_json(repo_root.join('artifacts', 'release-manifest.json'), errors)
site_registry = parse_json(repo_root.join('site', 'data', 'registry-index.json'), errors)
site_registry_js = parse_registry_js(repo_root.join('site', 'data', 'registry-index.js'), errors)
homepage = homepage_snapshot(read_text(repo_root.join('site', 'index.html'), errors), errors)

baseline = artifact_registry
baseline_counts = count_summary(baseline)
baseline_schema = baseline.dig('schema_versions', 'pivot_pattern')

{
  'site/data/registry-index.json' => site_registry,
  'site/data/registry-index.js' => site_registry_js,
  'artifacts/release-manifest.json' => artifact_manifest
}.each do |label, data|
  expect_equal(errors, "#{label} release", data['release'], baseline['release'])
  expect_equal(errors, "#{label} published_at", data['published_at'], baseline['published_at'])
  expect_equal(errors, "#{label} channel", data['channel'], 'stable')

  count_summary(data).each do |lane, count|
    expect_equal(errors, "#{label} counts.#{lane}", count, baseline_counts[lane])
  end
end

expect_equal(errors, 'homepage release', homepage['release'], baseline['release'])
expect_equal(errors, 'homepage published_at', homepage['published_at'], baseline['published_at'])
expect_equal(errors, 'homepage schema', homepage['schema'], baseline_schema)

homepage['counts'].each do |lane, count|
  expect_equal(errors, "homepage counts.#{lane}", count, baseline_counts[lane])
end

expect_equal(errors, 'noscript release', homepage.dig('noscript', 'release'), baseline['release'])
expect_equal(errors, 'noscript published_at', homepage.dig('noscript', 'published_at'), baseline['published_at'])

homepage.dig('noscript', 'counts').each do |lane, count|
  expect_equal(errors, "noscript counts.#{lane}", count, baseline_counts[lane])
end

if errors.any?
  warn 'Site release snapshot agreement check failed:'
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

puts "Homepage release snapshot agrees with registry data for #{baseline['release']}"
