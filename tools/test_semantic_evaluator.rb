#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'semantic_evaluator'

class SemanticEvaluatorTest < Minitest::Test
  E = EveryPivot::SemanticEvaluator

  def eq(ref, value)
    {'op' => 'eq', 'left' => {'ref' => ref}, 'right' => value}
  end

  def contract
    {'contract' => 'everypivot.semantic_pattern', 'version' => '1.0',
     'pattern' => {'id' => 'SYNTHETIC_CREATIVE_REFERENCE', 'version' => '1.0.0'},
     'parameters' => {'seed' => {'type' => 'record_id', 'required' => true, 'description' => 'Starting creative occurrence'}},
     'branches' => [{'id' => 'reference', 'bindings' => [
       {'name' => 'creative', 'kind' => 'entity', 'types' => ['adtech:creative'], 'query_seed' => true, 'where' => eq('creative.id', {'param' => 'seed'})},
       {'name' => 'reference', 'kind' => 'assertion', 'types' => ['references'], 'where' => eq('reference.subject', {'ref' => 'creative.id'})},
       {'name' => 'url', 'kind' => 'entity', 'types' => ['inet:url'], 'where' => eq('url.id', {'ref' => 'reference.object'})},
       {'name' => 'host', 'kind' => 'entity', 'types' => ['inet:fqdn'], 'where' => eq('host.id', {'ref' => 'url.attributes.host'}), 'optional' => true}
     ], 'where' => {'op' => 'present', 'value' => {'ref' => 'reference.evidence'}},
       'knowledge' => [{'ref' => 'reference.times.available'}],
       'time_bindings' => [{'value' => {'ref' => 'reference.times.available'}, 'object' => {'ref' => 'creative.id'}, 'occurrence' => {'ref' => 'reference.id'}}],
       'result' => {'mode' => 'bound', 'binding' => 'url', 'form' => 'inet:url', 'identity' => [{'ref' => 'url.id'}], 'fields' => {'relation_kind' => {'literal' => 'reference'}}}}]}
  end

  def record(id, kind, type, attrs = {}, links = {})
    {'id' => id, 'kind' => kind, 'type' => type, 'attributes' => attrs, 'times' => {}, 'evidence' => [{'source_id' => 's1', 'field' => '/records/' + id}]}.merge(links)
  end

  def input
    {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0', 'collection_id' => 'case-a',
     'sources' => [{'id' => 's1', 'publisher' => 'synthetic', 'document' => 'capture', 'revision' => 'r1', 'collection' => 'case-a', 'independent_origin' => nil}],
     'records' => [
       record('c1', 'entity', 'adtech:creative'), record('c2', 'entity', 'adtech:creative'),
       record('u1', 'entity', 'inet:url', {'host' => 'h1'}), record('u2', 'entity', 'inet:url', {'host' => 'h1'}),
       record('h1', 'entity', 'inet:fqdn'),
       record('r1', 'assertion', 'references', {}, {'subject' => 'c1', 'object' => 'u1'}),
       record('r2', 'assertion', 'references', {}, {'subject' => 'c2', 'object' => 'u2'})]}
  end

  def query
    {'parameters' => {'seed' => 'c1'}, 'limits' => {'max_bindings' => 1000, 'max_results' => 100}}
  end

  def test_explicit_joins_do_not_borrow_other_creative_and_project_earlier_url
    result = E.new(contract).evaluate(input, query)
    assert_equal 'complete', result['status']
    assert_equal ['u1'], result['results'].map { |r| r['id'] }
    assert_equal 'inet:url', result['results'][0]['form']
    assert_equal 'r1', result['results'][0]['bindings']['reference']
    assert_equal 'not_evaluated', result['results'][0]['assessment_acceptance']
    assert_nil result['results'][0]['sources'][0]['independent_origin']
  end

  def test_optional_hostname_absence_does_not_discard_ip_url
    data = input
    data['records'].reject! { |r| r['id'] == 'h1' }
    data['records'].find { |r| r['id'] == 'u1' }['attributes'] = {}
    result = E.new(contract).evaluate(data, query)
    assert_equal ['u1'], result['results'].map { |r| r['id'] }
    refute result['results'][0]['bindings'].key?('host')
  end

  def test_unproven_optional_context_does_not_discard_independent_result
    data = input
    data['records'].find { |r| r['id'] == 'h1' }['evidence'] = []
    result = E.new(contract).evaluate(data, query)
    assert_equal ['u1'], result['results'].map { |r| r['id'] }
    refute result['results'][0]['bindings'].key?('host')
    assert result['diagnostics'].any? { |d| d['reason'].include?('optional context') }
  end

  def test_optional_context_unknown_does_not_turn_a_known_failed_path_into_unresolved
    data = input
    data['records'].find { |r| r['id'] == 'u1' }['attributes'] = {}
    c = contract
    c['branches'][0]['where'] = eq('url.id', {'literal' => 'different-url'})
    result = E.new(c).evaluate(data, query)
    assert_empty result['results']
    assert_equal 'no_qualifying_result', result['outcome']
    assert result['diagnostics'].any? { |d| d['status'] == 'unresolved' && d['scope'] == 'optional_context' }
    # Once a required claim actually depends on that context, absence remains
    # unresolved. This is not a general missing-as-false shortcut.
    c['branches'][0]['where'] = eq('host.id', {'literal' => 'h1'})
    assert_equal 'unresolved', E.new(c).evaluate(data, query)['outcome']
  end

  def test_unknown_required_join_is_unresolved_known_wrong_is_no_match
    data = input
    data['records'].find { |r| r['id'] == 'r1' }.delete('subject')
    result = E.new(contract).evaluate(data, query)
    assert_empty result['results']
    assert_includes result['diagnostics'].map { |d| d['status'] }, 'unresolved'
    data = input
    data['records'].find { |r| r['id'] == 'r1' }['subject'] = 'c2'
    result = E.new(contract).evaluate(data, query)
    assert_empty result['results']
    assert_includes result['diagnostics'].map { |d| d['status'] }, 'no_match'
  end

  def test_duplicate_input_identity_is_invalid_not_arbitrary_last_writer
    data = input
    data['records'] << data['records'][0].dup
    assert_raises(EveryPivot::SemanticRecords::InvalidInput) { E.new(contract).evaluate(data, query) }
  end

  def test_bounds_are_analyst_supplied_and_partial_is_not_exhaustive
    q = query
    q['limits']['max_bindings'] = 1
    result = E.new(contract).evaluate(input, q)
    assert_equal 'partial', result['status']
    refute result['coverage']['exhaustive_for_supplied_input']
    assert_equal 1, result['coverage']['examined_bindings']
    q['limits']['max_bindings'] = 0
    assert_raises(E::InvalidInput) { E.new(contract).evaluate(input, q) }
  end

  def test_missing_source_revision_is_not_qualified_provenance
    data = input
    data['sources'][0]['revision'] = nil
    result = E.new(contract).evaluate(data, query)
    assert_empty result['results']
    assert result['diagnostics'].any? { |d| d['reason'].include?('source evidence') }
  end

  def test_repeated_source_labels_do_not_manufacture_independence
    data = input
    data['sources'] << data['sources'][0].merge('id' => 's2', 'document' => 'syndicated-copy')
    data['records'].find { |r| r['id'] == 'r1' }['evidence'] << {'source_id' => 's2', 'field' => '/copy'}
    result = E.new(contract).evaluate(data, query)
    assert_equal 2, result['results'][0]['sources'].size
    assert_equal 'not_evaluated', result['coverage']['independence']
  end

  def test_policy_is_explicit_and_unknown_membership_is_not_clearance
    c = contract
    c['parameters']['exclude_selected'] = {'type' => 'boolean', 'required' => false, 'description' => 'Selected path exclusion'}
    c['branches'][0]['policies'] = [{'id' => 'selected-context', 'revision' => '1', 'scope' => 'path', 'subject' => {'ref' => 'reference.id'}, 'default_enabled' => false, 'enabled_parameter' => 'exclude_selected', 'reason' => 'Analyst-selected context exclusion', 'when' => eq('reference.attributes.context', {'literal' => 'controlled'})}]
    data = input
    data['records'].find { |r| r['id'] == 'r1' }['attributes']['context'] = 'controlled'
    assert_equal 1, E.new(c).evaluate(data, query)['results'].size
    q = query
    q['parameters']['exclude_selected'] = true
    result = E.new(c).evaluate(data, q)
    assert_empty result['results']
    assert_includes result['diagnostics'].map { |d| d['status'] }, 'suppressed'
    data['records'].find { |r| r['id'] == 'r1' }['attributes'].delete('context')
    result = E.new(c).evaluate(data, q)
    assert_equal 1, result['results'].size
    assert_equal 'unresolved', result['results'][0]['policy_evaluations'][0]['decision']['status']
  end

  def test_knowledge_cutoff_requires_evidence_not_an_activity_timestamp
    q = query.merge('knowledge_cutoff' => {})
    result = E.new(contract).evaluate(input, q)
    assert_empty result['results']
    assert_includes result['diagnostics'].map { |d| d['status'] }, 'unresolved'
    c = contract
    c['branches'][0].delete('knowledge')
    result = E.new(c).evaluate(input, q)
    assert_includes result['diagnostics'].map { |d| d['status'] }, 'unsupported'
  end

  def test_compiler_forbids_manufactured_assessment_outputs
    c = contract
    c['branches'][0]['result']['fields']['confidence'] = {'literal' => 1.0}
    assert_raises(EveryPivot::SemanticContract::InvalidContract) { E.new(c) }
  end

  def test_query_malformed_shape_unused_parameters_and_mathematical_integers
    [nil, [], 'query', 1].each do |bad|
      assert_raises(E::InvalidInput) { E.new(contract).evaluate(input, bad) }
    end
    q = query
    q['limits'] = {'max_bindings' => 1000.0, 'max_results' => 10.0}
    assert_equal ['u1'], E.new(contract).evaluate(input, q)['results'].map { |r| r['id'] }
    c = contract
    c['parameters']['period'] = {'type' => 'period', 'required' => false, 'description' => 'Explicit case dates'}
    q['parameters']['period'] = {'start' => '2026-10-03', 'end' => '2026-10-01'}
    empty = input.merge('records' => [])
    assert_raises(EveryPivot::SemanticTime::InvalidInput) { E.new(c).evaluate(empty, q) }
    c['parameters']['selector'] = {'type' => 'selector', 'required' => false, 'description' => 'Typed selector'}
    q['parameters'].delete('period')
    q['parameters']['selector'] = {}
    assert_raises(EveryPivot::SemanticIdentity::InvalidInput) { E.new(c).evaluate(empty, q) }
  end

  def test_structured_null_equality_is_not_identity_evidence
    evaluator = E.new(contract)
    expr = {'op' => 'eq', 'left' => {'literal' => {'id' => nil}}, 'right' => {'literal' => {'id' => nil}}}
    assert_equal 'unsupported', evaluator.expression(expr, {}, {})['status']
  end

  def test_query_selected_assertion_cannot_bypass_its_missing_evidence
    c = contract
    c['parameters']['extra'] = {'type' => 'record_id', 'required' => false, 'description' => 'Another selected record'}
    data = input
    data['records'].find { |r| r['id'] == 'r1' }['evidence'] = []
    c['branches'][0]['where'] = {'op' => 'present', 'value' => {'ref' => 'reference.id'}}
    q = query
    q['parameters']['extra'] = 'r1'
    assert_empty E.new(c).evaluate(data, q)['results']
  end
end
