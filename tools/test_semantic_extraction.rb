#!/usr/bin/env ruby
# frozen_string_literal: true
require 'minitest/autorun'
require_relative 'semantic_evaluator'
require_relative '../fixtures/semantic-families/extraction/fixture_factory'

class SemanticExtractionTest < Minitest::Test
  F = ExtractionFixtures
  E = EveryPivot::SemanticEvaluator
  C = EveryPivot::SemanticContract
  def evaluate(data)
    E.new(data.fetch('contract')).evaluate(data.fetch('evidence'), data.fetch('query'),
      preserved_source_bytes: data.fetch('preserved_source_bytes'))
  end
  def ids(result); result['results'].map { |r| r['id'] }.uniq.sort; end
  def get(data, id); F.get(data, id); end
  def remove_control(data, policy)
    data['evidence']['records'].reject! { |r| r['type'].start_with?('policy:') && r.dig('attributes', 'policy') == policy }
  end
  def run_fixture(data); evaluate(F.seal(data)); end
  def assert_claims(data, expected)
    answer = evaluate(data)
    assert_equal expected.sort, ids(answer), [data['pattern'], answer['diagnostics']].inspect
    assert_equal 'complete', answer['status']
    answer['results'].each do |row|
      assert_equal 'evidence_only', row.dig('fields', 'claim_status')
      assert_equal 'match', row.dig('finding_evaluation', 'status')
      refute row.key?('accepted_assessment')
    end
    answer
  end

  def test_eleven_independent_static_fixtures_execute_with_explicit_expected_outputs
    root = File.expand_path('../fixtures/semantic-families/extraction', __dir__)
    files = Dir[File.join(root, 'cases/*.json')]
    assert_equal 11, files.length
    files.each do |path|
      data = JSON.parse(File.read(path))
      data['contract'] = JSON.parse(File.read(File.expand_path(data.delete('contract_path'), root)))
      assert_empty C.validate(data['contract'])
      assert_claims(data, data.delete('expected_result_ids'))
    end
  end

  def test_all_cluster_families_retain_old_sighting_and_allow_new_complete_finding
    F::CLUSTERS.keys.each do |id|
      data = F.cluster(id)
      before = F.deep(data['evidence'])
      answer = assert_claims(data, ['input'])
      assert_equal '2026-09-11T00:00:00Z', answer['results'][0].dig('finding_evaluation', 'first_scoped_time', 'value')
      assert_equal before, data['evidence']
      assert_equal '2024-12-15T00:00:00Z', get(data, 'historical-sighting').dig('times', 'observed', 'value')
      # Even a later global seed discovery is not extraction from this artifact.
      get(data, 'seed')['attributes']['global_discovered'] = '2026-09-14T00:00:00Z'
      assert_equal ['input'], ids(run_fixture(data))
    end
  end

  def test_replayed_old_complete_finding_does_not_reenter_any_family_window
    F.all.each do |id, data|
      data['evidence']['records'].each do |record|
        record['times'].each do |name, t|
          t['value'] = '2024-12-20T00:00:00Z' if %w[collection_available occurred].include?(name)
        end
      end
      data['claims'].each { |claim| claim['at'] = '2024-12-21T00:00:00Z' }
      replay = F.deep(data['claims'][0])
      replay['event'], replay['at'] = 'replay-established', '2026-09-12T00:00:00Z'
      data['claims'] << replay
      get(data, 'extraction')['attributes']['run_id'] = 'new-lab-run-does-not-make-a-new-finding'
      answer = run_fixture(data)
      assert_empty answer['results'], id
      assert answer['diagnostics'].any? { |d| d['status'] == 'outside_scope' }, id
    end
  end

  def test_window_boundaries_are_calendar_dates_and_not_refreshed_receipt
    data = F.email_urls
    data['claims'][0]['at'] = '2026-09-07T00:00:00Z'
    data['evidence']['records'].each do |r|
      r['times'].each { |name, t| t['value'] = '2026-09-06T00:00:00Z' if %w[occurred collection_available].include?(name) }
    end
    assert_equal ['url'], ids(run_fixture(data)) # query date minus seven days is inclusive
    data['claims'][0]['at'] = '2026-09-06T23:59:59Z'
    assert_empty run_fixture(data)['results']
  end

  def test_missing_preserved_bytes_and_unknown_history_are_unresolved_not_no_match
    data = F.cluster('CTI_FILE_SOURCE_PATH_CLUSTER')
    data['preserved_source_bytes'].delete('bytes-input')
    assert_equal 'unresolved', evaluate(data)['outcome']
    data = F.cluster('CTI_FILE_SOURCE_PATH_CLUSTER')
    assert_equal 'unresolved', evaluate(F.seal(data, 'unknown'))['outcome']
    data = F.cluster('CTI_FILE_SOURCE_PATH_CLUSTER')
    data['preserved_source_bytes']['bytes-input'] += 'tampered'
    assert_raises(E::InvalidInput) { evaluate(data) }
  end

  def test_decompiler_labels_do_not_become_recovered_function_names
    data = F.cluster('CTI_SAMPLE_FUNCTION_NAME_CLUSTER')
    get(data, 'extraction')['attributes']['symbol_origin'] = 'decompiler_inferred_label'
    answer = run_fixture(data)
    assert_empty answer['results']
    assert_equal 'no_qualifying_result', answer['outcome']
  end

  def test_debug_symbol_recovery_needs_exact_supporting_material_and_correspondence
    data = F.cluster('CTI_SAMPLE_FUNCTION_NAME_CLUSTER')
    get(data, 'extraction')['attributes']['symbol_origin'] = 'debug_symbol'
    get(data, 'extraction')['attributes']['symbol_association'] = 'symbols-for-file'
    assert_empty run_fixture(data)['results']
    F.artifact(data, 'symbols', 'evidence:debug_symbols', 'preserved supporting debug symbol bytes')
    F.rec(data, 'symbols-for-file', 'assertion', 'debug:artifact_symbols',
      {'artifact_sha256' => F.hash_of(data, 'input'), 'symbol_sha256' => F.hash_of(data, 'symbols'), 'correspondence_method' => 'exact-build-identity'},
      subject: 'input', object: 'symbols')
    data['claims'][0]['support'] += %w[symbols-for-file symbols]
    assert_equal ['input'], ids(run_fixture(data))
    get(data, 'symbols-for-file')['attributes']['artifact_sha256'] = 'a' * 64
    assert_empty run_fixture(data)['results']
  end

  def test_resource_hash_must_be_exact_retained_section_bytes
    data = F.cluster('CTI_SAMPLE_RESOURCE_SECTION_HASH_CLUSTER')
    %w[seed extraction output].each { |name| get(data, name)['attributes']['selector']['value'] = 'a' * 64 }
    assert_empty run_fixture(data)['results']
    data = F.cluster('CTI_SAMPLE_UNIQUE_STRING_CLUSTER')
    get(data, 'extraction')['attributes']['selector']['representation'] = 'utf16_decoded'
    assert_empty run_fixture(data)['results'] # no unimplemented cross-representation fallback
  end

  def test_exact_email_capture_and_field_occurrence_are_required
    data = F.cluster('CTI_EMAIL_HEADER_VALUE_CLUSTER')
    get(data, 'input')['attributes'].delete('capture_id')
    assert_equal 'unresolved', run_fixture(data)['outcome']
    data = F.cluster('CTI_EMAIL_MESSAGE_ID_HOST_CLUSTER')
    get(data, 'extraction')['attributes']['field_name'] = 'From'
    assert_empty run_fixture(data)['results']
    data = F.cluster('CTI_EMAIL_HEADER_VALUE_CLUSTER')
    get(data, 'input')['attributes']['capture_kind'] = 'gateway_modified'
    assert_equal ['input'], ids(run_fixture(data)) # actual saved variant remains valid
    get(data, 'extraction')['attributes']['field_name'] = 'Different-Header'
    assert_empty run_fixture(data)['results'] # equal text does not supply the selected header role
  end

  def test_ocr_image_survives_missing_or_wrong_page_association
    assert_claims(F.ocr, ['input'])
    data = F.ocr(page: true)
    answer = assert_claims(data, %w[input url])
    findings = answer['results'].map { |r| [r['id'], r.dig('finding_evaluation', 'first_scoped_time', 'value')] }.to_h
    assert_equal '2026-09-11T00:00:00Z', findings['input']
    assert_equal '2026-09-12T00:00:00Z', findings['url']
    get(data, 'association')['attributes']['page_capture_id'] = 'different-capture-at-same-url'
    assert_equal ['input'], ids(run_fixture(data))
    assert_equal 'crop', get(data, 'input')['attributes']['image_role'] # crop is not silently replaced by parent
  end

  def test_generic_uri_and_url_hierarchy_with_conditional_dns_output
    data = F.web(uri: 'urn:example:opaque:token')
    assert_claims(data, ['input'])
    assert_claims(F.web(uri: 'novel-scheme:/path?query#fragment'), ['input'])
    data = F.web(domain: true)
    assert_claims(data, %w[domain url])
    assert_claims(F.web(uri: 'https://192.0.2.20/resource'), ['url'])
    data = F.web(domain: true)
    get(data, 'host')['attributes']['selector']['value'] = 'unrelated.example'
    assert_equal ['url'], ids(run_fixture(data))
  end

  def test_resource_having_token_does_not_make_a_referenced_url_its_location
    data = F.web
    get(data, 'url')['attributes']['value'] = 'https://referenced.example/not-the-captured-resource'
    assert_empty run_fixture(data)['results']
  end

  def test_common_host_filter_is_only_domain_scoped_but_common_token_gates_dependents
    data = F.web(domain: true)
    remove_control(data, 'common_hosting_or_cdn_domains')
    F.add_control(data, 'common_hosting_or_cdn_domains', 'domain')
    assert_equal ['url'], ids(run_fixture(data))
    data = F.web(domain: true)
    remove_control(data, 'common_framework_or_analytics_tokens')
    F.add_control(data, 'common_framework_or_analytics_tokens', 'seed')
    answer = run_fixture(data)
    assert_empty answer['results']
    assert_equal 'suppressed', answer['outcome']
  end

  def test_pinned_revision_conflicts_and_unknown_membership_are_not_clearance
    data = F.web
    remove_control(data, 'common_framework_or_analytics_tokens')
    F.add_control(data, 'common_framework_or_analytics_tokens', 'seed', 'member', 'older-revision')
    answer = run_fixture(data)
    assert_empty answer['results']
    assert answer['diagnostics'].any? { |d| d['status'] == 'unresolved' && d['projected_result'] }
    F.add_control(data, 'common_framework_or_analytics_tokens', 'seed', 'member', 'policy-r1', 'current-member')
    F.add_control(data, 'common_framework_or_analytics_tokens', 'seed', 'not_member', 'policy-r1', 'current-conflict')
    answer = run_fixture(data)
    assert_empty answer['results']
    assert answer['diagnostics'].any? { |d| d['status'] == 'unresolved' && d['projected_result'] }
  end

  def test_missing_control_and_incomplete_nonmembership_retain_candidates_without_ordinary_eligibility
    data = F.web
    remove_control(data, 'common_framework_or_analytics_tokens')
    answer = run_fixture(data)
    assert_empty answer['results']
    assert answer['diagnostics'].any? { |d| d['projected_result'] && d['status'] == 'unresolved' }
    F.add_control(data, 'common_framework_or_analytics_tokens', 'seed', 'not_member')
    get(data, 'policy')['attributes']['coverage'] = 'partial_response'
    assert_empty run_fixture(data)['results']
  end

  def test_same_text_wrong_namespace_does_not_supply_control_applicability
    data = F.web
    remove_control(data, 'common_framework_or_analytics_tokens')
    F.add_control(data, 'common_framework_or_analytics_tokens', 'seed')
    get(data, 'policy')['attributes']['selector']['namespace'] = 'malware:config:string'
    answer = run_fixture(data)
    assert_empty answer['results']
    refute answer['diagnostics'].any? { |d| d['status'] == 'suppressed' }
    assert answer['diagnostics'].any? { |d| d['projected_result'] && d['status'] == 'unresolved' }
    equivalence = F.rec(data, 'explicit-equivalence', 'assertion', 'selector:equivalence',
      {'left_selector' => F.deep(get(data, 'seed')['attributes']['selector']),
       'right_selector' => F.deep(get(data, 'policy')['attributes']['selector']),
       'left_context' => 'contained_value', 'right_context' => 'contained_value',
       'profile' => 'explicit_selector_equivalence_v1', 'method' => 'source-qualified-semantic-mapping', 'method_version' => '1'}, available: nil)
    F.preserve(data, equivalence, JSON.generate(equivalence['attributes']))
    answer = run_fixture(data)
    assert_empty answer['results']
    assert answer['diagnostics'].any? { |d| d['status'] == 'suppressed' }
  end

  def test_selector_alias_record_cannot_bypass_an_applicable_control
    data = F.web
    remove_control(data, 'common_framework_or_analytics_tokens')
    F.add_control(data, 'common_framework_or_analytics_tokens', 'seed')
    alias_record = F.deep(get(data, 'seed'))
    alias_record['id'] = 'same-selector-alias'
    data['evidence']['records'] << alias_record
    data['query']['parameters']['seed'] = alias_record['id']
    answer = run_fixture(data)
    assert_empty answer['results']
    assert answer['diagnostics'].any? { |d| d['status'] == 'suppressed' }
  end

  def test_ip_url_dns_control_is_not_applicable_rather_than_cleared
    data = F.email_urls
    uri = 'https://192.0.2.20/B'
    get(data, 'output')['attributes']['uri']['value'] = uri
    get(data, 'url')['attributes']['value'] = uri
    data['claims'][0]['identity'][-1] = F.typed_identity('uri', uri)
    remove_control(data, 'common_email_service_links')
    remove_control(data, 'common_cdn_domains')
    data['evidence']['records'].reject! { |r| r['id'] == 'host' }
    F.add_control(data, 'common_email_service_links', 'url', 'not_member')
    answer = run_fixture(data)
    assert_equal ['url'], ids(answer)
    policy = answer['results'][0]['policy_evaluations'].find { |p| p['id'] == 'common_cdn_domains' }
    assert_equal 'no_match', policy['applicability']['status']
    assert_equal 'no_match', policy['decision']['status']
    assert_match(/not applicable/, policy['decision']['reason'])
  end

  def test_boolean_or_blank_capture_and_method_are_not_semantic_identity
    data = F.cluster('CTI_EMAIL_HEADER_VALUE_CLUSTER')
    get(data, 'input')['attributes']['capture_id'] = false
    assert_empty run_fixture(data)['results']
    data = F.cluster('CTI_FILE_SOURCE_PATH_CLUSTER')
    get(data, 'extraction')['attributes']['method'] = ' '
    assert_empty run_fixture(data)['results']
    data = F.cluster('CTI_EMAIL_HEADER_VALUE_CLUSTER')
    get(data, 'extraction')['attributes']['field_occurrence'] = false
    assert_empty run_fixture(data)['results']
  end

  def test_conflicting_path_policy_evidence_cannot_escape_through_a_separate_record
    data = F.response('payload_config')
    F.add_control(data, 'known_test_or_decoy_payloads', 'output')
    answer = run_fixture(data)
    assert_empty answer['results']
    assert answer['diagnostics'].any? { |d| d['status'] == 'unresolved' && d['projected_result'] }
  end

  def test_email_protected_url_is_output_but_decoded_or_navigation_destination_is_not
    data = F.email_urls
    assert_claims(data, ['url'])
    get(data, 'extraction')['attributes']['derivation_relation'] = 'decoded_protected_destination'
    assert_empty run_fixture(data)['results']
    get(data, 'extraction')['attributes']['derivation_relation'] = 'navigation_destination'
    assert_empty run_fixture(data)['results']
  end

  def test_source_map_direct_route_and_extra_surface_evidence_are_independent
    assert_claims(F.sourcemap, ['route'])
    data = F.sourcemap(surface: true)
    assert_claims(data, %w[route surface])
    get(data, 'surface_evidence')['attributes']['role'] = 'ordinary_application_page'
    assert_equal ['route'], ids(run_fixture(data))
    data = F.sourcemap
    get(data, 'extraction')['attributes']['route_basis'] = 'comment_or_library_example'
    assert_empty run_fixture(data)['results']
  end

  def test_source_map_referenced_path_requires_content_correspondence
    data = F.sourcemap(referenced: true)
    assert_claims(data, ['route'])
    get(data, 'correspondence')['attributes']['map_sha256'] = 'a' * 64
    assert_empty run_fixture(data)['results']
    data['query']['parameters']['seed'] = 'input' # independently investigate the map itself
    data['claims'][0]['support'] = %w[input extraction output route]
    assert_equal ['route'], ids(run_fixture(data))
  end

  def test_particular_response_and_payload_hash_share_finding_while_configuration_is_distinct
    data = F.response('payload_hash')
    answer = assert_claims(data, %w[output digest])
    assert_equal 1, answer['results'].map { |r| r.dig('finding_evaluation', 'claim_key') }.uniq.length
    assert answer['results'].all? { |r| r.dig('finding_evaluation', 'first_scoped_time', 'value') == '2026-09-11T00:00:00Z' }
    data = F.response('payload_config')
    answer = assert_claims(data, %w[output config])
    assert_equal 2, answer['results'].map { |r| r.dig('finding_evaluation', 'claim_key') }.uniq.length
    assert_claims(F.response('direct_config'), ['output'])
  end

  def test_response_reference_or_wrong_exchange_does_not_supply_payload
    data = F.response
    get(data, 'extraction')['attributes']['derivation_relation'] = 'later_download_referenced_by_response'
    assert_empty run_fixture(data)['results']
    data = F.response
    get(data, 'extraction')['attributes']['response_occurrence'] = 'exchange-R3'
    assert_empty run_fixture(data)['results']
    data = F.response('payload_config')
    remove_control(data, 'known_test_or_decoy_payloads')
    F.add_control(data, 'known_test_or_decoy_payloads', 'output')
    assert_empty run_fixture(data)['results']
  end

  def test_as_known_cutoff_does_not_backdate_new_extraction_to_old_sighting
    data = F.cluster('CTI_FILE_SOURCE_PATH_CLUSTER')
    data['query']['knowledge_cutoff'] = F.time('2024-12-31T23:59:59Z', 'case', 'case', '/case/cutoff')
    assert_empty evaluate(data)['results']
    data['query']['knowledge_cutoff']['value'] = '2026-09-14T23:59:59Z'
    assert_equal ['input'], ids(evaluate(data))
  end

  def test_missing_extraction_time_and_partial_search_cannot_assert_recent_finding
    data = F.cluster('CTI_FILE_SOURCE_PATH_CLUSTER')
    get(data, 'extraction')['times']['occurred'].delete('timezone')
    assert_equal 'unresolved', run_fixture(data)['outcome']
    data = F.web(domain: true)
    data['query']['limits']['max_bindings'] = 2
    result = evaluate(data)
    assert_equal 'partial', result['status']
    assert_empty result['results']
  end
end
