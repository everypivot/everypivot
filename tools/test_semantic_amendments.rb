#!/usr/bin/env ruby
# frozen_string_literal: true
require 'minitest/autorun'
require_relative 'semantic_amendments'

class SemanticAmendmentsTest < Minitest::Test
  A = EveryPivot::SemanticAmendments
  def source(id, publisher = 'Registry')
    {'id' => id, 'publisher' => publisher, 'document' => id + '.json', 'revision' => id,
     'collection' => 'case', 'independent_origin' => nil}
  end
  def record(id, kind = 'assertion', type = 'test:claim', src = 'r1')
    {'id' => id, 'kind' => kind, 'type' => type, 'attributes' => {'assertion_namespace' => 'registry:claim:1'},
     'times' => {}, 'evidence' => [{'source_id' => src, 'field' => '/records/' + id}]}
  end
  def data
    {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0', 'collection_id' => 'case',
     'sources' => [source('r1'), source('r2'), source('r3', 'Another publisher')],
     'records' => [record('claim'), record('replacement', 'assertion', 'test:claim', 'r2')]}
  end
  def envelope(id, object, value, revision = 'r2')
    {'binding' => {'object' => object, 'occurrence' => id}, 'field' => '/records/' + id + '/time', 'source_revision' => revision,
     'clock' => {'id' => 'reported', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end
  def add(d, id = 'withdrawal', operation = 'withdraw', source_id = 'r2')
    a = record(id, 'assertion', A::TYPE, source_id)
    a['subject'] = 'claim'
    a['object'] = 'replacement' if operation == 'correct'
    a['attributes'].merge!('operation' => operation, 'issuer_source_id' => source_id, 'supersedes_amendments' => [])
    a['times']['published'] = envelope(id, id, '2026-09-01T00:00:00Z', source_id)
    r = record(id + '-receipt', 'occurrence', 'evidence:claim_receipt', source_id)
    r['subject'] = id; r['attributes']['collection_id'] = 'case'
    r['times']['received'] = envelope(r['id'], id, '2026-09-02T00:00:00Z', source_id)
    d['records'].concat([a, r]); a
  end
  def run_case(d = data, cutoff = nil, source_ids = %w[r1 r2 r3])
    A.evaluate(evidence: d, assertion_ids: ['claim'], source_ids: source_ids, mode: 'require_unwithdrawn_in_scope', knowledge_cutoff: cutoff)
  end
  def state(got)
    got['states'].first['state']
  end
  def test_absence_is_only_reported_in_explicit_scope
    got = run_case
    assert_equal 'match', got['status']
    assert_equal 'reported_in_supplied_scope', state(got)
    assert_equal 'not_evaluated', got['source_authenticity']
    assert_equal false, got['has_gaps']
  end
  def test_withdrawal_and_distinct_correction_are_attached
    d = data; add(d)
    got = run_case(d)
    assert_equal 'no_match', got['status']; assert_equal 'withdrawn', state(got)
    assert_equal 'withdrawal', got['states'].first['amendments'].first['record']['id']
    d = data; add(d, 'correction', 'correct')
    got = run_case(d)
    assert_equal 'corrected', state(got)
    assert_equal 'replacement', got['states'].first['amendments'].first['record']['object']
  end
  def test_later_correction_does_not_erase_historical_as_known_report
    d = data; add(d)
    before = run_case(d, envelope('cutoff', 'query', '2026-08-31T23:59:59Z'))
    assert_equal 'match', before['status']
    assert_equal 'reported_in_supplied_scope', state(before)
    assert_equal ['withdrawal'], before['states'].first['later_context'].map { |a| a['record']['id'] }
    after = run_case(d, envelope('cutoff', 'query', '2026-09-02T00:00:00Z'))
    assert_equal 'withdrawn', state(after)
  end
  def test_missing_receipt_cannot_claim_pre_cutoff_availability
    d = data; add(d); d['records'].reject! { |r| r['type'] == 'evidence:claim_receipt' }
    got = run_case(d, envelope('cutoff', 'query', '2026-09-03T00:00:00Z'))
    assert_equal 'unresolved', got['status']
    assert_equal true, got['has_gaps']
    assert_equal 'withdrawn', state(run_case(d))
  end
  def test_wrong_collection_binding_revision_and_chronology_do_not_supply_knowledge
    %w[collection binding revision chronology].each do |kind|
      d = data; add(d); r = d['records'].last
      r['attributes']['collection_id'] = 'another-case' if kind == 'collection'
      r['times']['received']['binding']['object'] = 'claim' if kind == 'binding'
      r['times']['received']['source_revision'] = 'r1' if kind == 'revision'
      r['times']['received']['value'] = '2026-08-01T00:00:00Z' if kind == 'chronology'
      if kind == 'revision'
        assert_raises(EveryPivot::SemanticRecords::InvalidInput) { run_case(d, envelope('cutoff', 'query', '2026-09-03T00:00:00Z')) }
      else
        assert_equal 'unresolved', run_case(d, envelope('cutoff', 'query', '2026-09-03T00:00:00Z'))['status'], kind
      end
    end
  end
  def test_namespace_and_source_publisher_must_match_for_correction
    d = data; a = add(d); a['attributes']['assertion_namespace'] = 'different-claim'
    assert_equal 'unresolved', run_case(d)['status']
    d = data; add(d, 'other-withdrawal', 'withdraw', 'r3')
    assert_equal 'unresolved', run_case(d)['status']
    d = data; add(d, 'other-disagreement', 'dispute', 'r3')
    assert_equal 'contested', state(run_case(d))
  end
  def test_reinstatement_requires_explicit_supersession_not_latest_timestamp
    d = data; add(d); restored = add(d, 'restore', 'reinstate')
    assert_equal 'contested', state(run_case(d))
    restored['attributes']['supersedes_amendments'] = ['withdrawal']
    got = run_case(d)
    assert_equal 'reported_in_supplied_scope', state(got)
    assert_equal ['restore'], got['states'].first['active_amendment_ids']
    assert_equal 2, got['states'].first['amendments'].length
    restored['times']['published']['value'] = '2026-08-01T00:00:00Z'
    assert_equal 'unresolved', run_case(d)['status']
  end
  def test_scope_cannot_silently_omit_encountered_corrections
    d = data; add(d)
    got = run_case(d, nil, ['r1'])
    assert_equal 'unresolved', got['status']
    assert_equal true, got['has_gaps']
  end
  def test_retained_reports_are_labeled_even_when_withdrawn_or_unknown
    d = data; add(d)
    got = A.evaluate(evidence: d, assertion_ids: ['claim'], source_ids: %w[r1 r2], mode: 'retain_reports')
    assert_equal 'match', got['status']
    assert_equal 'no_match', got['support_status']
    assert_equal 'withdrawn', state(got)
    got = A.evaluate(evidence: d, assertion_ids: ['claim'], source_ids: ['r1'], mode: 'retain_reports')
    assert_equal 'match', got['status']
    assert_equal true, got['has_gaps']
    assert_equal 'unresolved_amendment_context', state(got)
  end
  def test_wrong_target_and_replay_do_not_change_assertion_identity
    d = data; a = add(d); a['subject'] = 'replacement'
    assert_equal 'reported_in_supplied_scope', state(run_case(d))
    d = data; add(d); add(d, 'same-withdrawal-reported-again')
    got = run_case(d)
    assert_equal 'withdrawn', state(got)
    assert_equal 2, got['states'].first['amendments'].length
  end
  def test_invalid_operation_references_and_cycles_are_input_errors
    d = data; a = add(d); a['attributes']['operation'] = 'verified'
    assert_raises(A::InvalidInput) { run_case(d) }
    d = data; a = add(d); b = add(d, 'b', 'reinstate')
    a['attributes']['supersedes_amendments'] = ['b']; b['attributes']['supersedes_amendments'] = ['withdrawal']
    assert_raises(A::InvalidInput) { run_case(d) }
    assert_raises(A::InvalidInput) { A.evaluate(evidence: data, assertion_ids: [], source_ids: ['r1'], mode: 'require_unwithdrawn_in_scope') }
    assert_raises(A::InvalidInput) { run_case(data, nil, ['missing']) }
  end
  def test_bounded_scan_cannot_report_absence_and_retains_encountered_context
    d = data; add(d)
    calls = 0
    got = A.evaluate(evidence: d, assertion_ids: ['claim'], source_ids: %w[r1 r2], mode: 'retain_reports',
                     consume: lambda { calls += 1; calls <= 3 })
    assert_equal 'unresolved', got['status']
    assert_equal true, got['partial']
    assert_equal 3, got['consumed']
    assert_equal ['withdrawal'], got['encountered_amendments'].map { |r| r['id'] }
    assert_empty got['states']
  end
end
