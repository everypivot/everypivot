#!/usr/bin/env ruby

require 'fileutils'
require 'digest'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'rbconfig'
require 'tmpdir'
require 'yaml'
require 'zlib'
require 'rubygems/package'
require_relative 'utf8_text'

class RegistryAssessmentTest < Minitest::Test
  ROOT = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: 'test directory')).join('..').expand_path

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

  def semantic_contract
    {'contract' => 'everypivot.semantic_pattern', 'version' => '1.0',
     'pattern' => {'id' => 'CTI_TEST', 'version' => '2.0.0'},
     'parameters' => {'seed' => {'type' => 'record_id', 'required' => true, 'description' => 'Exact file identity'}},
     'branches' => [{'id' => 'witnessed', 'bindings' => [
       {'name' => 'file', 'kind' => 'entity', 'types' => ['file:bytes'],
        'where' => {'op' => 'eq', 'left' => {'ref' => 'file.id'}, 'right' => {'param' => 'seed'}}},
       {'name' => 'sighting', 'kind' => 'occurrence', 'types' => ['file_sighting'],
        'where' => {'op' => 'eq', 'left' => {'ref' => 'sighting.subject'}, 'right' => {'ref' => 'file.id'}}}],
       'where' => {'op' => 'present', 'value' => {'ref' => 'sighting.evidence'}},
       'knowledge' => [{'ref' => 'sighting.times.available'}],
       'time_bindings' => [{'value' => {'ref' => 'sighting.times.available'}, 'object' => {'ref' => 'file.id'}, 'occurrence' => {'ref' => 'sighting.id'}}],
       'result' => {'mode' => 'bound', 'binding' => 'file', 'form' => 'file:bytes',
                    'identity' => [{'ref' => 'file.id'}], 'fields' => {}}}]}
  end

  def write_execution(root, data, document = semantic_contract)
    bytes = JSON.pretty_generate(document) + "\n"
    root.join('contracts', 'semantics').mkpath
    root.join('contracts', 'semantics', 'CTI_TEST.json').binwrite(bytes)
    data['pattern_schema_version'] = '1.6'
    data['execution'] = {'contract' => 'everypivot.semantic_pattern', 'version' => '1.0',
      'path' => 'contracts/semantics/CTI_TEST.json', 'sha256' => Digest::SHA256.hexdigest(bytes)}
    root.join('graph-pivots', 'working-set', 'CTI_TEST.yaml').write(YAML.dump(data))
  end

  def test_evidence_only_preserves_controls_and_never_exports_a_hint
    with_registry(pattern) do |root|
      out, err, status = build(root)
      assert status.success?, [out, err].join("\n")
      registry = JSON.parse(EveryPivot::Utf8Text.read(root.join('artifacts', 'registry-index.preview.json')))
      entry = registry['patterns'].first
      assert_equal 'evidence_only', entry['assessment_mode']
      refute entry.key?('assessment')
      assert_equal 'evidence_only', entry.dig('assessment_compatibility', 'status')
      assert_equal({'pattern_schema_version' => 1.5, 'assessment_mode' => 'evidence_only'}, entry.dig('assessment_compatibility', 'checked_input'))
      assert_equal pattern['hazards'], entry['hazards']
      assert_equal 1, entry.dig('controls', 'provenance', 'min_unique_sources')
      assert_equal false, entry.dig('assessment_compatibility', 'coverage', 'assessment_acceptance_evaluated')
      assert_equal 'verified', registry.dig('assessment_contract', 'status')
      assert_equal({'evidence_only' => 1}, registry['assessment_coverage'])
      assert_equal 'not_declared', entry.dig('semantic_execution', 'status')
      assert_equal 'not_evaluated', entry.dig('semantic_execution', 'runtime_acceptance')
      refute entry.dig('semantic_execution', 'coverage', 'runtime_executed')
      refute entry.key?('execution')
      assert_includes EveryPivot::Utf8Text.read(root.join('site-data', 'pattern-sources.preview.js')), 'assessment_mode: evidence_only'
    end
  end

  def test_v16_exports_exact_checked_input_and_declared_bindings_without_runtime_acceptance
    data = pattern.merge('target' => ' file:bytes ')
    with_registry(data) do |root|
      write_execution(root, data)
      out, err, status = build(root)
      assert status.success?, out + err
      entry = JSON.parse(EveryPivot::Utf8Text.read(root.join('artifacts', 'registry-index.preview.json')))['patterns'][0]
      check = entry['semantic_execution']
      assert_equal 'contract_valid', check['status']
      assert_equal data['execution'], entry['execution']
      assert_equal data.select { |key, _| %w[id version pattern_schema_version target execution].include?(key) }, check['checked_input']
      assert_equal data['target'], entry['target']
      assert_equal data['execution']['sha256'], check['reference_sha256']
      assert_equal 'everypivot.semantic_pattern', check['contract_id']
      assert_equal '1.0', check['contract_version']
      assert_equal 'not_evaluated', check['runtime_acceptance']
      packaged_contract = nil
      Zlib::GzipReader.open(root.join('artifacts', 'patterns.preview.tar.gz').to_s) do |gzip|
        Gem::Package::TarReader.new(gzip) do |archive|
          archive.each { |item| packaged_contract = item.read if item.file? && item.full_name == data['execution']['path'] }
        end
      end
      refute_nil packaged_contract, 'downloadable pattern bundle must carry its referenced execution contract'
      assert_equal data['execution']['sha256'], Digest::SHA256.hexdigest(packaged_contract)
      %w[reference_digest_verified pattern_identity_verified contract_shape_and_bindings_validated].each { |key| assert_equal true, check['coverage'][key] }
      %w[runtime_executed evidence_acceptance_evaluated assessment_acceptance_evaluated].each { |key| assert_equal false, check['coverage'][key] }
      branch = check['summary']['branches'][0]
      assert_equal %w[file sighting], branch['bindings'].map { |b| b['name'] }
      assert_equal 'bound', branch['result']['mode']
      assert_equal 'file', branch['result']['binding']
      assert_equal semantic_contract['branches'][0]['time_bindings'], branch['time_bindings']
      assert_equal semantic_contract['branches'][0]['knowledge'], branch['knowledge']
      refute entry.key?('confidence')
      assert_equal false, entry.dig('assessment_compatibility', 'coverage', 'assessment_acceptance_evaluated')
    end
  end

  def test_v16_bad_reference_cannot_replace_existing_generated_outputs
    %w[missing_file corrupt_hash unknown_property stale_pattern_version wrong_result_form unsupported_contract invalid_grammar malformed_json].each do |kind|
      data = pattern
      with_registry(data) do |root|
        write_execution(root, data)
        out, err, status = build(root)
        assert status.success?, out + err
        before = Dir.glob(root.join('{artifacts,site-data}', '**', '*').to_s).select { |p| File.file?(p) }.to_h { |p| [p, File.binread(p)] }
        refute_empty before
        path = root.join('contracts', 'semantics', 'CTI_TEST.json')
        case kind
        when 'missing_file' then path.delete
        when 'corrupt_hash' then data['execution']['sha256'] = '0' * 64
        when 'unknown_property' then data['execution']['accepted'] = true
        when 'stale_pattern_version' then data['version'] = '3.0.0'
        when 'wrong_result_form', 'unsupported_contract', 'invalid_grammar'
          document = semantic_contract
          document['branches'][0]['result']['form'] = 'inet:fqdn' if kind == 'wrong_result_form'
          document['version'] = '9.0' if kind == 'unsupported_contract'
          document['branches'][0]['where'] = {'op' => 'eval', 'text' => 'trust_source'} if kind == 'invalid_grammar'
          write_execution(root, data, document)
        when 'malformed_json'
          path.binwrite('{')
          data['execution']['sha256'] = Digest::SHA256.hexdigest('{')
        end
        root.join('graph-pivots', 'working-set', 'CTI_TEST.yaml').write(YAML.dump(data))
        _out, err, status = build(root)
        assert_equal 1, status.exitstatus, "#{kind}: #{err}"
        assert_match(/execution/, err, kind)
        before.each { |p, bytes| assert_equal bytes, File.binread(p), "#{kind}: #{p}" }
      end
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
      entry = JSON.parse(EveryPivot::Utf8Text.read(root.join('artifacts', 'registry-index.preview.json')))['patterns'].first
      assert_equal data['assessment_requirements'], entry['assessment_requirements']
      assert_equal 'candidate_compatible', entry.dig('assessment_compatibility', 'status')
      assert_equal data['assessment'], entry.dig('assessment_compatibility', 'checked_input', 'assessment')
      assert_equal data['assessment_requirements'], entry.dig('assessment_compatibility', 'checked_input', 'assessment_requirements')
      assert_equal '5416bf429a34afccb4e6657807c26b83491a39bdcbd6c9a313530cadbf032881', entry.dig('assessment_compatibility', 'manifest_sha256')
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

  def test_duplicate_ids_across_lanes_fail_both_gates_without_overwriting_outputs
    [false, true].each do |conflicting|
      with_registry(pattern) do |root|
        root.join('graph-pivots', 'validated').mkpath
        duplicate = pattern.merge('validation_state' => 'validated')
        duplicate['hazards'] = ['Different hazards must never replace the selected definition.'] if conflicting
        root.join('graph-pivots', 'validated', 'CTI_TEST.yaml').write(YAML.dump(duplicate))
        root.join('artifacts', 'registry-index.preview.json').write('existing snapshot')
        _out, err, status = build(root)
        assert_equal 1, status.exitstatus
        assert_includes err, 'duplicate pattern id "CTI_TEST"'
        assert_includes err, 'validated/CTI_TEST.yaml'
        assert_includes err, 'working-set/CTI_TEST.yaml'
        assert_equal 'existing snapshot', EveryPivot::Utf8Text.read(root.join('artifacts', 'registry-index.preview.json'))
        assert_equal ['registry-index.preview.json'], root.join('artifacts').children.map { |path| path.basename.to_s }
        refute root.join('site-data').exist?
        out, err, status = Open3.capture3(RbConfig.ruby, ROOT.join('tools', 'validate_pivots.rb').to_s,
          root.join('graph-pivots').to_s, '--strict-bridge')
        assert_equal 1, status.exitstatus
        assert_includes out + err, 'duplicate pattern id "CTI_TEST"'
      end
    end
  end

  def test_move_and_filename_lane_policy
    with_registry(pattern) do |root|
      root.join('graph-pivots', 'validated').mkpath
      old_path = root.join('graph-pivots', 'working-set', 'CTI_TEST.yaml')
      old_path.delete
      new_path = root.join('graph-pivots', 'validated', 'CTI_TEST.yaml')
      new_path.write(YAML.dump(pattern.merge('validation_state' => 'validated')))
      _out, err, status = build(root)
      assert status.success?, err
      assert_equal 1, JSON.parse(EveryPivot::Utf8Text.read(root.join('artifacts', 'registry-index.preview.json')))['patterns'].length
    end
    [pattern.merge('id' => 'CTI_OTHER'), pattern.merge('validation_state' => 'validated')].each do |data|
      with_registry(data) do |root|
        _out, err, status = build(root)
        assert_equal 1, status.exitstatus
        assert_match(/filename must match|validation_state.*should match lane/, err)
        assert_no_artifacts(root)
      end
    end
  end
end
