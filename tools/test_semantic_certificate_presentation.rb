#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'json'
require 'digest'
require 'base64'
require 'openssl'
require 'open3'
require_relative 'semantic_evaluator'

# Independently authored synthetic records and saved public certificate vectors.
# Tests exercise normalized evidence contracts, not native collection, report
# authenticity, certificate trust, legal conclusions or analyst acceptance.
class SemanticCertificatePresentationTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)
  FIXTURES = File.join(ROOT, 'fixtures/semantic-families/certificate-presentation')
  E = EveryPivot::SemanticEvaluator
  S = EveryPivot::SemanticIdentity

  def read(name)
    JSON.parse(File.read(File.join(FIXTURES, name)))
  end

  def evidence
    read('evidence.json')
  end

  def query(kind = 'exact')
    read(kind + '-query.json')
  end

  def contract(target = 'domains')
    id = target == 'domains' ? 'OSINT_CERT_SHA_TO_DOMAINS' : 'OSINT_CERT_TO_SERVERS'
    JSON.parse(File.read(File.join(ROOT, 'contracts/semantics', id + '.json')))
  end

  def evaluate(target = 'domains', data = evidence, request = query)
    E.new(contract(target)).evaluate(data, request)
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

  def targets(got)
    got['results'].map { |r| r['identity'].first }.sort
  end

  def empty(got, outcome = nil)
    assert_empty got['results']
    assert_equal outcome, got['outcome'] if outcome
  end

  def cutoff(value)
    {'binding' => {'object' => 'case-question', 'occurrence' => 'case-cutoff'},
     'field' => '/query/knowledge_cutoff', 'source_revision' => 'case-1',
     'clock' => {'id' => 'case-clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end

  def source_pointer(pointer)
    pointer.split('/').drop(1).reduce(read('source.json')) { |value, part| value.fetch(part.gsub('~1', '/').gsub('~0', '~')) }
  end

  def opposition(data, id)
    claim = source_pointer('/claims/' + id)
    attributes = claim.reject { |key, _| %w[kind type subject object].include?(key) }
    value = {'id' => id, 'kind' => claim['kind'], 'type' => claim['type'], 'attributes' => attributes,
             'times' => {}, 'evidence' => [{'source_id' => 'cert-source', 'field' => '/claims/' + id}], 'subject' => claim['subject']}
    data['records'] << value
  end

  def add_presentation_copy(data, suffix)
    [['p1', 'p1-' + suffix], ['n1', 'n1-' + suffix]].each do |old_id, new_id|
      copy = Marshal.load(Marshal.dump(record(data, old_id)))
      source = source_pointer('/claims/' + new_id)
      copy['id'] = new_id
      copy['subject'] = source['subject']
      copy['attributes'].keys.each { |key| copy['attributes'][key] = source[key] }
      copy['times'].each do |key, time|
        time['binding'] = {'object' => new_id, 'occurrence' => new_id}
        time['field'] = '/claims/' + new_id + '/' + key
        time['value'] = source[key]
      end
      copy['evidence'] = [{'source_id' => 'cert-source', 'field' => '/claims/' + new_id}]
      data['records'] << copy
    end
  end

  def test_source_identity_and_independent_base_expectations
    data = evidence
    assert_equal Digest::SHA256.file(File.join(FIXTURES, 'source.json')).hexdigest, data['sources'].first.dig('content_hash', 'value')
    data['records'].each do |r|
      r['evidence'].each { |edge| assert_kind_of Hash, source_pointer(edge['field']) }
      r['times'].each_value { |time| assert_equal time['value'], source_pointer(time['field']) }
      r['attributes'].each_value do |attribute|
        next unless attribute.is_a?(Hash) && attribute['provenance']
        assert_equal attribute, source_pointer(attribute['provenance']['field'])
      end
    end
    read('expected.json')['cases'].each do |expected|
      kind = expected['id'].start_with?('whole') ? 'exact' : 'spki'
      target = expected['id'].end_with?('domains') ? 'domains' : 'servers'
      got = evaluate(target, data, query(kind))
      assert_equal 'complete', got['status']
      assert_equal expected['targets'], targets(got)
      assert_equal expected['certificates'], got['results'].map { |r| r['fields']['candidate_certificate'] }.sort
      assert_equal [expected['reason']], got['results'].map { |r| r['fields']['match_reason'] }.uniq
      got['results'].each do |r|
        assert_equal 'evidence_only', r['evidence_mode']
        assert_equal 'not_evaluated', r['assessment_acceptance']
      end
    end
  end

  def test_saved_certificate_and_spki_vectors_reproduced_independently
    vectors = read('certificates.json')['certificates']
    vectors.each do |v|
      der, error, status = Open3.capture3('openssl', 'x509', '-outform', 'DER', stdin_data: v['pem'])
      assert status.success?, error
      assert_equal Base64.strict_decode64(v['der_base64']), der.b
      assert_equal v['sha256'], Digest::SHA256.hexdigest(der)
      key, error, status = Open3.capture3('openssl', 'x509', '-pubkey', '-noout', stdin_data: v['pem'])
      assert status.success?, error
      spki, error, status = Open3.capture3('openssl', 'pkey', '-pubin', '-outform', 'DER', stdin_data: key)
      assert status.success?, error
      assert_equal v['spki_sha256'], Digest::SHA256.hexdigest(spki)
      assert_equal '/CN=beta.example.test/O=Synthetic Fixture', OpenSSL::X509::Certificate.new(der).subject.to_s
    end
    refute_equal vectors[0]['sha256'], vectors[1]['sha256']
    assert_equal vectors[0]['spki_sha256'], vectors[1]['spki_sha256']
    refute_equal vectors[0]['spki_sha256'], vectors[2]['spki_sha256']
  end

  def test_renewal_and_rekey_do_not_create_whole_certificate_fallback
    data = evidence
    remove(data, 'p1')
    empty(evaluate('domains', data), 'no_qualifying_result')
    got = evaluate('domains', data, query('spki'))
    assert_equal ['d2'], targets(got)
    assert_equal ['cert-2'], got['results'].map { |r| r['fields']['candidate_certificate'] }
  end

  def test_pem_rewrapping_and_exact_der_keep_whole_content_identity
    data = evidence
    value = record(data, 'cert-1')['attributes']['certificate_selector']
    v = read('certificates.json')['certificates'].first
    value['certificate_pem'] = "-----BEGIN CERTIFICATE-----\n" + v['der_base64'].scan(/.{1,37}/).join("\n") + "\n-----END CERTIFICATE-----\n"
    assert_equal ['d1'], targets(evaluate('domains', data))
    value.delete('certificate_pem')
    value['certificate_der_base64'] = v['der_base64']
    assert_equal ['d1'], targets(evaluate('domains', data))
  end

  def test_reported_hash_and_reproduced_bytes_retain_distinct_provenance
    data = evidence
    selector = record(data, 'cert-1')['attributes']['certificate_selector']
    derived = S.normalize(selector)
    selector.delete('certificate_pem')
    reported = S.normalize(selector)
    refute_equal derived, reported
    assert_equal ['d1'], targets(evaluate('domains', data))
    assert_equal 'reported', evaluate('domains', data)['results'].first['fields']['candidate_certificate_selector'].dig('provenance', 'basis')
  end

  def test_presented_material_cannot_borrow_a_different_certificate
    data = evidence
    record(data, 'p1')['attributes']['certificate_selector']['value'] = read('certificates.json')['certificates'][1]['sha256']
    empty(evaluate('domains', data))
    assert_equal ['d2'], targets(evaluate('domains', data, query('spki')))
    data = evidence
    record(data, 'p1')['subject'] = 'cert-2'
    empty(evaluate('domains', data))
  end

  def test_typed_values_in_the_wrong_named_fields_do_not_change_match_reason
    data = evidence
    # A complete valid certificate selector placed in a field named spki_selector
    # cannot select the SPKI branch or emit an SPKI-reuse reason.
    data['records'].select { |r| r['type'] == 'x509:cert' }.each do |r|
      r['attributes']['spki_selector'] = Marshal.load(Marshal.dump(r['attributes']['certificate_selector']))
    end
    got = evaluate('domains', data)
    assert_equal ['whole_certificate_identity'], got['results'].map { |r| r['fields']['match_reason'] }.uniq
    empty(evaluate('domains', data, query('spki')))
    # Both sides of a purported full-certificate witness carrying equal SPKI
    # values still do not establish which certificate was actually presented.
    data = evidence
    data['records'].select { |r| r['type'] == 'x509:cert' }.each do |r|
      r['attributes']['certificate_selector'] = Marshal.load(Marshal.dump(r['attributes']['spki_selector']))
    end
    data['records'].select { |r| r['type'] == 'network:certificate_presentation' }.each do |r|
      original = r['attributes']['certificate_selector']
      wrong = Marshal.load(Marshal.dump(record(data, r['subject'])['attributes']['spki_selector']))
      wrong['provenance'] = original['provenance']
      r['attributes']['certificate_selector'] = wrong
    end
    empty(evaluate('domains', data, query('spki')))
  end

  def test_dns_and_ipv4_target_types_cannot_be_carried_by_an_equal_wrong_selector_kind
    data = evidence
    record(data, 'd1')['attributes']['selector'] = Marshal.load(Marshal.dump(record(data, 'ip1')['attributes']['selector']))
    record(data, 'd1')['attributes']['selector']['provenance'] = {'source' => 'cert-source', 'record_id' => 'd1', 'source_revision' => 'fixture-r1', 'field' => '/claims/d1/selector', 'basis' => 'reported'}
    record(data, 'n1')['attributes']['name_selector'] = Marshal.load(Marshal.dump(record(data, 'p1')['attributes']['address_selector']))
    record(data, 'n1')['attributes']['name_selector']['provenance'] = {'source' => 'cert-source', 'record_id' => 'n1', 'source_revision' => 'fixture-r1', 'field' => '/claims/n1/name_selector', 'basis' => 'reported'}
    assert_equal ['ip1'], targets(evaluate('servers', data))
    data = evidence
    record(data, 'ip1')['attributes']['selector'] = Marshal.load(Marshal.dump(record(data, 'd1')['attributes']['selector']))
    record(data, 'ip1')['attributes']['selector']['provenance'] = {'source' => 'cert-source', 'record_id' => 'ip1', 'source_revision' => 'fixture-r1', 'field' => '/claims/ip1/selector', 'basis' => 'reported'}
    record(data, 'p1')['attributes']['address_selector'] = Marshal.load(Marshal.dump(record(data, 'n1')['attributes']['name_selector']))
    record(data, 'p1')['attributes']['address_selector']['provenance'] = {'source' => 'cert-source', 'record_id' => 'p1', 'source_revision' => 'fixture-r1', 'field' => '/claims/p1/address_selector', 'basis' => 'reported'}
    assert_equal ['d1'], targets(evaluate('servers', data))
  end

  def test_spki_only_presentation_report_is_unresolved_without_certificate_witness
    data = evidence
    record(data, 'p1')['attributes'].delete('certificate_selector')
    got = evaluate('domains', data, query('spki'))
    assert_equal ['d2'], targets(got)
    assert got['diagnostics'].any? { |d| d['status'] == 'unresolved' }
    remove(data, 'p2')
    empty(evaluate('domains', data, query('spki')), 'unresolved')
  end

  def test_name_only_has_explicit_separate_purpose_and_no_presentation
    data = evidence
    remove(data, 'p1', 'p2', 'p3')
    empty(evaluate('domains', data), 'unresolved')
    got = evaluate('domains', data, query('name'))
    assert_equal ['d-beta'], targets(got)
    assert_equal 'certificate_field_name_association', got['results'].first['fields']['claim']
    refute got['results'].first['fields'].key?('presentation')
    assert_equal 'subject_common_name', got['results'].first['fields']['field_kind']
    assert_equal 'reported_certificate_field', got['results'].first['fields']['association_basis']
    assert_raises(E::InvalidInput) { evaluate('servers', data, query('name')) }
  end

  def test_name_spki_links_keep_distinct_certificates_and_do_not_merge_shared_name
    q = query('name')
    q['parameters']['selector'] = query('spki')['parameters']['selector']
    got = evaluate('domains', evidence, q)
    assert_equal ['cert-1', 'cert-2'], got['results'].map { |r| r['fields']['candidate_certificate'] }.sort
    assert_equal ['d-beta', 'd-beta'], targets(got)
    assert_equal ['explicit_exact_spki_reuse'], got['results'].map { |r| r['fields']['match_reason'] }.uniq
  end

  def test_ct_named_precertificate_does_not_become_final_or_presentation
    data = evidence
    record(data, 'cert-1')['attributes']['artifact_role'] = 'precertificate'
    record(data, 'cn1')['attributes']['association_basis'] = 'ct_reported_certificate_field'
    remove(data, 'p1')
    got = evaluate('domains', data, query('name'))
    assert_equal ['d-beta'], targets(got)
    assert_equal 'precertificate', got['results'].first['fields']['artifact_role']
    empty(evaluate('domains', data))
  end

  def test_name_only_uses_own_assertion_and_receipt_knowledge
    q = query('name')
    q['knowledge_cutoff'] = cutoff('2026-09-16T04:00:00Z')
    assert_equal ['d-beta'], targets(evaluate('domains', evidence, q))
    q['knowledge_cutoff'] = cutoff('2026-09-16T02:00:00Z')
    empty(evaluate('domains', evidence, q))
    data = evidence
    remove(data, 'cnr1')
    assert_equal ['d-beta'], targets(evaluate('domains', data, query('name')))
    q['knowledge_cutoff'] = cutoff('2026-09-20T00:00:00Z')
    empty(evaluate('domains', data, q), 'unresolved')
  end

  def test_requested_name_is_not_certificate_cn_and_does_not_authenticate
    result = evaluate['results'].first['fields']
    assert_equal 'alpha.example.test', result['target_selector']['value']
    assert_equal 'beta.example.test', result['certificate_name_context']
    assert_equal 'requested_sni', result['domain_basis']
    assert_equal ['d1'], targets(evaluate)
    assert_equal ['d-beta'], targets(evaluate('domains', evidence, query('name')))
  end

  def test_ip_only_presentation_does_not_manufacture_fqdn
    data = evidence
    remove(data, 'n1')
    empty(evaluate('domains', data))
    assert_equal ['ip1'], targets(evaluate('servers', data))
    %w[certificate_san certificate_cn dns_resolution scan_plan].each do |basis|
      data = evidence
      record(data, 'n1')['attributes']['basis'] = basis
      assert_equal ['ip1'], targets(evaluate('servers', data))
    end
  end

  def test_concrete_dns_normalization_only_and_no_wildcard_expansion
    data = evidence
    record(data, 'n1')['attributes']['name_selector']['value'] = 'ALPHA.Example.Test.'
    assert_equal ['d1'], targets(evaluate('domains', data))
    %w[*.example.test 192.0.2.10].each do |value|
      data = evidence
      record(data, 'n1')['attributes']['name_selector']['value'] = value
      assert_raises(S::InvalidInput) { evaluate('domains', data) }
    end
    data = evidence
    record(data, 'cn1')['attributes']['field_kind'] = 'san_wildcard'
    empty(evaluate('domains', data, query('name')))
  end

  def test_service_occurrence_name_and_address_joins_do_not_use_later_dns
    [['n1', 'service_context_id', 'later-context'], ['n1', 'service_record', 's2'],
     ['s1', 'context_id', 'another-context']].each do |id, key, value|
      data = evidence
      record(data, id)['attributes'][key] = value
      empty(evaluate('domains', data))
    end
    data = evidence
    record(data, 'p1')['attributes']['address_selector']['value'] = '192.0.2.99'
    assert_equal ['d1'], targets(evaluate('servers', data))
    assert_nil evaluate('servers', data)['results'].first['fields']['observed_address']
    record(data, 'p1')['attributes']['address_selector']['value'] = '192.000.2.10'
    assert_raises(S::InvalidInput) { evaluate('servers', data) }
  end

  def test_missing_optional_vantage_protocol_port_address_keeps_supported_named_presentation
    data = evidence
    record(data, 'p1')['attributes'].delete('vantage')
    record(data, 'p1')['attributes'].delete('address_selector')
    %w[protocol port address_record].each { |key| record(data, 's1')['attributes'].delete(key) }
    got = evaluate('servers', data)
    assert_equal ['d1'], targets(got)
    %w[vantage protocol reported_port observed_address].each { |key| assert_nil got['results'].first['fields'][key] }
  end

  def test_leaf_chain_and_unknown_roles_remain_as_reported
    %w[leaf chain_member unknown].each do |role|
      data = evidence
      record(data, 'p1')['attributes']['certificate_role'] = role
      assert_equal role, evaluate('domains', data)['results'].first['fields']['certificate_role']
    end
    data = evidence
    record(data, 'p1')['attributes']['observed_state'] = 'planned'
    empty(evaluate('domains', data))
  end

  def test_presentation_time_is_not_validity_receipt_or_reprocessing_time
    assert_equal ['d1'], targets(evaluate) # September presentation before October notBefore remains evidence.
    data = evidence
    record(data, 'p1')['times']['occurred']['value'] = '2024-12-10T00:00:00Z'
    empty(evaluate('domains', data), 'outside_scope')
    q = query
    q['parameters']['period'] = {'start' => '2024-12-10', 'end' => '2024-12-10'}
    assert_equal ['d1'], targets(evaluate('domains', data, q))
    record(data, 'p1')['times']['occurred']['value'] = '2027-10-02T00:00:00Z'
    q['parameters']['period'] = {'start' => '2027-10-02', 'end' => '2027-10-02'}
    assert_equal ['d1'], targets(evaluate('domains', data, q)) # after expiry is still an observed presentation
  end

  def test_utc_midnight_boundaries_and_unknown_or_conflicting_dates
    data = evidence
    q = query
    q['parameters']['period'] = {'start' => '2026-09-17', 'end' => '2026-09-17'}
    %w[2026-09-17T00:00:00Z 2026-09-17T23:59:59Z].each do |date|
      record(data, 'p1')['times']['occurred']['value'] = date
      assert_equal ['d1'], targets(evaluate('domains', data, q))
    end
    record(data, 'p1')['times']['occurred']['value'] = '2026-09-18T00:00:00Z'
    empty(evaluate('domains', data, q), 'outside_scope')
    record(data, 'p1')['times'].delete('occurred')
    empty(evaluate('domains', data, q), 'unresolved')
    data = evidence
    time = record(data, 'p1')['times']['occurred']
    other = Marshal.load(Marshal.dump(time)); other['value'] = '2026-09-18T00:00:00Z'
    record(data, 'p1')['times']['occurred'] = {'alternatives' => [time, other]}
    empty(evaluate('domains', data, q), 'unresolved')
  end

  def test_as_known_is_separate_and_requires_actual_claim_receipts
    q = query
    q['knowledge_cutoff'] = cutoff('2026-09-17T13:01:00Z')
    assert_equal ['d1'], targets(evaluate('domains', evidence, q))
    q['knowledge_cutoff'] = cutoff('2026-09-17T12:30:00Z')
    empty(evaluate('domains', evidence, q))
    data = evidence
    remove(data, 'pr1')
    assert_equal ['d1'], targets(evaluate('domains', data))
    q['knowledge_cutoff'] = cutoff('2026-09-20T00:00:00Z')
    empty(evaluate('domains', data, q), 'unresolved')
    data = evidence
    record(data, 'pr1')['attributes']['collection_id'] = 'different-collection'
    empty(evaluate('domains', data, q), 'unresolved')
  end

  def test_material_can_be_known_before_use_but_future_event_cannot_be_known_early
    q = query
    q['knowledge_cutoff'] = cutoff('2026-09-17T13:01:00Z')
    assert_equal ['d1'], targets(evaluate('domains', evidence, q))
    data = evidence
    record(data, 'pe1')['times']['occurred']['value'] = '2026-09-16T00:00:00Z'
    record(data, 'pr1')['times']['received']['value'] = '2026-09-16T01:00:00Z'
    assert_equal ['d1'], targets(evaluate('domains', data))
    empty(evaluate('domains', data, q))
  end

  def test_selector_source_revision_field_and_carrier_cannot_be_borrowed
    [%w[source_revision wrong-r2], %w[record_id cert-2], %w[field /unrelated/selector]].each do |field, value|
      data = evidence
      record(data, 'p1')['attributes']['certificate_selector']['provenance'][field] = value
      empty(evaluate('domains', data), 'no_qualifying_result')
    end
    data = evidence
    record(data, 'cert-1')['attributes']['certificate_selector']['value'] = '0' * 64
    empty(evaluate('domains', data), 'unresolved') # conflicting reported digest vs preserved bytes is not silently repaired
  end

  def test_default_retains_class_context_and_exclusion_requires_explicit_selection
    fields = evaluate['results'].first['fields']
    assert_equal 'member', fields['source_class_membership']
    q = query('spki')
    q['parameters']['exclude_mass_managed_source_certificate'] = true
    got = evaluate('domains', evidence, q)
    empty(got, 'suppressed')
    assert got['diagnostics'].any? { |d| d['status'] == 'suppressed' && d['policies'].any? { |p| p['scope'] == 'source' } }
    # C2 is a different selected source; C1's whole-certificate membership must not transfer across SPKI.
    q['parameters']['source_certificate'] = 'cert-2'
    assert_equal ['d1', 'd2'], targets(evaluate('domains', evidence, q))
  end

  def test_opposing_or_unknown_source_class_is_not_a_forced_winner
    data = evidence
    opposition(data, 'class-c1-opposing')
    q = query
    q['parameters']['exclude_mass_managed_source_certificate'] = true
    got = evaluate('domains', data, q)
    assert_equal ['member', 'not_member'], got['results'].map { |r| r['fields']['source_class_membership'] }.sort
    assert got['results'].flat_map { |r| r['policy_evaluations'] }.any? { |p| p.dig('decision', 'status') == 'unresolved' }
    refute got['diagnostics'].any? { |d| d['status'] == 'suppressed' }
    data = evidence
    record(data, 'class-c1')['attributes']['membership'] = nil
    refute_empty evaluate('domains', data, q)['results']
  end

  def test_cdn_address_policy_is_occurrence_scoped_across_ip_and_named_forms
    q = query('spki')
    q['parameters']['exclude_cdn_address'] = true
    got = evaluate('servers', evidence, q)
    assert_equal ['d2', 'ip2'], targets(got)
    suppressed = got['diagnostics'].select { |d| d['status'] == 'suppressed' }
    refute_empty suppressed
    assert suppressed.all? { |d| d['policies'].any? { |p| p['scope'] == 'occurrence' } }
    data = evidence
    opposition(data, 'class-ip1-opposing')
    got = evaluate('servers', data, q)
    assert_includes targets(got), 'ip1'
    assert_includes targets(got), 'd1'
    assert got['results'].flat_map { |r| r['policy_evaluations'] }.any? { |p| p.dig('decision', 'status') == 'unresolved' }
  end

  def test_wrong_class_subject_cannot_supply_missing_occurrence_correspondence
    data = evidence
    record(data, 'class-ip1')['subject'] = 'ip2'
    q = query
    q['parameters']['exclude_cdn_address'] = true
    assert_equal ['d1', 'ip1'], targets(evaluate('servers', data, q))
    data = evidence
    record(data, 'class-c1')['attributes']['policy_basis'] = 'unresolved_time_basis'
    q = query
    q['parameters']['exclude_mass_managed_source_certificate'] = true
    assert_equal ['d1'], targets(evaluate('domains', data, q))
  end

  def test_query_errors_unsupported_kinds_and_partial_execution_are_distinct
    q = query
    q['parameters'].delete('period')
    assert_raises(E::InvalidInput) { evaluate('domains', evidence, q) }
    q = query
    q['parameters']['selector'] = read('evidence.json')['records'].find { |r| r['id'] == 'ip1' }['attributes']['selector']
    assert_raises(E::UnsupportedInput) { evaluate('domains', evidence, q) }
    q = query('spki')
    q['limits']['max_results'] = 1
    got = evaluate('servers', evidence, q)
    assert_equal 'partial', got['status']
    assert got['results'].length <= 1
    q = query
    q['parameters']['purpose'] = 'deployment'
    assert_raises(E::InvalidInput) { evaluate('domains', evidence, q) }
    q = query('name')
    q['parameters']['period'] = {'start' => '2026-09-17', 'end' => '2026-09-17'}
    assert_raises(E::InvalidInput) { evaluate('domains', evidence, q) }
  end

  def test_replay_preserves_occurrence_identity_and_does_not_refresh_date
    data = evidence
    add_presentation_copy(data, 'replay')
    got = evaluate('domains', data)
    assert_equal ['presentation-event-1'], got['results'].map { |r| r['fields']['occurrence_id'] }.uniq
    assert_equal 1, got['results'].map { |r| r['identity'] }.uniq.length
    q = query
    q['parameters']['period'] = {'start' => '2026-09-19', 'end' => '2026-09-19'}
    empty(evaluate('domains', data, q), 'outside_scope')
  end

  def test_later_actual_presentation_has_its_own_occurrence_and_date
    data = evidence
    add_presentation_copy(data, 'later')
    q = query
    q['parameters']['period'] = {'start' => '2026-09-19', 'end' => '2026-09-19'}
    got = evaluate('domains', data, q)
    assert_equal ['presentation-event-1-later'], got['results'].map { |r| r['fields']['occurrence_id'] }
    assert_equal ['d1'], targets(got)
    q['knowledge_cutoff'] = cutoff('2026-09-20T00:00:00Z')
    empty(evaluate('domains', data, q), 'unresolved') # the original event's receipts do not prove later event availability
  end
end
