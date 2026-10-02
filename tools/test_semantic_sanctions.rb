#!/usr/bin/env ruby
# frozen_string_literal: true
require 'minitest/autorun'
require 'json'
require 'digest'
require_relative 'semantic_evaluator'

# Hypothetical normalized source records. No real transaction, designation,
# legal conclusion, source authentication, independence or native acceptance.
class SemanticSanctionsTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  DIR = File.join(ROOT, 'fixtures/semantic-families/sanctions')
  E = EveryPivot::SemanticEvaluator
  IDS = {
    'crypto' => 'FIN_CRYPTO_TX_TO_SANCTIONED', 'bank' => 'FIN_BANK_TXN_TO_SANCTIONED_COUNTERPART',
    'trade' => 'FIN_TRADE_PARTNER_SANCTIONS', 'owner' => 'FIN_BENEFICIAL_OWNER_TO_SANCTIONS',
    'parent' => 'FIN_ORG_LEI_PARENT_SANCTIONS', 'certificate' => 'CROSS_CERT_SUBJECT_TO_LEI_SANCTIONS',
    'domain' => 'CROSS_FQDN_TO_ORG_LEI_SANCTIONS', 'asn' => 'CROSS_ASN_ORG_TO_SANCTIONS'
  }.freeze
  EVENTS = %w[crypto bank trade].freeze
  RELATIONS = %w[owner parent domain asn].freeze

  def read(file)
    JSON.parse(File.read(File.join(DIR, file)))
  end
  def data(family = 'owner')
    read(family + '-evidence.json')
  end
  def query(family = 'owner', purpose = 'retrospective')
    read(family + '-' + (purpose == 'retrospective' ? 'retrospective' : 'historical') + '-query.json').tap do |q|
      q['parameters']['purpose'] = purpose
      q['parameters'].delete('at') unless purpose == 'historical_at'
    end
  end
  def contract(family)
    JSON.parse(File.read(File.join(ROOT, 'contracts/semantics', IDS.fetch(family) + '.json')))
  end
  def record(d, id)
    d.fetch('records').find { |r| r['id'] == id } || raise("missing synthetic fixture record #{id}")
  end
  def remove(d, *ids)
    loop do
      expanded = (ids + d['records'].select { |r| ids.include?(r['subject']) || ids.include?(r['object']) }.map { |r| r['id'] }).uniq
      break if expanded == ids
      ids = expanded
    end
    d['records'].reject! { |r| ids.include?(r['id']) }
  end
  def clone_record(d, old_id, new_id)
    r = Marshal.load(Marshal.dump(record(d, old_id)))
    r['id'] = new_id
    r['evidence'].each { |edge| edge['field'] = '/claims/' + new_id }
    r['times'].each do |key, t|
      t['field'] = '/claims/' + new_id + '/' + key
      t['binding']['occurrence'] = new_id
      t['binding']['object'] = new_id if t['binding']['object'] == old_id
    end
    d['records'] << r
    r
  end
  def envelope(id, object, value, field = 'published')
    {'binding' => {'object' => object, 'occurrence' => id}, 'field' => '/claims/' + id + '/' + field,
     'source_revision' => 'fixture-r1', 'clock' => {'id' => 'source-stated-utc', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end
  def historical_status(d)
    record(d, 'status')['times']['applicable'].merge!('start' => '2024-01-01T00:00:00Z', 'end' => '2025-01-01T00:00:00Z', 'end_inclusive' => false)
    d
  end
  def evaluate(family = 'owner', d = data(family), q = query(family))
    # Every synthetic mutation becomes a separately hashed in-memory source
    # snapshot. It never borrows the baseline source's content hash to attest a
    # changed report. The independent expectations below do not call the engine.
    d = Marshal.load(Marshal.dump(d))
    claims = d['records'].to_h do |r|
      [r['id'], r['attributes'].merge(r['times'].transform_values { |t| t['value'] || t.reject { |k, _| %w[binding field source_revision clock timezone].include?(k) } })]
    end
    bytes = JSON.generate('fixture_type' => 'synthetic_counterexample_snapshot', 'claims' => claims)
    d['sources'].each do |source|
      source['document'] = 'memory:synthetic-counterexample.json'
      source['content_hash'] = {'algorithm' => 'sha256', 'value' => Digest::SHA256.hexdigest(bytes), 'scope' => 'exact_source_bytes'}
    end
    E.new(contract(family)).evaluate(d, q, preserved_source_bytes: d['sources'].to_h { |source| [source['id'], bytes] })
  end
  def empty(got, outcome = nil)
    assert_empty got['results']
    assert_equal outcome, got['outcome'] if outcome
  end
  def qualified(got, count = 1)
    assert_equal 'complete', got['status']
    assert_equal count, got['results'].length
    got['results'].each do |r|
      assert_equal 'entry', r['id']; assert_equal 'listed-subject', r['fields']['listed_subject']
      assert_equal 'evidence_only', r['evidence_mode']; assert_equal 'not_evaluated', r['assessment_acceptance']
    end
  end
  def amendment(d, target, operation = 'withdraw', id = 'amendment')
    src = %w[status entry-subject].include?(target) ? 'list-correction-source' : 'correction-source'
    r = {'id' => id, 'kind' => 'assertion', 'type' => 'evidence:assertion_amendment', 'subject' => target,
         'attributes' => {'assertion_namespace' => record(d, target)['attributes']['assertion_namespace'],
                          'operation' => operation, 'issuer_source_id' => src, 'supersedes_amendments' => []},
         'times' => {'published' => envelope(id, id, '2026-09-05T00:00:00Z')},
         'evidence' => [{'source_id' => src, 'field' => '/claims/' + id}]}
    if operation == 'correct'
      replacement = clone_record(d, target, id + '-replacement')
      replacement['evidence'][0]['source_id'] = src
      r['object'] = replacement['id']
    end
    d['records'] << r
    receipt = {'id' => id + '-receipt', 'kind' => 'occurrence', 'type' => 'evidence:claim_receipt', 'subject' => id,
               'attributes' => {'collection_id' => 'sanctions-case'},
               'times' => {'received' => envelope(id + '-receipt', id, '2026-09-06T00:00:00Z', 'received')},
               'evidence' => [{'source_id' => src, 'field' => '/claims/' + id + '-receipt'}]}
    d['records'] << receipt
    r
  end

  def test_exact_fixture_hashes_mapping_and_independent_baseline_expectations
    read('expected.json')['families'].each do |expected|
      family = expected['family']; d = data(family); raw = read(family + '-source.json')
      assert_equal 'independently_authored_synthetic_sanctions_case', raw['fixture_type']
      digest = Digest::SHA256.file(File.join(DIR, family + '-source.json')).hexdigest
      d['sources'].each { |source| assert_equal digest, source.dig('content_hash', 'value') }
      d['records'].each do |r|
        assert_kind_of Hash, raw['claims'][r['id']]
        r['times'].each do |key, t|
          expected_time = t['precision'] == 'interval' ? t.slice('start', 'end') : t['value']
          assert_equal expected_time, raw['claims'][r['id']][key]
        end
      end
      qualified(evaluate(family), expected['retrospective']['count'])
      empty(evaluate(family, d, query(family, 'historical_at')))
      qualified(evaluate(family, historical_status(d), query(family, 'historical_at')), expected['positive_historical_variant']['count'])
    end
  end

  def test_later_designation_is_allowed_but_not_required_for_retrospective
    IDS.each_key do |family|
      d = data(family)
      record(d, 'status')['times']['applicable'].merge!('start' => '2019-01-01T00:00:00Z', 'end' => '2019-12-31T23:59:59Z')
      qualified(evaluate(family, d))
      record(d, 'status')['times'].delete('applicable')
      qualified(evaluate(family, d)) # unresolved chronology is retained, not reversed or filled by publication
      empty(evaluate(family, d, query(family, 'historical_at')), 'unresolved')
    end
  end

  def test_event_is_its_actual_occurrence_not_receipt_or_snapshot_date
    EVENTS.each do |family|
      d = data(family)
      record(d, 'event')['times']['occurred']['value'] = '2023-12-03T12:00:00Z'
      empty(evaluate(family, d), 'outside_scope')
      record(d, 'event')['times'].delete('occurred')
      empty(evaluate(family, d), 'unresolved')
    end
  end

  def test_crypto_direct_transfer_direction_does_not_pair_arbitrary_participants
    d = data('crypto')
    record(d, 'event')['subject'], record(d, 'event')['object'] = 'listed-subject', 'seed'
    qualified(evaluate('crypto', d))
    %w[aggregate_batch co_input_cluster planned_transfer].each do |kind|
      d = data('crypto'); record(d, 'event')['attributes']['record_kind'] = kind
      empty(evaluate('crypto', d))
    end
    d = data('crypto'); record(d, 'event')['attributes'].delete('transfer_unit_id')
    empty(evaluate('crypto', d), 'unresolved')
  end

  def test_bank_direct_counterparty_roles_exclude_intermediaries_and_batches
    %w[correspondent intermediary co_participant].each do |role|
      d = data('bank'); record(d, 'event')['attributes']['counterparty_role'] = role
      empty(evaluate('bank', d))
    end
    d = data('bank'); record(d, 'event')['attributes'].merge!('account_role' => 'recipient_account', 'counterparty_role' => 'originator')
    qualified(evaluate('bank', d))
    record(d, 'event')['attributes']['record_kind'] = 'aggregate_batch'
    empty(evaluate('bank', d))
  end

  def test_actual_events_required_even_when_test_context_is_retained
    EVENTS.each do |family|
      %w[planned failed].each do |state|
        d = data(family); record(d, 'event')['attributes']['execution_state'] = state
        empty(evaluate(family, d))
      end
      d = data(family); record(d, 'event')['attributes']['environment'] = 'synthetic_simulation'
      empty(evaluate(family, d))
      qualified(evaluate(family)) # model of a source-reported occurrence can retain separate test context
    end
  end

  def test_bo_role_is_not_inferred_from_percentage_nominee_or_control_only
    %w[shareholder nominee director employee control_only].each do |category|
      d = data('owner'); record(d, 'relationship')['attributes']['source_category'] = category
      empty(evaluate('owner', d))
    end
    d = data('owner'); record(d, 'relationship')['attributes']['category_mapping'] = 'ambiguous_combined_category'
    empty(evaluate('owner', d))
    d = data('owner'); record(d, 'relationship')['attributes']['amount'] = nil
    got = evaluate('owner', d); qualified(got); assert_nil got['results'].first['fields']['amount_context']
    record(d, 'relationship')['attributes']['stated_basis'] = 'source_reports_beneficial_owner_on_control_rights_basis'
    qualified(evaluate('owner', d))
  end

  def test_bo_amount_basis_and_conflicting_reports_are_preserved_without_winner
    d = data('owner')
    other = clone_record(d, 'relationship', 'relationship-opposing')
    other['attributes']['amount'] = {'value' => 80, 'unit' => 'percent', 'rights_type' => 'voting_rights', 'denominator' => 'votes', 'share_class' => 'special', 'calculation_basis' => 'source_reported'}
    got = evaluate('owner', d); qualified(got, 2)
    assert_equal [5, 80], got['results'].map { |r| r['fields']['amount_context']['value'] }.sort
    assert_equal %w[economic_interest voting_rights], got['results'].map { |r| r['fields']['amount_context']['rights_type'] }.sort
    refute got['results'].any? { |r| r['fields'].key?('control') }
  end

  def test_no_derived_ultimate_owner_and_parent_direction_must_be_explicit
    d = data('owner'); record(d, 'relationship')['attributes']['directness'] = 'calculated_product_of_shareholdings'
    empty(evaluate('owner', d))
    record(d, 'relationship')['attributes']['directness'] = 'reported_indirect'
    qualified(evaluate('owner', d))
    d = data('parent'); record(d, 'relationship')['attributes']['direction'] = 'parent_to_child'
    empty(evaluate('parent', d))
    d = data('parent'); record(d, 'relationship')['subject'], record(d, 'relationship')['object'] = 'parent-lei', 'child-lei'
    empty(evaluate('parent', d))
  end

  def test_later_lei_can_identify_historical_entity_but_does_not_create_old_parentage
    %w[parent certificate domain].each do |family|
      d = historical_status(data(family))
      qualified(evaluate(family, d, query(family, 'historical_at')))
    end
    d = historical_status(data('parent'))
    record(d, 'relationship')['times']['applicable'].merge!('start' => '2026-01-01T00:00:00Z', 'end' => '2026-12-31T23:59:59Z')
    empty(evaluate('parent', d, query('parent', 'historical_at')))
  end

  def test_certificate_subject_needs_complete_material_and_entity_correspondence
    d = data('certificate'); record(d, 'entity-resolution')['attributes']['basis'] = 'same_name_only'
    empty(evaluate('certificate', d))
    d = data('certificate'); remove(d, 'entity-resolution')
    empty(evaluate('certificate', d), 'unresolved')
    d = data('certificate'); record(d, 'subject-field')['attributes']['certificate_selector']['value'] = '0' * 64
    empty(evaluate('certificate', d), 'unresolved')
    q = query('certificate'); q['parameters']['period'] = {'start' => '2024-01-01', 'end' => '2024-12-31'}
    assert_raises(E::InvalidInput) { evaluate('certificate', data('certificate'), q) }
  end

  def test_registrant_and_asn_roles_do_not_become_domain_or_customer_control
    %w[domain asn].each do |family|
      d = data(family); record(d, 'relationship')['attributes']['identity_basis'] = 'same_name_only'
      empty(evaluate(family, d))
      d = data(family); record(d, 'relationship')['attributes']['role'] = 'inferred_customer_controller'
      empty(evaluate(family, d))
      got = evaluate(family); qualified(got)
      refute got['results'].first['fields'].key?('control')
    end
  end

  def test_explicit_period_some_requires_actual_coexistence_not_independent_overlaps
    RELATIONS.each do |family|
      d = data(family); q = query(family, 'historical_some')
      q['parameters']['period'] = {'start' => '2024-01-01', 'end' => '2026-12-31'}
      empty(evaluate(family, d, q), 'outside_scope') # relationship ends 2024; listing starts 2026
      record(d, 'status')['times']['applicable'].merge!('start' => '2024-12-15T00:00:00Z', 'end' => '2026-12-31T23:59:59Z')
      qualified(evaluate(family, d, q))
      q['parameters']['purpose'] = 'historical_all'
      empty(evaluate(family, d, q), 'outside_scope')
    end
  end

  def test_historical_all_does_not_convert_a_point_event_to_continuous_activity
    EVENTS.each do |family|
      d = historical_status(data(family)); q = query(family, 'historical_all')
      got = evaluate(family, d, q); qualified(got)
      assert_includes got['results'].first['fields']['time_meaning'], 'individual event'
      record(d, 'status')['times']['applicable']['end'] = '2024-12-04T00:00:00Z'
      empty(evaluate(family, d, q))
      q['parameters']['purpose'] = 'historical_some'
      qualified(evaluate(family, d, q))
    end
  end

  def test_missing_end_and_snapshot_do_not_establish_perpetual_or_continuous_state
    RELATIONS.each do |family|
      d = historical_status(data(family)); record(d, 'relationship')['times']['applicable'].delete('end')
      empty(evaluate(family, d, query(family, 'historical_at')), 'unresolved')
      d = historical_status(data(family)); record(d, 'relationship')['times']['applicable'] = envelope('relationship', 'relationship', '2024-12-03T12:00:00Z', 'applicable')
      empty(evaluate(family, d, query(family, 'historical_some')), 'unsupported')
    end
  end

  def test_removed_and_relisted_intervals_do_not_bridge_a_gap
    d = data('certificate'); first = record(d, 'status')
    first['times']['applicable'].merge!('start' => '2024-01-01T00:00:00Z', 'end' => '2024-01-31T23:59:59Z')
    second = clone_record(d, 'status', 'status-relisted')
    second['times']['applicable'].merge!('start' => '2024-09-01T00:00:00Z', 'end' => '2024-12-31T23:59:59Z')
    q = query('certificate', 'historical_at'); q['parameters']['period'] = {'start' => '2024-04-01', 'end' => '2024-04-30'}
    q['parameters']['at'] = envelope('case', 'case', '2024-04-15T00:00:00Z')
    empty(evaluate('certificate', d, q))
    q['parameters']['period'] = {'start' => '2024-12-01', 'end' => '2024-12-31'}
    q['parameters']['at'] = envelope('case', 'case', '2024-12-03T12:00:00Z')
    qualified(evaluate('certificate', d, q))
  end

  def test_exact_entry_revision_and_subject_identity_cannot_transfer_status
    IDS.each_key do |family|
      d = data(family); record(d, 'entry-subject')['subject'] = 'seed'
      empty(evaluate(family, d))
      d = data(family); record(d, 'status')['attributes']['entry_revision'] = 'different-revision'
      empty(evaluate(family, d))
      d = data(family); record(d, 'entry-subject')['attributes']['identity_basis'] = 'fuzzy_name'
      empty(evaluate(family, d))
    end
  end

  def test_fixed_source_scope_cannot_expand_to_new_documents_or_revisions
    IDS.each_key do |family|
      q = query(family); q['parameters']['reference_sources'].delete('list-source')
      empty(evaluate(family, data(family), q))
      q = query(family); q['parameters']['reference_sources'] = []
      assert_raises(E::InvalidInput) { evaluate(family, data(family), q) }
      q = query(family); q['parameters']['entry_revisions'] = []
      assert_raises(E::InvalidInput) { evaluate(family, data(family), q) }
      q = query(family); q['parameters']['reference_sources'] = ['absent-source']
      assert_raises(E::InvalidInput) { evaluate(family, data(family), q) }
      q = query(family); q['parameters']['entry_revisions'] = ['absent-revision']
      assert_raises(E::InvalidInput) { evaluate(family, data(family), q) }
    end
  end

  def test_later_received_evidence_can_support_old_status_without_backdated_knowledge
    IDS.each_key do |family|
      d = historical_status(data(family)); q = query(family, 'historical_at')
      qualified(evaluate(family, d, q))
      q['knowledge_cutoff'] = envelope('cutoff', 'case', '2024-12-31T23:59:59Z')
      empty(evaluate(family, d, q))
      q['knowledge_cutoff'] = envelope('cutoff', 'case', '2026-09-04T00:00:00Z')
      qualified(evaluate(family, d, q))
      remove(d, 'status-receipt')
      empty(evaluate(family, d, q), 'unresolved')
    end
  end

  def test_scoped_receipt_and_source_time_bindings_are_required_for_as_known
    d = historical_status(data('owner')); q = query('owner', 'historical_at')
    q['knowledge_cutoff'] = envelope('cutoff', 'case', '2026-09-04T00:00:00Z')
    record(d, 'relationship-receipt')['attributes']['collection_id'] = 'other-case'
    empty(evaluate('owner', d, q), 'unresolved')
    d = historical_status(data('owner')); record(d, 'relationship')['times']['published']['binding']['object'] = 'seed'
    empty(evaluate('owner', d, q))
    d = historical_status(data('owner')); record(d, 'relationship-receipt')['times']['received']['value'] = '2026-09-01T00:00:00Z'
    empty(evaluate('owner', d, q))
  end

  def test_withdrawn_historical_reports_are_retained_with_correction_but_not_maintained
    IDS.each_key do |family|
      d = historical_status(data(family)); amendment(d, 'entry-subject')
      got = evaluate(family, d); qualified(got)
      states = got['results'].first['amendment_evaluation']['states']
      assert_equal 'withdrawn', states.find { |s| s['assertion_id'] == 'entry-subject' }['state']
      assert_equal 'no_match', got['results'].first['amendment_evaluation']['support_status']
      empty(evaluate(family, d, query(family, 'historical_at')))
    end
  end

  def test_later_correction_stays_attached_without_erasing_earlier_as_known_view
    d = historical_status(data('owner')); amendment(d, 'relationship')
    q = query('owner', 'historical_at'); q['knowledge_cutoff'] = envelope('cutoff', 'case', '2026-09-04T00:00:00Z')
    got = evaluate('owner', d, q); qualified(got)
    state = got['results'].first['amendment_evaluation']['states'].find { |s| s['assertion_id'] == 'relationship' }
    assert_equal 'reported_in_supplied_scope', state['state']
    assert_equal ['amendment'], state['later_context'].map { |a| a['record']['id'] }
    q['knowledge_cutoff'] = envelope('cutoff', 'case', '2026-09-07T00:00:00Z')
    empty(evaluate('owner', d, q))
  end

  def test_unsupported_correction_scope_and_conflicting_amendments_do_not_choose_winner
    d = historical_status(data('owner')); amendment(d, 'relationship')
    q = query('owner', 'historical_at'); q['parameters']['reference_sources'].delete('correction-source')
    empty(evaluate('owner', d, q), 'unresolved')
    q = query('owner', 'historical_at'); amendment(d, 'relationship', 'reinstate', 'reinstatement')
    empty(evaluate('owner', d, q), 'unresolved')
    record(d, 'reinstatement')['attributes']['supersedes_amendments'] = ['amendment']
    qualified(evaluate('owner', d, q))
  end

  def test_correction_of_old_identity_does_not_silently_reuse_corrected_path
    d = historical_status(data('certificate')); a = amendment(d, 'entity-resolution', 'correct')
    replacement = record(d, a['object']); replacement['attributes']['claim'] = 'different_entity'
    got = evaluate('certificate', d); qualified(got)
    assert_equal 'corrected', got['results'].first['amendment_evaluation']['states'].find { |s| s['assertion_id'] == 'entity-resolution' }['state']
    empty(evaluate('certificate', d, query('certificate', 'historical_at')))
  end

  def test_default_retains_source_path_and_actual_test_context
    IDS.each_key do |family|
      got = evaluate(family); qualified(got)
      assert_empty got['results'].first['policy_evaluations']
      assert_equal 'member', got['results'].first['fields']['source_class_context']['membership']
      assert_equal 'member', got['results'].first['fields']['path_class_context']['membership']
    end
  end

  def test_explicit_source_path_and_event_filters_report_suppression
    IDS.each_key do |family|
      %w[source path].each do |scope|
        q = query(family); q['parameters']['exclude_' + scope + '_classes'] = true
        q['parameters'][scope + '_classes'] = [scope == 'source' ? 'shared_provider' : 'shared_intermediary']
        empty(evaluate(family, data(family), q), 'suppressed')
      end
    end
    EVENTS.each do |family|
      q = query(family); q['parameters'].merge!('exclude_event_classes' => true, 'event_classes' => ['controlled_test'])
      empty(evaluate(family, data(family), q), 'suppressed')
    end
  end

  def test_conflicting_or_unknown_classification_is_neither_clearance_nor_exclusion
    d = data('owner'); other = clone_record(d, 'source-class', 'source-class-opposing'); other['attributes']['membership'] = 'not_member'
    q = query('owner'); q['parameters'].merge!('exclude_source_classes' => true, 'source_classes' => ['shared_provider'])
    got = evaluate('owner', d, q); qualified(got, 2)
    assert got['results'].flat_map { |r| r['policy_evaluations'] }.any? { |p| p.dig('decision', 'status') == 'unresolved' }
    d = data('owner'); record(d, 'source-class')['attributes']['membership'] = nil
    qualified(evaluate('owner', d, q))
  end

  def test_path_class_conflict_retains_both_reports_for_the_same_required_path
    d = data('owner'); opposite = clone_record(d, 'path-class', 'path-class-opposing'); opposite['attributes']['membership'] = 'not_member'
    q = query('owner'); q['parameters'].merge!('exclude_path_classes' => true, 'path_classes' => ['shared_intermediary'])
    got = evaluate('owner', d, q); qualified(got, 2)
    assert_equal ['member', 'not_member'], got['results'].map { |r| r['fields']['path_class_context']['membership'] }.sort
    refute got['diagnostics'].any? { |d| d['status'] == 'suppressed' }
  end

  def test_explicit_contested_classification_and_allow_do_not_require_a_member_to_conflict
    IDS.each_key do |family|
      %w[source path].each do |scope|
        d = data(family)
        id = scope + '-class'
        record(d, id)['attributes']['membership'] = 'not_member'
        other = clone_record(d, id, id + '-contested')
        other['attributes']['membership'] = 'contested'
        q = query(family)
        q['parameters']['exclude_' + scope + '_classes'] = true
        q['parameters'][scope + '_classes'] = [record(d, id)['attributes']['class_id']]
        got = evaluate(family, d, q)
        refute_empty got['results'], [family, scope, got['diagnostics']].inspect
        assert got['results'].all? { |row| row['policy_evaluations'].any? { |p| p.dig('decision', 'status') == 'unresolved' } }
        assert_equal 'qualified_evidence_with_gaps', got['outcome']
      end
    end
  end

  def test_distinct_selected_classes_do_not_conflict_but_any_applicable_class_excludes
    %w[source path].each do |scope|
      d = data('owner'); id = scope + '-class'
      original_class = record(d, id)['attributes']['class_id']
      other = clone_record(d, id, id + '-other-class')
      other['attributes']['class_id'] = 'different-selected-class'
      other['attributes']['membership'] = 'not_member'
      q = query('owner')
      q['parameters']['exclude_' + scope + '_classes'] = true
      q['parameters'][scope + '_classes'] = [original_class, 'different-selected-class']
      empty(evaluate('owner', d, q), 'suppressed')
      # Selecting only the explicit nonmember class retains the source/path.
      q['parameters'][scope + '_classes'] = ['different-selected-class']
      refute_empty evaluate('owner', d, q)['results']
    end
  end

  def test_partial_path_class_search_cannot_exclude_before_reaching_opposing_report
    d = data('owner')
    other = clone_record(d, 'path-class', 'zz-path-opposed')
    other['attributes']['membership'] = 'not_member'
    q = query('owner')
    q['parameters'].merge!('exclude_path_classes' => true, 'path_classes' => ['shared_intermediary'])
    complete = evaluate('owner', d, q)
    qualified(complete, 2)
    q['limits']['max_bindings'] = 51
    partial = evaluate('owner', d, q)
    assert_equal 'partial', partial['status']
    refute partial['diagnostics'].any? { |entry| entry['status'] == 'suppressed' }
    refute_empty partial['results']
    assert partial['results'].all? { |row| row['policy_evaluations'].any? { |p| p['scope'] == 'path' && p.dig('decision', 'status') == 'unresolved' } }
  end

  def test_lei_classifications_keep_the_actual_classified_role
    %w[child-lei parent-lei listed-subject].each do |subject|
      d = data('parent'); record(d, 'path-class')['subject'] = subject
      got = evaluate('parent', d); qualified(got)
      assert_equal subject, got['results'].first['fields']['path_class_subject']
      q = query('parent'); q['parameters'].merge!('exclude_path_classes' => true, 'path_classes' => ['shared_intermediary'])
      empty(evaluate('parent', d, q), 'suppressed')
    end
  end

  def test_retention_cannot_repair_identity_or_role_and_low_value_does_not_imply_purpose
    d = data('bank'); record(d, 'event')['attributes']['counterparty_role'] = 'intermediary'
    empty(evaluate('bank', d))
    d = data('crypto'); record(d, 'event')['attributes']['value'] = {'amount' => '0.0000001', 'unit' => 'fixture'}
    remove(d, 'event-class')
    q = query('crypto'); q['parameters'].merge!('exclude_event_classes' => true, 'event_classes' => ['dust'])
    qualified(evaluate('crypto', d, q))
  end

  def test_replay_keeps_identified_event_and_cannot_create_new_event_time
    d = data('bank'); copy = clone_record(d, 'event', 'event-replay')
    got = evaluate('bank', d); qualified(got, 2)
    assert_equal ['bank-tx-1'], got['results'].map { |r| r['fields']['event_context']['transaction_id'] }.uniq
    q = query('bank'); q['parameters']['period'] = {'start' => '2026-09-01', 'end' => '2026-09-30'}
    empty(evaluate('bank', d, q), 'outside_scope')
    copy['attributes']['transaction_id'] = 'bank-tx-2'; copy['times']['occurred']['value'] = '2026-09-03T12:00:00Z'
    qualified(evaluate('bank', d, q))
  end

  def test_resource_budget_includes_amendment_work_and_reports_partial_without_absence
    d = data('owner'); 20.times { |i| amendment(d, 'relationship', 'withdraw', 'amend-' + i.to_s) }
    q = query('owner'); q['limits']['max_bindings'] = 100
    got = evaluate('owner', d, q)
    assert_equal 'partial', got['status']
    assert_equal false, got['coverage']['exhaustive_for_supplied_input']
    assert_equal 'not_evaluated', got['coverage']['external_completeness']
    assert got['diagnostics'].any? { |d| d.dig('amendment_evaluation', 'partial') == true }
  end
end
