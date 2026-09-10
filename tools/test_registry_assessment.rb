#!/usr/bin/env ruby

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'
require 'yaml'

class RegistryAssessmentTest < Minitest::Test
  ROOT = Pathname(__dir__).join('..').expand_path

  def with_registry(pattern)
    Dir.mktmpdir('everypivot-registry-assessment') do |dir|
      root = Pathname(dir)
      FileUtils.cp_r(ROOT.join('schemas'), root.join('schemas'))
      root.join('graph-pivots', 'working-set').mkpath
      root.join('fixtures').mkpath
      root.join('artifacts').mkpath
      root.join('graph-pivots', 'working-set', 'CTI_TEST.yaml').write(YAML.dump(pattern))
      yield root
    end
  end

  def pattern
    {
      'id' => 'CTI_TEST', 'name' => 'Shared feature lookup', 'version' => '2.0.0',
      'pattern_schema_version' => 1.5, 'assessment_mode' => 'evidence_only',
      'validation_state' => 'working_set', 'category' => 'CTI',
      'precision_tier' => 'low', 'robustness_class' => 'enumeration',
      'source' => 'file:pe:imphash', 'target' => 'file:bytes',
      'description' => 'Find files sharing a feature.',
      'hazards' => ['Benign files and common builders can share this feature.'],
      'constraints' => {'provenance' => {'min_unique_sources' => 1}},
      'hops' => [{'via' => 'observed_in', 'direction' => 'out', 'form' => 'file:bytes'}]
    }
  end

  def build(root)
    Open3.capture3(RbConfig.ruby, ROOT.join('tools', 'build_registry_index.rb').to_s,
                  '--repo-root', root.to_s, '--release', 'test-preview',
                  '--published-at', '2026-09-10', '--preview',
                  '--output', root.join('artifacts', 'registry-index.preview.json').to_s,
                  '--site-data-root', root.join('site-data').to_s)
  end

  def test_evidence_only_preserves_controls_and_never_exports_a_hint
    with_registry(pattern) do |root|
      out, err, status = build(root)
      assert status.success?, [out, err].join("\n")
      registry = JSON.parse(root.join('artifacts', 'registry-index.preview.json').read)
      entry = registry['patterns'].first
      assert_equal 'evidence_only', entry['assessment_mode']
      refute entry.key?('assessment')
      assert_equal 'evidence_only', entry.dig('assessment_compatibility', 'status')
      assert_equal pattern['hazards'], entry['hazards']
      assert_equal 1, entry.dig('controls', 'provenance', 'min_unique_sources')
      assert_equal false, entry.dig('assessment_compatibility', 'coverage', 'assessment_acceptance_evaluated')
      assert_equal 'verified', registry.dig('assessment_contract', 'status')
      assert_equal({'evidence_only' => 1}, registry['assessment_coverage'])
      assert_includes root.join('site-data', 'pattern-sources.preview.js').read, 'assessment_mode: evidence_only'
    end
  end

  def test_candidate_exports_qualifying_requirements_without_accepting_a_conclusion
    data = pattern.merge('assessment_mode' => 'candidate_assessment',
                         'assessment' => {'claim' => 'indicates', 'basis' => 'assessed',
                                          'subject_role' => 'observation', 'object_role' => 'incident',
                                          'scope' => 'incident_level'},
                         'assessment_requirements' => ['Independently support the incident association.'])
    with_registry(data) do |root|
      out, err, status = build(root)
      assert status.success?, [out, err].join("\n")
      entry = JSON.parse(root.join('artifacts', 'registry-index.preview.json').read)['patterns'].first
      assert_equal data['assessment_requirements'], entry['assessment_requirements']
      assert_equal 'candidate_compatible', entry.dig('assessment_compatibility', 'status')
      assert_equal false, entry.dig('assessment_compatibility', 'coverage', 'assessment_acceptance_evaluated')
      refute entry.key?('confidence')
    end
  end

  def test_invalid_mixed_mode_and_incomplete_legacy_hint_cannot_write_artifacts
    invalid = pattern.merge('assessment' => {'claim' => 'indicates', 'basis' => 'assessed', 'scope' => 'entity_level'})
    legacy = pattern.merge('pattern_schema_version' => 1.2,
                           'assessment' => {'claim' => 'indicates', 'basis' => 'assessed', 'scope' => 'incident_level'})
    legacy.delete('assessment_mode')
    [invalid, legacy].each do |data|
      with_registry(data) do |root|
        _out, _err, status = build(root)
        refute status.success?
        assert_empty root.join('artifacts').children
        refute root.join('site-data').exist?
      end
    end
  end

  def test_missing_contract_prevents_generation_even_for_evidence_only
    with_registry(pattern) do |root|
      FileUtils.rm_rf(root.join('schemas', 'sail-v0.4-draft'))
      _out, _err, status = build(root)
      assert_equal 2, status.exitstatus
      assert_empty root.join('artifacts').children
    end
  end

  def assert_no_artifacts(root)
    assert_empty root.join('artifacts').children
    refute root.join('site-data').exist?
  end

  def test_invalid_pattern_shape_and_root_runtime_fields_prevent_all_writes
    [
      pattern.reject { |key, _value| key == 'hops' },
      pattern.merge('hops' => []),
      pattern.merge('confidence' => 'high', 'accepted_assessment' => true),
      ['not', 'a', 'pattern'],
      'not a mapping',
      nil
    ].each do |data|
      with_registry(data) do |root|
        _out, err, status = build(root)
        assert_equal 1, status.exitstatus, err
        assert_match(/must be a mapping|is required|at least 1 item|is not allowed/, err)
        assert_no_artifacts(root)
      end
    end
  end

  def test_malformed_yaml_cannot_be_skipped_when_other_patterns_are_valid
    with_registry(pattern) do |root|
      root.join('graph-pivots', 'working-set', 'CTI_BROKEN.yaml').write('assessment: [')
      _out, err, status = build(root)
      assert_equal 1, status.exitstatus
      assert_includes err, 'YAML read/parse failed'
      assert_no_artifacts(root)
    end
  end

  def test_patterns_outside_indexed_lanes_cannot_enter_the_raw_bundle
    with_registry(pattern) do |root|
      root.join('graph-pivots', 'working-set', 'nested').mkpath
      root.join('graph-pivots', 'working-set', 'nested', 'CTI_UNCHECKED.yaml').write(YAML.dump(pattern.merge('confidence' => 'high')))
      _out, err, status = build(root)
      assert_equal 1, status.exitstatus
      assert_includes err, 'outside a supported lane directory'
      assert_no_artifacts(root)
    end
  end

  def test_empty_corpus_cannot_publish_empty_success_artifacts
    with_registry(pattern) do |root|
      root.join('graph-pivots', 'working-set', 'CTI_TEST.yaml').delete
      _out, err, status = build(root)
      assert_equal 1, status.exitstatus
      assert_includes err, 'contains no pattern YAML files'
      assert_no_artifacts(root)
    end
  end

  def test_missing_or_malformed_schema_prevents_all_writes
    [nil, '{', '{}', 'false'].each do |bytes|
      with_registry(pattern) do |root|
        schema_path = root.join('schemas', 'pivot_pattern.schema.json')
        bytes.nil? ? schema_path.delete : schema_path.write(bytes)
        _out, err, status = build(root)
        assert_equal 2, status.exitstatus
        assert_includes err, 'Pattern schema unavailable'
        assert_no_artifacts(root)
      end
    end
  end
end
