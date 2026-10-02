#!/usr/bin/env ruby

require 'digest'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'
require 'yaml'

require_relative 'build_release_pack'

class BuildReleasePackTest < Minitest::Test
  REPO_ROOT = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: __FILE__)).join('..').expand_path

  def available_test_locales
    available, status = Open3.capture2('locale', '-a')
    assert status.success?, 'Cannot discover available locales'
    utf8 = available.lines.map(&:strip).find { |name| name.downcase.delete('-_.') == 'enusutf8' } ||
           available.lines.map(&:strip).find { |name| name.downcase.delete('-_.') == 'cutf8' }
    ['C', utf8].compact
  end

  def count_lane(folder)
    Dir.glob(REPO_ROOT.join('graph-pivots', folder, '*.yaml').to_s).length
  end

  def query_profile_target_paths
    Dir.glob(REPO_ROOT.join('adapters', 'query-profiles', '*.yml').to_s).flat_map do |path|
      profile = YAML.safe_load(EveryPivot::Utf8Text.read(path), aliases: false)
      Array(profile['targets']).flat_map do |target|
        [
          target['generated_query_location'],
          target['fixture_graph_location'],
          target['fixture_load_location'],
          target['generated_bundle_location'],
          target['fixture_mapping_location']
        ]
      end
    end.compact.sort.uniq
  end

  def assert_query_profile_targets_present(output_dir)
    query_profile_target_paths.each do |relative_path|
      assert output_dir.join(relative_path).file?, "missing query profile target file: #{relative_path}"
    end
  end

  def assert_package_repository_provenance_assets_present(output_dir, manifest)
    fixture_paths = Dir.glob(REPO_ROOT.join('fixtures', 'package-repository-provenance', '**', '*.json').to_s)
                       .map { |path| Pathname(path).relative_path_from(REPO_ROOT).to_s }
    refute_empty fixture_paths, 'package/repository provenance sidecars must ship with the checker'
    required_paths = %w[
      tools/package_repository_provenance.rb
      tools/test_package_repository_provenance.rb
      schemas/package_repository_provenance.v1.schema.json
    ] + fixture_paths
    source_records = manifest.fetch('source_files').to_h { |record| [record.fetch('path'), record] }
    required_paths.each do |relative_path|
      packed_path = output_dir.join(relative_path)
      assert packed_path.file?, "missing packaged provenance dependency: #{relative_path}"
      assert_equal REPO_ROOT.join(relative_path).binread, packed_path.binread,
                   "packaged provenance dependency differs: #{relative_path}"
      assert_equal Digest::SHA256.file(packed_path).hexdigest, source_records.fetch(relative_path).fetch('sha256'),
                   "provenance dependency missing or incorrectly hashed in manifest: #{relative_path}"
    end
  end

  def test_canonical_release_pack_has_self_contained_provenance
    metadata = JSON.parse(REPO_ROOT.join('artifacts/registry-index.json').read)
    Dir.mktmpdir do |dir|
      output_dir = Pathname(dir).join('everypivot-pack')
      manifest = EveryPivot::BuildReleasePack.build_release_pack(
        output_dir: output_dir,
        release: metadata.fetch('release'),
        published_at: metadata.fetch('published_at'),
        force: false,
        artifact_mode: 'stable',
        authority_status: 'canonical',
        check_fixtures: false
      )

      provenance = manifest.fetch('provenance')
      assert_equal 'canonical', provenance.fetch('authority_status')
      assert_equal 'passed', manifest.dig('quality_gates', 'current_distribution')
      assert_equal 'passed', manifest.dig('quality_gates', 'cti_promotion_lint')
      assert_equal 'passed', manifest.dig('quality_gates', 'query_profile_suite')
      assert_equal 'passed', manifest.dig('quality_gates', 'validation_boundaries')
      assert_equal 'passed', manifest.dig('quality_gates', 'package_repository_provenance')
      assert_equal 'tools/package_repository_provenance.rb', manifest.dig('tool_entrypoints', 'package_repository_provenance')
      assert_equal 'tools/test_package_repository_provenance.rb', manifest.dig('tool_entrypoints', 'package_repository_provenance_tests')
      assert_package_repository_provenance_assets_present(output_dir, manifest)
      %w[pattern_identity.rb evidence_consistency.rb query_profile_traversal.rb test_validation_boundaries.rb utf8_text.rb test_utf8_text.rb test_distribution_eligibility.rb accept_neo4j_query_profiles.py test_accept_neo4j_query_profiles.py].each do |name|
        assert output_dir.join('tools', name).file?, "missing packaged validation dependency: #{name}"
      end
      assert_equal 'tools/accept_neo4j_query_profiles.py', manifest.dig('tool_entrypoints', 'neo4j_native_acceptance')
      assert output_dir.join('fixtures/query-profiles/neo4j/acceptance/OSINT_SSH_HOSTKEY_CLUSTER.json').file?
      assert output_dir.join('VALIDATION_SEMANTICS.md').file?
      assert_equal 'passed', manifest.dig('quality_gates', 'relation_catalog')
      assert_equal 'passed', manifest.dig('quality_gates', 'release_metadata')
      assert_equal 'passed', manifest.dig('quality_gates', 'generated_freshness')
      assert_equal 'passed', manifest.dig('quality_gates', 'site_links')
      assert_equal 'passed', manifest.dig('quality_gates', 'site_snapshot')
      assert_includes provenance.fetch('note'), 'Authoritative public registry pack'
      refute_includes provenance.keys, 'authority_doc'
      refute_includes provenance.keys, 'upstream_references'
      assert output_dir.join('adapters', 'query-profiles', 'neo4j_cypher_v0.yml').file?
      assert output_dir.join('adapters', 'query-profiles', 'opencti_stix_v0.yml').file?
      assert output_dir.join('adapters', 'opencti', 'schemas', 'x_everypivot_toplevel_extension.schema.json').file?
      assert_query_profile_targets_present(output_dir)
      assert output_dir.join('site', 'index.html').file?
      assert output_dir.join('site', 'data', 'registry-index.json').file?
      assert output_dir.join('site', 'data', 'registry-index.js').file?
      assert output_dir.join('site', 'data', 'pattern-sources.js').file?
      assert output_dir.join('site', 'data', 'pivot-pattern.schema.json').file?
      assert output_dir.join('site', 'data', 'pivot-pattern.schema.js').file?

      manifest_file = JSON.parse(EveryPivot::Utf8Text.read(output_dir.join('MANIFEST.json')))
      assert_equal 'passed', manifest_file.dig('quality_gates', 'cti_promotion_lint')
      assert_equal 'passed', manifest_file.dig('quality_gates', 'query_profile_suite')
      assert_equal 'passed', manifest_file.dig('quality_gates', 'package_repository_provenance')
      assert_equal 'passed', manifest_file.dig('quality_gates', 'release_metadata')
      assert_equal 'passed', manifest_file.dig('quality_gates', 'generated_freshness')
      refute_includes manifest_file.fetch('provenance').keys, 'authority_doc'
      refute_includes manifest_file.fetch('provenance').keys, 'upstream_references'

      release_metadata_stdout, release_metadata_stderr, release_metadata_status = Open3.capture3(
        RbConfig.ruby,
        output_dir.join('tools', 'check_release_metadata.rb').to_s,
        chdir: output_dir.to_s
      )
      assert release_metadata_status.success?, [release_metadata_stdout, release_metadata_stderr].reject(&:empty?).join("\n")

      freshness_stdout, freshness_stderr, freshness_status = Open3.capture3(
        RbConfig.ruby,
        output_dir.join('tools', 'check_generated_freshness.rb').to_s,
        chdir: output_dir.to_s
      )
      assert freshness_status.success?, [freshness_stdout, freshness_stderr].reject(&:empty?).join("\n")
    end
  end

  def test_registry_builder_uses_portable_artifact_references_outside_repo
    Dir.mktmpdir do |dir|
      output_path = Pathname(dir).join('registry-index.json')
      stdout, stderr, status = Open3.capture3(
        RbConfig.ruby,
        REPO_ROOT.join('tools', 'build_registry_index.rb').to_s,
        '--repo-root', REPO_ROOT.to_s,
        '--release', 'v0.1.1',
        '--published-at', '2026-05-22',
        '--output', output_path.to_s
      )
      assert status.success?, [stdout, stderr].reject(&:empty?).join("\n")

      registry_index = JSON.parse(EveryPivot::Utf8Text.read(output_path))
      assert_equal 'artifacts/patterns.tar.gz', registry_index.dig('artifacts', 'patterns_bundle')
      assert_equal 'artifacts/fixtures.tar.gz', registry_index.dig('artifacts', 'fixtures_bundle')
      assert_equal 'artifacts/release-manifest.json', registry_index.dig('artifacts', 'release_manifest')
      assert_includes registry_index.dig('license', 'code', 'applies_to'), 'adapters/'

      release_manifest = JSON.parse(EveryPivot::Utf8Text.read(output_path.dirname.join('release-manifest.json')))
      assert_includes release_manifest.dig('license', 'code', 'applies_to'), 'adapters/'
      downloads = release_manifest.fetch('downloads').to_h { |item| [item.fetch('name'), item.fetch('path')] }
      assert_equal 'artifacts/registry-index.json', downloads.fetch('registry-index')
      assert_equal 'artifacts/patterns.tar.gz', downloads.fetch('patterns-bundle')
      assert_equal 'artifacts/fixtures.tar.gz', downloads.fetch('fixtures-bundle')
    end
  end

  def with_pack_source
    Dir.mktmpdir('pack-refusal-') do |directory|
      source = Pathname(directory).join('source')
      EveryPivot::BuildReleasePack.copied_paths_for_mode('stable').each do |relative|
        EveryPivot::BuildReleasePack.copy_relative_path(relative, source)
      end
      EveryPivot::BuildReleasePack.copy_relative_path('artifacts/release-manifest.json', source)
      yield source, Pathname(directory).join('existing-pack')
    end
  end

  def pack_command(source, destination, mode)
    [RbConfig.ruby, source.join('tools/build_release_pack.rb').to_s,
     '--output-dir', destination.to_s, '--artifact-mode', mode,
     '--published-at', '2026-09-10', '--force']
  end

  def assert_preserved_pack(destination, expected)
    actual = Dir.glob(destination.join('**', '*').to_s).select { |name| File.file?(name) }
                .to_h { |name| [Pathname(name).relative_path_from(destination).to_s, File.binread(name)] }
    assert_equal expected, actual
  end

  def write_pack_sentinels(destination)
    expected = {'registry.json' => "existing JSON\n", 'registry.js' => "existing JavaScript\n",
                'patterns.tar.gz' => "\x1f\x8b\x00\xff".b}
    destination.mkpath
    expected.each { |name, bytes| destination.join(name).binwrite(bytes) }
    expected
  end

  def test_force_preserves_existing_pack_on_mixed_legacy_distribution_refusal
    with_pack_source do |source, destination|
      pattern_path = source.join('graph-pivots/working-set/ADTECH_AD_REQUEST_TO_INFECTION_HIT.yaml')
      pattern = YAML.safe_load(EveryPivot::Utf8Text.read(pattern_path), aliases: false)
      pattern['pattern_schema_version'] = 1.4
      pattern.delete('assessment_mode')
      pattern.delete('assessment_requirements')
      pattern_path.write(YAML.dump(pattern))
      expected = write_pack_sentinels(destination)
      %w[stable preview edge].each do |mode|
        stdout, stderr, status = Open3.capture3({'LANG' => 'C', 'LC_ALL' => 'C'}, *pack_command(source, destination, mode))
        refute status.success?, "legacy #{mode} pack unexpectedly published"
        assert_includes stdout + stderr, 'migration_required'
        assert_preserved_pack(destination, expected)
        assert_empty Dir.glob(destination.parent.join('.everypivot-pack-*').to_s)
      end
      absent = destination.parent.join('new-pack')
      _, stderr, status = Open3.capture3(*pack_command(source, absent, 'stable'))
      refute status.success?, stderr
      refute absent.exist?, 'refused build published a partial pack'
    end
  end

  def test_force_preserves_existing_pack_on_invalid_utf8
    with_pack_source do |source, destination|
      pattern_path = source.join('graph-pivots/working-set/ADTECH_AD_REQUEST_TO_INFECTION_HIT.yaml')
      pattern_path.binwrite(pattern_path.binread + "\n# truncated: \xf0\x9f\x98".b)
      expected = write_pack_sentinels(destination)
      available_test_locales.each do |locale|
        stdout, stderr, status = Open3.capture3({'LANG' => locale, 'LC_ALL' => locale}, *pack_command(source, destination, 'stable'))
        refute status.success?, 'invalid UTF-8 pack unexpectedly published'
        assert_includes stdout + stderr, 'Invalid UTF-8'
        assert_includes stdout + stderr, pattern_path.basename.to_s
        assert_preserved_pack(destination, expected)
      end
    end
  end

  def test_malformed_default_manifest_is_a_controlled_error
    with_pack_source do |source, destination|
      manifest_path = source.join('artifacts/release-manifest.json')
      expected = write_pack_sentinels(destination)
      {"{\"published_at\":\"\xff\"}".b => 'Invalid UTF-8', '{broken JSON' => 'Invalid JSON'}.each do |bytes, diagnostic|
        manifest_path.binwrite(bytes)
        available_test_locales.each do |locale|
          stdout, stderr, status = Open3.capture3({'LANG' => locale, 'LC_ALL' => locale}, RbConfig.ruby,
            source.join('tools/build_release_pack.rb').to_s, '--output-dir', destination.to_s, '--force')
          assert_equal 2, status.exitstatus
          assert_includes stdout + stderr, diagnostic
          assert_includes stdout + stderr, 'release-manifest.json'
          refute_includes stdout + stderr, "in `"
          assert_preserved_pack(destination, expected)
        end
      end
    end
  end

  def test_invalid_utf8_pack_arguments_preserve_existing_output
    Dir.mktmpdir('pack-arguments-') do |directory|
      destination = Pathname(directory).join('existing-pack')
      expected = write_pack_sentinels(destination)
      {"release-\xff".b => 'Invalid UTF-8', "\uFEFFrelease" => 'UTF-8 BOM is not permitted'}.each do |release, diagnostic|
        available_test_locales.each do |locale|
          stdout, stderr, status = Open3.capture3({'LANG' => locale, 'LC_ALL' => locale}, RbConfig.ruby,
            REPO_ROOT.join('tools/build_release_pack.rb').to_s, '--output-dir', destination.to_s,
            '--published-at', '2026-09-10', '--force', '--release', release)
          assert_equal 2, status.exitstatus
          assert_includes stdout + stderr, diagnostic
          assert_preserved_pack(destination, expected)
          assert_empty Dir.glob(destination.parent.join('.everypivot-pack-*').to_s)
        end
      end
    end
  end
end
