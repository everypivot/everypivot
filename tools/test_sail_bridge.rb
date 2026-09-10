#!/usr/bin/env ruby
# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tmpdir'
require 'yaml'
require_relative 'sail_bridge'
require_relative 'json_schema_validator'

class SailBridgeTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def setup
    @checker = EveryPivot::SailBridge.new(repo_root: ROOT)
  end

  def hint(**changes)
    {'claim' => 'indicates', 'basis' => 'assessed', 'scope' => 'incident_level',
     'subject_role' => 'observation', 'object_role' => 'incident'}.merge(changes.transform_keys(&:to_s))
  end

  def pattern(assessment = hint, version: '1.5')
    row = {'id' => 'CTI_BRIDGE_TEST', 'pattern_schema_version' => version, 'assessment' => assessment}
    if version.to_s == '1.5'
      row['assessment_mode'] = 'candidate_assessment'
      row['assessment_requirements'] = ['Corroborate the observation against a separately identified incident and review contradictions.']
    end
    row
  end

  def error_codes(row)
    @checker.check(row)['errors'].map { |entry| entry['code'] }
  end

  def test_original_imphash_fails_object_and_scope_without_invalidating_a_lookup
    row = pattern(hint(subject_role: 'behavioural_cluster', object_role: 'behavioural_cluster', scope: 'entity_level'), version: '1.4')
    assert_equal %w[object_not_allowed scope_not_allowed_for_subject], error_codes(row)
    row['pattern_schema_version'] = '1.5'
    row['assessment_mode'] = 'evidence_only'
    row.delete('assessment')
    result = @checker.check(row)
    assert_equal 'evidence_only', result['status']
    assert result['coverage']['complete']
    refute result['coverage']['assessment_acceptance_evaluated']
  end

  def test_every_canonical_legal_subject_scope_and_object_route
    matrix = JSON.parse(File.read(File.join(ROOT, 'schemas/sail-v0.4-draft/predicate_type_matrix.v0.4.json')))
    matrix['predicates'].each do |predicate|
      objects = predicate['allowed_object_roles'].map { |role| {'object_role' => role} } +
                predicate['allowed_object_kinds'].map { |kind| {'object_kind' => kind} }
      predicate['allowed_scope_by_subject_role'].each do |subject, scopes|
        scopes.product(objects).each do |scope, object|
          candidate = {'claim' => predicate['id'], 'basis' => 'assessed', 'subject_role' => subject, 'scope' => scope}.merge(object)
          result = @checker.check(pattern(candidate))
          assert_equal 'candidate_compatible', result['status'], candidate.inspect
          assert result['coverage']['complete'], candidate.inspect
        end
      end
    end
  end

  def test_disjunctive_object_rules_and_legacy_structural_warning
    legal_by_kind = hint(claim: 'targets', subject_role: 'campaign', scope: 'campaign_level', object_role: 'tool', object_kind: 'product')
    assert_equal 'candidate_compatible', @checker.check(pattern(legal_by_kind))['status']
    legal_by_role = legal_by_kind.merge('object_role' => 'target', 'object_kind' => 'assessment')
    assert_equal 'candidate_compatible', @checker.check(pattern(legal_by_role))['status']
    legacy = hint(claim: 'achieves', subject_role: 'threat_actor', scope: 'entity_level', object_role: 'concept')
    result = @checker.check(pattern(legacy, version: '1.4'))
    assert_equal 'candidate_compatible', result['status']
    assert_equal ['deprecated_structural_object_role'], result['warnings'].map { |entry| entry['code'] }
    # An unknown vocabulary token cannot be hidden by a legal alternative.
    assert_includes error_codes(pattern(legal_by_kind.merge('object_role' => 'nonsense'))), 'object_role_unknown'
    assert_includes error_codes(pattern(legal_by_role.merge('object_kind' => 'nonsense'))), 'object_kind_unknown'
  end

  def test_scope_is_subject_specific_and_omitted_subject_can_still_be_impossible
    assert_includes error_codes(pattern(hint(scope: 'campaign_level'))), 'scope_not_allowed_for_subject'
    assert_equal 'candidate_compatible', @checker.check(pattern(hint(subject_role: 'behavioural_cluster', scope: 'campaign_level')))['status']
    legacy = pattern({'claim' => 'indicates', 'basis' => 'assessed', 'scope' => 'entity_level'}, version: '1.2')
    result = @checker.check(legacy)
    assert_equal 'incompatible', result['status']
    assert_equal ['scope_not_allowed_for_any_legal_subject'], error_codes(legacy)
    assert_equal %w[subject_role_missing object_role_and_kind_missing], result['warnings'].map { |entry| entry['code'] }
    legacy['assessment']['scope'] = 'incident_level'
    result = @checker.check(legacy)
    assert_equal 'incomplete', result['status']
    refute result['coverage']['complete']
  end

  def test_candidate_requires_complete_shape_and_documentary_requirements
    row = pattern
    row['assessment'].delete('subject_role')
    assert_includes error_codes(row), 'complete_hint_required'
    [nil, [], [''], ['  '], [12], ['documented', nil]].each do |requirements|
      row = pattern
      row['assessment_requirements'] = requirements
      assert_includes error_codes(row), 'assessment_requirements_missing'
    end
  end

  def test_modes_fail_closed
    row = pattern
    row['assessment_mode'] = 'evidence_only'
    assert_includes error_codes(row), 'evidence_only_has_assessment'
    assert_includes error_codes(row), 'evidence_only_has_requirements'
    row = pattern
    row.delete('assessment_mode')
    assert_includes error_codes(row), 'assessment_mode_invalid'
    row['assessment_mode'] = 'accepted'
    assert_includes error_codes(row), 'assessment_mode_invalid'
    row['pattern_schema_version'] = '9.9'
    assert_includes error_codes(row), 'schema_version_unknown'
    row['pattern_schema_version'] = '1.4'
    assert_includes error_codes(row), 'assessment_mode_requires_v15'
  end

  def test_unknown_and_runtime_fields_are_rejected
    assert_includes error_codes(pattern(hint(claim: 'related_to'))), 'unknown_claim'
    assert_includes error_codes(pattern(hint(subject_role: 'file'))), 'subject_role_not_allowed'
    assert_includes error_codes(pattern(hint(confidence: 'high'))), 'assessment_field_unknown'
    assert_includes error_codes(pattern(hint(scope: 'global'))), 'scope_invalid'
    assert_includes error_codes(pattern(hint(basis: 'certain'))), 'basis_invalid'
    %w[demonstrated assessed suspected theoretical].each do |basis|
      assert_equal 'candidate_compatible', @checker.check(pattern(hint(basis: basis)))['status']
    end
  end

  def test_malformed_known_bridge_fields_cannot_bypass_the_checker
    %w[claim basis scope subject_role object_role object_kind].each do |field|
      [nil, [], {}, false, 42].each do |value|
        row = pattern
        row['assessment'][field] = value
        assert_equal 'incompatible', @checker.check(row)['status'], "#{field}=#{value.inspect}"
      end
    end
    [nil, [], false, 42, 'indicates'].each do |value|
      row = pattern
      row['assessment'] = value
      assert_equal 'incompatible', @checker.check(row)['status']
    end
  end

  def test_native_validator_blocks_root_runtime_fields_and_strict_incomplete
    source = File.join(ROOT, 'fixtures/cases/valid_v12_minimal/working-set/OSINT_VALID_V12_MINIMAL.yaml')
    row = YAML.safe_load(File.read(source), aliases: false)
    Dir.mktmpdir('everypivot-native-bridge-') do |tmp|
      filename = File.join(tmp, "#{row['id']}.yaml")
      File.write(filename, YAML.dump(row))
      command = [RbConfig.ruby, File.join(ROOT, 'tools/validate_pivots.rb'), tmp]
      # Use a neutral directory so the native lane check does not mask the bridge gate.
      row['validation_state'] = 'validated'
      File.write(filename, YAML.dump(row))
      stdout, stderr, status = Open3.capture3(*command)
      assert_equal 0, status.exitstatus, stdout + stderr
      stdout, _stderr, status = Open3.capture3(*command, '--strict-bridge')
      assert_equal 1, status.exitstatus
      assert_includes stdout, 'incomplete bridge compatibility is forbidden'
      row['pattern_schema_version'] = '1.5'
      row['assessment_mode'] = 'evidence_only'
      row.delete('assessment')
      row['confidence'] = 'high'
      row['accepted_assessment'] = true
      File.write(filename, YAML.dump(row))
      stdout, _stderr, status = Open3.capture3(*command)
      assert_equal 1, status.exitstatus
      assert_includes stdout, 'confidence is not allowed'
      assert_includes stdout, 'accepted_assessment is not allowed'
    end
  end

  def test_missing_corrupt_and_truncated_contracts_fail_closed
    Dir.mktmpdir('everypivot-contract-test-') do |tmp|
      assert_raises(EveryPivot::SailBridge::ContractError) { EveryPivot::SailBridge.new(repo_root: tmp) }
      source = File.join(ROOT, 'schemas')
      %w[manifest.json predicate_type_matrix.v0.4.json semantic_roles.v0.4.json structural_object_kinds.v0.4.json NOTICE LICENSE].each do |name|
        FileUtils.rm_rf(File.join(tmp, 'schemas'))
        FileUtils.cp_r(source, File.join(tmp, 'schemas'))
        path = File.join(tmp, 'schemas/sail-v0.4-draft', name)
        File.write(path, '{}')
        assert_raises(EveryPivot::SailBridge::ContractError, name) { EveryPivot::SailBridge.new(repo_root: tmp) }
      end
    end
  end

  def test_cli_reports_complete_counts_and_strict_incomplete_exit
    Dir.mktmpdir('everypivot-bridge-cli-') do |tmp|
      rows = [pattern, {'id' => 'CTI_EVIDENCE', 'pattern_schema_version' => '1.5', 'assessment_mode' => 'evidence_only'}, pattern({'claim' => 'indicates', 'basis' => 'assessed', 'scope' => 'incident_level'}, version: '1.2')]
      rows.each_with_index { |row, index| File.write(File.join(tmp, "pattern#{index}.yaml"), YAML.dump(row)) }
      command = [RbConfig.ruby, File.join(ROOT, 'tools/check_sail_bridge.rb'), tmp, '--json']
      stdout, stderr, status = Open3.capture3(*command)
      assert_equal 0, status.exitstatus, stderr
      report = JSON.parse(stdout)
      assert_equal 1, report['report_version']
      assert_equal 'verified', report['contract']['status']
      assert_equal 3, report['counts']['total']
      %w[evidence_only candidate_compatible incomplete].each { |name| assert_equal 1, report['counts'][name] }
      _stdout, _stderr, status = Open3.capture3(*command, '--strict-incomplete')
      assert_equal 1, status.exitstatus
      File.write(File.join(tmp, 'bad.yaml'), 'assessment: [')
      stdout, _stderr, status = Open3.capture3(*command)
      assert_equal 2, status.exitstatus
      assert_equal 'input_error', JSON.parse(stdout)['error']['code']
    end
  end

  def test_narrow_v15_schema_and_local_validator_boolean_and_string_constraints
    schema = EveryPivot::JsonSchemaValidator.new(JSON.parse(File.read(File.join(ROOT, 'schemas/pivot_pattern.schema.json'))))
    row = YAML.safe_load(File.read(File.join(ROOT, 'fixtures/cases/valid_v14_minimal/deferred/OSINT_VALID_V14_MINIMAL.yaml')), aliases: false)
    row['pattern_schema_version'] = '1.5'
    row['assessment_mode'] = 'evidence_only'
    row.delete('assessment')
    assert_empty schema.validate(row)
    row['assessment'] = hint
    assert_includes schema.validate(row), 'assessment is not allowed'
    row['assessment_mode'] = 'candidate_assessment'
    row['assessment_requirements'] = ['   ']
    assert schema.validate(row).any? { |message| message.include?('assessment_requirements[0] must match') }
    row['assessment_requirements'] = ['Corroborate incident association and review contradictions.']
    assert_empty schema.validate(row)
    row['pattern_schema_version'] = '1.4'
    assert_includes schema.validate(row), 'assessment_mode is not allowed'
  end
end
