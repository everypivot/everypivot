#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'semantic_time'

class SemanticTimeTest < Minitest::Test
  T = EveryPivot::SemanticTime

  def occurrence(value = '2026-09-14T12:00:00Z', precision: 'instant', timezone: 'UTC')
    {
      'binding' => { 'object' => 'file:f1', 'occurrence' => 'capture:c1' },
      'field' => '/captured_at', 'source_revision' => 'report:r1',
      'clock' => { 'id' => 'collector:c1', 'reference' => 'UTC', 'uncertainty_seconds' => 0 },
      'timezone' => timezone, 'precision' => precision,
      'interval_role' => 'occurrence', 'value' => value
    }
  end

  def interval(start_at, end_at, role: 'occurrence', end_inclusive: false)
    item = occurrence
    item.delete('value')
    item.merge('start' => start_at, 'end' => end_at, 'precision' => 'interval',
               'interval_role' => role, 'start_inclusive' => true, 'end_inclusive' => end_inclusive)
  end

  def test_exact_clock_conversion_keeps_evidence
    item = occurrence('2026-09-15T00:30:00+01:00', timezone: '+01:00')
    before = Marshal.load(Marshal.dump(item))
    answer = T.normalize(item)
    assert_equal 'match', answer['status']
    assert_equal '2026-09-14T23:30:00.000000000+00:00', answer.dig('normalized', 'lower')
    assert_equal before, item
    assert_equal before, answer['original']
  end

  def test_every_required_metadata_field_stays_unknown_when_absent
    %w[field source_revision timezone precision interval_role value clock binding].each do |key|
      item = occurrence
      item.delete(key)
      assert_equal 'unresolved', T.normalize(item)['status'], key
    end
    %w[id reference uncertainty_seconds].each do |key|
      item = occurrence
      item['clock'].delete(key)
      assert_equal 'unresolved', T.normalize(item)['status'], key
    end
    item = occurrence
    item['binding'].delete('occurrence')
    assert_equal 'unresolved', T.normalize(item)['status']
    assert_equal 'unresolved', T.normalize(nil)['status']
  end

  def test_unknown_and_unsupported_are_not_invalid_or_assumed_utc
    assert_equal 'unresolved', T.normalize(occurrence(nil))['status']
    assert_equal 'unresolved', T.normalize(occurrence(timezone: '-00:00'))['status']
    assert_equal 'unsupported', T.normalize(occurrence(timezone: 'Europe/London'))['status']
    item = occurrence
    item['clock']['reference'] = 'TAI'
    assert_equal 'unsupported', T.normalize(item)['status']
    assert_equal 'unsupported', T.compare(occurrence, 'approximately', occurrence)['status']
  end

  def test_supplied_malformed_values_and_offset_conflicts_are_invalid
    [42, '2026-02-30T12:00:00Z', '2026-09-14T24:00:00Z',
     '2026-09-14T12:00:60Z', '2026-09-14T12:00:00+01:00'].each do |value|
      assert_raises(T::InvalidInput) { T.normalize(occurrence(value)) }
    end
    item = occurrence
    item['clock']['uncertainty_seconds'] = -1
    assert_raises(T::InvalidInput) { T.normalize(item) }
    assert_raises(T::InvalidInput) { T.normalize(occurrence(timezone: '+24:00')) }
    assert_raises(T::InvalidInput) { T.normalize(occurrence(precision: 4)) }
    assert_raises(T::InvalidInput) { T.normalize([]) }
  end

  def test_explicit_timezone_can_interpret_offsetless_original
    item = occurrence('2026-09-14T12:00:00', timezone: '+01:00')
    assert_equal '2026-09-14T11:00:00.000000000+00:00', T.normalize(item).dig('normalized', 'lower')
    item.delete('timezone')
    assert_equal 'unresolved', T.normalize(item)['status']
  end

  def test_inclusive_calendar_window_is_not_rolling_hours
    { '2026-09-06T23:59:59Z' => 'no_match', '2026-09-07T00:00:00Z' => 'match',
      '2026-09-14T23:59:59Z' => 'match', '2026-09-15T00:00:00Z' => 'no_match' }.each do |value, expected|
      answer = T.calendar_window(occurrence(value), query_date: '2026-09-14', window_days: 7)
      assert_equal expected, answer['status'], value
      assert_equal({ 'start' => '2026-09-07', 'end' => '2026-09-14' }, answer['resolved_period'])
    end
    answer = T.calendar_window(occurrence('2016-09-16', precision: 'day'), query_date: '2026-09-14', window_days: 3650)
    assert_equal 'match', answer['status']
    assert_equal '2016-09-16', answer['resolved_period']['start']
  end

  def test_one_day_spans_two_utc_date_labels
    answer = T.calendar_window(occurrence('2026-09-14T00:00:00Z'), query_date: '2026-09-15', window_days: 1)
    assert_equal 'match', answer['status']
    assert_equal '2026-09-14', answer['resolved_period']['start']
    assert_equal 'match', T.calendar_window(occurrence, query_date: '2026-09-14', window_days: 0)['status']
    assert_raises(T::InvalidInput) { T.calendar_window(occurrence, query_date: '2026-09-14', window_days: 1.5) }
    assert_raises(T::InvalidInput) { T.calendar_window(occurrence, query_date: '2026-02-30', window_days: 1) }
  end

  def test_coarse_precision_is_possible_interval_not_midnight_event
    day = occurrence('2026-09-14', precision: 'day')
    normalized = T.normalize(day)['normalized']
    assert_equal '2026-09-15T00:00:00.000000000+00:00', normalized['upper']
    assert_equal false, normalized['upper_inclusive']
    assert_equal 'match', T.calendar_window(day, query_date: '2026-09-14', window_days: 0)['status']
    assert_equal 'unresolved', T.compare(day, '<=', occurrence('2026-09-14T12:00:00Z'))['status']
    assert_equal 'unresolved', T.compare(day, '==', day)['status']
    assert_equal 'match', T.compare(day, '<', occurrence('2026-09-15T00:00:00Z'))['status']
    assert_equal 'unresolved', T.calendar_window(occurrence('2026-09', precision: 'month'), query_date: '2026-09-14', window_days: 7)['status']
    assert_equal 'no_match', T.calendar_window(occurrence('2025', precision: 'year'), query_date: '2026-09-14', window_days: 7)['status']
  end

  def test_offset_date_can_cross_utc_boundary
    item = occurrence('2026-09-14', precision: 'day', timezone: '+01:00')
    assert_equal 'unresolved', T.calendar_window(item, query_date: '2026-09-14', window_days: 0)['status']
  end

  def test_clock_uncertainty_and_conflicting_evidence_do_not_choose_a_winner
    item = occurrence('2026-09-15T00:00:00Z')
    item['clock']['uncertainty_seconds'] = 2
    assert_equal 'unresolved', T.calendar_window(item, query_date: '2026-09-14', window_days: 0)['status']
    choices = { 'alternatives' => [occurrence('2026-09-14T12:00:00Z'), occurrence('2026-09-16T12:00:00Z')] }
    answer = T.calendar_window(choices, query_date: '2026-09-14', window_days: 0)
    assert_equal 'unresolved', answer['status']
    assert_equal 2, answer['alternatives'].length
  end

  def test_comparison_exact_and_uncertain_endpoints
    before, same, after = %w[2026-09-13T12:00:00Z 2026-09-14T12:00:00Z 2026-09-15T12:00:00Z].map { |value| occurrence(value) }
    assert_equal 'match', T.compare(before, 'lte', same)['status']
    assert_equal 'match', T.compare(same, '<=', same)['status']
    assert_equal 'no_match', T.compare(same, '<', same)['status']
    assert_equal 'match', T.compare(same, 'eq', same)['status']
    assert_equal 'no_match', T.compare(after, '<=', same)['status']
    assert_equal 'no_match', T.compare(before, '==', after)['status']
    closed = interval('2026-09-13T12:00:00Z', '2026-09-14T12:00:00Z', end_inclusive: true)
    assert_equal 'unresolved', T.compare(closed, '<', same)['status']
    assert_equal 'match', T.compare(closed, '<=', same)['status']
  end

  def test_evidenced_service_some_all_and_at_are_different
    service = interval('2026-08-01T00:00:00Z', '2026-10-01T00:00:00Z', role: 'service')
    period = { 'start' => '2026-09-01', 'end' => '2026-09-30' }
    assert_equal 'match', T.within(service, period: period, quantifier: 'some')['status']
    assert_equal 'match', T.within(service, period: period, quantifier: 'all')['status']
    assert_equal 'no_match', T.within(service, period: period, quantifier: 'contained')['status']
    shorter = interval('2026-09-10T00:00:00Z', '2026-09-20T00:00:00Z', role: 'service')
    assert_equal 'no_match', T.within(shorter, period: period, quantifier: 'all')['status']
    assert_equal 'match', T.within(shorter, period: period, quantifier: 'some')['status']
    assert_equal 'match', T.within(shorter, period: period, quantifier: 'contained')['status']
    assert_equal 'match', T.within(service, period: period, quantifier: 'at', at: occurrence)['status']
    assert_equal 'no_match', T.within(service, period: period, quantifier: 'at', at: occurrence('2026-10-01T00:00:00Z'))['status']
    assert_equal 'unsupported', T.compare(service, '<=', occurrence)['status']
    assert_equal 'unsupported', T.within(occurrence, period: period, quantifier: 'at', at: occurrence)['status']
  end

  def test_uncertain_occurrence_requires_contained_and_does_not_assert_possible_overlap_is_actual
    item = interval('2026-08-01T00:00:00Z', '2026-10-01T00:00:00Z')
    period = { 'start' => '2026-09-01', 'end' => '2026-09-30' }
    assert_equal 'unsupported', T.within(item, period: period, quantifier: 'some')['status']
    assert_equal 'unsupported', T.within(item, period: period, quantifier: 'all')['status']
    assert_equal 'unresolved', T.within(item, period: period, quantifier: 'contained')['status']
  end

  def test_missing_end_is_not_infinite_service_and_status_does_not_imply_continuity
    service = interval('2008-01-01T00:00:00Z', nil, role: 'service')
    assert_equal 'unresolved', T.calendar_window(service, query_date: '2026-09-14', window_days: 3650, quantifier: 'some')['status']
    status = occurrence('2026-09-14T12:00:00Z').merge('interval_role' => 'service')
    assert_equal 'match', T.calendar_window(status, query_date: '2026-09-14', window_days: 3650, quantifier: 'some')['status']
    assert_equal 'no_match', T.within(status, period: { 'start' => '2024-01-01', 'end' => '2024-12-31' }, quantifier: 'some')['status']
    unknown_bounds = interval('2026-08-01T00:00:00Z', '2026-10-01T00:00:00Z', role: 'service')
    unknown_bounds['clock']['uncertainty_seconds'] = 3
    assert_equal 'unresolved', T.normalize(unknown_bounds)['status']
  end

  def test_interval_input_endpoints_and_precision_are_explicit
    assert_raises(T::InvalidInput) { T.normalize(interval('2026-09-15T00:00:00Z', '2026-09-14T00:00:00Z')) }
    assert_raises(T::InvalidInput) { T.normalize(interval('2026-09-14T00:00:00Z', '2026-09-14T00:00:00Z')) }
    missing = interval('2026-09-14T00:00:00Z', '2026-09-15T00:00:00Z')
    missing.delete('end_inclusive')
    assert_equal 'unresolved', T.normalize(missing)['status']
    coarse = occurrence('2026-09-14', precision: 'day').merge('interval_role' => 'service')
    assert_equal 'unsupported', T.normalize(coarse)['status']
  end

  def test_late_extraction_does_not_refresh_contextual_sighting
    sighting = occurrence('2024-12-15T12:00:00Z')
    extraction = occurrence('2026-09-10T12:00:00Z')
    extraction['binding']['occurrence'] = 'extraction:e1'
    extraction['field'] = '/extracted_at'
    assert_equal 'no_match', T.calendar_window(sighting, query_date: '2026-09-14', window_days: 365)['status']
    assert_equal 'match', T.calendar_window(extraction, query_date: '2026-09-14', window_days: 365)['status']
    assert_equal 'no_match', T.compare(extraction, '<=', sighting)['status']
    assert_equal '2024-12-15T12:00:00Z', sighting['value']
    # This result dates the extraction only. The time helper cannot infer a
    # complete finding, first availability, new contextual sighting or knowledge.
    refute T.normalize(extraction).key?('finding_available_at')
  end

  def test_subnanosecond_precision_and_minute_input_are_preserved
    item = occurrence('2026-09-14T12:00:00.123456789123Z')
    assert_equal '2026-09-14T12:00:00.123456789123+00:00', T.normalize(item).dig('normalized', 'lower')
    item = occurrence('2026-09-14T12:00Z', precision: 'minute')
    assert_equal '2026-09-14T12:01:00.000000000+00:00', T.normalize(item).dig('normalized', 'upper')
    assert_equal 'match', T.normalize(occurrence('2026-09-14T12:00:00Z', precision: 'second'))['status']
  end

  def test_contract_does_not_ignore_unknown_or_competing_time_fields
    alternatives = { 'alternatives' => [occurrence, occurrence], 'value' => '2024-01-01' }
    assert_raises(T::InvalidInput) { T.normalize(alternatives) }
    assert_raises(T::InvalidInput) { T.normalize(occurrence.merge('assumed_utc' => true)) }
    assert_raises(T::InvalidInput) { T.normalize(occurrence.merge('start' => '2024-01-01T00:00:00Z')) }
    item = interval('2026-09-14T00:00:00Z', '2026-09-15T00:00:00Z')
    item['value'] = '2024-01-01'
    assert_raises(T::InvalidInput) { T.normalize(item) }
  end
end
