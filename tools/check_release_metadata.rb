#!/usr/bin/env ruby

require 'json'
require 'net/http'
require 'optparse'
require 'pathname'
require 'uri'

def read_text(path)
  path.read
rescue Errno::ENOENT
  nil
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
  text = read_text(path)
  unless text
    errors << "Missing #{path}"
    return {}
  end

  prefix = 'window.__EVERYPIVOT_REGISTRY__ = '
  unless text.start_with?(prefix)
    errors << "#{path} does not start with #{prefix.inspect}"
    return {}
  end

  json_text = text.delete_prefix(prefix).sub(/;\s*\z/, '')
  JSON.parse(json_text)
rescue JSON::ParserError => e
  errors << "Invalid embedded registry JSON in #{path}: #{e.message}"
  {}
end

def first_match(text, pattern)
  match = text&.match(pattern)
  match && match[1]
end

def all_matches(text, pattern)
  return [] unless text

  text.scan(pattern).flatten
end

def expect_equal(errors, label, actual, expected)
  return if actual == expected

  errors << "#{label}: expected #{expected.inspect}, got #{actual.inspect}"
end

def expect_includes(errors, label, actual, expected_values)
  return if expected_values.include?(actual)

  errors << "#{label}: expected one of #{expected_values.inspect}, got #{actual.inspect}"
end

def current_counts(repo_root)
  {
    'validated' => Dir.glob(repo_root.join('graph-pivots', 'validated', '*.yaml').to_s).length,
    'working_set' => Dir.glob(repo_root.join('graph-pivots', 'working-set', '*.yaml').to_s).length,
    'deferred' => Dir.glob(repo_root.join('graph-pivots', 'deferred', '*.yaml').to_s).length
  }
end

