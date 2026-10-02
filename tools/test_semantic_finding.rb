#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'semantic_finding'

class SemanticFindingTest < Minitest::Test
  F = EveryPivot::SemanticFinding
  C = EveryPivot::SemanticContract

  def temporal_envelope(value, object, event, field)
    {'binding' => {'object' => object, 'occurrence' => event}, 'field' => field,
     'source_revision' => 'r1', 'clock' => {'id' => 'lab-clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end

  def record(id, kind, type, attrs = {}, times = {}, field = '/evidence')
    {'id' => id, 'kind' => kind, 'type' => type, 'attributes' => attrs, 'times' => times,
     'evidence' => [{'source_id' => 's1', 'field' => field}]}
  end

  def fixture
    qualification = {'id' => 'selector-file', 'revision' => '1.0',
                     'contract_sha256' => C.digest({'id' => 'selector-file', 'revision' => '1.0', 'required_join' => 'extraction.subject = artifact.id'})}
    key = C.digest(['selector-file', 'selector:path:A', 'file:sha256:A'])
    origin = record('origin', 'occurrence', 'collection:origin', {'collection_id' => 'C'},
                    {'origin' => temporal_envelope('2020-01-01T00:00:00Z', 'origin', 'origin', '/origin')}, '/origin')
    snapshot = record('snapshot', 'occurrence', 'collection:history_snapshot', {'collection_id' => 'C'},
                      {'through' => temporal_envelope('2026-10-01T00:00:00Z', 'snapshot', 'snapshot', '/through')}, '/through')
    artifact = record('artifact', 'entity', 'file:hash', {'sha256' => 'a' * 64},
                      {'collection_available' => temporal_envelope('2024-12-15T00:00:00Z', 'artifact', 'receipt', '/file-available')}, '/file-available')
    extraction = record('extraction', 'assertion', 'selector:extracted', {'output' => '/a/b.c', 'method' => 'extractor-1'},
                        {'collection_available' => temporal_envelope('2026-09-10T00:00:00Z', 'extraction', 'receipt', '/extraction-available')}, '/extraction-available')
    extraction['subject'] = 'artifact'
    receipt = record('receipt', 'occurrence', 'evidence:availability', {'collection_id' => 'C'})
    history = record('history', 'assertion', 'finding:history', {'manifest_source_id' => 'manifest-source', 'manifest_field' => '/history'})
    history['evidence'] = [{'source_id' => 'manifest-source', 'field' => '/history'}]
    source = {'id' => 's1', 'publisher' => 'lab', 'document' => 'lab-records', 'revision' => 'r1', 'collection' => 'C', 'independent_origin' => nil}
    data = {evidence: {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0', 'collection_id' => 'C',
                      'sources' => [source, source.merge('id' => 'manifest-source', 'document' => 'history-manifest')],
                      'records' => [origin, snapshot, artifact, extraction, receipt, history]},
            claim_key: key, qualification: qualification, history_id: 'history', qualified_support_sets: [%w[artifact extraction]],
            manifest: {'contract' => F::ID, 'version' => '1.0', 'history_id' => 'history', 'revision' => 'r1', 'collection_id' => 'C',
                       'scope_id' => 'C-history-origin-through-snapshot', 'origin_id' => 'origin', 'through_id' => 'snapshot',
                       'origin_sha256' => C.digest(origin), 'through_sha256' => C.digest(snapshot),
                       'coverage' => 'complete_declared_scope', 'qualification' => qualification, 'establishments' => []}}
    add_establishment(data, 'established', '2026-09-11T00:00:00Z', %w[artifact extraction])
    seal(data)
  end

  def add_establishment(data, id, value, support, key = nil)
    entry = record(id, 'occurrence', 'finding:establishment',
                   {'claim_key' => key || data[:claim_key], 'collection_id' => 'C', 'history_id' => 'history',
                    'qualification' => data[:qualification], 'support' => support.map { |sid| {'record_id' => sid, 'sha256' => '0' * 64} }},
                   {'established' => temporal_envelope(value, id, id, "/#{id}")}, "/#{id}")
    data[:evidence]['records'] << entry
  end

  def find(data, id)
    data[:evidence]['records'].find { |entry| entry['id'] == id }
  end

  def seal(data)
    events = data[:evidence]['records'].select { |entry| entry['type'] == 'finding:establishment' }
    events.each do |entry|
      entry['attributes']['support'].each { |support| support['sha256'] = C.digest(find(data, support['record_id'])) }
    end
    data[:manifest]['establishments'] = events.map { |entry| {'record_id' => entry['id'], 'sha256' => C.digest(entry)} }
    data[:manifest]['origin_sha256'] = C.digest(find(data, data[:manifest]['origin_id'])) if find(data, data[:manifest]['origin_id'])
    data[:manifest]['through_sha256'] = C.digest(find(data, data[:manifest]['through_id'])) if find(data, data[:manifest]['through_id'])
    bytes = JSON.generate('history' => data[:manifest])
    data[:evidence]['sources'].find { |entry| entry['id'] == 'manifest-source' }['content_hash'] =
      {'algorithm' => 'sha256', 'value' => Digest::SHA256.hexdigest(bytes), 'scope' => 'exact_source_bytes'}
    data[:preserved_source_bytes] = {'manifest-source' => bytes}
    data
  end

  def evaluate(data)
    F.evaluate(**data.reject { |key, _value| key == :manifest })
  end

  def test_actual_later_establishment_requires_and_preserves_all_evidence
    data = fixture
    before = Marshal.load(Marshal.dump(data))
    answer = evaluate(data)
    assert_equal 'match', answer['status']
    assert_equal '2026-09-11T00:00:00Z', answer['first_scoped_time']['value']
    assert_equal ['established'], answer['earliest_establishment_ids']
    assert_equal 'source_asserted_complete_declared_scope', answer.dig('history', 'coverage_basis')
    assert_equal '2024-12-15T00:00:00Z', find(data, 'artifact').dig('times', 'collection_available', 'value')
    assert_equal before, data
    refute answer.key?('confidence')
    assert answer['limits'].any? { |text| text.include?('no global first-discovery') }
  end

  def test_maximum_component_time_and_boolean_do_not_supply_completion
    data = fixture
    data[:evidence]['records'].reject! { |entry| entry['type'] == 'finding:establishment' }
    find(data, 'extraction')['attributes']['completed'] = true
    seal(data)
    answer = evaluate(data)
    assert_equal 'unresolved', answer['status']
    assert_match(/actual establishment/, answer['reason'])
    data = fixture
    find(data, 'established')['attributes']['completed'] = true
    seal(data)
    assert_raises(F::InvalidInput) { evaluate(data) }
  end

  def test_same_claim_reprocessing_keeps_earliest_complete_finding
    data = fixture
    older = Marshal.load(Marshal.dump(find(data, 'extraction')))
    older['id'] = 'older-extraction'
    older['times']['collection_available'] = temporal_envelope('2026-08-09T00:00:00Z', 'older-extraction', 'receipt', '/older-available')
    older['evidence'] = [{'source_id' => 's1', 'field' => '/older-available'}]
    older['attributes']['method'] = 'extractor-0'
    data[:evidence]['records'] << older
    data[:qualified_support_sets] << %w[artifact older-extraction]
    add_establishment(data, 'earlier', '2026-08-10T00:00:00Z', %w[artifact older-extraction])
    add_establishment(data, 'reprocessed', '2026-09-12T00:00:00Z', %w[artifact extraction])
    seal(data)
    answer = evaluate(data)
    assert_equal 'match', answer['status']
    assert_equal ['earlier'], answer['earliest_establishment_ids']
    assert_equal '2026-08-10T00:00:00Z', answer['first_scoped_time']['value']
    assert_equal 3, answer['equivalent_establishment_ids'].length
    assert_equal 'no_match', EveryPivot::SemanticTime.calendar_window(answer['first_scoped_time'], query_date: '2026-09-14', window_days: 30)['status']
  end

  def test_incomplete_or_missing_original_history_cannot_prove_novelty
    data = fixture
    data[:manifest]['coverage'] = 'unknown'
    assert_equal 'unresolved', evaluate(seal(data))['status']
    data = fixture
    data[:preserved_source_bytes] = {}
    assert_equal 'unresolved', evaluate(data)['status']
    data = fixture
    data[:evidence]['records'].reject! { |entry| entry['id'] == 'origin' }
    assert_equal 'unresolved', evaluate(seal(data))['status']
  end

  def test_unresolved_earlier_equivalent_cannot_be_skipped_for_recent_event
    data = fixture
    add_establishment(data, 'earlier-unknown', '2026-08-01T00:00:00Z', %w[artifact extraction])
    find(data, 'earlier-unknown')['times']['established'].delete('timezone')
    answer = evaluate(seal(data))
    assert_equal 'unresolved', answer['status']
    assert_match(/later event cannot manufacture freshness/, answer['reason'])
    refute answer.key?('first_scoped_time')
  end

  def test_establishment_with_known_future_support_does_not_qualify
    data = fixture
    find(data, 'extraction')['times']['collection_available']['value'] = '2026-09-15T00:00:00Z'
    answer = evaluate(seal(data))
    assert_equal 'no_match', answer['status']
    assert_match(/known later support/, answer['establishment_checks'][0]['reason'])
  end

  def test_independently_complete_outputs_keep_separate_dates
    data = fixture
    second_key = C.digest(['page-finding', 'selector:path:A', 'capture:page1'])
    add_establishment(data, 'page', '2026-09-14T00:00:00Z', %w[artifact extraction], second_key)
    seal(data)
    assert_equal '2026-09-11T00:00:00Z', evaluate(data)['first_scoped_time']['value']
    data[:claim_key] = second_key
    assert_equal '2026-09-14T00:00:00Z', evaluate(data)['first_scoped_time']['value']
  end

  def test_wrong_collection_profile_key_or_unqualified_support_does_not_pass
    data = fixture
    data[:manifest]['collection_id'] = 'other-collection'
    assert_equal 'no_match', evaluate(seal(data))['status']
    data = fixture
    data[:qualification] = data[:qualification].merge('revision' => 'other')
    assert_equal 'unsupported', evaluate(data)['status']
    data = fixture
    data[:claim_key] = C.digest(['unrelated-claim'])
    assert_equal 'unresolved', evaluate(data)['status']
    data = fixture
    data[:qualified_support_sets] = [%w[artifact]]
    assert_equal 'unresolved', evaluate(data)['status']
  end

  def test_required_collection_availability_is_not_derived_from_ingestion_or_observation
    data = fixture
    availability = find(data, 'extraction')['times'].delete('collection_available')
    find(data, 'extraction')['times']['observed'] = availability
    answer = evaluate(seal(data))
    assert_equal 'unresolved', answer['status']
    refute answer.key?('first_scoped_time')
  end

  def test_exact_time_binding_source_field_and_revision_must_correspond
    data = fixture
    find(data, 'extraction')['times']['collection_available']['binding']['object'] = 'artifact'
    assert_equal 'unresolved', evaluate(seal(data))['status']
    data = fixture
    find(data, 'extraction')['times']['collection_available']['field'] = '/other-field'
    assert_equal 'unresolved', evaluate(seal(data))['status']
    data = fixture
    find(data, 'receipt')['attributes']['collection_id'] = 'other-collection'
    assert_equal 'unresolved', evaluate(seal(data))['status']
    data = fixture
    find(data, 'receipt')['type'] = 'file:sighting'
    assert_equal 'unresolved', evaluate(seal(data))['status']
  end

  def test_altered_manifest_establishment_or_support_bytes_fail_integrity
    data = fixture
    data[:preserved_source_bytes]['manifest-source'] += ' '
    assert_raises(F::IntegrityFailure) { evaluate(data) }
    data = fixture
    find(data, 'established')['times']['established']['value'] = '2026-09-12T00:00:00Z'
    assert_raises(F::IntegrityFailure) { evaluate(data) }
    data = fixture
    find(data, 'extraction')['attributes']['output'] = '/wrong/file.c'
    assert_raises(F::IntegrityFailure) { evaluate(data) }
    data = fixture
    find(data, 'snapshot')['times']['through']['value'] = '2026-10-02T00:00:00Z'
    assert_raises(F::IntegrityFailure) { evaluate(data) }
  end

  def test_unlisted_establishment_blocks_completeness_and_endpoint_limits_scope
    data = fixture
    add_establishment(data, 'not-in-manifest', '2026-09-12T00:00:00Z', %w[artifact extraction])
    assert_equal 'unresolved', evaluate(data)['status']
    data = fixture
    find(data, 'snapshot')['times']['through']['value'] = '2026-09-10T00:00:00Z'
    assert_equal 'unresolved', evaluate(seal(data))['status']
  end

  def test_duplicate_json_keys_and_injected_extra_completion_fields_are_invalid
    data = fixture
    bytes = data[:preserved_source_bytes]['manifest-source'].sub('"coverage":', '"coverage":"unknown","coverage":')
    data[:preserved_source_bytes]['manifest-source'] = bytes
    data[:evidence]['sources'].find { |source| source['id'] == 'manifest-source' }['content_hash']['value'] = Digest::SHA256.hexdigest(bytes)
    assert_raises(F::InvalidInput) { evaluate(data) }
    data = fixture
    data[:manifest]['all_history_proven'] = true
    assert_raises(F::InvalidInput) { evaluate(seal(data)) }
  end

  def test_matching_field_and_revision_must_identify_one_source
    %w[origin snapshot established extraction].each do |id|
      data = fixture
      duplicate = data[:evidence]['sources'].first.merge('id' => 'same-revision-another-source', 'document' => 'different-document')
      data[:evidence]['sources'] << duplicate
      existing = find(data, id)['evidence'].first
      find(data, id)['evidence'] << existing.merge('source_id' => duplicate['id'])
      answer = evaluate(seal(data))
      assert_equal 'unresolved', answer['status'], id
      refute answer.key?('first_scoped_time'), id
    end
  end

  def test_repeated_reference_to_same_source_is_not_a_new_ambiguous_source
    data = fixture
    find(data, 'extraction')['evidence'] << find(data, 'extraction')['evidence'].first.dup
    assert_equal 'match', evaluate(seal(data))['status']
  end

  def test_other_content_hash_scope_cannot_prove_exact_source_reproduction
    ['normalized_json', 'exact preserved JSON document bytes', 'rendered_text'].each do |scope|
      data = fixture
      data[:evidence]['sources'].find { |source| source['id'] == 'manifest-source' }['content_hash']['scope'] = scope
      answer = evaluate(data)
      assert_equal 'unsupported', answer['status']
      assert_match(/exact_source_bytes/, answer['reason'])
      refute answer.key?('first_scoped_time')
    end
  end

  def add_unqualified_equivalent(data, value = '2026-09-13T00:00:00Z')
    incomplete = Marshal.load(Marshal.dump(find(data, 'extraction')))
    incomplete['id'] = 'unqualified-extraction'
    incomplete['times'] = {}
    data[:evidence]['records'] << incomplete
    # This branch is deliberately not in the engine-qualified support sets.
    add_establishment(data, 'unresolved-equivalent', value, %w[artifact unqualified-extraction])
    data
  end

  def test_provably_later_unresolved_support_does_not_erase_qualified_first_availability
    data = add_unqualified_equivalent(fixture)
    answer = evaluate(seal(data))
    assert_equal 'match', answer['status']
    assert_equal '2026-09-11T00:00:00Z', answer['first_scoped_time']['value']
    assert_equal ['established'], answer['equivalent_establishment_ids']
    assert_equal ['unresolved-equivalent'], answer['unresolved_later_establishment_ids']
    later = answer['establishment_checks'].find { |check| check['record_id'] == 'unresolved-equivalent' }
    assert_equal 'unresolved', later['status']
    assert_equal 'provably_later_context', later['freshness_effect']
    assert_equal 'match', later['earliest_ordering']['status']
  end

  def test_potentially_earlier_equal_or_source_ambiguous_event_still_blocks_freshness
    ['2026-09-01T00:00:00Z', '2026-09-11T00:00:00Z'].each do |value|
      answer = evaluate(seal(add_unqualified_equivalent(fixture, value)))
      assert_equal 'unresolved', answer['status'], value
      refute answer.key?('first_scoped_time')
    end
    data = add_unqualified_equivalent(fixture)
    find(data, 'unresolved-equivalent')['times']['established']['clock']['uncertainty_seconds'] = 3 * 86_400
    assert_equal 'unresolved', evaluate(seal(data))['status']
    data = add_unqualified_equivalent(fixture)
    find(data, 'unresolved-equivalent')['times']['established']['timezone'] = nil
    assert_equal 'unresolved', evaluate(seal(data))['status']
    data = add_unqualified_equivalent(fixture)
    find(data, 'unresolved-equivalent')['evidence'] = []
    assert_equal 'unresolved', evaluate(seal(data))['status']
  end

  def test_reversed_or_incomparable_history_scope_is_checked_even_without_establishments
    data = fixture
    data[:evidence]['records'].reject! { |record| record['type'] == 'finding:establishment' }
    find(data, 'origin')['times']['origin']['value'] = '2026-10-02T00:00:00Z'
    error = assert_raises(F::InvalidInput) { evaluate(seal(data)) }
    assert_match(/coverage endpoint precedes/, error.message)
    data = fixture
    data[:evidence]['records'].reject! { |record| record['type'] == 'finding:establishment' }
    find(data, 'origin')['times']['origin']['value'] = '2026-10-01T00:00:00Z'
    find(data, 'origin')['times']['origin']['clock']['uncertainty_seconds'] = 1
    answer = evaluate(seal(data))
    assert_equal 'unresolved', answer['status']
    assert_match(/origin-to-endpoint order/, answer['reason'])
  end

  def test_later_unresolved_context_cannot_hide_corrupt_support_or_scope_hashes
    data = seal(add_unqualified_equivalent(fixture))
    find(data, 'unqualified-extraction')['attributes']['output'] = 'tampered'
    assert_raises(F::IntegrityFailure) { evaluate(data) }
    data = fixture
    find(data, 'origin')['times'] = {}
    assert_raises(F::IntegrityFailure) { evaluate(data) }
    data = fixture
    find(data, 'snapshot')['type'] = 'unrelated-record'
    assert_raises(F::IntegrityFailure) { evaluate(data) }
  end
end
