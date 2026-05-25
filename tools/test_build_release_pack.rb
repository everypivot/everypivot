#!/usr/bin/env ruby

require 'json'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'
require 'yaml'

require_relative 'build_release_pack'

class BuildReleasePackTest < Minitest::Test
  REPO_ROOT = Pathname(__dir__).join('..').expand_path

  def count_lane(folder)
    Dir.glob(REPO_ROOT.join('graph-pivots', folder, '*.yaml').to_s).length
  end

  def query_profile_target_paths
    Dir.glob(REPO_ROOT.join('adapters', 'query-profiles', '*.yml').to_s).flat_map do |path|
      profile = YAML.safe_load(Pathname(path).read, aliases: false)
      Array(profile['targets']).flat_map do |target|
        [
          target['generated_query_location'],
          target['fixture_graph_location'],
          target['fixture_load_location']
        ]
      end
    end.compact.sort.uniq
  end

  def assert_query_profile_targets_present(output_dir)
    query_profile_target_paths.each do |relative_path|
      assert output_dir.join(relative_path).file?, "missing query profile target file: #{relative_path}"
    end
  end

  def test_build_release_pack_writes_manifest_and_portable_tooling
    Dir.mktmpdir do |dir|
      output_dir = Pathname(dir).join('everypivot-pack')
      manifest = EveryPivot::BuildReleasePack.build_release_pack(
        output_dir: output_dir,
        release: 'v0.1.1-preview',
        published_at: '2026-05-22',
        force: false,
        artifact_mode: 'preview',
        authority_status: 'canonical_local_preview',
        check_fixtures: true
      )

      assert_equal 'everypivot-release-pack', manifest['name']
      assert_equal 'preview', manifest['artifact_mode']
      assert_equal 'canonical_local_preview', manifest.dig('provenance', 'authority_status')
      assert_includes manifest.dig('provenance', 'note'), 'Canonical local preview'
      assert_equal 'passed', manifest.dig('quality_gates', 'validator')
      assert_equal 'passed', manifest.dig('quality_gates', 'fixture_suite')
      assert_equal 'passed', manifest.dig('quality_gates', 'query_profile_suite')
      assert_equal count_lane('validated'), manifest.dig('counts', 'validated')
      assert_equal count_lane('working-set'), manifest.dig('counts', 'working_set')
      assert_equal count_lane('deferred'), manifest.dig('counts', 'deferred')

      assert output_dir.join('MANIFEST.json').file?
      assert output_dir.join('adapters', 'query-profiles', 'neo4j_cypher_v0.yml').file?
      assert_query_profile_targets_present(output_dir)
      assert output_dir.join('graph-pivots', 'validated').directory?
      refute output_dir.join('graph-pivots', '.DS_Store').exist?
      assert output_dir.join('schemas', 'pivot_pattern.schema.json').file?
      assert output_dir.join('artifacts', 'registry-index.preview.json').file?
      assert output_dir.join('artifacts', 'release-manifest.preview.json').file?
      assert output_dir.join('artifacts', 'patterns.preview.tar.gz').file?
      assert output_dir.join('artifacts', 'fixtures.preview.tar.gz').file?
      assert output_dir.join('tools', 'build_release_pack.rb').file?
      assert output_dir.join('tools', 'build_registry_index.rb').file?
      assert output_dir.join('tools', 'check_release_metadata.rb').file?
      assert output_dir.join('tools', 'check_generated_freshness.rb').file?
      assert output_dir.join('tools', 'check_relation_catalog.rb').file?
      assert output_dir.join('tools', 'check_site_links.rb').file?
      assert output_dir.join('tools', 'check_site_snapshot.rb').file?
      assert output_dir.join('tools', 'test_build_release_pack.rb').file?
      assert output_dir.join('tools', 'check_query_profile_suite.rb').file?
      assert output_dir.join('tools', 'smoke_neo4j_query_profiles.rb').file?
      assert output_dir.join('tools', 'generate_query_profile_demo.rb').file?
      refute output_dir.join('site').exist?
      refute output_dir.join('planning-notes').exist?

      manifest_file = JSON.parse(output_dir.join('MANIFEST.json').read)
      assert_equal manifest['package_id'], manifest_file['package_id']
      assert_equal 'preview', manifest_file['artifact_mode']
      assert_equal 'passed', manifest_file.dig('quality_gates', 'query_profile_suite')
      assert_equal 'passed', manifest_file.dig('quality_gates', 'relation_catalog')
      assert_equal 'not_applicable', manifest_file.dig('quality_gates', 'release_metadata')
      assert_equal 'not_applicable', manifest_file.dig('quality_gates', 'generated_freshness')

      registry_index = JSON.parse(output_dir.join('artifacts', 'registry-index.preview.json').read)
      assert_equal 'preview', registry_index['channel']
      tracking_pattern = registry_index['patterns'].find { |pattern| pattern['id'] == 'OSINT_TRACKING_ID_TO_DOMAINS' }
      assert_equal 'high_cardinality', tracking_pattern['deferred_reason']
      assert_equal true, tracking_pattern.dig('presentation', 'high_cardinality', 'applies')
      assert_equal 'controls_published', tracking_pattern.dig('presentation', 'high_cardinality', 'state')
      assert_equal 3, tracking_pattern.dig('controls', 'negative_node_count')
      assert_equal 10_000, tracking_pattern.dig('controls', 'degree_caps', 'web:tracking:id')

      release_manifest = JSON.parse(output_dir.join('artifacts', 'release-manifest.preview.json').read)
      assert_equal 'preview', release_manifest['channel']
      assert_includes release_manifest.dig('license', 'code', 'applies_to'), 'adapters/'

      validator_stdout, validator_stderr, validator_status = Open3.capture3(
        RbConfig.ruby,
        output_dir.join('tools', 'validate_pivots.rb').to_s,
        output_dir.join('graph-pivots').to_s,
        chdir: output_dir.to_s
      )
      assert validator_status.success?, [validator_stdout, validator_stderr].reject(&:empty?).join("\n")

      rebuilt_index = output_dir.join('artifacts', 'registry-index.rebuilt.preview.json')
      rebuild_stdout, rebuild_stderr, rebuild_status = Open3.capture3(
        RbConfig.ruby,
        output_dir.join('tools', 'build_registry_index.rb').to_s,
        '--repo-root', output_dir.to_s,
        '--release', 'rebuilt-preview',
        '--published-at', '2026-05-22',
        '--output', rebuilt_index.to_s,
        '--preview',
        chdir: output_dir.to_s
      )
      assert rebuild_status.success?, [rebuild_stdout, rebuild_stderr].reject(&:empty?).join("\n")
      assert rebuilt_index.file?
      assert_equal 'preview', JSON.parse(rebuilt_index.read)['channel']

      fixture_stdout, fixture_stderr, fixture_status = Open3.capture3(
        RbConfig.ruby,
        output_dir.join('tools', 'check_fixture_suite.rb').to_s,
        chdir: output_dir.to_s
      )
      assert fixture_status.success?, [fixture_stdout, fixture_stderr].reject(&:empty?).join("\n")

      query_profile_stdout, query_profile_stderr, query_profile_status = Open3.capture3(
        RbConfig.ruby,
        output_dir.join('tools', 'check_query_profile_suite.rb').to_s,
        chdir: output_dir.to_s
      )
      assert query_profile_status.success?, [query_profile_stdout, query_profile_stderr].reject(&:empty?).join("\n")
    end
  end

  def test_canonical_release_pack_omits_nonpublic_provenance_links
    Dir.mktmpdir do |dir|
      output_dir = Pathname(dir).join('everypivot-pack')
      manifest = EveryPivot::BuildReleasePack.build_release_pack(
        output_dir: output_dir,
        release: 'v0.3.0',
        published_at: '2026-05-25',
        force: false,
        artifact_mode: 'stable',
        authority_status: 'canonical',
        check_fixtures: false
      )

      provenance = manifest.fetch('provenance')
      assert_equal 'canonical', provenance.fetch('authority_status')
      assert_equal 'passed', manifest.dig('quality_gates', 'query_profile_suite')
      assert_equal 'passed', manifest.dig('quality_gates', 'relation_catalog')
      assert_equal 'passed', manifest.dig('quality_gates', 'release_metadata')
      assert_equal 'passed', manifest.dig('quality_gates', 'generated_freshness')
      assert_equal 'passed', manifest.dig('quality_gates', 'site_links')
      assert_equal 'passed', manifest.dig('quality_gates', 'site_snapshot')
      assert_includes provenance.fetch('note'), 'canonical EveryPivot repository'
      refute_includes provenance.keys, 'authority_doc'
      refute_includes provenance.keys, 'upstream_references'
      assert output_dir.join('adapters', 'query-profiles', 'neo4j_cypher_v0.yml').file?
      assert_query_profile_targets_present(output_dir)
      assert output_dir.join('site', 'index.html').file?
      assert output_dir.join('site', 'data', 'registry-index.json').file?
      assert output_dir.join('site', 'data', 'registry-index.js').file?
      assert output_dir.join('site', 'data', 'pattern-sources.js').file?
      assert output_dir.join('site', 'data', 'pivot-pattern.schema.json').file?
      assert output_dir.join('site', 'data', 'pivot-pattern.schema.js').file?

      manifest_file = JSON.parse(output_dir.join('MANIFEST.json').read)
      assert_equal 'passed', manifest_file.dig('quality_gates', 'query_profile_suite')
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

      registry_index = JSON.parse(output_path.read)
      assert_equal 'artifacts/patterns.tar.gz', registry_index.dig('artifacts', 'patterns_bundle')
      assert_equal 'artifacts/fixtures.tar.gz', registry_index.dig('artifacts', 'fixtures_bundle')
      assert_equal 'artifacts/release-manifest.json', registry_index.dig('artifacts', 'release_manifest')
      assert_includes registry_index.dig('license', 'code', 'applies_to'), 'adapters/'

      release_manifest = JSON.parse(output_path.dirname.join('release-manifest.json').read)
      assert_includes release_manifest.dig('license', 'code', 'applies_to'), 'adapters/'
      downloads = release_manifest.fetch('downloads').to_h { |item| [item.fetch('name'), item.fetch('path')] }
      assert_equal 'artifacts/registry-index.json', downloads.fetch('registry-index')
      assert_equal 'artifacts/patterns.tar.gz', downloads.fetch('patterns-bundle')
      assert_equal 'artifacts/fixtures.tar.gz', downloads.fetch('fixtures-bundle')
    end
  end
end
