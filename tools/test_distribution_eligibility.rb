#!/usr/bin/env ruby
# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'
require 'yaml'
require_relative 'sail_bridge'
require_relative 'utf8_text'

class DistributionEligibilityTest < Minitest::Test
  ROOT = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: 'test directory')).join('..').expand_path
  CHANNELS = {stable: [], preview: ['--preview'], edge: ['--edge']}.freeze

  def setup
    @checker = EveryPivot::SailBridge.new(repo_root: ROOT)
  end

  # Independently constructed contract cases, not transformed historic fixtures.
  def evidence
    {'id' => 'CTI_DISTRIBUTION_TEST', 'name' => 'Observation lookup', 'version' => '1.0.0',
     'pattern_schema_version' => 1.5, 'assessment_mode' => 'evidence_only',
     'validation_state' => 'working_set', 'category' => 'CTI',
     'precision_tier' => 'low', 'robustness_class' => 'enumeration',
     'source' => 'file:bytes', 'target' => 'risk:incident',
     'description' => 'Retain an observed incident association for review.',
     'hazards' => ['An observation does not establish incident acceptance.'],
     'constraints' => {'provenance' => {'min_unique_sources' => 1}},
     'hops' => [{'via' => 'observed_in', 'direction' => 'out', 'form' => 'risk:incident'}]}
  end

  def candidate
    evidence.merge('assessment_mode' => 'candidate_assessment',
      'assessment' => {'claim' => 'indicates', 'basis' => 'assessed', 'scope' => 'incident_level',
        'subject_role' => 'observation', 'object_role' => 'incident'},
      'assessment_requirements' => ['Independently corroborate the incident association and review contradictions.'])
  end

  def legacy(version = 1.4)
    candidate.reject { |key, _value| %w[assessment_mode assessment_requirements].include?(key) }
      .merge('pattern_schema_version' => version)
  end

  def invalid_current_cases
    cases = {}
    cases['mode_absent'] = candidate.reject { |key, _value| key == 'assessment_mode' }
    [nil, 'unknown', false, [], {}].each_with_index { |mode, index| cases["mode_invalid_#{index}"] = candidate.merge('assessment_mode' => mode) }
    cases['version_absent'] = candidate.reject { |key, _value| key == 'pattern_schema_version' }
    [nil, '9.9', '', false, [], {}].each_with_index { |version, index| cases["version_invalid_#{index}"] = candidate.merge('pattern_schema_version' => version) }
    cases['requirements_absent'] = candidate.reject { |key, _value| key == 'assessment_requirements' }
    [nil, [], [''], ['  '], [nil], 'Corroborate', [1]].each_with_index do |requirements, index|
      cases["requirements_invalid_#{index}"] = candidate.merge('assessment_requirements' => requirements)
    end
    cases['hint_absent'] = candidate.reject { |key, _value| key == 'assessment' }
    cases['hint_null'] = candidate.merge('assessment' => nil)
    cases['evidence_hint_null'] = evidence.merge('assessment' => nil)
    cases['evidence_hint_complete'] = evidence.merge('assessment' => candidate['assessment'])
    [nil, [], ['Documented']].each_with_index { |requirements, index| cases["evidence_requirements_#{index}"] = evidence.merge('assessment_requirements' => requirements) }
    cases['illegal_subject_scope'] = candidate.merge('assessment' => candidate['assessment'].merge('scope' => 'campaign_level'))
    cases['illegal_object'] = candidate.merge('assessment' => candidate['assessment'].merge('object_role' => 'tool'))
    cases['unknown_kind_cannot_hide_legal_role'] = candidate.merge('assessment' => candidate['assessment'].merge('object_kind' => 'nonsense'))
    cases['null_subject_is_not_absent'] = candidate.merge('assessment' => candidate['assessment'].merge('subject_role' => nil))
    cases['subject_absent'] = candidate.merge('assessment' => candidate['assessment'].reject { |key, _value| key == 'subject_role' })
    cases
  end

  def with_registry(rows, unicode: false)
    dir = Dir.mktmpdir(unicode ? 'everypivot-distribution-é漢😀-' : 'everypivot-distribution-')
    root = Pathname(EveryPivot::Utf8Text.decode(dir, path: 'temporary test directory'))
    FileUtils.cp_r(ROOT.join('schemas'), root.join('schemas'))
    root.join('graph-pivots', 'working-set').mkpath
    root.join('fixtures').mkpath
    rows.each do |row|
      root.join('graph-pivots', 'working-set', "#{row['id']}.yaml").write(YAML.dump(row))
    end
    yield root
  ensure
    remove_test_tree(dir) if dir && File.exist?(dir)
  end

  # Ruby 2.6 FileUtils traversal mixes path and directory-entry encodings.
  # Fixture cleanup is a byte-based filesystem operation in either locale.
  def remove_test_tree(path)
    bytes = path.to_s.b
    if File.lstat(bytes).directory?
      Dir.foreach(bytes, encoding: Encoding::BINARY) do |name|
        next if name == '.' || name == '..'
        remove_test_tree(File.join(bytes, name.b))
      end
      Dir.rmdir(bytes)
    else
      File.unlink(bytes)
    end
  end

  def run_tool(name, *args)
    Open3.capture3(RbConfig.ruby, ROOT.join('tools', name).to_s, *args.map(&:to_s))
  end

  def seed_outputs(root, channel)
    suffix = channel == :stable ? '' : ".#{channel}"
    paths = %W[artifacts/registry-index#{suffix}.json artifacts/release-manifest#{suffix}.json artifacts/patterns#{suffix}.tar.gz artifacts/fixtures#{suffix}.tar.gz site-data/registry-index#{suffix}.json site-data/registry-index#{suffix}.js site-data/pattern-sources#{suffix}.js site-data/pivot-pattern.schema#{suffix}.json site-data/pivot-pattern.schema#{suffix}.js]
    paths.to_h do |relative|
      path = root.join(relative)
      path.dirname.mkpath
      bytes = "EXISTING\x00\xff #{relative}".b
      path.binwrite(bytes)
      [path, bytes]
    end
  end

  def build(root, channel)
    suffix = channel == :stable ? '' : ".#{channel}"
    run_tool('build_registry_index.rb', '--repo-root', root, '--release', 'test-distribution',
      '--published-at', '2026-09-15', '--output', root.join('artifacts', "registry-index#{suffix}.json"),
      '--site-data-root', root.join('site-data'), *CHANNELS.fetch(channel))
  end

  def assert_preserved(before)
    before.each { |path, bytes| assert_equal bytes, path.binread, path.to_s }
  end

  def test_current_modes_and_numeric_or_string_schema_are_eligible_without_acceptance
    [evidence, candidate].each do |row|
      [1.5, '1.5', 1.6, '1.6'].each do |version|
        result = @checker.check(row.merge('pattern_schema_version' => version))
        assert result.dig('distribution', 'eligible'), result.inspect
        assert_equal 'current', result.dig('distribution', 'classification')
        assert_empty result.dig('distribution', 'errors')
        assert result.dig('coverage', 'complete')
        refute result.dig('coverage', 'assessment_acceptance_evaluated')
      end
    end
  end

  def test_v16_assessment_gate_preserves_current_invalid_cases_and_sail_pin
    invalid_current_cases.each do |label, row|
      next if label.start_with?('version_')
      result = @checker.check(row.merge('pattern_schema_version' => '1.6'))
      refute result.dig('distribution', 'eligible'), label
      assert_equal 'current', result.dig('distribution', 'classification'), label
      refute result.dig('coverage', 'assessment_acceptance_evaluated'), label
    end
    assert_equal '0.4-draft', @checker.contract_info['version']
    assert_equal EveryPivot::SailBridge::MANIFEST_SHA256, @checker.contract_info['manifest_sha256']
  end

  def test_supported_legacy_semantic_status_is_preserved_but_distribution_requires_migration
    [1.1, 1.2, 1.3, 1.4, '1.1', '1.2', '1.3', '1.4'].each do |version|
      result = @checker.check(legacy(version))
      assert_equal 'candidate_compatible', result['status']
      assert_empty result['errors']
      assert result.dig('coverage', 'complete')
      refute result.dig('distribution', 'eligible')
      assert_equal 'legacy_diagnostic', result.dig('distribution', 'classification')
      assert_equal ['migration_required'], result.dig('distribution', 'errors').map { |error| error['code'] }
    end
    assert_equal %w[evidence_only candidate_compatible incomplete incompatible], EveryPivot::SailBridge::STATUSES
  end

  def test_specific_incomplete_illegal_legacy_and_absence_diagnostics_remain
    incomplete = legacy(1.2)
    incomplete['assessment'].delete('subject_role')
    result = @checker.check(incomplete)
    assert_equal 'incomplete', result['status']
    assert_includes result['warnings'].map { |entry| entry['code'] }, 'subject_role_missing'
    result = @checker.check(incomplete.merge('pattern_schema_version' => 1.4))
    assert_equal 'incompatible', result['status']
    assert_includes result['errors'].map { |entry| entry['code'] }, 'complete_hint_required'
    illegal = legacy.merge('assessment' => candidate['assessment'].merge('scope' => 'entity_level', 'object_role' => 'tool'))
    result = @checker.check(illegal)
    assert_equal 'incompatible', result['status']
    assert_includes result['errors'].map { |entry| entry['code'] }, 'object_not_allowed'
    assert_includes result['errors'].map { |entry| entry['code'] }, 'scope_not_allowed_for_subject'
    absent = legacy(1.1).reject { |key, _value| key == 'assessment' }
    assert_equal 'incomplete', @checker.check(absent)['status']
    [1.2, 1.3, 1.4].each do |version|
      assert_includes @checker.check(absent.merge('pattern_schema_version' => version))['errors'].map { |entry| entry['code'] }, 'assessment_missing'
    end
    result = @checker.check(legacy.merge('assessment_mode' => nil))
    assert_includes result['errors'].map { |entry| entry['code'] }, 'assessment_mode_requires_v15'
    refute result.dig('distribution', 'eligible')
  end

  def test_invalid_current_contract_cases_fail_closed
    invalid_current_cases.each do |name, row|
      result = @checker.check(row)
      assert_equal 'incompatible', result['status'], name
      refute result.dig('distribution', 'eligible'), name
      refute_empty result.dig('distribution', 'errors'), name
    end
    absent = @checker.check(candidate.merge('assessment' => candidate['assessment'].reject { |key, _| key == 'subject_role' }))
    null = @checker.check(candidate.merge('assessment' => candidate['assessment'].merge('subject_role' => nil)))
    assert_includes absent['warnings'].map { |entry| entry['code'] }, 'subject_role_missing'
    refute_includes null['warnings'].map { |entry| entry['code'] }, 'subject_role_missing'
    assert_includes null['errors'].map { |entry| entry['code'] }, 'subject_role_not_allowed'
  end

  def test_legacy_diagnosis_succeeds_explicit_distribution_gate_fails_and_counts_are_separate
    with_registry([legacy]) do |root|
      library = root.join('graph-pivots')
      out, err, status = run_tool('check_sail_bridge.rb', library, '--json', '--strict-incomplete')
      assert_equal 0, status.exitstatus, out + err
      report = JSON.parse(out)
      assert_equal 'semantic_compatibility_only', report['counts_scope']
      assert_equal 1, report['counts']['candidate_compatible']
      assert_equal({'eligible' => 0, 'not_eligible' => 1, 'legacy_diagnostic' => 1, 'current_candidate_compatible' => 0}, report['distribution_counts'])
      refute report['findings'].first.dig('distribution', 'eligible')
      out, err, status = run_tool('check_sail_bridge.rb', library, '--current-distribution')
      assert_equal 1, status.exitstatus, out + err
      assert_includes out, 'migration_required'
      assert_includes out, 'not active current coverage'
      out, err, status = run_tool('validate_pivots.rb', library, '--strict-metadata', '--strict-bridge')
      assert_equal 0, status.exitstatus, out + err
      assert_includes out, 'legacy diagnostic material, not distributable'
      assert_includes out, 'current_candidate_compatible=0'
      out, err, status = run_tool('validate_pivots.rb', library, '--strict-metadata', '--strict-bridge', '--current-distribution')
      assert_equal 1, status.exitstatus, out + err
      assert_includes out, 'migration_required'
    end
  end

  def test_current_cli_gate_succeeds_and_legacy_mixed_library_has_no_active_legacy_coverage
    with_registry([evidence, candidate.merge('id' => 'CTI_CANDIDATE')]) do |root|
      %w[check_sail_bridge.rb validate_pivots.rb].each do |tool|
        out, err, status = run_tool(tool, root.join('graph-pivots'), '--current-distribution')
        assert_equal 0, status.exitstatus, out + err
      end
      root.join('graph-pivots/working-set/CTI_LEGACY.yaml').write(YAML.dump(legacy.merge('id' => 'CTI_LEGACY')))
      out, err, status = run_tool('check_sail_bridge.rb', root.join('graph-pivots'), '--json', '--current-distribution')
      assert_equal 1, status.exitstatus, err
      report = JSON.parse(out)
      assert_equal 2, report['counts']['candidate_compatible']
      assert_equal 1, report['distribution_counts']['current_candidate_compatible']
    end
  end

  def test_all_registry_channels_preserve_json_javascript_and_binary_outputs_on_legacy_or_mixed_inputs
    [[legacy], [evidence, legacy.merge('id' => 'CTI_LEGACY')]].each do |rows|
      CHANNELS.each_key do |channel|
        with_registry(rows) do |root|
          before = seed_outputs(root, channel)
          out, err, status = build(root, channel)
          assert_equal 1, status.exitstatus, out + err
          assert_includes err, 'migration_required'
          assert_preserved(before)
        end
      end
    end
  end

  def test_invalid_current_inputs_reject_registry_generation_before_writes
    invalid_current_cases.each do |name, row|
      with_registry([row]) do |root|
        before = seed_outputs(root, :preview)
        out, err, status = build(root, :preview)
        assert_equal 1, status.exitstatus, "#{name}: #{out}#{err}"
        assert_preserved(before)
      end
    end
  end

  def test_supplied_compatibility_metadata_cannot_override_source_validation
    {'checked_input' => {'pattern_schema_version' => 1.5, 'assessment_mode' => 'candidate_assessment'},
     'manifest_sha256' => EveryPivot::SailBridge::MANIFEST_SHA256,
     'assessment_compatibility' => {'status' => 'candidate_compatible', 'coverage' => {'complete' => true}}}.each do |key, value|
      with_registry([legacy.merge(key => value)]) do |root|
        before = seed_outputs(root, :stable)
        out, err, status = build(root, :stable)
        assert_equal 1, status.exitstatus, out + err
        assert_includes err, 'migration_required'
        assert_includes err, "#{key} is not allowed"
        assert_preserved(before)
      end
    end
  end

  def test_pinned_contract_failures_are_specific_and_preserve_outputs_in_all_channels
    CHANNELS.each_key do |channel|
      %w[missing corrupt].each do |kind|
        with_registry([evidence]) do |root|
          path = root.join('schemas/sail-v0.4-draft/manifest.json')
          kind == 'missing' ? path.delete : path.binwrite('{}')
          before = seed_outputs(root, channel)
          out, err, status = build(root, channel)
          assert_equal 2, status.exitstatus, out + err
          assert_includes err, 'Assessment contract unavailable'
          assert_includes err, kind == 'missing' ? 'SAIL contract pack unavailable' : 'Pinned SAIL manifest SHA256 mismatch'
          assert_preserved(before)
        end
      end
    end
  end

  def locales
    available, status = Open3.capture2('locale', '-a')
    skip 'Cannot discover installed locales; Unicode argument matrix cannot run' unless status.success?
    names = available.lines.map(&:strip)
    utf8_locale = %w[en_US.UTF-8 C.UTF-8].map do |preferred|
      names.find { |value| value.delete('-').downcase == preferred.delete('-').downcase }
    end.compact.first
    skip 'No supported UTF-8 locale is installed; Unicode argument matrix cannot run' unless utf8_locale
    ['C', utf8_locale]
  rescue Errno::ENOENT
    skip 'locale command is unavailable; Unicode argument matrix cannot run'
  end

  def test_unicode_output_names_and_labels_work_in_c_and_utf8_locales
    locales.each do |locale|
      with_registry([evidence], unicode: true) do |root|
        output = root.join('artifacts', "registry-index.é漢😀.json")
        command = [RbConfig.ruby, ROOT.join('tools/build_registry_index.rb').to_s,
          '--repo-root', root.to_s, '--release', 'test-é漢😀', '--published-at', '2026-09-15',
          '--output', output.to_s, '--site-data-root', root.join('site-data').to_s]
        out, err, status = Open3.capture3({'LANG' => locale, 'LC_ALL' => locale}, *command)
        assert_equal 0, status.exitstatus, "#{locale}: #{out}#{err}"
        registry = JSON.parse(EveryPivot::Utf8Text.read(output))
        assert_equal 'test-é漢😀', registry['release']
        assert_equal 'artifacts/patterns.é漢😀.tar.gz', registry['artifacts']['patterns_bundle']
        assert root.join('artifacts', 'patterns.é漢😀.tar.gz').file?
        assert root.join('site-data', 'registry-index.é漢😀.js').file?
      end
    end
  end

  def test_invalid_utf8_output_or_release_arguments_preserve_every_output
    locales.each do |locale|
      %w[--output --release].each do |option|
        ["\xff".b, "\xf0\x9f\x98".b, "\xef\xbb\xbf".b + 'BOM'].each do |invalid|
          with_registry([evidence]) do |root|
            before = seed_outputs(root, :stable)
            command = [RbConfig.ruby, ROOT.join('tools/build_registry_index.rb').to_s,
              '--repo-root', root.to_s, '--release', 'test', '--published-at', '2026-09-15',
              '--output', root.join('artifacts/registry-index.json').to_s,
              '--site-data-root', root.join('site-data').to_s, option, invalid]
            out, err, status = Open3.capture3({'LANG' => locale, 'LC_ALL' => locale}, *command)
            assert_equal 2, status.exitstatus, "#{locale}: #{out}#{err}"
            assert_includes err, 'Registry argument error'
            assert_match(/Invalid UTF-8|UTF-8 BOM is not permitted/, err)
            assert_preserved(before)
          end
        end
      end
    end
  end

  def test_current_candidate_registry_binding_preserves_requirements_and_never_asserts_acceptance
    CHANNELS.each_key do |channel|
      with_registry([evidence, candidate.merge('id' => 'CTI_CANDIDATE')]) do |root|
        out, err, status = build(root, channel)
        assert_equal 0, status.exitstatus, out + err
        suffix = channel == :stable ? '' : ".#{channel}"
        registry = JSON.parse(EveryPivot::Utf8Text.read(root.join('artifacts', "registry-index#{suffix}.json")))
        assert_equal({'evidence_only' => 1, 'candidate_compatible' => 1}, registry['assessment_coverage'])
        registry['patterns'].each do |entry|
          compatibility = entry['assessment_compatibility']
          assert_equal EveryPivot::SailBridge::MANIFEST_SHA256, compatibility['manifest_sha256']
          assert_equal entry.select { |key, _value| %w[pattern_schema_version assessment_mode assessment assessment_requirements].include?(key) }, compatibility['checked_input']
          refute compatibility['coverage']['assessment_acceptance_evaluated']
        end
      end
    end
  end
end
