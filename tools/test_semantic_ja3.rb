#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require_relative 'semantic_evaluator'

# Synthetic normalized-source contract cases, not PCAP parser, native collector,
# source-truth or analyst acceptance. Expectations precede evaluation and do not
# use the evaluator to construct an expected result.
class SemanticJa3Test < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  FIXTURES = File.join(ROOT, 'fixtures/semantic-families/ja3')
  E = EveryPivot::SemanticEvaluator

  def read(name)
    JSON.parse(File.read(File.join(FIXTURES, name)))
  end

  def evidence
    read('evidence.json')
  end

  def contract(role = 'client')
    id = role == 'client' ? 'OSINT_TLS_JA3_TO_FQDNS' : 'OSINT_TLS_JA3S_TO_FQDNS'
    JSON.parse(File.read(File.join(ROOT, 'contracts/semantics', id + '.json')))
  end

  def query(role = 'client')
    read(role + '-query.json')
  end

  def run_case(role = 'client', data = evidence, request = query(role))
    E.new(contract(role)).evaluate(data, request)
  end

  def record(data, id)
    data.fetch('records').find { |r| r['id'] == id } || raise("fixture record absent: #{id}")
  end

  def remove(data, *ids)
    loop do
      dependent = data['records'].select { |r| ids.include?(r['subject']) || ids.include?(r['object']) }.map { |r| r['id'] }
      expanded = (ids + dependent).uniq
      break if expanded == ids
      ids = expanded
    end
    data['records'].reject! { |r| ids.include?(r['id']) }
  end

  def assert_empty_result(got, status = nil)
    assert_empty got['results']
    assert_equal status, got['outcome'] if status
  end

  def cutoff(value)
    {'binding' => {'object' => 'case-knowledge-question', 'occurrence' => 'case-cutoff'},
     'field' => '/query/knowledge_cutoff', 'source_revision' => 'case-1',
     'clock' => {'id' => 'case-clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end

  def source_pointer(source, pointer)
    pointer.split('/').drop(1).reduce(source) { |value, part| value.fetch(part.gsub('~1', '/').gsub('~0', '~')) }
  end

  def test_base_source_mapping_and_independently_declared_expectations
    data = evidence
    source = read('source.json')
    assert_equal 'independently_authored_synthetic_tls_evidence', source['fixture_type']
    assert_equal Digest::SHA256.file(File.join(FIXTURES, 'source.json')).hexdigest, data['sources'].first.dig('content_hash', 'value')
    data['records'].each do |r|
      r['evidence'].each { |edge| assert_kind_of Hash, source_pointer(source, edge['field']) }
      r['times'].each_value { |t| assert_equal source_pointer(source, t['field']), t['value'] }
      r['attributes'].select { |key, _| key.end_with?('selector') }.each_value do |selector|
        assert_equal source_pointer(source, selector['provenance']['field']), selector
      end
    end
    read('expected.json')['cases'].first(2).each do |expected|
      role = expected['id'].start_with?('client') ? 'client' : 'server'
      got = run_case(role)
      assert_equal 'complete', got['status']
      assert_equal 1, got['results'].length
      fields = got['results'].first['fields']
      assert_equal expected['expected_domain'], fields['named_domain']
      assert_equal expected['expected_occurrence'], fields['occurrence_id']
      assert_equal expected['expected_state'], fields['observed_state']
      assert_equal 'evidence_only', got['results'].first['evidence_mode']
      assert_equal 'not_evaluated', got['results'].first['assessment_acceptance']
    end
  end

  def test_client_and_server_use_their_own_dates_across_midnight
    q = query('server')
    q['parameters']['period'] = {'start' => '2026-09-30', 'end' => '2026-09-30'}
    assert_empty_result(run_case('server', evidence, q), 'outside_scope')
    q = query
    q['parameters']['period'] = {'start' => '2026-10-01', 'end' => '2026-10-01'}
    assert_empty_result(run_case('client', evidence, q), 'outside_scope')
  end

  def test_equal_hex_of_other_fingerprint_kind_is_not_a_match
    q = query('server')
    q['parameters']['selector'] = query['parameters']['selector']
    assert_raises(E::UnsupportedInput) { run_case('server', evidence, q) }
    q = query
    q['parameters']['selector'] = query('server')['parameters']['selector']
    assert_raises(E::UnsupportedInput) { run_case('client', evidence, q) }
  end

  def test_observed_attempt_needs_no_observed_response
    data = evidence
    remove(data, 'm-server')
    assert_equal 1, run_case('client', data)['results'].length
    assert_empty_result(run_case('server', data), 'unresolved')
    assert_equal 'attempt_observed', run_case('client', data)['results'].first['fields']['observed_state']
  end

  def test_planned_and_offline_generated_messages_do_not_become_network_attempts
    %w[planned offline_generated failed].each do |state|
      data = evidence
      record(data, 'm-client')['attributes']['observed_state'] = state
      assert_empty_result(run_case('client', data))
    end
  end

  def test_response_cannot_borrow_client_message_state
    data = evidence
    record(data, 'm-server')['attributes']['observed_state'] = 'attempt_observed'
    assert_empty_result(run_case('server', data))
    data = evidence
    record(data, 'm-server')['attributes']['message_role'] = 'client'
    assert_empty_result(run_case('server', data))
  end

  def test_unknown_optional_endpoint_context_does_not_invent_or_erase_named_exchange
    data = evidence
    %w[client_endpoint destination_endpoint vantage].each { |key| record(data, 'e1')['attributes'].delete(key) }
    record(data, 'm-server')['attributes'].delete('responder_endpoint')
    got = run_case('server', data)
    assert_equal 1, got['results'].length
    fields = got['results'].first['fields']
    %w[client_endpoint destination_endpoint responder_endpoint vantage].each { |key| assert_nil fields[key] }
    assert_equal 'alpha.example.test', fields['named_domain']
  end

  def test_actual_exchange_leg_message_and_name_correspondence_each_required
    changes = [
      ['e1', 'leg_id', 'different-leg'],
      ['m-client', 'exchange_id', 'another-exchange'],
      ['n-client', 'leg_id', 'different-leg'],
      ['n-client', 'associated_message_id', 'm-server'],
      ['n-client', 'name', 'different.example.test'],
      ['d-alpha', 'normalization', 'unmapped-name-rule']
    ]
    changes.each do |id, field, value|
      data = evidence
      record(data, id)['attributes'][field] = value
      assert_empty_result(run_case('client', data))
    end
  end

  def test_dns_certificate_san_and_scan_plan_cannot_supply_domain_association
    %w[dns_cooccurrence certificate_san scan_plan].each do |basis|
      data = evidence
      record(data, 'n-client')['attributes']['basis'] = basis
      assert_empty_result(run_case('client', data))
    end
    %w[joined_application_request observed_scan_exchange].each do |basis|
      data = evidence
      record(data, 'n-client')['attributes']['basis'] = basis
      assert_equal 1, run_case('client', data)['results'].length
    end
  end

  def test_reported_fingerprint_retains_its_origin_without_local_reproduction
    result = run_case['results'].first
    assert_equal 'reported', result.dig('fields', 'fingerprint', 'provenance', 'basis')
    assert_equal 'fixture-r1', result.dig('fields', 'fingerprint', 'provenance', 'source_revision')
    refute result['fields'].key?('locally_reproduced')
    %w[source_revision field record_id source].each do |field|
      data = evidence
      record(data, 'm-client')['attributes']['selector']['provenance'][field] = 'unsupported-origin'
      assert_empty_result(run_case('client', data))
    end
  end

  def test_actual_time_binding_cannot_be_borrowed_from_other_occurrence
    data = evidence
    record(data, 'm-client')['times']['occurred']['binding']['occurrence'] = 'm-server'
    assert_empty_result(run_case('client', data))
  end

  def test_as_known_uses_derivation_establishment_and_scoped_receipts
    q = query
    q['knowledge_cutoff'] = cutoff('2026-10-01T00:05:00Z')
    assert_equal 1, run_case('client', evidence, q)['results'].length
    q['knowledge_cutoff'] = cutoff('2026-10-01T00:02:30Z')
    assert_empty_result(run_case('client', evidence, q))
    # Capture occurred before this cutoff, but its selected derivation and
    # association witnesses do not establish knowledge by the earlier time.
    q['knowledge_cutoff'] = cutoff('2026-09-30T23:59:55Z')
    assert_empty_result(run_case('client', evidence, q))
  end

  def test_unknown_knowledge_keeps_retrospective_activity_but_not_as_known_result
    data = evidence
    remove(data, 'derive-client', 'establish-client')
    assert_equal 1, run_case('client', data)['results'].length
    q = query
    q['knowledge_cutoff'] = cutoff('2026-10-01T00:05:00Z')
    assert_empty_result(run_case('client', data, q), 'unresolved')
  end

  def test_receipt_from_other_collection_cannot_supply_requested_collection_knowledge
    data = evidence
    record(data, 'receive-name-client')['attributes']['collection_id'] = 'another-collection'
    assert_equal 1, run_case('client', data)['results'].length
    q = query
    q['knowledge_cutoff'] = cutoff('2026-10-01T00:05:00Z')
    assert_empty_result(run_case('client', data, q), 'unresolved')
  end

  def test_future_occurrence_cannot_be_known_earlier_through_bad_receipt_dates
    data = evidence
    %w[derive-client receive-client establish-client receive-name-client].each do |id|
      record(data, id)['times'].each_value { |time| time['value'] = '2026-09-29T00:00:00Z' }
    end
    q = query
    q['knowledge_cutoff'] = cutoff('2026-09-30T12:00:00Z')
    assert_empty_result(run_case('client', data, q))
  end

  def test_impossible_receipt_or_derivation_chronology_only_defeats_as_known_claim
    [['derive-client', 'occurred', '2026-09-29T00:00:00Z'],
     ['receive-client', 'received', '2026-09-30T23:59:55Z'],
     ['establish-client', 'occurred', '2026-09-29T00:00:00Z'],
     ['receive-name-client', 'received', '2026-10-01T00:02:00Z']].each do |id, field, time|
      data = evidence
      record(data, id)['times'][field]['value'] = time
      # Activity evidence is retained; inconsistent knowledge witnesses cannot
      # establish the selected as-known reconstruction.
      assert_equal 1, run_case('client', data)['results'].length
      q = query
      q['knowledge_cutoff'] = cutoff('2026-10-01T00:05:00Z')
      assert_empty_result(run_case('client', data, q))
    end
  end

  def test_default_retains_source_class_and_actual_scanning_context
    got = run_case
    fields = got['results'].first['fields']
    assert_equal 'scanner_generated', fields['purpose_context']
    assert_equal 'scanner_profile', fields['source_class']
    assert_equal 'member', fields['source_class_membership']
    assert_empty got['results'].first['policy_evaluations']
  end

  def test_source_class_suppression_is_explicit_and_does_not_transfer_to_ja3s
    q = query
    q['parameters']['exclude_scanner_profile'] = true
    got = run_case('client', evidence, q)
    assert_empty_result(got, 'suppressed')
    assert got['diagnostics'].any? { |d| d['status'] == 'suppressed' && d['policies'].any? { |p| p['scope'] == 'source' } }
    assert_equal 1, run_case('server')['results'].length
    q = query('server')
    q['parameters']['exclude_scanner_profile'] = true
    assert_raises(E::InvalidInput) { run_case('server', evidence, q) }
  end

  def clone_record(data, old_id, new_id)
    value = Marshal.load(Marshal.dump(record(data, old_id)))
    value['id'] = new_id
    value['attributes']['selector']['provenance']['record_id'] = new_id if value['attributes']['selector']
    value['attributes']['name_selector']['provenance']['record_id'] = new_id if value['attributes']['name_selector']
    value['times'].each_value do |time|
      %w[object occurrence].each { |key| time['binding'][key] = new_id if time['binding'][key] == old_id }
    end
    # Positive replay/new-event and conflicting-assertion vectors have their
    # own independently authored raw source records, not rewritten provenance.
    if read('source.json')['claims'].key?(new_id)
      value['evidence'] = [{'source_id' => 'synthetic-ja3-report', 'field' => '/claims/' + new_id}]
      value['attributes']['selector']['provenance']['field'] = '/claims/' + new_id + '/selector' if value['attributes']['selector']
      value['attributes']['name_selector']['provenance']['field'] = '/claims/' + new_id + '/name_selector' if value['attributes']['name_selector']
      value['times'].each { |name, time| time['field'] = '/claims/' + new_id + '/' + name }
    end
    data['records'] << value
    value
  end

  def test_conflicting_source_class_assertions_retain_evidence_without_winner
    data = evidence
    opposite = clone_record(data, 'class-scanner', 'class-scanner-opposing')
    opposite['attributes']['membership'] = 'not_member'
    assert_equal read('source.json').dig('claims', 'class-scanner-opposing', 'membership'), opposite['attributes']['membership']
    q = query
    q['parameters']['exclude_scanner_profile'] = true
    got = run_case('client', data, q)
    refute_empty got['results']
    assert_equal ['member', 'not_member'], got['results'].map { |r| r['fields']['source_class_membership'] }.sort
    assert got['results'].flat_map { |r| r['policy_evaluations'] }.any? { |p| p.dig('decision', 'status') == 'unresolved' }
    refute got['diagnostics'].any? { |d| d['status'] == 'suppressed' }
  end

  def test_unknown_classification_is_not_evidenced_exclusion
    data = evidence
    record(data, 'class-scanner')['attributes']['membership'] = nil
    q = query
    q['parameters']['exclude_scanner_profile'] = true
    got = run_case('client', data, q)
    refute_empty got['results']
    assert_equal 'unresolved', got['results'].first['policy_evaluations'].first['decision']['status']
  end

  def test_actual_exchange_filter_is_separate_and_leg_scoped
    q = query('server')
    q['parameters']['exclude_scanner_exchange'] = true
    assert_empty_result(run_case('server', evidence, q), 'suppressed')
    data = evidence
    record(data, 'purpose-scan')['attributes']['leg_id'] = 'unobserved-origin-leg'
    got = run_case('server', data, q)
    refute_empty got['results']
    assert_equal 'unresolved', got['results'].first['policy_evaluations'].first['decision']['status']
  end

  def test_conflicting_exchange_purpose_does_not_force_a_winner
    data = evidence
    opposite = clone_record(data, 'purpose-scan', 'purpose-ordinary')
    opposite['attributes']['purpose'] = 'ordinary_client'
    assert_equal read('source.json').dig('claims', 'purpose-ordinary', 'purpose'), opposite['attributes']['purpose']
    q = query('server')
    q['parameters']['exclude_scanner_exchange'] = true
    got = run_case('server', data, q)
    assert_equal ['ordinary_client', 'scanner_generated'], got['results'].map { |r| r['fields']['purpose_context'] }.sort
    refute got['diagnostics'].any? { |d| d['status'] == 'suppressed' }
  end

  def test_replay_preserves_occurrence_identity_and_distinct_support
    data = evidence
    duplicate = clone_record(data, 'm-client', 'm-client-reimport')
    association = clone_record(data, 'n-client', 'n-client-reimport')
    association['attributes']['associated_message_id'] = duplicate['id']
    got = run_case('client', data)
    assert_equal 2, got['results'].length
    assert_equal ['network-message-client'], got['results'].map { |r| r['fields']['occurrence_id'] }.uniq
    assert_equal 1, got['results'].map { |r| r['identity'] }.uniq.length
    assert_equal ['2026-09-30T23:59:50Z'], got['results'].map { |r| r['fields']['occurrence_time']['value'] }.uniq
  end

  def test_new_network_observation_uses_its_own_date_and_identity
    data = evidence
    newer = clone_record(data, 'm-client', 'm-client-later')
    newer['attributes']['occurrence_id'] = 'network-message-client-later'
    newer['times']['occurred']['value'] = '2026-10-01T02:00:00Z'
    association = clone_record(data, 'n-client', 'n-client-later')
    association['attributes']['associated_message_id'] = newer['id']
    q = query
    q['parameters']['period'] = {'start' => '2026-10-01', 'end' => '2026-10-01'}
    got = run_case('client', data, q)
    assert_equal ['network-message-client-later'], got['results'].map { |r| r['fields']['occurrence_id'] }
  end

  def test_unsupported_extraction_recipe_does_not_turn_into_a_negative_domain_claim
    q = query
    q['parameters']['selector']['algorithm'] = 'unknown-vendor-recipe'
    assert_raises(E::UnsupportedInput) { run_case('client', evidence, q) }
  end

  def test_resource_limits_are_explicit_and_report_partial_execution
    q = query
    q['limits']['max_bindings'] = 1
    got = run_case('client', evidence, q)
    assert_equal 'partial', got['status']
    assert_equal false, got['coverage']['exhaustive_for_supplied_input']
    assert_equal 'not_evaluated', got['coverage']['external_completeness']
  end

  def test_domain_label_cannot_hide_wildcard_address_or_unpinned_unicode_name
    ['*.example.test', '192.0.2.1', 'bücher.example'].each do |name|
      data = evidence
      record(data, 'd-alpha')['attributes']['value'] = name
      record(data, 'd-alpha')['attributes']['name_selector']['value'] = name
      record(data, 'n-client')['attributes']['name'] = name
      record(data, 'n-client')['attributes']['name_selector']['value'] = name
      assert_raises(EveryPivot::SemanticIdentity::InvalidInput) { run_case('client', data) }
    end
    data = evidence
    record(data, 'n-client')['attributes']['name_selector']['provenance']['record_id'] = 'n-server'
    assert_empty_result(run_case('client', data))
  end

  def test_explicit_ascii_case_and_root_dot_recipe_can_join_preserved_name_spellings
    data = evidence
    record(data, 'n-client')['attributes']['name'] = 'ALPHA.EXAMPLE.TEST.'
    record(data, 'n-client')['attributes']['name_selector']['value'] = 'ALPHA.EXAMPLE.TEST.'
    result = run_case('client', data)
    assert_equal ['d-alpha'], result['results'].map { |row| row['id'] }
    assert_equal 'alpha.example.test', result['results'].first['fields']['named_domain']
  end

  def test_matching_wrong_kind_selectors_do_not_turn_hashes_into_domain_names
    data = evidence
    [['d-alpha', 'value'], ['n-client', 'name']].each do |id, field|
      attrs = record(data, id)['attributes']
      attrs[field] = 'a' * 64
      provenance = attrs['name_selector']['provenance']
      attrs['name_selector'] = {'kind' => 'certificate_sha256', 'algorithm' => 'sha256',
        'representation' => 'der', 'normalization' => 'exact_der_v1', 'scope' => 'whole_certificate',
        'value' => 'a' * 64, 'provenance' => provenance}
    end
    assert_empty_result(run_case('client', data), 'no_qualifying_result')
  end

  def test_occurrence_identity_and_leg_must_be_nonblank_text
    [false, 7, {}, '   '].each do |bad|
      data = evidence
      record(data, 'm-client')['attributes']['occurrence_id'] = bad
      assert_empty_result(run_case('client', data))
    end
    data = evidence
    %w[m-client e1 n-client].each { |id| record(data, id)['attributes']['leg_id'] = false }
    assert_empty_result(run_case('client', data))
  end
end
