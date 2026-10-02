#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'minitest/autorun'
require_relative 'json_schema_validator'
require_relative 'sail_bridge'
require_relative 'utf8_text'

class SemanticAuthoringSchemaTest < Minitest::Test
  ROOT = File.expand_path('..', EveryPivot::Utf8Text.decode(__dir__, path: __FILE__))

  def setup
    schema = JSON.parse(EveryPivot::Utf8Text.read(File.join(ROOT, 'schemas/pivot_pattern.schema.json')))
    @schema = EveryPivot::JsonSchemaValidator.new(schema)
    @bridge = EveryPivot::SailBridge.new(repo_root: ROOT)
  end

  def execution
    {'contract' => 'everypivot.semantic_pattern', 'version' => '1.0',
     'path' => 'contracts/semantics/CTI_AUTHORED_BINDING.json', 'sha256' => 'a' * 64}
  end

  def pattern
    {'pattern_schema_version' => '1.6', 'id' => 'CTI_AUTHORED_BINDING', 'version' => '3.0.0',
     'name' => 'Bound evidence lookup', 'category' => 'CTI',
     'description' => 'Return source-bound evidence, retaining interpretation limits.',
     'source' => 'file:sourcepath', 'target' => 'file:bytes',
     'hops' => [{'via' => 'extracted_from', 'direction' => 'out', 'form' => 'file:bytes'}],
     'constraints' => {}, 'validation_state' => 'deferred', 'deferred_reason' => 'needs_fixtures',
     'assessment_mode' => 'evidence_only', 'execution' => execution}
  end

  def candidate
    pattern.merge('assessment_mode' => 'candidate_assessment',
      'assessment' => {'claim' => 'indicates', 'basis' => 'assessed', 'scope' => 'incident_level',
                       'subject_role' => 'observation', 'object_role' => 'incident'},
      'assessment_requirements' => ['Corroborate the identified incident and review contradictory evidence.'])
  end

  def test_v16_string_and_numeric_versions_require_explicit_execution
    ['1.6', 1.6].each do |version|
      row = pattern.merge('pattern_schema_version' => version)
      assert_empty @schema.validate(row)
      row.delete('execution')
      assert_includes @schema.validate(row), 'execution is required'
    end
  end

  def test_v15_remains_supported_without_executable_semantics
    ['1.5', 1.5].each do |version|
      row = pattern.reject { |key, _| key == 'execution' }.merge('pattern_schema_version' => version)
      assert_empty @schema.validate(row)
      assert @bridge.check(row).dig('distribution', 'eligible')
      row['execution'] = execution
      assert_includes @schema.validate(row), 'execution is not allowed'
    end
  end

  def test_legacy_authoring_cannot_hide_an_execution_reference
    %w[1.1 1.2 1.3 1.4].each do |version|
      row = candidate.reject { |key, _| %w[assessment_mode assessment_requirements execution].include?(key) }
      row['pattern_schema_version'] = version
      assert_empty @schema.validate(row)
      row['execution'] = execution
      assert_includes @schema.validate(row), 'execution is not allowed'
    end
  end

  def test_execution_shape_is_closed_complete_and_separately_versioned
    %w[contract version path sha256].each do |key|
      row = pattern
      row['execution'].delete(key)
      assert @schema.validate(row).any? { |error| error.include?("execution.#{key} is required") }, key
    end
    [nil, true, [], 'contract'].each do |bad|
      refute_empty @schema.validate(pattern.merge('execution' => bad))
    end
    {'contract' => 'sail.assessment', 'version' => 1.0, 'adapter_profile' => 'neo4j'}.each do |key, bad|
      row = pattern
      row['execution'][key] = bad
      refute_empty @schema.validate(row), key
    end
  end

  def test_digest_and_path_are_exact_whole_strings
    ['a' * 63, 'a' * 65, 'A' * 64, 'z' * 64, ('a' * 64) + "\n", "\n" + ('a' * 64), false].each do |bad|
      row = pattern
      row['execution']['sha256'] = bad
      refute_empty @schema.validate(row), bad.inspect
    end
    ['../outside.json', '/contracts/semantics/ID.json', 'contracts/semantics/../ID.json',
     'contracts/semantics/id.json', 'contracts/semantics/ID.yaml',
     "contracts/semantics/ID.json\n", "wrong\ncontracts/semantics/ID.json", 'https://example.test/ID.json'].each do |bad|
      row = pattern
      row['execution']['path'] = bad
      refute_empty @schema.validate(row), bad.inspect
    end
  end

  def test_assessment_contract_is_unchanged_in_v16
    assert_empty @schema.validate(candidate)
    assert_equal 'candidate_compatible', @bridge.check(candidate)['status']
    refute @bridge.check(candidate).dig('coverage', 'assessment_acceptance_evaluated')
    row = pattern.merge('assessment' => candidate['assessment'])
    assert_includes @schema.validate(row), 'assessment is not allowed'
    row = candidate
    row['assessment_requirements'] = ['  ']
    refute_empty @schema.validate(row)
    row = candidate
    row['assessment'].delete('subject_role')
    assert_includes @schema.validate(row), 'assessment.subject_role is required'
    row = pattern
    row.delete('assessment_mode')
    assert_includes @schema.validate(row), 'assessment_mode is required'
  end

  def test_reference_shape_pass_does_not_claim_content_or_runtime_acceptance
    row = pattern
    # This hash has no supplied content witness in this shape-only test.
    assert_empty @schema.validate(row)
    result = @bridge.check(row)
    assert_equal 'evidence_only', result['status']
    refute_includes result['coverage']['checks_performed'], 'execution'
    refute result['coverage']['assessment_acceptance_evaluated']
    assert_equal '0.4-draft', @bridge.contract_info['version']
    assert_equal '5416bf429a34afccb4e6657807c26b83491a39bdcbd6c9a313530cadbf032881', @bridge.contract_info['manifest_sha256']
  end

  def test_unknown_authoring_versions_still_fail
    [nil, '1.60', '1.7', 1.7, 1, true, []].each do |version|
      refute_empty @schema.validate(pattern.merge('pattern_schema_version' => version)), version.inspect
    end
  end
end
