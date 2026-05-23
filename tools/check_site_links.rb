#!/usr/bin/env ruby

require 'fileutils'
require 'optparse'
require 'pathname'
require 'tmpdir'
require 'uri'

STAGED_ARTIFACTS = %w[
  registry-index.json
  release-manifest.json
  patterns.tar.gz
  fixtures.tar.gz
].freeze

EXPECTED_HOMEPAGE_LINKS = %w[
  ./data/pivot-pattern.schema.json
  ./artifacts/registry-index.json
  ./artifacts/patterns.tar.gz
  ./artifacts/fixtures.tar.gz
].freeze

PREVIEW_LEAK_MARKERS = %w[
  __EVERYPIVOT_PREVIEW__
  __EVERYPIVOT_PATTERN_SOURCES__
  registry-index.preview
  pattern-sources
].freeze

def local_url?(value)
  return false if value.empty? || value.start_with?('#', '//')

  uri = URI.parse(value)
  !uri.absolute? && !value.start_with?('mailto:', 'tel:', 'javascript:')
rescue URI::InvalidURIError
  true
end

def strip_query_and_fragment(value)
  value.split(/[?#]/, 2).first.to_s
end

def under_root?(root, path)
  relative = path.expand_path.relative_path_from(root.expand_path).to_s
  relative != '..' && !relative.start_with?("../")
rescue ArgumentError
  false
end

def resolve_target(root, source_file, raw_value)
  local_path = strip_query_and_fragment(raw_value)
  return nil if local_path.empty?

  if local_path.start_with?('/')
    root.join(local_path.delete_prefix('/')).cleanpath
  else
    source_file.dirname.join(local_path).cleanpath
  end
end

def copy_site_to_staging(repo_root, staging_parent)
  FileUtils.cp_r(repo_root.join('site'), staging_parent)
  staging_root = staging_parent.join('site')
  artifact_root = staging_root.join('artifacts')
  artifact_root.mkpath

  STAGED_ARTIFACTS.each do |name|
    FileUtils.cp(repo_root.join('artifacts', name), artifact_root.join(name))
  end

  staging_root
end

options = {
  repo_root: Pathname(__dir__).join('..').expand_path
}

OptionParser.new do |parser|
  parser.banner = 'Usage: check_site_links.rb [options]'

  parser.on('--repo-root PATH', 'Repository root to check') do |value|
    options[:repo_root] = Pathname(value).expand_path
  end
end.parse!

repo_root = options[:repo_root]
errors = []

Dir.mktmpdir('everypivot-site-link-audit') do |tmp|
  staging_parent = Pathname(tmp)
  staging_root = copy_site_to_staging(repo_root, staging_parent)
  homepage = staging_root.join('index.html')
  homepage_text = homepage.read

  STAGED_ARTIFACTS.each do |name|
    staged = staging_root.join('artifacts', name)
    errors << "Missing staged artifact #{staged}" unless staged.file?
  end

  EXPECTED_HOMEPAGE_LINKS.each do |href|
    errors << "Homepage is missing release artifact link #{href}" unless homepage_text.include?("href=\"#{href}\"")
  end

  noscript = homepage_text[/<noscript\b[^>]*>(.*?)<\/noscript>/mi, 1]
  if noscript.nil?
    errors << 'Homepage is missing noscript fallback'
  else
    EXPECTED_HOMEPAGE_LINKS.each do |href|
      errors << "Noscript fallback is missing #{href}" unless noscript.include?("href=\"#{href}\"")
    end
  end

  PREVIEW_LEAK_MARKERS.each do |marker|
    errors << "Homepage references preview-only data marker #{marker}" if homepage_text.include?(marker)
  end

  Dir.glob(staging_root.join('**', '*.html').to_s).sort.each do |html_path|
    source_file = Pathname(html_path)
    relative_source = source_file.relative_path_from(staging_root).to_s
    text = source_file.read

    text.scan(/\b(href|src)\s*=\s*(['"])(.*?)\2/i) do |attribute, _quote, raw_value|
      next unless local_url?(raw_value)

      local_path = strip_query_and_fragment(raw_value)
      next if local_path.empty?

      if local_path.split('/').include?('..')
        errors << "#{relative_source}: #{attribute}=#{raw_value.inspect} contains a .. path segment"
        next
      end

      target = resolve_target(staging_root, source_file, raw_value)
      unless target && under_root?(staging_root, target)
        errors << "#{relative_source}: #{attribute}=#{raw_value.inspect} escapes the Pages publish root"
        next
      end

      next if target.file? || target.directory?

      relative_target = target.relative_path_from(staging_root).to_s
      errors << "#{relative_source}: #{attribute}=#{raw_value.inspect} points to missing #{relative_target}"
    end
  end
end

if errors.any?
  warn 'Static site link audit failed:'
  errors.each { |error| warn "  - #{error}" }
  exit 1
end

puts 'Static site links resolve under the staged Pages publish root'