def release_note_date(repo_root, release)
  notes_path = repo_root.join('docs', 'releases', "#{release}.md")
  text = read_text(notes_path)
  return [nil, "Missing #{notes_path}"] unless text

  heading = first_match(text, /\A# EveryPivot ([^\n]+) Release Notes/)
  return [nil, "#{notes_path}: release-note heading does not name #{release}"] unless heading == release

  date = first_match(text, /^Release date: ([0-9]{4}-[0-9]{2}-[0-9]{2})$/)
  return [nil, "#{notes_path}: missing Release date line"] unless date

  [date, nil]
end

options = {
  repo_root: Pathname(__dir__).join('..').expand_path,
  expected_release: ENV['EXPECTED_RELEASE'],
  print_release: false,
  print_published_at: false,
  probe_live: nil
}

OptionParser.new do |parser|
  parser.banner = 'Usage: check_release_metadata.rb [options]'

  parser.on('--repo-root PATH', 'Repository root to check') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end

  parser.on('--expected-release TAG', 'Require the current release to match TAG') do |value|
    options[:expected_release] = value
  end

  parser.on('--print-release', 'Print the current release after validation') do
    options[:print_release] = true
  end

  parser.on('--print-published-at', 'Print the current published date after validation') do
    options[:print_published_at] = true
  end

  parser.on('--probe-live BASE_URL', 'Probe the live deploy: GET BASE_URL + site.homepage / site.patterns and assert they resolve. 200 passes, 404 fails, 5xx and connection errors are warnings (transient).') do |value|
    options[:probe_live] = value.sub(%r{/\z}, '')
  end
end.parse!

repo_root = options[:repo_root]
errors = []

readme = read_text(repo_root.join('README.md'))
readme_release = first_match(readme, /^- Release: `([^`]+)`$/)
readme_published_at = first_match(readme, /^\s*--published-at ([0-9]{4}-[0-9]{2}-[0-9]{2}) \\?$/)
readme_corpus_count = first_match(readme, /^- Corpus: ([0-9]+) patterns$/)&.to_i
readme_lane_counts = readme&.match(/^- Lanes: ([0-9]+) `validated`, ([0-9]+) `working_set`, ([0-9]+) `deferred`$/)

stable_registry = parse_json(repo_root.join('artifacts', 'registry-index.json'), errors)
stable_manifest = parse_json(repo_root.join('artifacts', 'release-manifest.json'), errors)
site_registry = parse_json(repo_root.join('site', 'data', 'registry-index.json'), errors)
site_registry_js = parse_registry_js(repo_root.join('site', 'data', 'registry-index.js'), errors)

release = readme_release || stable_registry['release']
published_at = readme_published_at || stable_registry['published_at']

if release.nil?
  errors << 'Unable to determine current release from README.md or artifacts/registry-index.json'
end

if published_at.nil?
  errors << 'Unable to determine published date from README.md or artifacts/registry-index.json'
end

errors << 'README.md is missing the Current Release line' unless readme_release
errors << 'README.md build command is missing --published-at' unless readme_published_at

if options[:expected_release] && !options[:expected_release].empty?
  expect_equal(errors, 'expected release', release, options[:expected_release])
end

if release && published_at
  note_date, note_error = release_note_date(repo_root, release)
  errors << note_error if note_error
  expect_equal(errors, "docs/releases/#{release}.md release date", note_date, published_at) if note_date
end

if readme
  release_args = all_matches(readme, /^\s*--release ([^\\\s]+) \\?$/)
  release_args.each do |value|
    expect_equal(errors, 'README.md build --release', value, release)
  end
end

tools_readme = read_text(repo_root.join('tools', 'README.md'))
tool_release_args = all_matches(tools_readme, /--release ([^\s]+)/)
tool_release_args.each do |value|
  expect_includes(errors, 'tools/README.md --release', value, [release, "#{release}-preview"])
end
tool_dates = all_matches(tools_readme, /--published-at ([0-9]{4}-[0-9]{2}-[0-9]{2})/)
tool_dates.each do |value|
  expect_equal(errors, 'tools/README.md --published-at', value, published_at)
end

build_registry = read_text(repo_root.join('tools', 'build_registry_index.rb'))
expect_equal(
  errors,
  'tools/build_registry_index.rb default release',
  first_match(build_registry, /release:\s*'([^']+)'/),
  release
)

build_release_pack = read_text(repo_root.join('tools', 'build_release_pack.rb'))
pack_default = first_match(build_release_pack, /DEFAULT_RELEASE\s*=\s*'([^']+)'/)
expect_equal(errors, 'tools/build_release_pack.rb DEFAULT_RELEASE', pack_default, release)

spec = read_text(repo_root.join('docs', 'REGISTRY_INDEX_SPEC.md'))
expect_equal(errors, 'docs/REGISTRY_INDEX_SPEC.md example release', first_match(spec, /"release": "([^"]+)"/), release)
expect_equal(errors, 'docs/REGISTRY_INDEX_SPEC.md example published_at', first_match(spec, /"published_at": "([^"]+)"/), published_at)

stable_surfaces = {
  'artifacts/registry-index.json' => stable_registry,
  'artifacts/release-manifest.json' => stable_manifest,
  'site/data/registry-index.json' => site_registry,
  'site/data/registry-index.js' => site_registry_js
}

stable_surfaces.each do |label, data|
  expect_equal(errors, "#{label} release", data['release'], release)
  expect_equal(errors, "#{label} published_at", data['published_at'], published_at)
  expect_equal(errors, "#{label} channel", data['channel'], 'stable')
end

expect_equal(
  errors,
  'artifacts/release-manifest.json site.homepage',
  stable_manifest.dig('site', 'homepage'),
  '/'
)
expect_equal(
  errors,
  'artifacts/release-manifest.json site.patterns',
  stable_manifest.dig('site', 'patterns'),
  '/'
)

actual_counts = current_counts(repo_root)
stable_surfaces.each do |label, data|
  actual_counts.each do |lane, count|
    expect_equal(errors, "#{label} counts.#{lane}", data.dig('counts', lane), count)
  end
end

if readme_corpus_count
  expect_equal(errors, 'README.md corpus count', readme_corpus_count, actual_counts.values.sum)
end

if readme_lane_counts
  %w[validated working_set deferred].zip(readme_lane_counts.captures.map(&:to_i)).each do |lane, count|
    expect_equal(errors, "README.md lane count #{lane}", count, actual_counts.fetch(lane))
  end
else
  errors << 'README.md is missing lane counts'
end

site_index = read_text(repo_root.join('site', 'index.html')) || ''
if site_index.match?(%r{github\.com/everypivot/everypivot/blob/v[0-9]})
  errors << 'site/index.html hard-codes a GitHub release tag; use generated registry release metadata instead'
end

if errors.any?
  warn 'Release metadata consistency check failed:'
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

# Live-probe extension. Opt-in via --probe-live BASE_URL.
#
# Asserts the paths declared in the release manifest's site.homepage and
# site.patterns actually resolve on the deployed surface. A manifest that
# advertises a path that 404s on the live deploy is a release defect even
# if the local validators pass, because generated metadata is part of the
# public trust surface.
#
# Distinguishes:
#   200       → pass
#   404 / 3xx → fail (drift between declared and deployed)
#   5xx       → warning (transient server error; not a release defect)
#   network   → warning (transient; not a release defect)
#
# This step runs only when --probe-live is passed, so the static check
# path is unaffected and offline runs continue to work.
def probe_once(url, redirects_left:)
  uri = URI.parse(url)
  Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 15, read_timeout: 15) do |http|
    response = http.head(uri.request_uri)
    case response
    when Net::HTTPSuccess
      { status: response.code.to_i, kind: :pass }
    when Net::HTTPRedirection
      if redirects_left > 0
        probe_once(response['location'], redirects_left: redirects_left - 1)
      else
        { status: response.code.to_i, kind: :fail, reason: 'too many redirects' }
      end
    when Net::HTTPServerError
      { status: response.code.to_i, kind: :warn, reason: 'transient server error' }
    else
      { status: response.code.to_i, kind: :fail, reason: response.message }
    end
  end
rescue StandardError => e
  { status: nil, kind: :warn, reason: "network error: #{e.class}: #{e.message}" }
end

def probe_url(url, retries: 2)
  attempt = 0
  loop do
    result = probe_once(url, redirects_left: 3)
    return result if result[:kind] != :warn || attempt >= retries
    attempt += 1
    sleep(0.5 * (2**(attempt - 1)))
  end
end

if options[:probe_live]
  base = options[:probe_live]
  paths_to_probe = [
    ['site.homepage', stable_manifest.dig('site', 'homepage')],
    ['site.patterns', stable_manifest.dig('site', 'patterns')]
  ].reject { |_, p| p.nil? }

  probe_failures = []
  probe_warnings = []
  paths_to_probe.each do |label, path|
    url = "#{base}#{path}"
    result = probe_url(url)
    case result[:kind]
    when :pass
      puts "  probe pass  #{label}=#{path}  → HTTP #{result[:status]}  #{url}"
    when :fail
      probe_failures << "  probe FAIL  #{label}=#{path}  → HTTP #{result[:status]}  #{url}  (#{result[:reason]})"
    when :warn
      probe_warnings << "  probe warn  #{label}=#{path}  → #{result[:status] || 'no response'}  #{url}  (#{result[:reason]})"
    end
  end

  probe_warnings.each { |w| warn w }
  unless probe_failures.empty?
    warn 'Live-probe drift between manifest and deployed surface:'
    probe_failures.each { |f| warn f }
    exit 1
  end
  puts "Live probe against #{base} passed for #{paths_to_probe.size} path(s)."
end

if options[:print_release]
  puts release
elsif options[:print_published_at]
  puts published_at
else
  puts "Release metadata consistent for #{release} (#{published_at})"
end
