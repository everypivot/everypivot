#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'semantic_evaluator'

# Independent synthetic expectations: artifact A was sighted in December 2024;
# a September 2026 extraction from those preserved bytes can be newly available
# knowledge without a new sighting. Artifact B sharing a selector is a different
# occurrence. Expected results below are authored, not computed by another run.
class SemanticFoundationAdversarialTest < Minitest::Test
  E = EveryPivot::SemanticEvaluator
  C = EveryPivot::SemanticContract
  R = EveryPivot::SemanticRecords
  I = EveryPivot::SemanticIdentity
  T = EveryPivot::SemanticTime

  def ref(value)
    {'ref' => value}
  end

  def eq(left, right)
    {'op' => 'eq', 'left' => ref(left), 'right' => right}
  end

  def stamp(value, object = 'artifact_a', occurrence = 'extraction_a', field = '/records/extraction_a/available')
    {'binding' => {'object' => object, 'occurrence' => occurrence}, 'field' => field,
     'source_revision' => 'revision-1', 'clock' => {'id' => 'capture-clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end

  def row(id, kind, type, attributes = {}, links = {})
    {'id' => id, 'kind' => kind, 'type' => type, 'attributes' => attributes, 'times' => {},
     'evidence' => [{'source_id' => 'source-1', 'field' => '/records/' + id}]}.merge(links)
  end

  def input
    a = row('extraction_a', 'occurrence', 'extracts_path', {}, 'subject' => 'artifact_a', 'object' => 'selector_a')
    a['times']['available'] = stamp('2026-09-14T12:00:00Z')
    a['times']['knowledge'] = stamp('2026-09-15T08:00:00Z', 'artifact_a', 'extraction_a', '/records/extraction_a/knowledge')
    b = row('extraction_b', 'occurrence', 'extracts_path', {}, 'subject' => 'artifact_b', 'object' => 'selector_a')
    b['times']['available'] = stamp('2026-09-14T12:00:00Z', 'artifact_b', 'extraction_b', '/records/extraction_b/available')
    {'contract' => R::CONTRACT, 'version' => '1.0', 'collection_id' => 'collection-a',
     'sources' => [{'id' => 'source-1', 'publisher' => 'synthetic laboratory', 'document' => 'preserved-analysis-record',
                    'revision' => 'revision-1', 'collection' => 'collection-a', 'independent_origin' => nil}],
     'records' => [row('artifact_a', 'entity', 'file:bytes', {'historical_sighting' => '2024-12-03T10:00:00Z'}),
                   row('artifact_b', 'entity', 'file:bytes'), row('selector_a', 'entity', 'file:sourcepath', {'value' => '/build/project/main.c'}), a, b]}
  end

  def contract
    {'contract' => C::ID, 'version' => '1.0', 'pattern' => {'id' => 'SYNTHETIC_EXTRACTION_BINDING', 'version' => '1.0.0'},
     'parameters' => {'seed' => {'type' => 'record_id', 'required' => true, 'description' => 'Exact preserved artifact'},
                      'period' => {'type' => 'period', 'required' => true, 'description' => 'Selected finding availability dates'}},
     'branches' => [{'id' => 'per_artifact', 'bindings' => [
       {'name' => 'artifact', 'kind' => 'entity', 'types' => ['file:bytes'], 'where' => eq('artifact.id', {'param' => 'seed'})},
       {'name' => 'run', 'kind' => 'occurrence', 'types' => ['extracts_path'], 'where' => eq('run.subject', ref('artifact.id'))},
       {'name' => 'selector', 'kind' => 'entity', 'types' => ['file:sourcepath'], 'where' => eq('selector.id', ref('run.object'))}
     ], 'where' => {'op' => 'within', 'value' => ref('run.times.available'), 'period' => {'param' => 'period'}, 'quantifier' => 'contained'},
       'knowledge' => [ref('run.times.knowledge')],
       'time_bindings' => [
         {'value' => ref('run.times.available'), 'object' => ref('artifact.id'), 'occurrence' => ref('run.id')},
         {'value' => ref('run.times.knowledge'), 'object' => ref('artifact.id'), 'occurrence' => ref('run.id')}],
       'result' => {'mode' => 'bound', 'binding' => 'artifact', 'form' => 'file:bytes', 'identity' => [ref('artifact.id')],
                    'fields' => {'path' => ref('selector.attributes.value'), 'extraction_id' => ref('run.id')}}}]}
  end

  def query
    {'parameters' => {'seed' => 'artifact_a', 'period' => {'start' => '2026-09-01', 'end' => '2026-09-30'}},
     'limits' => {'max_bindings' => 1000, 'max_results' => 100}}
  end

  def evaluate(data = input, c = contract, q = query)
    E.new(c).evaluate(data, q)
  end

  def record(data, id)
    data['records'].find { |r| r['id'] == id }
  end

  def no_qualification(result, statuses)
    assert_empty result['results']
    assert (result['diagnostics'].map { |d| d['status'] } & statuses).any?, result['diagnostics'].inspect
  end

  def test_later_extraction_preserves_old_sighting_and_does_not_borrow_other_artifact
    data = input
    before = Marshal.dump(data)
    result = evaluate(data)
    assert_equal ['artifact_a'], result['results'].map { |r| r['id'] }
    assert_equal 'extraction_a', result['results'][0]['bindings']['run']
    assert_equal '2024-12-03T10:00:00Z', record(data, 'artifact_a')['attributes']['historical_sighting']
    assert_equal before, Marshal.dump(data)
    assert_equal 'not_evaluated', result['coverage']['assessment_acceptance']
    refute result['results'][0].key?('confidence')
  end

  def test_known_wrong_object_and_occurrence_are_not_a_valid_time_for_this_binding
    {'object' => 'artifact_b', 'occurrence' => 'extraction_b'}.each do |role, wrong|
      data = input
      record(data, 'extraction_a')['times']['available']['binding'][role] = wrong
      assert_empty R.validate(data), 'the reference exists; the claimed binding is nevertheless wrong'
      no_qualification(evaluate(data), ['no_match'])
    end
  end

  def test_unknown_binding_and_unknown_availability_are_distinct_from_malformed_time
    data = input
    record(data, 'extraction_a')['times']['available']['binding']['occurrence'] = nil
    no_qualification(evaluate(data), ['unresolved'])
    data = input
    record(data, 'extraction_a')['times'].delete('available')
    no_qualification(evaluate(data), ['unresolved'])
    data = input
    record(data, 'extraction_a')['times']['available']['value'] = '2026-02-30T12:00:00Z'
    assert_raises(R::InvalidInput) { evaluate(data) }
  end

  def test_missing_or_wrong_join_cannot_turn_shared_selector_into_same_artifact
    data = input
    record(data, 'extraction_a').delete('subject')
    no_qualification(evaluate(data), ['unresolved'])
    data = input
    record(data, 'extraction_a')['subject'] = 'artifact_b'
    no_qualification(evaluate(data), ['no_match'])
  end

  def test_complete_known_revision_conflict_is_invalid_while_unknown_revision_is_unresolved
    data = input
    record(data, 'extraction_a')['times']['available']['source_revision'] = 'other-revision'
    assert_raises(R::InvalidInput) { evaluate(data) }
    data = input
    data['sources'][0]['revision'] = nil
    no_qualification(evaluate(data), ['unresolved'])
  end

  def test_time_must_be_supported_by_its_own_carrier_evidence_field
    data = input
    record(data, 'extraction_a')['times']['available']['field'] = '/records/extraction_b/available'
    no_qualification(evaluate(data), %w[no_match unresolved])
  end

  def test_json_pointer_empty_key_is_not_a_whole_parent_field
    data = input
    # The trailing slash denotes an empty property name. It must not be trimmed
    # into the parent /records/extraction_a and thereby authorize its siblings.
    record(data, 'extraction_a')['evidence'][0]['field'] = '/records/extraction_a/'
    no_qualification(evaluate(data), %w[no_match unresolved])
  end

  def test_same_revision_label_in_two_sources_does_not_select_a_time_origin
    data = input
    # Independent documents can both call their revision "revision-1" and use
    # the same field path. Neither that label nor the shared path identifies
    # which document supplied this timestamp; the evaluator must not pick one.
    data['sources'] << data['sources'][0].merge('id' => 'source-2',
      'publisher' => 'another synthetic laboratory', 'document' => 'different-analysis-record')
    extra = {'source_id' => 'source-2', 'field' => '/records/extraction_a'}
    record(data, 'extraction_a')['evidence'] << extra
    no_qualification(evaluate(data), ['unresolved'])
    # An explicitly unrelated supporting field does not make the time origin
    # ambiguous, because only the first source covers the selected time field.
    extra['field'] = '/unrelated-record'
    assert_equal ['artifact_a'], evaluate(data)['results'].map { |r| r['id'] }
  end

  def test_as_known_cutoff_does_not_backdate_later_findings
    q = query.merge('knowledge_cutoff' => stamp('2026-09-15T07:59:59Z', 'case-query', 'query-issued', '/query/cutoff'))
    no_qualification(evaluate(input, contract, q), ['no_match'])
    q['knowledge_cutoff']['value'] = '2026-09-15T08:00:00Z'
    assert_equal ['artifact_a'], evaluate(input, contract, q)['results'].map { |r| r['id'] }
    data = input
    record(data, 'extraction_a')['times'].delete('knowledge')
    no_qualification(evaluate(data, contract, q), ['unresolved'])
    assert_equal ['artifact_a'], evaluate(data)['results'].map { |r| r['id'] }, 'retrospective inquiry does not invent earlier availability'
  end

  def test_unsupported_query_cutoff_is_rejected_even_when_there_are_no_records
    q = query.merge('knowledge_cutoff' => stamp('2026-09-15T08:00:00Z', 'case-query', 'query-issued', '/query/cutoff'))
    q['knowledge_cutoff']['clock']['reference'] = 'TAI'
    assert_raises(E::UnsupportedInput) { evaluate(input.merge('records' => []), contract, q) }
  end

  def test_unknown_query_cutoff_is_not_reported_as_a_resolved_empty_search
    q = query.merge('knowledge_cutoff' => {})
    no_qualification(evaluate(input.merge('records' => []), contract, q), ['unresolved'])
  end

  def test_unknown_exclusion_membership_stays_unknown_and_known_exclusion_suppresses
    c = contract
    c['branches'][0]['policies'] = [{'id' => 'controlled-context', 'revision' => 'policy-r1', 'scope' => 'occurrence',
      'subject' => ref('run.id'), 'default_enabled' => true, 'reason' => 'Exclude the selected controlled occurrence',
      'when' => eq('run.attributes.controlled', {'literal' => true})}]
    result = evaluate(input, c)
    assert_equal ['artifact_a'], result['results'].map { |r| r['id'] }
    assert_equal 'unresolved', result['results'][0]['policy_evaluations'][0]['decision']['status']
    refute result['results'][0].key?('cleared')
    data = input
    record(data, 'extraction_a')['attributes']['controlled'] = true
    no_qualification(evaluate(data, c), ['suppressed'])
    record(data, 'extraction_a')['attributes']['controlled'] = false
    assert_equal ['artifact_a'], evaluate(data, c)['results'].map { |r| r['id'] }
  end

  def test_binding_and_result_caps_report_partial_and_preserve_witnesses
    q = query
    q['limits']['max_bindings'] = 1
    result = evaluate(input, contract, q)
    assert_equal 'partial', result['status']
    refute result['coverage']['exhaustive_for_supplied_input']
    data = input
    second = Marshal.load(Marshal.dump(record(data, 'extraction_a')))
    second['id'] = 'extraction_c'
    second['evidence'][0]['field'] = '/records/extraction_c'
    second['times'].each do |name, t|
      t['binding']['occurrence'] = 'extraction_c'
      t['field'] = '/records/extraction_c/' + name
    end
    data['records'] << second
    full = evaluate(data)
    assert_equal %w[extraction_a extraction_c], full['results'].map { |r| r['bindings']['run'] }.sort
    q = query
    q['limits']['max_results'] = 1
    result = evaluate(data, contract, q)
    assert_equal 1, result['results'].length
    assert_equal 'partial', result['status']
    refute result['coverage']['exhaustive_for_supplied_input']
    assert_equal 'not_evaluated', result['coverage']['external_completeness']
    assert_equal true, result['coverage']['search_complete_for_supplied_input']
    assert_equal({'qualified_witnesses_before_limit' => 2, 'returned' => 1, 'truncated' => true}, result['coverage']['result_selection'])
  end

  def test_structured_and_boolean_values_cannot_exploit_truthiness_or_scalar_equality
    e = E.new(contract)
    [[[], []], [{'id' => 'same'}, {'id' => 'same'}]].each do |left, right|
      spec = {'op' => 'eq', 'left' => {'literal' => left}, 'right' => {'literal' => right}}
      assert_equal 'unsupported', e.expression(spec, {}, {})['status']
    end
    [[false, 0], [true, 1], [false, 'false'], [true, 'true']].each do |left, right|
      spec = {'op' => 'eq', 'left' => {'literal' => left}, 'right' => {'literal' => right}}
      assert_equal 'no_match', e.expression(spec, {}, {})['status']
    end
    [true, false, '1', 0, -1, 1.1].each do |bad|
      q = query
      q['limits']['max_results'] = bad
      assert_raises(E::InvalidInput) { evaluate(input, contract, q) }
    end
  end

  def selector(attrs = {})
    {'kind' => 'issuer_serial', 'issuer_namespace' => {'kind' => 'reported_name', 'value' => 'CN=Issuer', 'matching_rule' => 'exact_v1'},
     'serial' => '10', 'serial_radix' => 10,
     'provenance' => {'source' => 'source-1', 'record_id' => 'selector_a', 'source_revision' => 'revision-1',
                       'field' => '/records/selector_a/selector', 'basis' => 'reported'}}.merge(attrs)
  end

  def test_record_selector_provenance_cannot_borrow_an_unrelated_source_revision_or_field
    c = contract
    c['parameters']['wanted'] = {'type' => 'selector', 'required' => true, 'description' => 'Explicit issuer and serial selector'}
    c['branches'][0]['where'] = {'op' => 'all', 'args' => [c['branches'][0]['where'],
      {'op' => 'typed_equal', 'left' => ref('selector.attributes.selector'), 'right' => {'param' => 'wanted'}}]}
    data = input
    record(data, 'selector_a')['attributes']['selector'] = selector
    q = query
    q['parameters']['wanted'] = selector('serial' => '0A', 'serial_radix' => 16)
    assert_equal ['artifact_a'], evaluate(data, c, q)['results'].map { |r| r['id'] }
    {'source' => 'unlinked-source', 'record_id' => 'artifact_b', 'source_revision' => 'never-reported', 'field' => '/records/extraction_b/selector'}.each do |key, bad|
      altered = Marshal.load(Marshal.dump(data))
      record(altered, 'selector_a')['attributes']['selector']['provenance'][key] = bad
      no_qualification(evaluate(altered, c, q), %w[no_match unresolved])
    end
  end

  def test_radix_and_literal_uri_hierarchy_do_not_invent_equivalence
    # Decimal 10 is hex 0A; hex 10 is decimal 16. No implementation-derived oracle.
    assert_equal 'match', I.compare(selector, selector('serial' => '0a', 'serial_radix' => 16))['status']
    assert_equal 'no_match', I.compare(selector, selector('serial' => '10', 'serial_radix' => 16))['status']
    assert_raises(I::InvalidInput) { I.normalize(selector('serial' => '0x0A', 'serial_radix' => 16)) }
    uri = {'kind' => 'uri', 'normalization' => 'literal_rfc3986_v1', 'value' => 'custom:opaque/path?x=1#part', 'provenance' => selector['provenance']}
    parsed = I.normalize(uri)['reference']
    refute parsed.key?('authority')
    refute parsed.key?('url')
    assert_equal 'no_match', I.compare(uri, uri.merge('value' => 'custom:opaque%2Fpath?x=1#part'))['status']
    url = 'https://192.0.2.77/resource?x=1#part'
    parsed = I.parse_uri(url)
    assert_equal url, parsed['uri']
    assert_equal url, parsed['url']
    refute parsed.key?('domain')
    ['custom:opaque path', 'custom:path%zz', 'https://[broken]/path'].each { |bad| assert_raises(I::InvalidInput) { I.parse_uri(bad) } }
  end

  def test_compiler_requires_time_roles_and_forbids_precomputed_authority
    c = contract
    c['branches'][0].delete('time_bindings')
    assert_raises(C::InvalidContract) { E.new(c) }
    c = contract
    c['branches'][0]['result']['fields']['accepted_assessment'] = {'literal' => true}
    assert_raises(C::InvalidContract) { E.new(c) }
    data = input
    record(data, 'extraction_a')['attributes'].merge!('match' => true, 'confidence' => 1, 'accepted_assessment' => true)
    record(data, 'extraction_a')['times'].delete('available')
    no_qualification(evaluate(data), ['unresolved'])
  end

  def test_temporal_operands_cannot_bypass_binding_checks_by_hiding_in_attributes
    c = contract
    c['branches'][0]['where']['value'] = ref('run.attributes.unbound_time')
    c['branches'][0]['time_bindings'].reject! { |b| b.dig('value', 'ref') == 'run.times.available' }
    # A record-derived temporal value needs an explicit occurrence/object and
    # evidence field binding wherever it is stored; v1 stores those in times.
    assert_raises(C::InvalidContract) { E.new(c) }
  end
end
