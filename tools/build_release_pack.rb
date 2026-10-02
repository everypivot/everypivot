#!/usr/bin/env ruby

require 'digest'
require 'fileutils'
require 'json'
require 'open3'
require 'optparse'
require 'pathname'
require 'rbconfig'
require 'time'
require 'tmpdir'
require_relative 'utf8_text'

module EveryPivot
  module BuildReleasePack
    class BuildError < StandardError; end

    REPO_ROOT = Pathname(Utf8Text.decode(__dir__, path: __FILE__)).join('..').expand_path
    PACK_NAME = 'everypivot-release-pack'
    DEFAULT_RELEASE = 'v0.6.0'
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
      VALIDATION_SEMANTICS.md
      .reachable-history-allowlist
    ].freeze
    # Dotfiles that survive the should_include_file? filter when discovered
    # via directory walks (and that we want listed in the pack manifest's
    # source_files inventory). The reachable-history scanner's allow-list
    # ships so the scanner can be re-run inside an unpacked pack after the
    # consumer initialises a git repo, without false-positive self-matches
    # against its own pattern definitions.
    INCLUDED_DOTFILES = %w[
      .gitignore
      .reachable-history-allowlist
    ].freeze
    ROOT_DIRECTORIES = %w[
      adapters
      contracts
      docs
      graph-pivots
      schemas
      fixtures
    ].freeze
    STABLE_ONLY_DIRECTORIES = %w[
      site
    ].freeze
    TOOL_FILES = %w[
      tools/README.md
      tools/build_registry_index.rb
      tools/build_release_pack.rb
      tools/utf8_text.rb
      tools/test_utf8_text.rb
      tools/test_distribution_eligibility.rb
      tools/check_generated_freshness.rb
      tools/check_reachable_history.rb
      tools/check_relation_catalog.rb
      tools/check_release_metadata.rb
      tools/check_site_links.rb
      tools/check_site_snapshot.rb
      tools/test_build_release_pack.rb
      tools/test_check_reachable_history.rb
      tools/validate_pivots.rb
      tools/check_fixture_suite.rb
      tools/check_cti_promotion_lint.rb
      tools/test_cti_promotion_lint.rb
      tools/check_query_profile_suite.rb
      tools/smoke_neo4j_query_profiles.rb
      tools/accept_neo4j_query_profiles.py
      tools/test_accept_neo4j_query_profiles.py
      tools/generate_query_profile_demo.rb
      tools/generate_stix_mapping_profile_demo.rb
      tools/stix_mapping_validation.rb
      tools/test_stix_mapping_validation.rb
      tools/json_schema_validator.rb
      tools/sail_bridge.rb
      tools/check_sail_bridge.rb
      tools/test_sail_bridge.rb
      tools/test_registry_assessment.rb
      tools/test_site_assessment.js
      tools/pattern_identity.rb
      tools/evidence_consistency.rb
      tools/query_profile_traversal.rb
      tools/test_validation_boundaries.rb
      tools/package_repository_provenance.rb
      tools/test_package_repository_provenance.rb
      tools/semantic_contract.rb
      tools/semantic_records.rb
      tools/semantic_identity.rb
      tools/semantic_time.rb
      tools/semantic_finding.rb
      tools/semantic_amendments.rb
      tools/semantic_result_primitives.rb
      tools/semantic_package_repository.rb
      tools/test_semantic_package_repository.rb
      tools/semantic_certificate_profiles.rb
      tools/test_semantic_certificate_profiles.rb
      tools/semantic_evaluator.rb
      tools/evaluate_semantic_pattern.rb
      tools/test_semantic_contract.rb
      tools/test_semantic_records.rb
      tools/test_semantic_identity.rb
      tools/test_semantic_time.rb
      tools/test_semantic_finding.rb
      tools/test_semantic_amendments.rb
      tools/test_semantic_result_primitives.rb
      tools/test_semantic_result_bindings.rb
      tools/test_semantic_signing.rb
      tools/test_semantic_certificate_expansion.rb
      tools/check_semantic_fixture_hashes.rb
      tools/data/reviewed_semantic_fixture_hashes.json
      tools/test_semantic_sanctions.rb
      tools/test_semantic_extraction.rb
      tools/test_semantic_finding_integration.rb
      tools/test_semantic_evaluator.rb
      tools/test_semantic_execution_primitives.rb
      tools/test_semantic_certificate_presentation.rb
      tools/semantic_neo4j_adapter.rb
      tools/test_semantic_neo4j_adapter.rb
      tools/accept_semantic_neo4j.rb
      tools/test_semantic_authoring_schema.rb
      tools/test_semantic_foundation_adversarial.rb
      tools/check_semantic_suite.rb
      tools/test_semantic_ja3.rb
    ].freeze
    STABLE_SITE_GENERATED_FILES = %w[
      site/data/registry-index.json
      site/data/registry-index.js
      site/data/pattern-sources.js
      site/data/pivot-pattern.schema.json
      site/data/pivot-pattern.schema.js
    ].freeze
    module_function

    # A missing manifest permits a fresh-build date. Malformed declared text
    # remains an input error, rather than silently selecting a different date.
    def default_published_at
      manifest_path = REPO_ROOT.join('artifacts', 'release-manifest.json')
      return Time.now.utc.strftime('%F') unless manifest_path.file?

      JSON.parse(Utf8Text.read(manifest_path)).fetch('published_at') { Time.now.utc.strftime('%F') }
    rescue JSON::ParserError => e
      raise BuildError, "Invalid JSON in #{manifest_path}: #{e.message}"
    end

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
      when 'canonical', 'authoritative'
        'Authoritative public registry pack.'
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
      name = path.basename.to_s
      !name.start_with?('.') || INCLUDED_DOTFILES.include?(name)
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

    def copied_paths_for_mode(artifact_mode)
      paths = ROOT_FILES + ROOT_DIRECTORIES + TOOL_FILES
      paths += STABLE_ONLY_DIRECTORIES if artifact_mode == 'stable'
      paths
    end

    def run_pack_gate!(output_dir, relative_tool, *args)
      run_command!(
        [RbConfig.ruby, output_dir.join(relative_tool).to_s, *args],
        chdir: output_dir
      )
    end

    def build_release_pack(output_dir:, release:, published_at:, force:, artifact_mode:, authority_status:, check_fixtures:)
      if output_dir.exist? && !force
        raise BuildError, "Output directory already exists: #{output_dir}"
      end

      # All copied-input gates and generation complete before replacing an
      # existing pack. A refusal, including --force, preserves its bytes.
      output_dir.parent.mkpath
      Dir.mktmpdir('.everypivot-pack-', output_dir.parent.to_s) do |temporary|
        staging_dir = Pathname(temporary).join('pack')
        manifest = assemble_release_pack(
          output_dir: staging_dir, release: release, published_at: published_at,
          artifact_mode: artifact_mode, authority_status: authority_status,
          check_fixtures: check_fixtures
        )
        backup = Pathname(temporary).join('previous-pack')
        File.rename(output_dir, backup) if output_dir.exist?
        begin
          File.rename(staging_dir, output_dir)
        rescue SystemCallError
          File.rename(backup, output_dir) if backup.exist?
          raise
        end
        manifest
      end
    end

    def assemble_release_pack(output_dir:, release:, published_at:, artifact_mode:, authority_status:, check_fixtures:)
      output_dir.mkpath

      copied_source_files = []
      copied_paths_for_mode(artifact_mode).each do |relative_path|
        copied_source_files.concat(copy_relative_path(relative_path, output_dir))
      end

      run_pack_gate!(output_dir, 'tools/validate_pivots.rb', output_dir.join('graph-pivots').to_s)
      run_pack_gate!(output_dir, 'tools/check_sail_bridge.rb', '--strict-incomplete', '--current-distribution')
      run_pack_gate!(output_dir, 'tools/check_cti_promotion_lint.rb')

      fixture_status = 'not_run'
      if check_fixtures
        run_pack_gate!(output_dir, 'tools/check_fixture_suite.rb')
        fixture_status = 'passed'
      end

      run_pack_gate!(output_dir, 'tools/check_query_profile_suite.rb')
      run_pack_gate!(output_dir, 'tools/test_validation_boundaries.rb')
      run_pack_gate!(output_dir, 'tools/test_package_repository_provenance.rb')
      run_pack_gate!(output_dir, 'tools/check_semantic_suite.rb')
      relation_catalog_status = 'not_run'
      site_gate_status = 'not_applicable'

      artifact_output = output_dir.join('artifacts', artifact_output_name(artifact_mode))
      registry_command = [
        RbConfig.ruby,
        output_dir.join('tools', 'build_registry_index.rb').to_s,
        '--repo-root', output_dir.to_s,
        '--release', release,
        '--published-at', published_at,
        '--output', artifact_output.to_s
      ]
      if artifact_mode == 'stable'
        registry_command.concat(['--site-data-root', output_dir.join('site', 'data').to_s])
      end
      registry_command << '--preview' if artifact_mode == 'preview'
      registry_command << '--edge' if artifact_mode == 'edge'
      run_command!(registry_command, chdir: output_dir)

      run_pack_gate!(output_dir, 'tools/check_relation_catalog.rb')
      relation_catalog_status = 'passed'

      if artifact_mode == 'stable'
        run_pack_gate!(output_dir, 'tools/check_release_metadata.rb')
        run_pack_gate!(output_dir, 'tools/check_generated_freshness.rb')
        run_pack_gate!(output_dir, 'tools/check_site_links.rb')
        run_pack_gate!(output_dir, 'tools/check_site_snapshot.rb')
        site_gate_status = 'passed'
      end

      release_manifest_path = artifact_output.dirname.join(
        derived_variant_name(artifact_output.basename.to_s, 'release-manifest', '.json')
      )
      patterns_bundle_path = artifact_output.dirname.join(
        derived_variant_name(artifact_output.basename.to_s, 'patterns', '.tar.gz')
      )
      fixtures_bundle_path = artifact_output.dirname.join(
        derived_variant_name(artifact_output.basename.to_s, 'fixtures', '.tar.gz')
      )

      registry_index = JSON.parse(Utf8Text.read(artifact_output))
      release_manifest = JSON.parse(Utf8Text.read(release_manifest_path))

      stable_site_generated_paths = STABLE_SITE_GENERATED_FILES.map { |relative_path| output_dir.join(relative_path) }
      copied_source_files -= stable_site_generated_paths if artifact_mode == 'stable'
      source_records = copied_source_files.sort.map { |path| file_record(path, base: output_dir) }
      generated_paths = [artifact_output, release_manifest_path, patterns_bundle_path, fixtures_bundle_path]
      generated_paths.concat(stable_site_generated_paths.select(&:file?)) if artifact_mode == 'stable'
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
          'assessment_bridge' => 'tools/check_sail_bridge.rb',
          'fixture_suite' => 'tools/check_fixture_suite.rb',
          'cti_promotion_lint' => 'tools/check_cti_promotion_lint.rb',
          'query_profile_suite' => 'tools/check_query_profile_suite.rb',
          'neo4j_native_acceptance' => 'tools/accept_neo4j_query_profiles.py',
          'neo4j_acceptance_tests' => 'tools/test_accept_neo4j_query_profiles.py',
          'validation_boundaries' => 'tools/test_validation_boundaries.rb',
          'package_repository_provenance' => 'tools/package_repository_provenance.rb',
          'package_repository_provenance_tests' => 'tools/test_package_repository_provenance.rb',
          'semantic_evaluator' => 'tools/evaluate_semantic_pattern.rb',
          'semantic_synthetic_suite' => 'tools/check_semantic_suite.rb',
          'release_metadata' => 'tools/check_release_metadata.rb',
          'generated_freshness' => 'tools/check_generated_freshness.rb',
          'relation_catalog' => 'tools/check_relation_catalog.rb',
          'site_links' => 'tools/check_site_links.rb',
          'site_snapshot' => 'tools/check_site_snapshot.rb',
          'query_profile_demo_generator' => 'tools/generate_query_profile_demo.rb',
          'stix_mapping_profile_demo_generator' => 'tools/generate_stix_mapping_profile_demo.rb',
          'registry_builder' => 'tools/build_registry_index.rb',
          'release_pack_builder' => 'tools/build_release_pack.rb'
        },
        'license_notice' => 'EveryPivot uses Apache-2.0 for code, schema, tooling, docs, adapters, generated adapter queries, and site assets, and CC BY 4.0 for pattern corpus and fixtures. See LICENSE, LICENSE-CODE, LICENSE-DATA, NOTICE, and TRADEMARK.md.',
        'provenance' => provenance(authority_status),
        'quality_gates' => {
          'validator' => 'passed',
          'assessment_bridge' => 'passed',
          'current_distribution' => 'passed',
          'cti_promotion_lint' => 'passed',
          'fixture_suite' => fixture_status,
          'validation_boundaries' => 'passed',
          'package_repository_provenance' => 'passed',
          'semantic_synthetic_suite' => 'passed',
          'query_profile_suite' => 'passed',
          'relation_catalog' => relation_catalog_status,
          'release_metadata' => artifact_mode == 'stable' ? 'passed' : 'not_applicable',
          'generated_freshness' => artifact_mode == 'stable' ? 'passed' : 'not_applicable',
          'site_links' => site_gate_status,
          'site_snapshot' => site_gate_status
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
      argv = argv.map { |argument| Utf8Text.decode(argument, path: 'command line argument') }
      options = {
        release: DEFAULT_RELEASE,
        published_at: nil,
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

        opt.on('--force', 'Replace an existing pack only after the staged build passes') do
          options[:force] = true
        end
      end

      parser.parse!(argv)
      options[:published_at] ||= default_published_at
      options[:output_dir] ||= default_output_dir(options[:release], options[:artifact_mode])
      options[:output_dir] = Pathname(Utf8Text.decode(options[:output_dir].to_s, path: '--output-dir'))
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
    rescue BuildError, Utf8Text::Error, SystemCallError => e
      warn e.message
      2
    end
  end
end

if $PROGRAM_NAME == __FILE__
  exit EveryPivot::BuildReleasePack.main(ARGV)
end
