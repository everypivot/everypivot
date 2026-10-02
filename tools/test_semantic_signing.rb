#!/usr/bin/env ruby
# frozen_string_literal: true
require 'minitest/autorun'
require_relative 'semantic_evaluator'
require_relative '../fixtures/semantic-families/signing/fixture_factory'

class SemanticSigningTest < Minitest::Test
  F = SigningFixtures
  E = EveryPivot::SemanticEvaluator
  C = EveryPivot::SemanticContract
  def get(d, id); F.get(d, id); end
  def evaluate(d, seal: false)
    F.seal(d) if seal
    E.new(d['contract']).evaluate(d['evidence'], d['query'], preserved_source_bytes: d['preserved_source_bytes'])
  end
  def ids(r); r['results'].map { |v| v['id'] }.uniq.sort; end
  def check(d, expected = ['artifact'])
    r = evaluate(d)
    assert_equal expected.sort, ids(r), [d['pattern'], d['query']['parameters'], r['diagnostics'].last(8)].inspect
    assert_equal 'complete', r['status']
    r['results'].each do |row|
      assert_equal 'evidence_only', row.dig('fields', 'claim_status')
      assert_equal 'match', row.dig('finding_evaluation', 'status')
      refute row.key?('accepted_assessment')
    end
    r
  end
  def set_earlier(d, at = '2024-12-21T00:00:00Z')
    d['evidence']['records'].each do |r|
      r['times'].each { |name, t| t['value'] = '2024-12-20T00:00:00Z' if %w[checked collection_available].include?(name) }
    end
    d['claims'].each { |c| c['at'] = at }
    F.seal(d)
  end
  def assert_none(d)
    r = evaluate(d, seal: true)
    assert_empty r['results'], r['diagnostics'].inspect
    r
  end
  def cutoff(d, value)
    d['query']['knowledge_cutoff'] = F.time(value, 'query-cutoff', 'query-cutoff', '/query/cutoff')
  end
  def class_record(d, id = 'class-member', membership = 'member', role: 'primary_signer', kind: 'certificate_sha256')
    selector = F.rehome(get(d, 'certificate')['attributes'][F::CERT_FIELDS.fetch(kind)], id, 'selector')
    record = F.rec(d, id, 'assertion', 'policy:signing_credential', {'selector' => selector, 'role' => role, 'class' => 'shared_signing_service',
      'basis' => 'named source report with explicit class basis', 'basis_mode' => 'selected_period_context_not_signing_time', 'revision' => 'class-r1', 'membership' => membership}, subject: 'certificate')
    record['times']['applicable'] = F.time('2026-09-01T00:00:00Z', 'certificate', id, '/records/' + id + '/applicable')
    record['times']['applicable'].delete('value')
    record['times']['applicable'].merge!('precision' => 'interval', 'interval_role' => 'validity', 'start' => '2026-09-01T00:00:00Z', 'end' => '2026-10-01T00:00:00Z', 'start_inclusive' => true, 'end_inclusive' => false)
    record
  end
  def enable_class(d, records)
    d['query']['parameters'].merge!('exclude_selected_credentials' => true, 'classification_records' => records,
      'classification_class' => 'shared_signing_service',
      'classification_revision' => 'class-r1', 'classification_period' => {'start' => '2026-09-01', 'end' => '2026-09-30'})
  end
  def amendment(d, id = 'withdrawal', operation = 'withdraw', target = 'association', replacement: nil, supersedes: [])
    attrs = {'operation' => operation, 'assertion_namespace' => 'synthetic-signing-reports',
      'issuer_source_id' => 'report', 'supersedes_amendments' => supersedes}
    a = F.rec(d, id, 'assertion', 'evidence:assertion_amendment', attrs, subject: target, object: replacement, available: '2026-09-21T00:00:00Z')
    a['times']['published'] = F.time('2026-09-20T00:00:00Z', id, id, '/records/' + id + '/published')
    receipt = F.rec(d, id + '-received', 'occurrence', 'evidence:claim_receipt', {'collection_id' => 'signing-fixture-collection'}, subject: id, available: nil)
    receipt['times']['received'] = F.time('2026-09-21T00:00:00Z', id, receipt['id'], '/records/' + receipt['id'] + '/received')
    a
  end

  def test_five_contracts_compile_and_source_reported_findings_execute
    F::IDS.each do |id|
      d = F.build(id)
      assert_empty C.validate(d['contract'])
      r = check(d, id == 'SUPPLY_CODESIGN_CERT_TO_PACKAGES' ? ['package'] : ['artifact'])
      assert_equal 'source_reported_scoped_check', r['results'][0].dig('fields', 'verification_report', 'basis')
      assert_equal '2024-12-15T00:00:00Z', get(d, 'sighting').dig('times', 'observed', 'value')
    end
  end
  def test_ten_independent_saved_cases_and_preserved_report_hashes
    root = File.expand_path('../fixtures/semantic-families/signing', __dir__)
    cases = Dir[File.join(root, 'cases/*.json')]
    assert_equal 10, cases.length
    cases.each do |path|
      d = JSON.parse(File.read(path))
      d['contract'] = JSON.parse(File.read(File.expand_path(d.delete('contract_path'), root)))
      d['preserved_source_bytes'].each do |id, bytes|
        source = d['evidence']['sources'].find { |s| s['id'] == id }
        assert_equal source.dig('content_hash', 'value'), Digest::SHA256.hexdigest(bytes)
      end
      check(d, d.delete('expected_result_ids'))
    end
  end
  def test_all_five_presence_and_scoped_verified_purposes_are_distinct
    F::IDS.each do |id|
      %w[certificate_presence scoped_verified_signature].each do |purpose|
        d = F.build(id, purpose: purpose)
        r = check(d, id == 'SUPPLY_CODESIGN_CERT_TO_PACKAGES' ? ['package'] : ['artifact'])
        assert_equal purpose, r['results'][0].dig('fields', 'purpose')
        if purpose == 'certificate_presence'
          assert_nil r['results'][0].dig('fields', 'verification_scope')
        else
          assert_equal 'source_reported_scoped_check_no_local_reproduction', r['results'][0].dig('fields', 'verification_scope')
        end
      end
    end
  end
  def test_container_presence_cannot_become_reported_or_verified_signing
    d = F.build(purpose: 'certificate_presence')
    d['query']['parameters']['purpose'] = 'reported_signer'
    assert_none(d)
    d['query']['parameters']['purpose'] = 'scoped_verified_signature'
    assert_none(d)
  end
  def test_apk_findings_require_the_particular_artifacts_reported_apk_format
    %w[certificate_presence reported_signer scoped_verified_signature].each do |purpose|
      d = F.build('CTI_APK_SIGNING_CERT_CLUSTER', purpose: purpose)
      get(d, 'artifact')['attributes']['format'] = 'pe'
      assert_none(d)
    end
  end
  def test_chain_member_and_unknown_roles_remain_presence_only
    %w[chain_member other unknown].each do |role|
      d = F.build(purpose: 'certificate_presence', role: role)
      assert_equal role, check(d)['results'][0].dig('fields', 'signature_role')
      d['query']['parameters']['role'] = 'primary_signer'
      assert_none(d)
    end
  end
  def test_timestamp_signer_inquiry_is_explicit_and_not_primary_signer
    d = F.build(role: 'timestamp')
    check(d)
    d['query']['parameters']['role'] = 'primary_signer'
    assert_none(d)
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'signature_material', role: 'timestamp')
    check(d)
    d['query']['parameters']['role'] = 'primary_signer'
    assert_none(d)
  end
  def test_verification_requires_all_exact_bindings_and_actual_check_scope
    %w[artifact_identity signature_selector certificate_selector spki_selector covered_content].each do |field|
      d = F.build(purpose: 'scoped_verified_signature')
      get(d, 'verification')['attributes'][field]['value'] = '0' * 64
      assert_none(d)
    end
    %w[scheme format role].each do |field|
      d = F.build(purpose: 'scoped_verified_signature')
      get(d, 'verification')['attributes'][field] = 'incompatible'
      assert_none(d)
    end
    %w[verifier method method_version limitations report_location].each do |field|
      d = F.build(purpose: 'scoped_verified_signature')
      get(d, 'verification')['attributes'].delete(field)
      assert_equal 'unresolved', assert_none(d)['outcome']
    end
  end
  def test_failed_unsupported_incomplete_and_absent_checks_do_not_erase_reported_link
    %w[failed unsupported unavailable incomplete malformed].each do |state|
      d = F.build
      get(d, 'verification')['attributes']['check_status'] = state
      r = evaluate(d, seal: true)
      assert_equal ['artifact'], ids(r)
      assert_equal state, r['results'][0].dig('fields', 'verification_report', 'check_status')
      d['query']['parameters']['purpose'] = 'scoped_verified_signature'
      assert_none(d)
    end
    d = F.build
    d['evidence']['records'].reject! { |r| r['id'] == 'verification' }
    assert_equal ['artifact'], ids(evaluate(d, seal: true))
  end
  def test_bare_signed_flag_does_not_supply_missing_signature_or_signer
    d = F.build
    get(d, 'artifact')['attributes']['signed'] = true
    d['evidence']['records'].reject! { |r| r['id'] == 'signer' }
    assert_none(d)
  end
  def test_verification_time_is_not_signing_time_or_new_contextual_sighting
    d = F.build(purpose: 'scoped_verified_signature')
    before = F.deep(d['evidence'])
    r = check(d)
    assert_equal before, d['evidence']
    assert_equal '2026-09-11T00:00:00Z', r['results'][0].dig('finding_evaluation', 'first_scoped_time', 'value')
    refute r['results'][0]['fields'].key?('signing_time')
    get(d, 'verification')['times']['checked']['value'] = '2026-09-12T00:00:00Z'
    assert_none(d) # cannot report a completed check as available before it happened
  end
  def test_exact_certificate_and_public_key_branches_do_not_merge_renewals
    %w[certificate_sha256 spki_sha256].each do |kind|
      d = F.build(kind: kind)
      # Same public key, different certificate serial and DER identity.
      cert = get(d, 'certificate')
      F::CERT_FIELDS.each { |k, field| cert['attributes'][field] = F.cert_selector(k, 'certificate', field, 1) }
      %w[signer verification].each do |id|
        get(d, id)['attributes']['certificate_selector'] = F.cert_selector('certificate_sha256', id, 'certificate_selector', 1)
      end
      if kind == 'certificate_sha256'
        assert_none(d)
      else
        d['claims'][0]['identity'][2] = F.typed_identity(cert['attributes']['certificate_selector'])
        assert_equal ['artifact'], ids(evaluate(d, seal: true))
      end
    end
  end
  def test_rekey_and_issuer_namespace_do_not_silently_fallback
    d = F.build(kind: 'spki_sha256')
    get(d, 'certificate')['attributes']['spki_selector'] = F.cert_selector('spki_sha256', 'certificate', 'spki_selector', 2)
    assert_none(d)
    d = F.build('CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT')
    get(d, 'certificate')['attributes']['issuer_serial_selector']['issuer_namespace']['kind'] = 'authority_id'
    assert_equal 'unresolved', assert_none(d)['outcome']
    d = F.build('CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT')
    d['query']['parameters']['certificate_selector'] = F.cert_selector('certificate_sha256', 'seed', 'certificate_selector')
    assert_raises(E::UnsupportedInput) { evaluate(d) }
  end
  def test_declared_kind_guards_prevent_field_label_conflation
    d = F.build(kind: 'spki_sha256')
    get(d, 'certificate')['attributes']['spki_selector'] = F.rehome(get(d, 'certificate')['attributes']['certificate_selector'], 'certificate', 'spki_selector')
    assert_none(d)
    d = F.build(purpose: 'scoped_verified_signature')
    get(d, 'verification')['attributes']['artifact_identity'] = F.rehome(get(d, 'verification')['attributes']['covered_content'], 'verification', 'artifact_identity')
    assert_none(d)
  end
  def test_source_field_revision_and_carrier_mismatch_do_not_qualify
    %w[source_revision record_id field].each do |key|
      d = F.build
      get(d, 'signer')['attributes']['certificate_selector']['provenance'][key] = 'wrong'
      assert_none(d)
    end
  end
  def test_replayed_old_findings_do_not_reenter_case_period
    F::IDS.each do |id|
      d = set_earlier(F.build(id))
      replay = F.deep(d['claims'][0]); replay['event'] = 'reprocessed'; replay['at'] = '2026-09-12T00:00:00Z'; d['claims'] << replay
      get(d, 'association')['attributes']['method_version'] = 'new-tool-version'
      r = assert_none(d)
      assert r['diagnostics'].any? { |v| v['status'] == 'outside_scope' }
    end
  end
  def test_actual_establishment_not_max_component_time_or_unknown_history
    d = F.build
    d['claims'].clear
    assert_equal 'unresolved', assert_none(d)['outcome']
    d = F.build
    assert_equal 'unresolved', evaluate(F.seal(d, 'unknown'))['outcome']
    d = F.build
    d['preserved_source_bytes'].delete('manifest')
    assert_equal 'unresolved', evaluate(d)['outcome']
  end
  def test_explicit_case_period_and_boundaries_have_no_3650_day_default
    d = F.build
    d['query']['parameters'].delete('period')
    assert_raises(E::InvalidInput) { evaluate(d) }
    d = F.build
    d['query']['parameters']['period'] = {'start' => '2026-09-11', 'end' => '2026-09-11'}
    check(d)
    d['claims'][0]['at'] = '2026-09-10T23:59:59Z'
    assert_none(d)
  end
  def test_package_requires_specific_artifact_version_namespace_and_variant
    d = F.build('SUPPLY_CODESIGN_CERT_TO_PACKAGES')
    r = check(d, ['package'])
    assert_equal '2026-09-15T12:00:00Z', r['results'][0].dig('finding_evaluation', 'first_scoped_time', 'value')
    %w[variant artifact_identity source_location].each do |field|
      copy = F.deep(d); get(copy, 'package_link')['attributes'].delete(field); assert_none(copy)
    end
    get(d, 'package_link')['attributes']['artifact_identity']['value'] = 'f' * 64
    assert_none(d)
  end
  def test_package_presence_is_labelled_presence_and_never_whole_product_signing
    d = F.build('SUPPLY_CODESIGN_CERT_TO_PACKAGES', purpose: 'certificate_presence')
    r = check(d, ['package'])
    assert_equal 'certificate_presence', r['results'][0].dig('fields', 'purpose')
    assert_equal 'windows-x64-installer', r['results'][0].dig('fields', 'package_binding', 'variant')
    refute r['results'][0]['fields'].key?('signed_product')
  end
  def test_detached_catalog_and_manifest_correspondence_retain_covered_object_scope
    %w[detached_signature_exact_artifact catalog_member_covered_digest manifest_member_covered_digest].each do |scope|
      d = F.build('SUPPLY_CODESIGN_CERT_TO_PACKAGES')
      get(d, 'association')['attributes']['correspondence'] = scope
      get(d, 'association')['attributes']['covered_object'] = 'exact referenced member digest, no individual-signature inference'
      d['claims'][0]['identity'][8] = scope
      d['claims'][0]['identity'][9] = get(d, 'association')['attributes']['covered_object']
      r = evaluate(d, seal: true)
      assert_equal ['package'], ids(r), r['diagnostics'].inspect
      assert_equal scope, r['results'][0].dig('fields', 'relationship_report', 'correspondence')
    end
  end
  def test_authenticode_image_digest_is_independent_of_signing_and_whole_file_identity
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content')
    r = check(d)
    refute r['results'][0]['fields'].key?('certificate_identity')
    refute r['results'][0]['fields'].key?('signature_role')
    get(d, 'artifact')['attributes']['signature_inspection'] = {'result' => 'failed', 'scope' => 'embedded signature only'}
    assert_equal ['artifact'], ids(evaluate(d, seal: true))
    get(d, 'analysis')['attributes']['input_status'] = 'malformed_image_scope_unknown'
    assert_none(d)
  end
  def test_unknown_embedded_signature_does_not_become_unsigned_or_detached_absence
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content')
    get(d, 'artifact')['attributes']['signature_inspection'] = {'result' => 'no_embedded_signature', 'scope' => 'embedded_only'}
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    refute r['results'][0]['fields'].key?('unsigned')
  end
  def test_authenticode_selector_purpose_and_kind_are_eagerly_checked
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content')
    d['query']['parameters']['material_selector'] = F.material('input')
    assert_raises(E::InvalidInput) { evaluate(d) }
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content')
    d['query']['parameters']['image_selector'] = F.artifact_identity('input')
    assert_raises(E::UnsupportedInput) { evaluate(d) }
  end
  def test_current_credential_context_retained_by_default_and_selected_policy_suppresses
    d = F.build
    class_record(d)
    assert_equal ['artifact'], ids(evaluate(d, seal: true))
    enable_class(d, ['class-member'])
    assert_equal 'suppressed', assert_none(d)['outcome']
  end
  def test_conflicting_classification_is_retained_without_a_winner
    d = F.build
    class_record(d); class_record(d, 'class-opposed', 'not_member'); enable_class(d, %w[class-member class-opposed])
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    assert r['results'].all? { |row| row['policy_evaluations'].any? { |p| p.dig('decision', 'reason').include?('conflict') } }
  end
  def test_explicit_contested_classification_alone_blocks_a_false_clearance
    d = F.build
    class_record(d, 'class-allow', 'not_member'); class_record(d, 'class-contested', 'contested')
    enable_class(d, %w[class-allow class-contested])
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    assert r['results'].all? { |row| row['policy_evaluations'].any? { |p| p.dig('decision', 'status') == 'unresolved' } }
    assert_equal 'qualified_evidence_with_gaps', r['outcome']
  end
  def test_unknown_classification_and_wrong_role_do_not_supply_exclusion_or_clearance
    d = F.build
    class_record(d, 'timestamp-class', 'member', role: 'timestamp'); enable_class(d, ['timestamp-class'])
    assert_equal ['artifact'], ids(evaluate(d, seal: true))
    d = F.build
    class_record(d); enable_class(d, ['class-member']); get(d, 'class-member')['attributes'].delete('basis')
    assert_equal ['artifact'], ids(evaluate(d, seal: true))
  end
  def test_signer_class_filter_cannot_erase_independent_image_findings
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content')
    # No certificate, classification, or role is manufactured for the image branch.
    enable_class(d, ['history'])
    check(d)
  end
  def test_supported_historical_evidence_outside_certificate_validity_is_retained
    d = F.build
    get(d, 'certificate')['attributes']['declared_validity'] = {'not_before' => '2026-10-01', 'not_after' => '2027-10-01'}
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    refute r['results'][0]['fields'].key?('valid_at_signing')
  end
  def test_historical_knowledge_does_not_backdate_finding_to_capture
    d = F.build
    cutoff(d, '2024-12-31T23:59:59Z')
    assert_none(d)
    cutoff(d, '2026-09-11T00:00:00Z')
    assert_equal ['artifact'], ids(evaluate(d, seal: true))
  end
  def test_partial_search_cannot_establish_newest_or_first_finding
    d = F.build
    d['query']['limits']['max_bindings'] = 1
    r = evaluate(d)
    assert_equal 'partial', r['status']
    assert_empty r['results']
  end

  def test_unselected_purposes_with_absent_record_types_do_not_create_false_gaps
    %w[image_content signature_material reported_signer certificate_presence].each do |purpose|
      d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: purpose)
      r = check(d)
      assert_equal 'qualified_evidence', r['outcome']
      assert r['diagnostics'].all? { |x| x['branch'].start_with?(purpose + '_') }
    end
  end
  def test_historical_artifact_references_qualify_without_becoming_recent
    %w[image_content signature_material certificate_presence reported_signer scoped_verified_signature].each do |purpose|
      d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: purpose, reference: true)
      r = check(d)
      row = r['results'][0]
      assert_equal '2026-09-11T00:00:00Z', row.dig('finding_evaluation', 'first_scoped_time', 'value')
      assert row['reference_support'].any? { |v| v['record_id'].start_with?('reference_') }, row['reference_support'].inspect
      assert r['diagnostics'].any? { |v| v['status'] == 'outside_scope' && v.dig('finding_evaluation', 'first_scoped_time', 'value') == '2024-12-21T00:00:00Z' }
    end
  end
  def test_later_reference_arrival_never_renews_candidate_or_backdates_reference_knowledge
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content', reference: true)
    original = check(d)['results'][0].dig('finding_evaluation', 'claim_key')
    get(d, 'reference_analysis')['times']['collection_available']['value'] = '2026-09-21T00:00:00Z'
    d['claims'][1]['at'] = '2026-09-21T12:00:00Z'
    # The separately evidenced reference can change; candidate availability remains Sep 11.
    r = evaluate(d, seal: true)
    candidate = r['results'].find { |row| row['id'] == 'artifact' }
    assert_equal original, candidate.dig('finding_evaluation', 'claim_key')
    assert_equal '2026-09-11T00:00:00Z', candidate.dig('finding_evaluation', 'first_scoped_time', 'value')
    cutoff(d, '2026-09-18T00:00:00Z')
    assert_empty evaluate(d)['results']
    d['query'].delete('knowledge_cutoff')
    d['query']['parameters']['period'] = {'start' => '2026-09-20', 'end' => '2026-09-30'}
    refute ids(evaluate(d)).include?('artifact')
  end
  def test_wrong_or_missing_reference_join_cannot_be_repaired_by_candidate_match
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content', reference: true)
    get(d, 'reference_analysis')['attributes']['artifact_identity']['value'] = '0' * 64
    assert_none(d)
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content', reference: true)
    get(d, 'reference_analysis')['times'].delete('collection_available')
    cutoff(d, '2026-09-18T00:00:00Z')
    assert_equal 'unresolved', assert_none(d)['outcome']
  end
  def test_changed_artifact_bytes_cannot_inherit_the_predecessor_finding_or_capture
    d = F.build
    get(d, 'artifact')['attributes']['identity'] = F.artifact_identity('artifact', 'changed signed derivative bytes')
    assert_none(d) # old attachment identity cannot follow changed bytes
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content')
    before = F.deep(d['claims'][0]['identity'])
    new_identity = F.artifact_identity('artifact', 'same image scope but different certificate table')
    get(d, 'artifact')['attributes']['identity'] = new_identity
    get(d, 'analysis')['attributes']['artifact_identity'] = F.rehome(new_identity, 'analysis', 'artifact_identity')
    assert_equal 'unresolved', assert_none(d)['outcome'] # no establishment for the different whole file
    d['claims'][0]['identity'][1] = F.typed_identity(new_identity)
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    assert_equal before[2], r['results'][0]['identity'][2] # same image digest does not collapse full files
    refute_equal before[1], r['results'][0]['identity'][1]
  end
  def test_material_scope_recipe_and_report_provenance_cannot_be_silently_repaired
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'signature_material')
    get(d, 'analysis')['attributes']['selector']['scope'] = 'different_selected_blob'
    assert_equal 'unresolved', assert_none(d)['outcome']
    d = F.build
    get(d, 'association')['attributes']['covered_content']['provenance']['source_revision'] = 'not-this-revision'
    assert_none(d)
  end
  def test_utc_equal_check_and_receipt_are_valid_but_missing_binding_is_not
    d = F.build(purpose: 'scoped_verified_signature')
    get(d, 'verification')['times']['checked']['value'] = '2026-09-10T00:00:00Z'
    assert_equal ['artifact'], ids(evaluate(d, seal: true))
    get(d, 'verification')['times']['checked']['binding']['object'] = 'certificate'
    assert_none(d)
  end
  def test_absent_pem_bytes_are_reported_and_present_bytes_can_reproduce_the_same_identity
    d = F.build
    selector = get(d, 'certificate')['attributes']['certificate_selector']
    assert_equal false, EveryPivot::SemanticIdentity.normalize(selector)['locally_reproduced']
    selector['certificate_pem'] = F.vector['pem']
    assert_equal true, EveryPivot::SemanticIdentity.normalize(selector)['locally_reproduced']
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    refute r['results'][0]['fields'].key?('locally_verified_signature')
  end
  def test_different_credential_classes_are_not_opposing_assertions
    d = F.build
    class_record(d); class_record(d, 'not-a-debug-key', 'not_member')
    get(d, 'not-a-debug-key')['attributes']['class'] = 'debug_signing_credential'
    enable_class(d, %w[class-member not-a-debug-key])
    assert_equal 'suppressed', assert_none(d)['outcome']
    d['query']['parameters']['classification_class'] = 'debug_signing_credential'
    assert_equal ['artifact'], ids(evaluate(d))
  end
  def test_exclusion_needs_an_explicit_class_scope_even_when_no_result_exists
    d = F.build
    enable_class(d, ['history'])
    d['query']['parameters'].delete('classification_class')
    assert_raises(E::InvalidInput) { evaluate(d) }
  end
  def test_withdrawal_attaches_historical_status_without_renewing_first_finding
    F::IDS.each do |id|
      d = F.build(id)
      before = evaluate(d)['results'][0]['finding_evaluation']
      amendment(d)
      r = evaluate(d, seal: true)
      assert_equal id == 'SUPPLY_CODESIGN_CERT_TO_PACKAGES' ? ['package'] : ['artifact'], ids(r)
      row = r['results'][0]
      assert_equal before['first_scoped_time'], row.dig('finding_evaluation', 'first_scoped_time')
      assert_equal before['claim_key'], row.dig('finding_evaluation', 'claim_key')
      assert_equal 'no_match', row.dig('amendment_evaluation', 'support_status')
      assert row.dig('amendment_evaluation', 'states').any? { |s| s['state'] == 'withdrawn' }
    end
  end
  def test_correction_reports_do_not_replace_history_with_a_maintained_claim
    d = F.build
    old = get(d, 'association')
    replacement = F.rec(d, 'replacement', 'assertion', old['type'], old['attributes'], subject: old['subject'], object: old['object'], available: '2026-09-21T00:00:00Z')
    replacement['attributes']['artifact_identity'] = F.artifact_identity('replacement', 'corrected different artifact', 'artifact_identity')
    amendment(d, 'correction', 'correct', 'association', replacement: 'replacement')
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    assert_equal '2026-09-11T00:00:00Z', r['results'][0].dig('finding_evaluation', 'first_scoped_time', 'value')
    state = r['results'][0].dig('amendment_evaluation', 'states').find { |s| s['assertion_id'] == 'association' }
    assert_equal 'corrected', state['state']
    assert_includes state['replacement_assertion_ids'], 'replacement'
  end
  def test_later_amendment_retained_separately_under_historical_knowledge
    d = F.build
    amendment(d)
    cutoff(d, '2026-09-18T00:00:00Z')
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    state = r['results'][0].dig('amendment_evaluation', 'states').find { |s| s['assertion_id'] == 'association' }
    assert_equal 'reported_in_supplied_scope', state['state']
    refute_empty state['later_context']
    cutoff(d, '2026-09-22T00:00:00Z')
    r = evaluate(d)
    assert_equal ['artifact'], ids(r)
    assert r['results'][0].dig('amendment_evaluation', 'states').any? { |s| s['state'] == 'withdrawn' }
  end
  def test_unknown_amendment_availability_is_not_absence_and_conflicts_have_no_winner
    d = F.build
    amendment(d); get(d, 'withdrawal-received')['times'].delete('received')
    cutoff(d, '2026-09-22T00:00:00Z')
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    assert_equal true, r['results'][0].dig('amendment_evaluation', 'has_gaps')
    d = F.build
    amendment(d); amendment(d, 'disputed', 'dispute')
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    assert_equal true, r['results'][0].dig('amendment_evaluation', 'has_gaps')
  end
  def test_authenticode_reference_amendment_is_context_not_candidate_novelty
    d = F.build('CTI_AUTHENTICODE_HASH_CLUSTER', purpose: 'image_content', reference: true)
    amendment(d, 'reference-withdrawal', 'withdraw', 'reference_analysis')
    r = evaluate(d, seal: true)
    assert_equal ['artifact'], ids(r)
    row = r['results'][0]
    assert_equal '2026-09-11T00:00:00Z', row.dig('finding_evaluation', 'first_scoped_time', 'value')
    assert row.dig('amendment_evaluation', 'states').any? { |s| s['assertion_id'] == 'reference_analysis' && s['state'] == 'withdrawn' }
  end
end
