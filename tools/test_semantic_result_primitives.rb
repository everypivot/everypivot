#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'semantic_result_primitives'

# Independently specified synthetic cases; no feed, filesystem traversal,
# decompressor, publisher authentication or native backend is exercised here.
class SemanticResultPrimitivesTest < Minitest::Test
  P = EveryPivot::SemanticResultPrimitives

  def setup
    @data = {'records' => {}, 'sources' => {}}
    @bytes = {}
  end

  def source(id, bytes = nil)
    value = {'id' => id, 'publisher' => 'synthetic-publisher', 'document' => id,
             'revision' => 'r1', 'collection' => 'test-collection', 'independent_origin' => nil}
    value['content_hash'] = {'algorithm' => 'sha256', 'value' => Digest::SHA256.hexdigest(bytes), 'scope' => 'exact_source_bytes'} if bytes
    @data['sources'][id] = value
  end

  def rec(id, type, kind = 'entity', attrs = {})
    @data['records'][id] = {'id' => id, 'type' => type, 'kind' => kind, 'attributes' => attrs, 'times' => {}, 'evidence' => []}
  end

  def preserve(record, bytes)
    id = record['id'] + '-source'
    source(id, bytes)
    @bytes[id] = bytes
    record['evidence'] = [{'source_id' => id, 'field' => '/'}]
    record['attributes']['content'] = {'source_id' => id, 'source_revision' => 'r1', 'field' => '/',
      'sha256' => Digest::SHA256.hexdigest(bytes), 'byte_length' => bytes.bytesize, 'representation' => 'exact_source_bytes'}
  end

  def scope(kind = 'collected_file_set')
    {'identity' => 'explicit-fixture-scope', 'kind' => kind, 'description' => 'All named files in this preserved collection only'}
  end

  def kit(id, files = {'config.php' => 'configuration=A', 'assets/site.css' => "body {}\x00".b}, scope_value = scope)
    record = rec(id, 'kit:file_set_manifest')
    entries = files.map do |path, bytes|
      member = rec(id + '-entry-' + @data['records'].length.to_s, 'kit:file_set_member')
      preserve(member, bytes)
      {'path' => path, 'record_id' => member['id'], 'sha256' => Digest::SHA256.hexdigest(bytes), 'byte_length' => bytes.bytesize}
    end
    manifest = {'contract' => 'everypivot.file_set_manifest', 'version' => '1.0', 'profile' => 'exact_manifest_v1',
      'scope' => scope_value, 'path_mapping' => 'exact_relative_posix_v1', 'normalization' => 'none',
      'exclusions' => [], 'transformations' => [], 'entries' => entries}
    preserve(record, JSON.generate(manifest))
    coverage = rec(id + '-coverage', 'kit:file_set_coverage', 'assertion')
    coverage['subject'] = id
    record['attributes']['coverage_record_id'] = coverage['id']
    inventory = {'contract' => 'everypivot.file_set_coverage', 'version' => '1.0',
      'manifest_sha256' => record['attributes']['content']['sha256'], 'scope' => scope_value,
      'method' => 'explicit_path_inventory_v1', 'method_version' => '1.0',
      'coverage' => 'complete_for_declared_scope', 'paths' => files.keys}
    preserve(coverage, JSON.generate(inventory))
    id
  end

  def body(id)
    JSON.parse(@bytes[@data['records'][id]['attributes']['content']['source_id']])
  end

  def change_body(id, update_coverage = false)
    value = body(id)
    yield value
    preserve(@data['records'][id], JSON.generate(value))
    if update_coverage
      change_body(id + '-coverage') { |inventory| inventory['manifest_sha256'] = @data['records'][id]['attributes']['content']['sha256'] }
    end
  end

  def compare(left = 'left', right = 'right', limits = {})
    P.file_set_equal(left: left, right: right, evidence: @data, preserved_source_bytes: @bytes, limits: limits)
  end

  def provenance(id, field, source_id = 'publisher-report')
    {'source' => source_id, 'record_id' => id, 'source_revision' => 'r1', 'field' => field, 'basis' => 'reported'}
  end

  def address(value = '203.0.113.9')
    {'kind' => 'ipv4', 'value' => value, 'representation' => 'dotted_decimal', 'normalization' => 'strict_dotted_decimal_v1',
     'provenance' => provenance('query', '/value', 'declared-query-seed')}
  end

  def prefix(value = '203.0.113.0/24')
    source('publisher-report')
    record = rec('prefix', 'network:prefix_scope', 'assertion',
      'prefix' => {'value' => value, 'representation' => 'ipv4_cidr', 'normalization' => 'strict_network_cidr_v1', 'provenance' => provenance('prefix', '/scope/cidr')},
      'applicability' => {'value' => 'all_addresses_in_prefix', 'provenance' => provenance('prefix', '/scope/member_applicability')})
    record['evidence'] = [{'source_id' => 'publisher-report', 'field' => '/scope'}]
    record
  end

  def in_prefix(value = '203.0.113.9')
    P.ip_in_prefix(address: address(value), prefix: 'prefix', evidence: @data)
  end

  def test_prefix_exact_boundaries_and_different_network
    prefix
    %w[203.0.113.0 203.0.113.9 203.0.113.255].each { |ip| assert_equal 'match', in_prefix(ip)['status'] }
    %w[203.0.112.255 203.0.114.0].each { |ip| assert_equal 'no_match', in_prefix(ip)['status'] }
    prefix('203.0.113.9/32')
    assert_equal 'match', in_prefix['status']
    assert_equal 'no_match', in_prefix('203.0.113.8')['status']
    prefix('0.0.0.0/0')
    assert_equal 'match', in_prefix('255.255.255.255')['status']
    refute in_prefix.key?('confidence')
  end

  def test_containment_without_publisher_applicability_is_not_a_match
    record = prefix
    record['attributes'].delete('applicability')
    assert_equal 'unresolved', in_prefix['status']
    record['attributes']['applicability'] = {'value' => 'all_addresses_in_prefix'}
    assert_equal 'unresolved', in_prefix['status']
    record = prefix
    record['attributes']['applicability']['value'] = 'listed_individual_addresses_only'
    assert_equal 'no_match', in_prefix['status']
    record['attributes']['applicability']['value'] = 'same_asn'
    assert_equal 'unsupported', in_prefix['status']
  end

  def test_prefix_provenance_must_have_same_real_source_revision_and_literal_field
    record = prefix
    record['attributes']['prefix']['provenance']['source_revision'] = 'r2'
    assert_equal 'no_match', in_prefix['status']
    record = prefix
    record['attributes']['applicability']['provenance']['record_id'] = 'other'
    assert_equal 'no_match', in_prefix['status']
    record = prefix
    record['attributes']['applicability']['provenance']['field'] = '/scope_lookalike/value'
    assert_equal 'no_match', in_prefix['status']
    record = prefix
    @data['sources']['publisher-report']['publisher'] = nil
    assert_equal 'unresolved', in_prefix['status']
    prefix
    @data['sources']['publisher-report']['revision'] = nil
    assert_equal 'unresolved', in_prefix['status']
    record = prefix
    source('other-report')
    record['evidence'] << {'source_id' => 'other-report', 'field' => '/scope'}
    record['attributes']['applicability']['provenance']['source'] = 'other-report'
    assert_equal 'no_match', in_prefix['status']
  end

  def test_ambiguous_radix_host_bits_and_malformed_prefixes_are_invalid
    %w[203.0.113.1/24 203.0.113.0/024 203.0.113.0/33 203.000.113.0/24 0xcb007100/24 203.0.113.0].each do |value|
      prefix(value)
      assert_raises(P::InvalidInput) { in_prefix }
    end
    prefix
    %w[203.0.113.009 0xcb007109 3405803785 203.0.113.999].each { |value| assert_raises(P::InvalidInput) { in_prefix(value) } }
    record = prefix
    record['attributes'].delete('applicability')
    record['attributes']['prefix']['value'] = false
    assert_raises(P::InvalidInput) { in_prefix }
    record = prefix
    record['attributes']['applicability']['value'] = nil
    record['attributes']['applicability']['provenance'] = false
    assert_raises(P::InvalidInput) { in_prefix }
    record = prefix('2001:db8::/32')
    record['attributes']['prefix']['representation'] = 'ipv6_cidr'
    assert_equal 'unsupported', in_prefix['status']
  end

  def test_exact_sets_compare_bytes_and_paths_not_archive_digest_or_manifest_serialization
    kit('left'); kit('right')
    @data['records']['left']['attributes']['archive_sha256'] = 'a' * 64
    @data['records']['right']['attributes']['archive_sha256'] = 'b' * 64
    left_hash = @data['records']['left']['attributes']['content']['sha256']
    refute_equal left_hash, @data['records']['right']['attributes']['content']['sha256']
    result = compare
    assert_equal 'match', result['status']
    assert_equal true, result['locally_reproduced']
    assert_equal 2, result['left']['entry_count']
    assert_equal 'collected_file_set', result['scope']['kind']
    assert_equal 'source_reported_complete_inventory_locally_crosschecked', result['left']['coverage_basis']
    assert_match(/not_archive_identity_deployment/, result['claim'])
    refute result.key?('confidence')
  end

  def test_changed_configuration_and_literal_paths_defeat_exact_equality
    kit('left'); kit('right', {'config.php' => 'configuration=B', 'assets/site.css' => "body {}\x00".b})
    assert_equal 'no_match', compare['status']
    kit('right', {'Config.php' => 'configuration=A', 'assets/site.css' => "body {}\x00".b})
    assert_equal 'no_match', compare['status']
    kit('right', {'config.php' => 'configuration=A'})
    assert_equal 'no_match', compare['status']
  end

  def test_subset_matches_retain_scope_and_cannot_match_a_different_scope
    kit('left', {'assets/a.css' => 'same'}, scope('declared_subset'))
    kit('right', {'assets/a.css' => 'same'}, scope('declared_subset'))
    result = compare
    assert_equal 'match', result['status']
    assert_equal 'declared_subset', result['scope']['kind']
    kit('right', {'assets/a.css' => 'same'}, scope)
    assert_equal 'unresolved', compare['status']
    kit('right', {'assets/a.css' => 'same'}, scope('complete_deployed_kit'))
    assert_equal 'unsupported', compare['status']
  end

  def test_partial_or_unrecorded_inventory_is_not_complete_file_set_evidence
    kit('left'); kit('right')
    change_body('right-coverage') { |value| value['coverage'] = 'partial_for_declared_scope' }
    assert_equal 'no_match', compare['status']
    change_body('right-coverage') { |value| value['coverage'] = 'unknown' }
    assert_equal 'unresolved', compare['status']
    change_body('right-coverage') { |value| value['coverage'] = 'complete_for_declared_scope'; value['paths'] << 'missing.php' }
    assert_equal 'no_match', compare['status']
    @data['records']['right']['attributes'].delete('coverage_record_id')
    assert_equal 'unresolved', compare['status']
  end

  def test_coverage_must_be_bound_to_exact_preserved_manifest_and_scope
    kit('left'); kit('right')
    @data['records']['right-coverage']['subject'] = 'left'
    assert_equal 'no_match', compare['status']
    @data['records']['right-coverage']['subject'] = 'right'
    change_body('right-coverage') { |value| value['manifest_sha256'] = '0' * 64 }
    assert_equal 'no_match', compare['status']
    change_body('right-coverage') { |value| value['manifest_sha256'] = @data['records']['right']['attributes']['content']['sha256']; value['scope']['identity'] = 'other' }
    assert_equal 'no_match', compare['status']
  end

  def test_every_actual_member_manifest_and_coverage_byte_identity_is_required
    kit('left'); kit('right')
    %w[left left-coverage].each do |id|
      sid = @data['records'][id]['attributes']['content']['source_id']
      saved = @bytes.delete(sid)
      assert_equal 'unresolved', compare['status']
      @bytes[sid] = saved + '!'
      assert_raises(P::InvalidInput) { compare }
      @bytes[sid] = saved
    end
    member = body('left')['entries'][0]['record_id']
    sid = @data['records'][member]['attributes']['content']['source_id']
    saved = @bytes.delete(sid)
    assert_equal 'unresolved', compare['status']
    @bytes[sid] = saved.sub('A', 'B')
    assert_raises(P::InvalidInput) { compare }
  end

  def test_known_manifest_member_hash_conflicts_are_integrity_failures
    kit('left'); kit('right')
    change_body('left', true) { |value| value['entries'][0]['sha256'] = '0' * 64 }
    assert_raises(P::InvalidInput) { compare }
    kit('left')
    change_body('left', true) { |value| value['entries'][0]['byte_length'] += 1 }
    assert_raises(P::InvalidInput) { compare }
    kit('left')
    @data['sources']['left-source']['content_hash']['value'] = '0' * 64
    assert_raises(P::InvalidInput) { compare }
  end

  def test_no_silent_path_normalization_duplicates_or_exclusions
    kit('right')
    ['/config.php', '../config.php', './config.php', 'a//b', 'a\\b', "a\x00b"].each do |path|
      kit('left', {path => 'x'})
      assert_raises(P::InvalidInput) { compare }
    end
    kit('left')
    change_body('left', true) { |value| value['entries'] << value['entries'][0] }
    assert_raises(P::InvalidInput) { compare }
    kit('left')
    change_body('left', true) { |value| value['exclusions'] = ['config.php'] }
    assert_equal 'unsupported', compare['status']
    kit('left')
    change_body('left', true) { |value| value['normalization'] = 'case_fold' }
    assert_equal 'unsupported', compare['status']
  end

  def test_reordered_entries_and_exact_utf8_paths_need_no_hidden_normalization
    files = {"caf\u00e9.php" => "\xff\x00".b, 'other' => ''}
    kit('left', files)
    kit('right', files.to_a.reverse.to_h)
    assert_equal 'match', compare['status']
  end

  def test_precomputed_equal_and_completed_shortcuts_are_rejected
    kit('left'); kit('right')
    change_body('left', true) { |value| value['result'] = 'equal' }
    assert_raises(P::InvalidInput) { compare }
    kit('left')
    change_body('left-coverage') { |value| value['completed'] = true }
    assert_raises(P::InvalidInput) { compare }
    kit('left')
    change_body('left-coverage') { |value| value['coverage'] = true }
    assert_raises(P::InvalidInput) { compare }
  end

  def test_missing_is_unknown_but_supplied_wrong_types_are_invalid
    kit('left'); kit('right')
    change_body('left', true) { |value| value['entries'][0].delete('sha256') }
    assert_equal 'unresolved', compare['status']
    [false, [], {}, 7].each do |invalid|
      kit('left')
      change_body('left', true) { |value| value['entries'][0]['sha256'] = invalid }
      assert_raises(P::InvalidInput) { compare }
    end
    kit('left')
    @data['records']['left']['attributes']['content']['source_revision'] = nil
    assert_equal 'unresolved', compare['status']
    @data['records']['left']['attributes']['content']['source_revision'] = false
    assert_raises(P::InvalidInput) { compare }
    assert_equal 'unresolved', compare(nil)['status']
  end

  def test_broken_record_source_and_scope_references_do_not_create_a_match
    kit('left'); kit('right')
    change_body('left', true) { |value| value['entries'][0]['record_id'] = 'does-not-exist' }
    assert_raises(P::InvalidInput) { compare }
    kit('left')
    @data['records']['left']['attributes']['content']['source_id'] = 'does-not-exist'
    assert_raises(P::InvalidInput) { compare }
    kit('left')
    @data['records']['left']['attributes']['content']['source_revision'] = 'r2'
    assert_equal 'no_match', compare['status']
    kit('left')
    @data['records']['left']['attributes']['content']['field'] = '/unlinked'
    assert_equal 'no_match', compare['status']
  end

  def test_duplicate_json_keys_are_invalid_even_if_last_value_would_qualify
    kit('left'); kit('right')
    bytes = @bytes['left-source'].sub('"profile":', '"profile":"false_recipe","profile":')
    preserve(@data['records']['left'], bytes)
    assert_raises(P::InvalidInput) { compare }
  end

  def test_explicit_finite_budgets_fail_without_an_equality_claim
    kit('left'); kit('right')
    %w[max_manifest_bytes max_coverage_bytes max_entries max_total_entry_bytes].each do |key|
      got = compare('left', 'right', key => 1)
      assert_equal 'unsupported', got['status'], key
      assert_match(/budget_exceeded/, got['reason'])
      refute_equal true, got['locally_reproduced']
    end
    assert_equal 'match', compare('left', 'right', 'max_entries' => 2.0)['status']
    [false, 0, -1, 1.5, Float::INFINITY, {}, '2'].each { |value| assert_raises(P::InvalidInput) { compare('left', 'right', 'max_entries' => value) } }
    assert_raises(P::InvalidInput) { compare('left', 'right', 'unbounded' => true) }
  end

  def test_raw_envelope_and_indexed_inputs_agree_without_mutation
    kit('left'); kit('right')
    before = Marshal.dump([@data, @bytes])
    raw = {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0', 'collection_id' => 'test',
           'records' => @data['records'].values, 'sources' => @data['sources'].values}
    result = P.file_set_equal(left: 'left', right: 'right', evidence: raw, preserved_source_bytes: @bytes)
    assert_equal compare, result
    assert_equal before, Marshal.dump([@data, @bytes])
  end

  def test_explicit_shared_paths_are_candidates_even_when_config_bytes_differ
    kit('left'); kit('right', {'config.php' => 'configuration=B'})
    call = ->(paths) { P.file_set_shared_paths(left: 'left', right: 'right', paths: paths, evidence: @data, preserved_source_bytes: @bytes) }
    assert_equal 'no_match', compare['status']
    result = call.call(['config.php'])
    assert_equal 'match', result['status']
    assert_equal ['config.php'], result['shared_paths']
    assert_match(/not_content_equality_rarity/, result['claim'])
    assert_equal 'no_match', call.call(['assets/site.css'])['status']
    [[], ['config.php', 'config.php'], ['../config.php'], [false], 'config.php'].each { |paths| assert_raises(P::InvalidInput) { call.call(paths) } }
    @bytes.delete('left-coverage-source')
    assert_equal 'unresolved', call.call(['config.php'])['status']
  end
end
