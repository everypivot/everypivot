#!/usr/bin/env ruby
# frozen_string_literal: true
require 'minitest/autorun'
require_relative 'semantic_evaluator'
require_relative '../fixtures/semantic-families/result-bindings/fixture_factory'
class SemanticResultBindingsTest < Minitest::Test
  F = ResultBindingFixtures
  X = ExtractionFixtures
  def evaluate(d)
    EveryPivot::SemanticEvaluator.new(d['contract']).evaluate(d['evidence'], d['query'], preserved_source_bytes: d['preserved_source_bytes'])
  end
  def get(d, id); X.get(d, id); end
  def outcomes(r); r['results'].map { |v| v.dig('fields', 'comparison_outcome') }.uniq.sort; end
  def ids(r); r['results'].map { |v| v['id'] }.uniq.sort; end
  def test_phase_comparison_is_constructed_for_actual_request_with_explicit_rule
    d = F.phase
    r = evaluate(d)
    assert_equal ['mismatch'], outcomes(r), r['diagnostics'].inspect
    row = r['results'][0]
    assert_equal 'construct', row['mode']
    assert_equal 'risk:observation', row['form']
    assert_equal 'request-R17', row['fields']['request_identity']
    assert_equal 'evidence_only', row['fields']['claim_status']
    refute row['fields'].key?('accepted_assessment')
  end
  def test_phase_multiphase_and_contradiction_do_not_force_a_winner_or_add_mismatches
    r = evaluate(F.phase(outcome: 'compatible'))
    assert_equal ['compatible'], outcomes(r)
    assert r['results'].all? { |v| v['form'] == 'evidence:phase_comparison' }
    r = evaluate(F.phase(outcome: 'contested'))
    assert_includes outcomes(r), 'contested'
    refute_includes outcomes(r), 'mismatch'
    assert r['results'].all? { |v| v['form'] == 'evidence:phase_comparison' }
  end
  def test_phase_inference_needs_its_actual_evidence_and_does_not_become_declaration
    d = F.phase(basis: 'inferred')
    r = evaluate(d)
    assert_equal ['mismatch'], outcomes(r)
    assert_equal 'inferred', r['results'][0]['fields']['role_basis']
    d['preserved_source_bytes'].delete('bytes-role-exchange')
    assert_empty evaluate(d)['results']
  end
  def test_request_scope_is_not_nearby_endpoint_or_different_tenant
    d = F.phase
    get(d, 'role')['attributes']['tenant'] = 'tenant-8'
    assert_empty evaluate(X.seal(d))['results']
    d = F.phase
    get(d, 'request-input')['attributes']['request_occurrence'] = 'other-request-with-same-url'
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_phase_context_start_completion_and_missing_context_are_not_interchangeable
    assert_equal ['mismatch'], outcomes(evaluate(F.phase(method: 'page_start')))
    assert_empty evaluate(F.phase(method: 'page_complete'))['results']
    d = F.phase(method: 'page_start')
    d['evidence']['records'].reject! { |v| v['id'] == 'context-link' }
    assert_empty evaluate(X.seal(d))['results']
    assert_equal ['mismatch'], outcomes(evaluate(F.phase)) # request-only method needs no manufactured page
  end
  def test_request_activity_window_does_not_refresh_with_later_comparison_evidence
    d = F.phase
    get(d, 'request')['times']['occurred']['value'] = '2026-06-01T12:00:00Z'
    assert_empty evaluate(X.seal(d))['results']
    d['query']['parameters']['query_date'] = '2026-06-02'
    assert_equal ['mismatch'], outcomes(evaluate(d))
  end
  def test_officer_is_direct_appointment_not_co_appointee_expansion_or_concurrent_service
    d = F.officer
    r = evaluate(d)
    assert_equal %w[A B], ids(r), r['diagnostics'].inspect
    assert r['results'].all? { |v| v.dig('fields', 'relationship') == 'direct_evidenced_appointment' }
    refute_includes ids(r), 'C'
  end
  def test_missing_service_end_does_not_become_infinite_or_current
    d = F.officer
    get(d, 'Alice-B-service')['times']['held'].delete('end')
    assert_equal ['A'], ids(evaluate(X.seal(d)))
    active = X.rec(d, 'Alice-B-current', 'assertion', 'org:dated_active_status', {'status' => 'active_at_evidenced_time'}, subject: 'Alice-B')
    active['times']['status_at'] = X.time('2026-09-01T12:00:00Z', 'Alice-B', active['id'], '/records/Alice-B-current/status_at')
    assert_equal %w[A B], ids(evaluate(X.seal(d)))
  end
  def test_service_period_and_professional_context_do_not_change_direct_appointment_identity
    d = F.officer
    X.rec(d, 'professional-A', 'assertion', 'org:appointment_capacity', {'capacity' => 'professional_director'}, subject: 'Alice-A')
    assert_equal %w[A B], ids(evaluate(X.seal(d)))
    d['query']['parameters']['scope'] = 'explicit_service_period'
    d['query']['parameters']['period'] = {'start' => '2018-01-01', 'end' => '2019-12-31'}
    assert_equal ['A'], ids(evaluate(d))
    get(d, 'Alice-A')['attributes']['person_scope'] = 'different-person-same-display-name'
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_creative_direct_and_script_reference_and_request_are_distinct_supported_paths
    %w[direct script].product(%w[reference request]).each do |path, kind|
      d = F.creative(path: path, kind: kind)
      r = evaluate(d)
      assert_equal ['url'], ids(r), [path, kind, r['diagnostics']].inspect
      row = r['results'][0]
      assert_equal kind == 'reference' ? 'URI reference' : 'creative-associated request', row['fields']['finding_kind']
      assert_equal '2026-09-15T00:00:00Z', row.dig('finding_evaluation', 'first_scoped_time', 'value')
      assert_equal 'inet:url', row['form']
      refute row['fields'].key?('control')
    end
  end
  def test_creative_shared_script_does_not_transfer_a_request_between_creative_captures
    d = F.creative(path: 'script', kind: 'request')
    get(d, 'correlation')['attributes']['creative_capture'] = 'different-C2'
    assert_empty evaluate(X.seal(d))['results']
    d = F.creative(kind: 'request')
    get(d, 'request')['attributes']['stage'] = 'initiated_attempt'
    r = evaluate(d)
    assert_equal 'initiated_attempt', r['results'][0]['fields']['request_stage']
    refute r['results'][0]['fields'].key?('completed_delivery')
  end
  def test_creative_ip_and_generic_uri_do_not_manufacture_dns_or_url_nodes
    d = F.creative(uri: 'https://192.0.2.20/pixel')
    r = evaluate(d)
    assert_equal ['url'], ids(r)
    assert_match(/not applicable/, r['results'][0]['fields']['dns_screening'])
    d = F.creative(uri: 'urn:example:campaign:41')
    r = evaluate(d)
    assert_equal 1, r['results'].length, r['diagnostics'].inspect
    assert_equal 'evidence:creative_reference', r['results'][0]['form']
    refute d['evidence']['records'].any? { |v| v['type'] == 'inet:url' }
  end
  def test_creative_unknown_hostname_control_cannot_be_evaded_by_generic_uri_view
    d = F.creative
    d['evidence']['records'].reject! { |v| v['id'] == 'clear-pixel' }
    r = evaluate(X.seal(d))
    assert_empty r['results']
    assert r['diagnostics'].any? { |v| v['projected_result'] && v['status'] == 'unresolved' }
    refute r['diagnostics'].any? { |v| v.dig('projected_result', 'form') == 'evidence:creative_reference' }
  end
  def test_three_listing_questions_do_not_convert_member_evidence_to_an_asn_claim
    %w[ip asn network].each do |question|
      d = F.sbl(question)
      r = evaluate(d)
      assert_equal [question == 'network' ? 'infrastructure' : 'claim'], ids(r), r['diagnostics'].inspect
      assert_equal 'historical_source_assertion', r['results'][0]['fields']['finding_kind']
      assert_match(/history beyond supplied revisions unknown/, r['results'][0]['fields']['history_limit'])
    end
    d = F.sbl('asn')
    get(d, 'claim')['attributes']['subject_kind'] = 'ipv4'
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_covering_range_requires_publisher_applicability_as_well_as_arithmetic
    d = F.sbl('ip', covering: true)
    assert_equal ['claim'], ids(evaluate(d))
    get(d, 'prefix-scope')['attributes']['applicability']['value'] = 'listed_individual_addresses_only'
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_historical_network_join_does_not_use_later_assignment_or_receipt
    d = F.sbl('network', network_start: '2026-09-01T00:00:00Z')
    assert_empty evaluate(d)['results']
    d = F.sbl('network')
    get(d, 'association')['attributes']['coverage'] = 'one_member_only'
    assert_empty evaluate(X.seal(d))['results']
    d = F.sbl('ip')
    d['query']['parameters']['period'] = {'start' => '2026-09-01', 'end' => '2026-09-30'}
    assert_empty evaluate(d)['results']
  end
  def test_source_withdrawal_is_retained_as_history_not_unwithdrawn_adverse_support
    d = F.sbl
    X.rec(d, 'withdrawal', 'assertion', 'evidence:assertion_amendment', {'operation' => 'withdraw', 'assertion_namespace' => 'publisher-list-A',
      'issuer_source_id' => 'report', 'supersedes_amendments' => [], 'reason' => 'source withdraws mistaken earlier entry'}, subject: 'claim')
    r = evaluate(X.seal(d))
    assert_equal ['claim'], ids(r)
    assert_match(/withdraw/, JSON.generate(r['results'][0]['amendment_evaluation']))
    assert_match(/not current or certified unwithdrawn/, r['results'][0]['fields']['history_limit'])
  end
  def test_kit_archive_fileset_and_paths_are_distinct_comparisons_with_same_candidate_deployment
    %w[archive file_set paths].each do |match|
      d = F.phishkit(match: match)
      r = evaluate(d)
      assert_equal ['infrastructure'], ids(r), [match, r['diagnostics']].inspect
      assert_includes r['results'].map { |v| v['fields']['match_reason'] }, match
      assert_equal '2024-12-10T12:00:00Z', r['results'][0]['fields']['activity_time']['value']
    end
  end
  def test_kit_comparison_and_deployment_do_not_transfer_between_candidates
    d = F.phishkit
    get(d, 'resource')['attributes']['representation_id'] = 'left'
    assert_empty evaluate(X.seal(d))['results']
    d = F.phishkit
    get(d, 'deployment')['attributes']['stage'] = 'archive_offered_for_download'
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_client_evidence_can_qualify_but_cache_or_peer_alone_cannot_establish_network_serving
    d = F.phishkit(network: 'ipv4', source: 'client_network_capture')
    r = evaluate(d)
    assert_equal ['infrastructure'], ids(r)
    assert_equal 'delivery_endpoint', r['results'][0]['fields']['infrastructure_role']
    assert_equal 'unknown', r['results'][0]['fields']['origin_role']
    get(d, 'resource')['attributes']['delivery_provenance'] = 'client_cache'
    assert_empty evaluate(X.seal(d))['results']
    d = F.phishkit(network: 'ipv4')
    get(d, 'delivery')['attributes']['role'] = 'unbound_network_peer'
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_old_undated_and_new_receipt_do_not_require_discovery_before_activity
    d = F.phishkit(receipt: false)
    assert_equal ['infrastructure'], ids(evaluate(d))
    get(d, 'deployment')['times'].delete('occurred')
    r = evaluate(X.seal(d))
    assert_equal ['infrastructure'], ids(r)
    assert_nil r['results'][0]['fields']['activity_time']
    d = F.phishkit
    get(d, 'arrival')['times']['received']['value'] = '2020-01-01T00:00:00Z'
    assert_equal ['infrastructure'], ids(evaluate(X.seal(d)))
  end
  def test_controlled_scope_unknown_and_shared_host_context_remain_distinct
    d = F.phishkit
    X.rec(d, 'shared', 'assertion', 'kit:deployment_context', {'explanation' => 'public kit delivered through shared CDN'}, subject: 'deployment')
    assert_equal ['infrastructure'], ids(evaluate(X.seal(d)))
    get(d, 'purpose')['attributes'].merge!('disposition' => 'controlled', 'purpose' => 'research')
    r = evaluate(X.seal(d))
    assert_empty r['results']
    assert r['diagnostics'].any? { |v| v['status'] == 'suppressed' }
    d['query']['parameters']['include_controlled'] = true
    assert_equal ['infrastructure'], ids(evaluate(d))
    d = F.phishkit
    get(d, 'purpose')['attributes']['occurrence_key'] = 'later-sinkhole-2026'
    r = evaluate(X.seal(d))
    assert_empty r['results']
    assert r['diagnostics'].any? { |v| v['projected_result'] && v['status'] == 'unresolved' }
  end
  def test_supplied_same_occurrence_is_reference_not_new_hosting_discovery
    d = F.phishkit
    d['query']['parameters']['reference_deployments'] = ['deployment']
    r = evaluate(d)
    assert_equal ['evidence:deployment_reference'], r['results'].map { |v| v['form'] }.uniq
    assert r['results'].all? { |v| v['fields']['view'] == 'reference' }
  end
  def test_generic_paths_do_not_supply_qualifying_hosting_or_defeat_an_exact_branch
    d = F.phishkit(match: 'paths')
    get(d, 'path-comparison')['attributes']['qualification'] = 'only_generic_default_paths'
    r = evaluate(X.seal(d))
    assert_equal ['evidence:kit_comparison_clue'], r['results'].map { |v| v['form'] }.uniq
    refute r['results'].any? { |v| v['form'] == 'inet:fqdn' }
    d = F.phishkit(match: 'file_set')
    X.rec(d, 'generic', 'assertion', 'kit:shared_path_interpretation', {'paths' => ['readme.txt'], 'profile' => 'literal_shared_paths_v1',
      'qualification' => 'only_generic_default_paths', 'interpretation_basis' => 'documented default file', 'ordinary_explanations' => 'stock readme', 'scope' => 'collected paths'},
      subject: 'left', object: 'right')
    r = evaluate(X.seal(d))
    assert_includes r['results'].map { |v| v['form'] }, 'inet:fqdn'
    assert_includes r['results'].map { |v| v['form'] }, 'evidence:kit_comparison_clue'
  end
  def test_exact_component_clue_survives_without_whole_kit_or_deployment_claim
    d = F.phishkit
    d['evidence']['records'].reject! { |v| %w[kit:representation kit:deployment].include?(v['type']) }
    # Remove records with references to the deliberately absent deployment.
    d['evidence']['records'].reject! { |v| v['subject'] == 'deployment' || v['object'] == 'deployment' }
    X.rec(d, 'seed-component', 'assertion', 'kit:component', {'component_scope' => 'stylesheet only'}, subject: 'seed', object: 'left')
    X.rec(d, 'candidate-component', 'assertion', 'kit:component', {'component_scope' => 'one shared stylesheet'}, subject: 'candidate', object: 'right')
    r = evaluate(X.seal(d))
    assert r['results'].all? { |v| v['form'] == 'evidence:kit_comparison_clue' }
    assert_includes r['results'].map { |v| v['fields']['match_reason'] }, 'exact preserved component bytes'
  end
  def test_source_qualified_substantive_derivation_requires_real_inputs_and_changed_correspondence
    d = F.phishkit(receipt: false)
    X.artifact(d, 'analysis-input', 'evidence:analysis_input', 'preserved older capture for analysis')
    X.artifact(d, 'before', 'evidence:analysis_output', 'prior candidate correspondence', {'candidate_id' => 'previous-candidate'})
    X.artifact(d, 'after', 'evidence:analysis_output', 'new candidate correspondence recovered from capture', {'candidate_id' => 'candidate', 'representation_id' => 'right',
      'location_id' => 'location', 'resource_scope' => 'campaign/Q7Z application revision1', 'input_sha256' => X.hash_of(d, 'analysis-input'), 'correspondence_id' => 'resource'}, available: '2026-09-16T00:00:00Z')
    X.rec(d, 'derivation', 'occurrence', 'analysis:kit_context_derivation', {'collection_id' => 'fixture-collection', 'input_id' => 'analysis-input',
      'prior_output_id' => 'before', 'contribution_role' => 'candidate_correspondence', 'profile' => 'source_reported_changed_correspondence_v1',
      'run_id' => 'actual-analysis-run-1', 'method' => 'manual-reconstruction', 'method_version' => '1',
      'changed_contribution' => 'source reports newly recovered candidate correspondence in preserved response', 'equivalence_limit' => 'comparison to stated prior output only; earlier history unknown'},
      subject: 'candidate', object: 'after', occurred: '2026-09-15T12:00:00Z', available: '2026-09-16T00:00:00Z')
    r = evaluate(X.seal(d))
    focus = r['results'].select { |v| v['fields']['priority_basis'] == 'source_reported_substantive_derivation' }
    refute_empty focus
    assert_equal '2024-12-10T12:00:00Z', focus[0]['fields']['activity_time']['value']
    refute_empty focus[0]['search_priority']
    get(d, 'before')['attributes']['candidate_id'] = 'candidate' # changed digest/tool label alone cannot qualify
    r = evaluate(X.seal(d))
    refute r['results'].any? { |v| v['fields']['priority_basis'] == 'source_reported_substantive_derivation' }
    assert_includes ids(r), 'infrastructure' # unranked historical witness remains eligible
  end
  def test_static_case_oracles_are_complete_and_match_independent_expected_forms
    root = File.expand_path('..', __dir__)
    Dir[File.join(root, 'fixtures/semantic-families/result-bindings/cases/*.json')].sort.each do |path|
      d = JSON.parse(File.read(path))
      d['contract'] = JSON.parse(File.read(File.join(root, d['contract_path'])))
      r = evaluate(d)
      expected = d['expected']
      assert_equal expected['execution_status'], r['status'], path
      assert_equal expected['forms'].sort, r['results'].map { |v| v['form'] }.uniq.sort, path
      assert_equal expected['bound_ids'].sort, ids(r), path if expected['bound_ids']
      {'comparison_outcomes' => 'comparison_outcome', 'finding_kinds' => 'finding_kind', 'match_reasons' => 'match_reason'}.each do |key, field|
        assert_equal expected[key].sort, r['results'].map { |v| v['fields'][field] }.uniq.sort, path if expected[key]
      end
      assert r['results'].all? { |v| v['assessment_acceptance'] == expected['assessment_acceptance'] }, path
    end
  end
  def test_partial_period_exclusion_cannot_suppress_entire_listing_history
    d = F.sbl
    d['query']['parameters'].merge!('apply_exclusions' => true, 'exclusion_rules' => ['case-rule-A'])
    exclusion = X.rec(d, 'exclude-part', 'assertion', 'investigation:exclusion', {'rule_id' => 'case-rule-A', 'rule_revision' => '1',
      'reason' => 'explicit case period exclusion', 'disposition' => 'exclude'}, subject: 'claim')
    exclusion['times']['applicable'] = F.interval('2024-04-10T00:00:00Z', '2024-04-11T00:00:00Z', 'seed', exclusion['id'], '/records/exclude-part/applicable')
    r = evaluate(X.seal(d))
    assert_empty r['results']
    refute r['diagnostics'].any? { |v| v['status'] == 'suppressed' }
    assert r['diagnostics'].any? { |v| v['projected_result'] && v['status'] == 'unresolved' }
    exclusion['times']['applicable']['start'] = '2024-04-01T00:00:00Z'
    exclusion['times']['applicable']['end'] = '2024-05-01T00:00:00Z'
    r = evaluate(X.seal(d))
    assert_empty r['results']
    assert r['diagnostics'].any? { |v| v['status'] == 'suppressed' }
  end
  def test_positive_investigation_evaluation_cannot_omit_a_requested_rule
    d = F.sbl
    d['query']['parameters'].merge!('apply_exclusions' => true, 'exclusion_rules' => %w[A B])
    exclusion = X.rec(d, 'retain', 'assertion', 'investigation:exclusion', {'rule_id' => 'A', 'rule_revision' => '1',
      'reason' => 'source evaluates selected investigation scope', 'disposition' => 'retain', 'evaluated_rule_ids' => ['A']}, subject: 'claim')
    exclusion['times']['applicable'] = F.interval('2024-04-01T00:00:00Z', '2024-05-01T00:00:00Z', 'seed', 'retain', '/records/retain/applicable')
    assert_empty evaluate(X.seal(d))['results']
    exclusion['attributes']['evaluated_rule_ids'] << 'B'
    assert_equal ['claim'], ids(evaluate(X.seal(d)))
  end
  def test_conflicting_controlled_purpose_has_no_automatic_winner
    d = F.phishkit
    attrs = X.deep(get(d, 'purpose')['attributes']).merge('disposition' => 'controlled', 'purpose' => 'test')
    attrs.delete('availability_occurrence')
    X.rec(d, 'contrary-purpose', 'assertion', 'kit:occurrence_purpose', attrs, subject: 'deployment')
    r = evaluate(X.seal(d))
    assert_empty r['results']
    refute r['diagnostics'].any? { |v| v['status'] == 'suppressed' }
    assert r['diagnostics'].any? { |v| v['projected_result'] && v['status'] == 'unresolved' }
  end
  def test_copied_baseline_record_does_not_become_an_additional_hosting_discovery
    d = F.phishkit
    old = get(d, 'deployment')
    attrs = X.deep(old['attributes'])
    attrs.delete('availability_occurrence')
    X.rec(d, 'baseline-copy', 'occurrence', 'kit:deployment', attrs, subject: 'candidate', occurred: '2024-12-10T12:00:00Z')
    d['query']['parameters']['reference_deployments'] = ['baseline-copy']
    r = evaluate(X.seal(d))
    assert_equal ['evidence:deployment_reference'], r['results'].map { |v| v['form'] }.uniq
    get(d, 'deployment')['attributes']['origin_source_id'] = 'manifest' # label cannot invent a source link
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_preserved_kit_integrity_is_invalid_not_a_nonmatch_or_suppressed_result
    d = F.phishkit(match: 'file_set')
    d['preserved_source_bytes']['bytes-right-file-0'] = 'altered config bytes'
    assert_raises(EveryPivot::SemanticResultPrimitives::InvalidInput) { evaluate(d) }
  end
  def test_result_limits_are_explicit_partial_coverage_not_a_negative_result
    d = F.phishkit
    d['query']['limits']['max_bindings'] = 1
    r = evaluate(d)
    assert_equal 'partial', r['status']
    refute r['coverage']['search_complete_for_supplied_input']
    assert_empty r['results']
  end
  def test_different_baseline_labels_require_positive_source_qualified_distinctness
    d = F.phishkit
    attrs = X.deep(get(d, 'deployment')['attributes']); attrs.delete('availability_occurrence')
    attrs['occurrence_key'] = 'other-capture-label'
    X.rec(d, 'other-baseline', 'occurrence', 'kit:deployment', attrs, subject: 'candidate')
    d['query']['parameters']['reference_deployments'] = ['other-baseline']
    r = evaluate(X.seal(d))
    assert_empty r['results']
    assert r['diagnostics'].any? { |v| v['projected_result'] && v['status'] == 'unresolved' }
    attrs = X.deep(get(d, 'deployment')['attributes']); attrs.delete('availability_occurrence')
    attrs.merge!('candidate_id' => 'candidate', 'compared_baseline_ids' => ['other-baseline'], 'disposition' => 'distinct_occurrences',
      'profile' => 'source_qualified_occurrence_comparison_v1', 'method' => 'source_capture_event_correspondence', 'method_version' => '1',
      'comparison_basis' => 'source distinguishes two independently recorded actual responses, retaining each capture and timestamp')
    proof = X.rec(d, 'distinctness-proof', 'assertion', 'kit:baseline_comparison', attrs, subject: 'deployment')
    X.preserve(d, proof, JSON.generate(attrs))
    assert_equal ['infrastructure'], ids(evaluate(X.seal(d)))
    proof['attributes']['compared_baseline_ids'] = []
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_explicit_control_dispute_prevents_positive_clearance_without_a_member_claim
    d = F.phishkit
    attrs = X.deep(get(d, 'purpose')['attributes']); attrs.delete('availability_occurrence')
    attrs['disposition'] = 'contested'
    X.rec(d, 'disputed-purpose', 'assertion', 'kit:occurrence_purpose', attrs, subject: 'deployment')
    r = evaluate(X.seal(d))
    assert_empty r['results']
    refute r['diagnostics'].any? { |v| v['status'] == 'suppressed' }
  end
  def test_dated_active_service_cannot_be_known_before_the_actual_status_event
    d = F.officer
    d['evidence']['records'].reject! { |v| v['type'] == 'org:service_interval' }
    d['query']['parameters'].merge!('scope' => 'explicit_service_period', 'period' => {'start' => '2026-01-01', 'end' => '2026-12-31'})
    status = X.rec(d, 'future-status', 'assertion', 'org:dated_active_status', {'status' => 'active_at_evidenced_time'}, subject: 'Alice-B', available: '2026-09-01T00:00:00Z')
    status['times']['status_at'] = X.time('2026-10-01T00:00:00Z', 'Alice-B', 'future-status', '/records/future-status/status_at')
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_provided_future_deployment_clock_does_not_pass_as_completed_but_absent_clock_is_retained
    d = F.phishkit
    get(d, 'deployment')['times']['occurred']['value'] = '2026-10-01T00:00:00Z'
    assert_empty evaluate(X.seal(d))['results']
    get(d, 'deployment')['times'].delete('occurred')
    assert_equal ['infrastructure'], ids(evaluate(X.seal(d)))
    get(d, 'deployment')['times']['occurred'] = X.time(nil, 'candidate', 'deployment', '/records/deployment/occurred')
    assert_empty evaluate(X.seal(d))['results']
  end
  def test_receipt_priority_does_not_remove_an_independently_known_historical_witness
    d = F.phishkit
    d['query']['knowledge_cutoff'] = X.time('2026-09-14T23:59:59Z', 'cutoff', 'cutoff', '/cutoff')
    r = evaluate(d)
    assert_equal ['infrastructure'], ids(r)
    assert r['results'].all? { |v| v['fields']['arrival'].nil? }
    assert r['results'].all? { |v| v['fields']['priority_basis'] == 'unranked_base_evidence' }
  end
  def test_selected_component_subset_is_a_clue_not_qualifying_kit_hosting
    d = F.phishkit(match: 'file_set')
    replace_bytes = lambda do |record, document|
      bytes = JSON.generate(document); descriptor = record['attributes']['content']; source_id = descriptor['source_id']
      digest = Digest::SHA256.hexdigest(bytes)
      descriptor.merge!('sha256' => digest, 'byte_length' => bytes.bytesize)
      d['preserved_source_bytes'][source_id] = bytes
      d['evidence']['sources'].find { |source| source['id'] == source_id }['content_hash']['value'] = digest
    end
    %w[left right].each do |id|
      manifest = get(d, id)
      body = JSON.parse(d['preserved_source_bytes'][manifest['attributes']['content']['source_id']])
      body['scope'].merge!('kind' => 'declared_subset', 'description' => 'selected readme component only; configuration and other files omitted')
      body['entries'].select! { |entry| entry['path'] == 'readme.txt' }
      replace_bytes.call(manifest, body)
      coverage = get(d, id + '-coverage')
      inventory = JSON.parse(d['preserved_source_bytes'][coverage['attributes']['content']['source_id']])
      inventory.merge!('scope' => body['scope'], 'manifest_sha256' => manifest['attributes']['content']['sha256'], 'paths' => ['readme.txt'])
      replace_bytes.call(coverage, inventory)
    end
    r = evaluate(X.seal(d))
    assert_equal ['evidence:kit_comparison_clue'], r['results'].map { |v| v['form'] }.uniq
    assert_equal ['exact preserved declared subset'], r['results'].map { |v| v['fields']['match_reason'] }.uniq
    refute r['results'].any? { |v| %w[inet:fqdn inet:ipv4].include?(v['form']) }
    assert_includes JSON.generate(r['results']), 'declared_subset'
  end
  def test_as_known_appointment_requires_actual_availability_occurrence_in_this_collection
    %w[other_collection wrong_kind].each do |variation|
      d = F.officer
      d['query']['knowledge_cutoff'] = X.time('2026-09-14T23:59:59Z', 'cutoff', 'cutoff', '/cutoff')
      d['evidence']['records'].select { |record| record['type'] == 'evidence:availability' }.each do |record|
        if variation == 'other_collection'
          record['attributes']['collection_id'] = 'different-collection'
        else
          record['kind'] = 'entity'
        end
      end
      assert_empty evaluate(d)['results'], variation
    end
  end
end
