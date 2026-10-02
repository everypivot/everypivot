#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'semantic_evaluator'

# Independent fixed counterexamples for reusable primitives. They do not infer
# expected results from the evaluator or claim that any native parser ran.
class SemanticExecutionPrimitivesTest < Minitest::Test
  E = EveryPivot::SemanticEvaluator
  C = EveryPivot::SemanticContract
  T = EveryPivot::SemanticTime

  def ref(value); {'ref' => value}; end
  def lit(value); {'literal' => value}; end
  def param(value); {'param' => value}; end
  def parameters
    {'day' => {'type' => 'date', 'required' => true, 'description' => 'Explicit UTC query date'}}
  end
  def contract(predicate = {'op' => 'present', 'value' => {'ref' => 'artifact.id'}})
    {'contract' => C::ID, 'version' => '1.0', 'pattern' => {'id' => 'PRIMITIVE_TEST', 'version' => '1.0.0'},
     'parameters' => parameters,
     'branches' => [{'id' => 'content', 'bindings' => [{'name' => 'artifact', 'kind' => 'entity', 'types' => ['evidence:artifact']}],
       'where' => predicate, 'result' => {'mode' => 'bound', 'binding' => 'artifact', 'form' => 'evidence:artifact',
         'identity' => [ref('artifact.id')], 'fields' => {'period' => {'calendar_period' => {'query_date' => param('day'), 'days' => lit(7)}}}}}]}
  end
  def content_predicate
    {'op' => 'content_matches', 'record' => ref('artifact.id'), 'source' => ref('artifact.attributes.content.source_id'),
     'sha256' => ref('artifact.attributes.content.sha256'), 'byte_length' => ref('artifact.attributes.content.byte_length'),
     'representation' => ref('artifact.attributes.content.representation')}
  end
  def bytes; "preserved\x00bytes\xff".b; end
  def input
    digest = Digest::SHA256.hexdigest(bytes)
    {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0', 'collection_id' => 'case',
     'sources' => [{'id' => 'content', 'publisher' => 'synthetic', 'document' => 'artifact.bin', 'revision' => 'r1', 'collection' => 'case',
       'independent_origin' => nil, 'content_hash' => {'algorithm' => 'sha256', 'value' => digest, 'scope' => 'exact_source_bytes'}}],
     'records' => [{'id' => 'a1', 'kind' => 'entity', 'type' => 'evidence:artifact',
       'attributes' => {'content' => {'source_id' => 'content', 'sha256' => digest, 'byte_length' => bytes.bytesize, 'representation' => 'exact_source_bytes'}},
       'times' => {}, 'evidence' => [{'source_id' => 'content', 'field' => '/'}]}]}
  end
  def query
    {'parameters' => {'day' => '2026-09-14'}, 'limits' => {'max_bindings' => 100, 'max_results' => 100}}
  end
  def envelope(start_at, end_at, role = 'service')
    {'binding' => {'object' => 'subject', 'occurrence' => 'assertion'}, 'field' => '/valid', 'source_revision' => 'r1',
     'clock' => {'id' => 'source-clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'interval', 'interval_role' => role,
     'start' => start_at, 'end' => end_at, 'start_inclusive' => true, 'end_inclusive' => false}
  end
  def selector(kind, value)
    result = {'kind' => kind, 'value' => value, 'provenance' => {'source' => 'query', 'record_id' => 'query', 'source_revision' => 'r1', 'field' => '/value', 'basis' => 'reported'}}
    kind == 'uri' ? result.merge('normalization' => 'literal_rfc3986_v1') : result.merge('normalization' => 'dns_ascii_lower_v1', 'representation' => 'ascii')
  end

  def test_calendar_period_is_fixed_explicit_and_inclusive_even_on_leap_year
    got = E.new(contract).evaluate(input, query)
    assert_equal({'start' => '2026-09-07', 'end' => '2026-09-14'}, got['results'].first['fields']['period'])
    assert_equal({'start' => '2024-02-29', 'end' => '2024-03-01'}, T.resolve_calendar_period(query_date: '2024-03-01', window_days: 1))
    %w[2026-02-30 2026-9-14 today].each do |date|
      q = query; q['parameters']['day'] = date
      assert_raises(T::InvalidInput) { E.new(contract).evaluate(input, q) }
    end
    c = contract; c['branches'][0]['result']['fields']['period']['calendar_period']['days'] = param('day')
    assert_raises(C::InvalidContract) { E.new(c) }
  end

  def test_declared_scalar_choices_fail_as_invalid_query_even_with_no_records
    c = contract
    c['parameters']['purpose'] = {'type' => 'string', 'required' => true, 'description' => 'Explicit inquiry', 'enum' => ['history', 'at_time']}
    q = query; q['parameters']['purpose'] = 'screen_everything'
    data = input; data['records'] = []
    assert_raises(E::InvalidInput) { E.new(c).evaluate(data, q) }
    q['parameters']['purpose'] = 'history'
    assert_empty E.new(c).evaluate(data, q)['results']
    c['parameters']['purpose']['enum'] = [false]
    assert_raises(C::InvalidContract) { E.new(c) }
  end

  def test_selector_kind_coverage_is_eager_and_not_a_negative_match
    c = contract
    c['parameters']['selector'] = {'type' => 'selector', 'required' => true, 'description' => 'URI only', 'selector_kinds' => ['uri']}
    q = query; q['parameters']['selector'] = selector('dns_name', 'example.test')
    data = input; data['records'] = []
    assert_raises(E::UnsupportedInput) { E.new(c).evaluate(data, q) }
    q['parameters']['selector'] = selector('uri', 'urn:example:resource')
    assert_empty E.new(c).evaluate(data, q)['results']
    c['parameters']['day']['selector_kinds'] = ['uri']
    assert_raises(C::InvalidContract) { E.new(c) }
  end

  def test_point_inquiry_requires_point_configuration_without_observing_any_data
    c = contract
    c['parameters']['purpose'] = {'type' => 'string', 'required' => true, 'description' => 'Inquiry kind', 'enum' => ['history', 'at']}
    c['parameters']['point'] = {'type' => 'time', 'required' => false, 'description' => 'Requested point', 'requires_when' => {'parameter' => 'purpose', 'values' => ['at']}}
    c['parameters']['point']['allowed_when'] = {'parameter' => 'purpose', 'values' => ['at']}
    q = query; q['parameters']['purpose'] = 'at'
    data = input; data['records'] = []
    assert_raises(E::InvalidInput) { E.new(c).evaluate(data, q) }
    q['parameters']['purpose'] = 'history'
    assert_empty E.new(c).evaluate(data, q)['results']
    q['parameters']['point'] = envelope('2026-09-01T00:00:00Z', '2026-09-02T00:00:00Z', 'occurrence')
    assert_raises(E::InvalidInput) { E.new(c).evaluate(data, q) }
    c['parameters']['point']['requires_when']['values'] = ['undeclared']
    assert_raises(C::InvalidContract) { E.new(c) }
  end

  def test_exact_supplied_binary_content_is_reproduced_and_missing_bytes_are_unknown
    evaluator = E.new(contract(content_predicate))
    got = evaluator.evaluate(input, query, preserved_source_bytes: {'content' => bytes})
    assert_equal ['a1'], got['results'].map { |row| row['id'] }
    assert_equal Digest::SHA256.hexdigest(bytes), got['supplied_content'].first['value']
    assert_equal 'unresolved', evaluator.evaluate(input, query)['outcome']
    assert_empty evaluator.evaluate(input, query)['results']
    assert_raises(E::InvalidInput) { evaluator.evaluate(input, query, preserved_source_bytes: {'content' => bytes + '!'}) }
  end

  def test_mismatched_length_digest_and_hash_scope_cannot_certify_preservation
    evaluator = E.new(contract(content_predicate))
    %w[sha256 byte_length].each do |key|
      data = input
      data['records'][0]['attributes']['content'][key] = key == 'sha256' ? '0' * 64 : 999
      assert_raises(E::InvalidInput) { evaluator.evaluate(data, query, preserved_source_bytes: {'content' => bytes}) }
    end
    data = input; data['sources'][0]['content_hash']['scope'] = 'selected_fields'
    assert_empty evaluator.evaluate(data, query, preserved_source_bytes: {'content' => bytes})['results']
    data = input; data['records'][0]['attributes']['content']['representation'] = 'decompressed_content'
    assert_equal 'unsupported', evaluator.evaluate(data, query, preserved_source_bytes: {'content' => bytes})['outcome']
  end

  def test_reference_source_scope_checks_linked_sources_not_asserted_source_label
    c = contract({'op' => 'all_in', 'left' => {'evidence_sources' => 'artifact'}, 'right' => param('sources')})
    c['parameters']['sources'] = {'type' => 'string_array', 'required' => true, 'description' => 'Permitted exact source-revision IDs'}
    q = query; q['parameters']['sources'] = ['content']
    assert_equal 1, E.new(c).evaluate(input, q)['results'].length
    q['parameters']['sources'] = ['another-source']
    assert_empty E.new(c).evaluate(input, q)['results']
    data = input; data['records'][0]['evidence'] = []
    q['parameters']['sources'] = ['content']
    assert_equal 'unresolved', E.new(c).evaluate(data, q)['outcome']
  end

  def test_separate_overlap_with_query_is_not_common_historical_applicability
    owner = envelope('2024-01-01T00:00:00Z', '2025-01-01T00:00:00Z')
    listing = envelope('2026-09-01T00:00:00Z', '2026-10-01T00:00:00Z', 'validity')
    period = {'start' => '2024-01-01', 'end' => '2026-10-01'}
    assert_equal 'match', T.within(owner, period: period, quantifier: 'some')['status']
    assert_equal 'match', T.within(listing, period: period, quantifier: 'some')['status']
    assert_equal 'no_match', T.coexists([owner, listing], period: period)['status']
    owner['end'] = '2026-09-15T00:00:00Z'
    assert_equal 'match', T.coexists([owner, listing], period: period)['status']
    owner['end'] = nil
    assert_equal 'unresolved', T.coexists([owner, listing], period: period)['status']
  end

  def test_touching_exclusive_boundaries_and_uncertain_occurrences_do_not_establish_coexistence
    a = envelope('2026-09-01T00:00:00Z', '2026-09-15T00:00:00Z')
    b = envelope('2026-09-15T00:00:00Z', '2026-10-01T00:00:00Z')
    period = {'start' => '2026-09-01', 'end' => '2026-09-30'}
    assert_equal 'no_match', T.coexists([a, b], period: period)['status']
    a['end_inclusive'] = true
    assert_equal 'match', T.coexists([a, b], period: period)['status']
    a['interval_role'] = 'occurrence'
    assert_equal 'unsupported', T.coexists([a, b], period: period)['status']
  end

  def uri_comparison(uri, component, right)
    E.new(contract).expression({'op' => 'uri_component_equal', 'uri' => lit(selector('uri', uri)), 'component' => component, 'right' => lit(right)}, {}, {})
  end

  def test_generic_uri_url_and_dns_host_have_distinct_positive_and_inapplicable_results
    assert_equal 'match', uri_comparison('https://EXAMPLE.test/a?b#c', 'url', 'https://EXAMPLE.test/a?b#c')['status']
    assert_equal 'match', uri_comparison('https://EXAMPLE.test/a', 'dns_host', selector('dns_name', 'example.test'))['status']
    %w[urn:example:thing mailto:user@example.test https://192.0.2.1/a https://[2001:db8::1]/a].each do |uri|
      assert_equal 'no_match', uri_comparison(uri, 'dns_host', selector('dns_name', 'example.test'))['status']
    end
    assert_equal 'no_match', uri_comparison('urn:example:thing', 'url', 'urn:example:thing')['status']
    assert_equal 'unsupported', uri_comparison('custom://example.test/a', 'dns_host', selector('dns_name', 'example.test'))['status']
    assert_equal 'unsupported', uri_comparison('https://%65xample.test/a', 'dns_host', selector('dns_name', 'example.test'))['status']
    assert_equal 'no_match', uri_comparison('https://foo,bar/a', 'dns_host', selector('dns_name', 'example.test'))['status']
  end

  def test_host_kind_retains_file_authority_and_distinguishes_inapplicability_from_unknown_mapping
    {'https://example.test/a' => 'dns', 'file://files.example.test/share/a' => 'dns',
     'file:///tmp/a' => 'none', 'urn:example:a' => 'none',
     'https://192.0.2.1/a' => 'ipv4', 'https://[2001:db8::1]/a' => 'ipv6',
     'https://[v1.token]/a' => 'ipvfuture', 'https://foo,bar/a' => 'reg_name'}.each do |uri, kind|
      assert_equal 'match', uri_comparison(uri, 'host_kind', kind)['status'], uri
      assert_equal 'no_match', uri_comparison(uri, 'host_kind', kind == 'dns' ? 'none' : 'dns')['status'], uri
    end
    ['custom://example.test/a', 'https://001.2.3.4/a', 'https://999.2.3.4/a', 'urn://authority/path'].each do |uri|
      assert_equal 'unsupported', uri_comparison(uri, 'host_kind', 'dns')['status']
    end
    [false, 'undeclared'].each do |bad|
      assert_equal 'unsupported', uri_comparison('urn:example:a', 'host_kind', bad)['status']
      assert_equal 'unsupported', uri_comparison('https://example.test/a', 'host_kind', bad)['status']
    end
    assert_equal 'match', uri_comparison('file://FILES.example.test/share/a', 'dns_host', selector('dns_name', 'files.example.test'))['status']
  end

  def test_declared_reference_arrays_are_nonempty_and_distinct_before_evidence_search
    c = contract
    c['parameters']['refs'] = {'type' => 'string_array', 'required' => true, 'description' => 'Explicit reference scope', 'min_items' => 1, 'unique_items' => true}
    [[], ['a', 'a']].each do |refs|
      q = query; q['parameters']['refs'] = refs
      assert_raises(E::InvalidInput) { E.new(c).evaluate(input, q) }
    end
  end

  def test_reference_array_ids_are_checked_even_if_no_row_can_match
    %w[source record].each do |kind|
      c = contract({'op' => 'eq', 'left' => lit(1), 'right' => lit(2)})
      c['parameters']['refs'] = {'type' => 'string_array', 'required' => true, 'description' => 'Explicit reference scope', 'item_reference' => kind}
      q = query; q['parameters']['refs'] = ['missing']
      assert_raises(E::InvalidInput) { E.new(c).evaluate(input, q) }
      q['parameters']['refs'] = [kind == 'source' ? 'content' : 'a1']
      assert_empty E.new(c).evaluate(input, q)['results']
      c['parameters']['refs']['item_reference'] = 'guessed'
      assert_raises(C::InvalidContract) { E.new(c) }
    end
  end

  def test_calendar_window_cannot_construct_an_out_of_domain_period
    assert_raises(T::InvalidInput) { T.resolve_calendar_period(query_date: '0000-01-01', window_days: 1) }
    assert_raises(T::InvalidInput) { T.resolve_calendar_period(query_date: '2026-10-02', window_days: 10_000_000) }
  end

  def test_text_array_requires_actual_nonblank_labels
    c = contract({'op' => 'nonblank_text_array', 'value' => ref('artifact.attributes.labels')})
    [false, [], [false], ['x', 1], [' ']].each do |value|
      data = input; data['records'][0]['attributes']['labels'] = value
      assert_empty E.new(c).evaluate(data, query)['results']
    end
    data = input; data['records'][0]['attributes']['labels'] = ['phase', 'phase']
    assert_equal 1, E.new(c).evaluate(data, query)['results'].size
    assert_equal 'unresolved', E.new(c).evaluate(input, query)['outcome']
  end

  def test_optional_absence_is_bounded_and_unknown_is_never_absent
    c = contract({'op' => 'binding_absent', 'binding' => 'contrary'})
    c['branches'][0]['bindings'] << {'name' => 'contrary', 'kind' => 'assertion', 'types' => ['context:contrary'], 'optional' => true,
      'where' => {'op' => 'eq', 'left' => ref('contrary.subject'), 'right' => ref('artifact.id')}}
    assert_equal 1, E.new(c).evaluate(input, query)['results'].size
    data = input
    candidate = {'id' => 'c1', 'kind' => 'assertion', 'type' => 'context:contrary', 'subject' => 'a1',
      'attributes' => {}, 'times' => {}, 'evidence' => [{'source_id' => 'content', 'field' => '/'}]}
    data['records'] << candidate
    assert_empty E.new(c).evaluate(data, query)['results']
    candidate['evidence'] = []
    got = E.new(c).evaluate(data, query)
    assert_empty got['results']
    assert_equal 'unresolved', got['outcome']
    candidate.delete('subject')
    assert_equal 'unresolved', E.new(c).evaluate(data, query)['outcome']
    q = query; q['limits']['max_bindings'] = 1
    assert_equal 'partial', E.new(c).evaluate(data, q)['status']
    c['branches'][0]['bindings'].last.delete('optional')
    assert_raises(C::InvalidContract) { E.new(c) }
  end

  def priority_case
    c = contract
    c['branches'][0]['bindings'] << {'name' => 'receipt', 'kind' => 'occurrence', 'types' => ['evidence:claim_receipt'], 'optional' => true,
      'where' => {'op' => 'eq', 'left' => ref('receipt.subject'), 'right' => ref('artifact.id')},
      'priority' => {'time' => ref('receipt.times.received'), 'period' => {'calendar_period' => {'query_date' => param('day'), 'days' => lit(180)}}}}
    c['branches'][0]['time_bindings'] = [{'value' => ref('receipt.times.received'), 'object' => ref('artifact.id'), 'occurrence' => ref('receipt.id')}]
    data = input
    [['a-old', '2024-12-10T00:00:00Z'], ['b-unknown', nil], ['z-recent', '2026-09-12T00:00:00Z']].each do |id, date|
      t = date && {'binding' => {'object' => 'a1', 'occurrence' => id}, 'field' => '/received', 'source_revision' => 'r1',
        'clock' => {'id' => 'clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0}, 'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => date}
      data['records'] << {'id' => id, 'kind' => 'occurrence', 'type' => 'evidence:claim_receipt', 'subject' => 'a1',
        'attributes' => {}, 'times' => t ? {'received' => t} : {}, 'evidence' => [{'source_id' => 'content', 'field' => '/received'}]}
    end
    [c, data]
  end

  def test_search_focus_orders_visits_without_filtering_older_or_undated
    c, data = priority_case
    got = E.new(c).evaluate(data, query)
    assert_equal %w[z-recent a-old b-unknown], got['results'].map { |r| r['bindings']['receipt'] }
    assert_equal %w[recent outside_focus undated_or_unresolved], got['results'].map { |r| r['search_priority'][0]['group'] }
    q = query; q['limits']['max_results'] = 1
    limited = E.new(c).evaluate(data, q)
    assert_equal ['z-recent'], limited['results'].map { |r| r['bindings']['receipt'] }
    assert_equal true, limited['coverage']['search_complete_for_supplied_input']
    q = query; q['limits']['max_bindings'] = 5
    partial = E.new(c).evaluate(data, q)
    assert_equal 'partial', partial['status']
    refute partial['coverage']['search_complete_for_supplied_input']
  end

  def test_priority_failure_cannot_discard_an_otherwise_supported_result
    c, data = priority_case
    data['records'].last['times']['received']['binding']['object'] = 'z-recent'
    got = E.new(c).evaluate(data, query)
    assert_equal 3, got['results'].size
    assert_equal 'undated_or_unresolved', got['results'].find { |r| r['bindings']['receipt'] == 'z-recent' }['search_priority'][0]['group']
    data['records'].reject! { |r| r['kind'] == 'occurrence' }
    assert_equal 1, E.new(c).evaluate(data, query)['results'].size
    c['branches'][0]['bindings'].last['priority']['time'] = ref('artifact.times.observed')
    assert_raises(C::InvalidContract) { E.new(c) }
  end

  def test_malformed_query_is_not_masked_by_unsupported_selector_kind
    c = contract
    c['parameters']['selector'] = {'type' => 'selector', 'required' => true, 'description' => 'URI only', 'selector_kinds' => ['uri']}
    q = query; q['parameters']['selector'] = selector('dns_name', 'example.test')
    q['limits']['max_bindings'] = false
    assert_raises(E::InvalidInput) { E.new(c).evaluate(input, q) }
  end

  def test_content_source_and_representation_wrong_json_types_are_invalid
    %w[source_id representation].each do |key|
      [false, []].each do |bad|
        data = input; data['records'][0]['attributes']['content'][key] = bad
        assert_raises(E::InvalidInput) { E.new(contract(content_predicate)).evaluate(data, query) }
      end
    end
  end

  def test_coexists_rejects_string_parameter_as_period_at_compile_time
    c = contract
    c['parameters']['state'] = {'type' => 'time', 'required' => true, 'description' => 'state'}
    c['branches'][0]['where'] = {'op' => 'coexists', 'values' => [param('state')], 'period' => param('day')}
    assert_raises(C::InvalidContract) { E.new(c) }
  end

  def test_optional_time_order_preserves_only_genuinely_absent_occurrence
    c = contract({'op'=>'time_compare_if_present','operator'=>'lte','left'=>ref('artifact.times.occurred'),'right'=>ref('artifact.times.available')})
    c['branches'][0]['time_bindings'] = %w[occurred available].map { |k| {'value'=>ref('artifact.times.'+k),'object'=>ref('artifact.id'),'occurrence'=>ref('artifact.id')} }
    assert_equal 1, E.new(c).evaluate(input,query)['results'].size
    data=input;data['records'][0]['times']['occurred']=nil
    assert_raises(EveryPivot::SemanticRecords::InvalidInput) { E.new(c).evaluate(data,query) }
    t={'binding'=>{'object'=>'a1','occurrence'=>'a1'},'field'=>'/','source_revision'=>'r1','clock'=>{'id'=>'clock','reference'=>'UTC','uncertainty_seconds'=>0},'timezone'=>'UTC','precision'=>'instant','interval_role'=>'occurrence','value'=>'2026-09-01T00:00:00Z'}
    data['records'][0]['times']={'occurred'=>t,'available'=>Marshal.load(Marshal.dump(t))}
    assert_equal 1,E.new(c).evaluate(data,query)['results'].size
    data['records'][0]['times']['available']['value']='2026-08-01T00:00:00Z'
    assert_empty E.new(c).evaluate(data,query)['results']
    data['records'][0]['times']['occurred'].delete('value')
    assert_empty E.new(c).evaluate(data,query)['results']
  end

  def test_explicit_policy_dispute_and_opposing_claims_keep_their_exact_class_scope
    c=contract
    c['branches'][0]['policies']=[{'id'=>'control','revision'=>'1','scope'=>'source','subject'=>lit('selected-subject'),'default_enabled'=>true,'required_evaluation'=>true,
      'when'=>{'op'=>'eq','left'=>ref('artifact.attributes.membership'),'right'=>lit('member')},
      'allow_when'=>{'op'=>'eq','left'=>ref('artifact.attributes.membership'),'right'=>lit('not_member')},
      'conflict_when'=>{'op'=>'eq','left'=>ref('artifact.attributes.membership'),'right'=>lit('contested')},
      'partition_by'=>[ref('artifact.attributes.class')],'reason'=>'Selected class only'}]
    data=input; data['records'][0]['attributes'].merge!('membership'=>'not_member','class'=>'A')
    other=Marshal.load(Marshal.dump(data['records'][0]));other['id']='other';other['attributes']['membership']='contested';data['records']<<other
    got=E.new(c).evaluate(data,query);assert_empty got['results'];assert_equal 'unresolved',got['outcome']
    other['attributes']['class']='B'
    assert_equal ['a1'],E.new(c).evaluate(data,query)['results'].map{|r|r['id']}
    other['attributes']['class']='A';other['attributes']['membership']='member'
    assert_empty E.new(c).evaluate(data,query)['results']
    c['branches'][0]['policies'][0]['required_evaluation']=false
    got=E.new(c).evaluate(data,query);assert_equal 2,got['results'].size;assert got['results'].all?{|r|r['policy_evaluations'][0]['decision']['status']=='unresolved'}
  end
end
