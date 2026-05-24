#!/usr/bin/env ruby

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'pathname'
require 'rbconfig'
require 'time'

module EveryPivot
  module BuildReleasePack
    class BuildError < StandardError; end

    REPO_ROOT = Pathname(__dir__).join('..').expand_path
    PACK_NAME = 'everypivot-release-pack'
    DEFAULT_RELEASE = 'v0.2.0'
    DEFAULT_PUBLISHED_AT = Time.now.utc.strftime('%F')
    DEFAULT_ARTIFACT_MODE = 'stable'
    DEFAULT_AUTHORITY_STATUS = 'canonical'
    ROOT_FILES = %w[
      README.md
      CHANGELOG.md
      CONTRIBUTING.md
      CODE_OF_CONDUCT.md
      SECURITY.md
      LICENSE
      LICENSE-CODE
      LICENSE-DATA
      NOTICE
      TRADEMARK.md
    ].freeze
    ROOT_DIRECTORIES = %w[
      docs
      graph-pivots
      schemas
      fixtures
    ].freeze
    TOOL_FILES = %w[
      tools/README.md
      tools/build_registry_index.rb
      tools/build_release_pack.rb
      tools/check_release_metadata.rb
      tools/validate_pivots.rb
      tools/check_fixture_suite.rb
      tools/json_schema_validator.rb
    ].freeze
    module_function

    def slugify(text)
      text.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/\A-+|-+\z/, '')
    end

    def package_id(release, artifact_mode)
      slug = slugify(release)
      slug = "#{slug}-#{artifact_mode}" unless slug.include?(artifact_mode)
      "#{PACK_NAME}-#{slug}"
    end

    def default_output_dir(release, artifact_mode)
      REPO_ROOT.join('dist', package_id(release, artifact_mode))
    end

    def authority_note(authority_status)
      case authority_status
      when 'preview_mirror_with_local_extensions'
        'Preview distribution surface with local extensions. Provenance must stay explicit.'
      when 'preview_mirror'
        'Preview distribution surface built before canonical publication.'
      when 'canonical_local_preview'
        'Canonical local preview distribution for validating release contents before emitting stable artifacts.'
      when 'canonical'
        'Authoritative public registry pack emitted from the canonical EveryPivot repository.'
      when 'authoritative'
        'Authoritative public registry pack emitted after the canonical ownership handoff.'
      else
        "Authority status declared as `#{authority_status}`."
      end
    end

    def provenance(authority_status)
      {
        'authority_status' => authority_status,
        'note' => authority_note(authority_status)
      }
    end

    def artifact_output_name(artifact_mode)
      case artifact_mode
      when 'preview'
        'registry-index.preview.json'
      when 'stable'
        'registry-index.json'
      when 'edge'
        'registry-index.edge.json'
      else
        raise BuildError, "Unknown artifact mode: #{artifact_mode}"
      end
    end

    def derived_variant_name(output_name, prefix, extension)
      suffix = output_name.sub(/^registry-index/, '').sub(/\.json$/, '')
      suffix = '' if suffix == '.json'
      "#{prefix}#{suffix}#{extension}"
    end

    def should_include_file?(path)
      !path.basename.to_s.start_with?('.') || path.basename.to_s == '.gitignore'
    end

    def walk_files(path)
      return [] unless path.exist?
      return [path] if path.file? && should_include_file?(path)

      Dir.glob(path.join('**', '*').to_s, File::FNM_DOTMATCH).sort.each_with_object([]) do |entry, files|
        candidate = Pathname(entry)
        next unless candidate.file?
        next unless should_include_file?(candidate)

        files << candidate
      end
    end

    def copy_relative_path(relative_path, destination_root)
      source = REPO_ROOT.join(relative_path)
      destination = destination_root.join(relative_path)
      raise BuildError, "Missing source path: #{source}" unless source.exist?

      FileUtils.mkdir_p(destination.parent)
      if source.directory?
        walk_files(source).each do |source_file|
          destination_file = destination.join(source_file.relative_path_from(source))
          FileUtils.mkdir_p(destination_file.parent)
          FileUtils.cp(source_file, destination_file, preserve: true)
        end
      else
        FileUtils.cp(source, destination, preserve: true)
      end
      walk_files(destination)
    end

    def sha256_file(path)
      Digest::SHA256.file(path).hexdigest
    end

    def file_record(path, base:)
      {
        'path' => path.relative_path_from(base).to_s,
        'size_bytes' => path.size,
        'sha256' => sha256_file(path)
      }
    end

    def combined_digest(records)
      digest = Digest::SHA256.new
      records.sort_by { |record| record['path'] }.each do |record|
        digest << record['path'] << "\0" << record['sha256'] << "\0"
      end
      digest.hexdigest
    end

    def run_command!(command, chdir:)
      stdout, stderr, status = Open3.capture3(*command, chdir: chdir.to_s)
      return stdout if status.success?

      details = [stdout, stderr].reject(&:empty?).join("\n")
      raise BuildError, "Command failed (#{status.exitstatus}): #{command.join(' ')}\n#{details}"
    end

    def build_release_pack(output_dir:, release:, published_at:, force:, artifact_mode:, authority_status:, check_fixtures:)
      if output_dir.exist?
        raise BuildError, "Output directory already exists: #{output_dir}" unless force

        FileUtils.remove_entry(output_dir)
      end
      output_dir.mkpath

      copied_source_files = []
      (ROOT_FILES + ROOT_DIRECTORIES + TOOL_FILES).each do |relative_path|
        copied_source_files.concat(copy_relative_path(relative_path, output_dir))
      end

      validator_command = [
        RbConfig.ruby,
        output_dir.join('tools', 'validate_pivots.rb').to_s,
        output_dir.join('graph-pivots').to_s
      ]
      run_command!(validator_command, chdir: output_dir)

      fixture_status = 'not_run'
      if check_fixtures
        fixture_command = [
          RbConfig.ruby,
          output_dir.join('tools', 'check_fixture_suite.rb').to_s
        ]
        run_command!(fixture_command, chdir: output_dir)
        fixture_status = 'passed'
      end

      artifact_output = output_dir.join('artifacts', artifact_output_name(artifact_mode))
      registry_command = [
        RbConfig.ruby,
        output_dir.join('tools', 'build_registry_index.rb').to_s,
        '--repo-root', output_dir.to_s,
        '--release', release,
        '--published-at', published_at,
        '--output', artifact_output.to_s
      ]
      registry_command << '--preview' if artifact_mode == 'preview'
      registry_command << '--edge' if artifact_mode == 'edge'
      run_command!(registry_command, chdir: output_dir)

      release_manifest_path = artifact_output.dirname.join(
        derived_variant_name(artifact_output.basename.to_s, 'release-manifest', '.json')
      )
      patterns_bundle_path = artifact_output.dirname.join(
        derived_variant_name(artifact_output.basename.to_s, 'patterns', '.tar.gz')
      )
      fixtures_bundle_path = artifact_output.dirname.join(
        derived_variant_name(artifact_output.basename.to_s, 'fixtures', '.tar.gz')
      )

      registry_index = JSON.parse(artifact_output.read)
      release_manifest = JSON.parse(release_manifest_path.read)

      source_records = copied_source_files.sort.map { |path| file_record(path, base: output_dir) }
      generated_paths = [artifact_output, release_manifest_path, patterns_bundle_path, fixtures_bundle_path]
      generated_records = generated_paths.map { |path| file_record(path, base: output_dir) }

      manifest = {
        'name' => PACK_NAME,
        'package_id' => package_id(release, artifact_mode),
        'release' => release,
        'published_at' => published_at,
        'artifact_mode' => artifact_mode,
        'layout_version' => 1,
        'source_root' => '.',
        'tool_entrypoints' => {
          'validator' => 'tools/validate_pivots.rb',
          'fixture_suite' => 'tools/check_fixture_suite.rb',
          'registry_builder' => 'tools/build_registry_index.rb',
          'release_pack_builder' => 'tools/build_release_pack.rb'
        },
        'license_notice' => 'EveryPivot uses Apache-2.0 for code, schema, tooling, docs, and site assets, and CC BY 4.0 for pattern corpus and fixtures. See LICENSE, LICENSE-CODE, LICENSE-DATA, NOTICE, and TRADEMARK.md.',
        'provenance' => provenance(authority_status),
        'quality_gates' => {
          'validator' => 'passed',
          'fixture_suite' => fixture_status
        },
        'schema_versions' => registry_index['schema_versions'],
        'counts' => registry_index['counts'],
        'release_artifacts' => {
          'registry_index' => artifact_output.relative_path_from(output_dir).to_s,
          'release_manifest' => release_manifest_path.relative_path_from(output_dir).to_s,
          'patterns_bundle' => patterns_bundle_path.relative_path_from(output_dir).to_s,
          'fixtures_bundle' => fixtures_bundle_path.relative_path_from(output_dir).to_s,
          'schema' => registry_index.dig('artifacts', 'schema'),
          'validator' => release_manifest.fetch('downloads').find { |item| item['name'] == 'validator' }['path']
        },
        'source_files' => source_records,
        'generated_files' => generated_records,
        'source_digest' => combined_digest(source_records),
        'generated_digest' => combined_digest(generated_records)
      }

      output_dir.join('MANIFEST.json').write(JSON.pretty_generate(manifest) + "\n")
      manifest
    end

    def parse_args(argv)
      options = {
        release: DEFAULT_RELEASE,
        published_at: DEFAULT_PUBLISHED_AT,
        artifact_mode: DEFAULT_ARTIFACT_MODE,
        authority_status: DEFAULT_AUTHORITY_STATUS,
        force: false,
        check_fixtures: true
      }

      parser = OptionParser.new do |opt|
        opt.banner = 'Usage: build_release_pack.rb [options]'

        opt.on('--output-dir PATH', 'Directory to write the assembled release pack into') do |value|
          options[:output_dir] = Pathname(value).expand_path
        end

        opt.on('--release TAG', 'Release tag to embed in the pack metadata') do |value|
          options[:release] = value
        end

        opt.on('--published-at DATE', 'Published date to embed in the pack metadata') do |value|
          options[:published_at] = value
        end

        opt.on('--artifact-mode MODE', 'Artifact mode: preview, stable, or edge') do |value|
          options[:artifact_mode] = value
        end

        opt.on('--authority-status STATUS', 'Provenance status for the pack manifest') do |value|
          options[:authority_status] = value
        end

        opt.on('--check-fixtures', 'Run the fixture suite inside the copied pack before emitting artifacts') do
          options[:check_fixtures] = true
        end

        opt.on('--skip-fixtures', 'Skip the fixture suite inside the copied pack and record the gate as not_run') do
          options[:check_fixtures] = false
        end

        opt.on('--force', 'Overwrite the output directory if it already exists') do
          options[:force] = true
        end
      end

      parser.parse!(argv)
      options[:output_dir] ||= default_output_dir(options[:release], options[:artifact_mode])
      [options, parser]
    end

    def main(argv = ARGV)
      options, parser = parse_args(argv)
      unless %w[preview stable edge].include?(options[:artifact_mode])
        warn parser.to_s
        raise BuildError, "Unsupported artifact mode: #{options[:artifact_mode]}"
      end

      manifest = build_release_pack(
        output_dir: options[:output_dir],
        release: options[:release],
        published_at: options[:published_at],
        force: options[:force],
        artifact_mode: options[:artifact_mode],
        authority_status: options[:authority_status],
        check_fixtures: options[:check_fixtures]
      )
      puts JSON.pretty_generate(
        {
          output_dir: options[:output_dir].to_s,
          package_id: manifest['package_id'],
          artifact_mode: manifest['artifact_mode']
        }
      )
      0
    rescue BuildError => e
      warn e.message
      2
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit EveryPivot::BuildReleasePack.main(ARGV)
end
