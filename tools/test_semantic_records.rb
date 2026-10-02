#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'minitest/autorun'
require_relative 'semantic_records'

class SemanticRecordsTest < Minitest::Test
  R = EveryPivot::SemanticRecords

  def evidence
    {'contract' => R::CONTRACT, 'version' => '1.0', 'collection_id' => 'lab-collection',
     'sources' => [{'id' => 'report-r1', 'publisher' => 'publisher-A',
                   'document' => 'document-A', 'revision' => 'revision-1',
                   'collection' => 'lab-collection', 'independent_origin' => nil,
                   'content_hash' => {'algorithm' => 'sha256', 'value' => 'a' * 64,
                                      'scope' => 'the preserved report UTF-8 bytes'}}],
     'records' => [
       {'id' => 'file-A', 'kind' => 'entity', 'type' => 'file:bytes',
        'attributes' => {'sha256' => 'b' * 64}, 'times' => {}, 'evidence' => []},
       {'id' => 'sighting-A', 'kind' => 'occurrence', 'type' => 'file_sighting',
        'subject' => 'file-A', 'attributes' => {'location' => 'endpoint-A'},
        'times' => {'observed' => time},
        'evidence' => [{'source_id' => 'report-r1', 'field' => '/observations/0/observed'}]}]}
  end

  def time
    {'binding' => {'object' => 'file-A', 'occurrence' => 'sighting-A'},
     'field' => '/observations/0/observed', 'source_revision' => 'revision-1',
     'clock' => {'id' => 'source-clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'day', 'interval_role' => 'occurrence',
     'value' => '2024-12-03'}
  end

  def errors(data)
    R.validate(data).join("\n")
  end

  def test_known_records_are_indexed_without_mutation_or_assessment
    data = evidence
    original = JSON.generate(data)
    assert_empty R.validate(data)
    got = R.index(data)
    assert_equal %w[records sources], got.keys.sort
    assert_same data['records'][1], got['records']['sighting-A']
    assert_same data['sources'][0], got['sources']['report-r1']
    assert_equal original, JSON.generate(data)
    refute got.key?('confidence')
    refute got.key?('assessment')
  end

  def test_empty_collection_is_valid_encoding_not_a_qualifying_result
    data = evidence.merge('records' => [], 'sources' => [])
    assert_empty R.validate(data)
    assert_equal({'records' => {}, 'sources' => {}}, R.index(data))
  end

  def test_explicit_unknown_source_metadata_remains_unknown
    data = evidence
    %w[publisher document revision collection independent_origin].each { |key| data['sources'][0][key] = nil }
    data['records'][1]['times']['observed']['source_revision'] = nil
    assert_empty R.validate(data)
    assert_nil R.index(data)['sources']['report-r1']['independent_origin']
    assert_equal 'unresolved', EveryPivot::SemanticTime.normalize(data['records'][1]['times']['observed'])['status']
  end

  def test_metadata_absence_and_blank_are_not_silently_normalized
    data = evidence
    data['sources'][0].delete('revision')
    assert_match(/revision: required/, errors(data))
    data = evidence
    data['sources'][0]['revision'] = '  '
    assert_match(/revision: expected a nonblank string or null/, errors(data))
  end

  def test_repeated_source_labels_do_not_create_independence
    data = evidence
    data['sources'] << data['sources'][0].merge('id' => 'syndicated-copy', 'publisher' => 'publisher-B')
    data['records'][1]['evidence'] << {'source_id' => 'syndicated-copy', 'field' => '/observations/0/observed'}
    assert_empty R.validate(data)
    result = R.index(data)
    assert result['sources'].values.all? { |source| source['independent_origin'].nil? }
    refute result.key?('independent_source_count')
  end

  def test_conflicting_source_revisions_are_preserved_without_a_winner
    data = evidence
    data['sources'] << data['sources'][0].merge('id' => 'report-r2', 'revision' => 'revision-2')
    second = data['records'][1].merge('id' => 'sighting-B', 'attributes' => {'location' => 'endpoint-B'},
      'times' => {}, 'evidence' => [{'source_id' => 'report-r2', 'field' => '/observations/0'}])
    data['records'] << second
    assert_empty R.validate(data)
    assert_equal 3, R.index(data)['records'].length
  end

  def test_record_and_source_ids_are_unique_in_their_explicit_namespaces
    %w[records sources].each do |field|
      data = evidence
      data[field] << data[field][0].dup
      assert_match(/duplicate identity/, errors(data))
      exception = assert_raises(R::InvalidInput) { R.index(data) }
      assert exception.errors.any? { |message| message.include?('duplicate identity') }
    end
  end

  def test_subject_object_and_evidence_references_must_resolve
    %w[subject object].each do |field|
      data = evidence
      data['records'][1][field] = 'missing-record'
      assert_match(/#{field}: unknown record/, errors(data))
    end
    data = evidence
    data['records'][1]['evidence'][0]['source_id'] = 'missing-source'
    assert_match(/source_id: unknown source/, errors(data))
  end

  def test_temporal_occurrence_and_object_references_must_resolve
    %w[object occurrence].each do |field|
      data = evidence
      data['records'][1]['times']['observed']['binding'][field] = 'another-file'
      assert_match(/binding.#{field}: unknown record/, errors(data))
    end
  end

  def test_known_revision_mismatch_is_invalid_and_unknown_is_retained
    data = evidence
    data['records'][1]['times']['observed']['source_revision'] = 'not-the-preserved-revision'
    assert_match(/no linked evidence source has revision/, errors(data))
    data['sources'][0]['revision'] = nil
    assert_empty R.validate(data)
    assert_nil R.index(data)['sources']['report-r1']['revision']
  end

  def test_time_unknown_differs_from_malformed_and_unsupported
    data = evidence
    data['records'][1]['times']['observed'].delete('clock')
    assert_empty R.validate(data)
    assert_equal 'unresolved', EveryPivot::SemanticTime.normalize(data['records'][1]['times']['observed'])['status']
    data = evidence
    data['records'][1]['times']['observed']['value'] = '2024-02-30'
    refute_empty R.validate(data)
    data = evidence
    data['records'][1]['times']['observed']['timezone'] = 'Europe/London'
    assert_empty R.validate(data)
    assert_equal 'unsupported', EveryPivot::SemanticTime.normalize(data['records'][1]['times']['observed'])['status']
  end

  def test_alternative_time_references_are_checked_recursively
    data = evidence
    other = time
    other['binding']['occurrence'] = 'missing-occurrence'
    data['records'][1]['times']['observed'] = {'alternatives' => [time, other]}
    assert_match(/alternatives\[1\].binding.occurrence: unknown record/, errors(data))
  end

  def test_alternative_container_cannot_hide_parent_time_facts
    data = evidence
    data['records'][1]['times']['observed'] = time.merge('alternatives' => [time, time.merge('value' => '2026-09-01')])
    assert_match(/alternatives container cannot supply parent time facts/, errors(data))
  end

  def test_scoped_hash_has_explicit_algorithm_bytes_and_scope
    data = evidence
    %w[algorithm value scope].each do |key|
      edited = JSON.parse(JSON.generate(data))
      edited['sources'][0]['content_hash'].delete(key)
      refute_empty R.validate(edited), key
    end
    data['sources'][0]['content_hash']['value'] = 'A' * 64
    assert_match(/lowercase hexadecimal/, errors(data))
    data = evidence
    data['sources'][0]['content_hash']['algorithm'] = 'sha1'
    assert_match(/only sha256/, errors(data))
    data = evidence
    data['sources'][0]['content_hash'] = nil
    assert_empty R.validate(data)
  end

  def test_closed_envelope_rejects_undocumented_history_and_claim_fields
    ['finding_history', 'accepted_assessment', 'confidence', 'match'].each do |field|
      data = evidence.merge(field => true)
      assert_match(/#{field}: undeclared field/, errors(data))
    end
    data = evidence
    data['records'][1]['accepted_assessment'] = true
    assert_match(/accepted_assessment: undeclared field/, errors(data))
  end

  def test_raw_reported_booleans_are_data_not_results
    data = evidence
    data['records'][1]['attributes'] = {'match' => true, 'accepted_assessment' => true, 'confidence' => 100}
    assert_empty R.validate(data)
    got = R.index(data)
    assert_equal data['records'][1]['attributes'], got['records']['sighting-A']['attributes']
    refute got.key?('match')
    refute got.key?('accepted_assessment')
  end

  def test_json_encoding_rejects_nonfinite_numbers_cycles_and_ruby_only_values
    [Float::NAN, Float::INFINITY, :symbol, Object.new, "\xff".b].each do |bad|
      data = evidence
      data['records'][0]['attributes']['bad'] = bad
      refute_empty R.validate(data)
    end
    data = evidence
    data['records'][0]['attributes']['bad'] = data
    assert_match(/cyclic data is not JSON/, errors(data))
  end

  def test_unknown_time_metadata_does_not_hide_malformed_supplied_fields
    {'original_value' => 123, 'start_inclusive' => 'yes', 'field' => []}.each do |key, bad|
      data = evidence
      data['records'][1]['times']['observed'] = {key => bad}
      refute_empty R.validate(data), key
    end
    data = evidence
    data['records'][1]['times']['observed'] = {'clock' => {'uncertainty_seconds' => -1}}
    assert_match(/uncertainty_seconds: expected nonnegative finite/, errors(data))
    data['records'][1]['times']['observed'] = {'precision' => 'day', 'start' => nil}
    assert_match(/cannot also supply interval fields/, errors(data))
    data['records'][1]['times']['observed'] = {'precision' => 'interval', 'value' => nil}
    assert_match(/interval cannot also supply a point value/, errors(data))
  end

  def test_wrong_container_types_and_unknown_versions_fail_without_crashing
    [nil, false, [], 'document'].each { |input| refute_empty R.validate(input) }
    %w[sources records].each do |key|
      data = evidence.merge(key => {})
      assert_match(/#{key}: expected an array/, errors(data))
    end
    [1.0, nil, '2.0'].each do |version|
      assert_match(/version: expected/, errors(evidence.merge('version' => version)))
    end
  end
end
