#!/usr/bin/env ruby
# frozen_string_literal: true
require 'minitest/autorun'
require_relative 'semantic_evaluator'
require_relative '../fixtures/semantic-families/certificate-expansion/fixture_factory'

class SemanticCertificateExpansionTest < Minitest::Test
  F=CertificateExpansionFixtures
  X=ExtractionFixtures
  C=CertificateExpansionContracts
  def evaluate(d)
    EveryPivot::SemanticEvaluator.new(d['contract']).evaluate(d['evidence'],d['query'],preserved_source_bytes:d['preserved_source_bytes'])
  end
  def get(d,id); F.get(d,id); end
  def targets(result); result['results'].map{|r|r['id']}.uniq.sort; end
  def empties(d,outcome=nil)
    r=evaluate(d); assert_empty r['results']; assert_equal outcome,r['outcome'] if outcome; r
  end
  def reseal(d); F.seal(d); end
  def amendment(d,id='withdrawal',subject='sale',operation='withdraw',receipt='2026-09-25T00:00:00Z')
    get(d,subject)['attributes']['assertion_namespace']='synthetic-marketplace'
    a=X.rec(d,id,'assertion','evidence:assertion_amendment',{'operation'=>operation,'issuer_source_id'=>'report','assertion_namespace'=>'synthetic-marketplace'},subject:subject)
    a['times']['published']=X.time('2026-09-18T00:00:00Z',id,id,'/records/'+id+'/published')
    if receipt
      r=X.rec(d,id+'-receipt','occurrence','evidence:claim_receipt',{'collection_id'=>'fixture-collection'},subject:id)
      r['times']['received']=X.time(receipt,id,r['id'],'/records/'+r['id']+'/received')
    end
    a
  end
  def cutoff(value)
    X.time(value,'case-question','case-cutoff','/case/cutoff')
  end
  def test_eight_independently_declared_base_questions_have_expected_result_forms
    [F.rdp,F.profile,F.profile('issuer_validity'),F.profile('short_lived'),F.marketplace].each do |d|
      r=evaluate(d); assert_equal 'complete',r['status']; assert_equal %w[p1-domain p1-ip],targets(r),d['pattern']
      assert_equal %w[inet:fqdn inet:ipv4],r['results'].map{|x|x['form']}.sort
      assert r['results'].all?{|x|x.dig('fields','evidence_mode')=='evidence_only'}
    end
    assert_equal ['p1-domain'],targets(evaluate(F.reuse))
    assert_equal ['sample'],targets(evaluate(F.c2))
    assert_equal %w[evidence:ct_wildcard_scope inet:fqdn],evaluate(F.ct_names)['results'].map{|v|v['form']}.sort
  end
  def test_checked_in_contracts_reproduce_the_explicit_factory_and_are_compilable
    C.all_contracts.each do |c|
      actual=JSON.parse(File.read(File.join(C::ROOT,'contracts/semantics',c['pattern']['id']+'.json')))
      assert_equal c,actual
      assert_equal c,EveryPivot::SemanticContract.compile(actual)
    end
  end
  def test_RDP_requires_actual_protocol_and_material_not_generic_TLS_or_SPKI
    d=F.rdp; get(d,'p1-service')['attributes']['protocol']='tls'; empties(reseal(d))
    d=F.rdp; get(d,'p1')['attributes']['observed_state']='planned_scan'; empties(reseal(d))
    d=F.rdp; d['query']['parameters']['selector']=get(d,'certificate')['attributes']['spki_selector']
    assert_raises(EveryPivot::SemanticEvaluator::UnsupportedInput){evaluate(d)}
    d=F.rdp; get(d,'p1')['attributes']['certificate_selector']['value']='d'*64; empties(reseal(d))
  end
  def test_RDP_occurrence_period_is_not_refreshed_by_receipt_or_query
    d=F.rdp; get(d,'p1')['times']['occurred']['value']='2024-12-03T12:00:00Z'; empties(reseal(d),'outside_scope')
    d['query']['parameters']['period']={'start'=>'2024-12-01','end'=>'2024-12-31'}
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d))
    get(d,'p1')['times'].delete('occurred'); empties(reseal(d),'unresolved')
  end
  def test_unknown_optional_address_retains_supported_name_presentation
    d=F.rdp
    get(d,'p1-service')['attributes'].delete('address_record')
    get(d,'p1')['attributes'].delete('address_selector')
    assert_equal ['p1-domain'],targets(evaluate(reseal(d)))
    get(d,'p1-name')['attributes']['basis']='certificate_san'
    empties(reseal(d))
  end
  def test_explicit_endpoint_filter_cannot_be_evaded_by_FQDN_display
    d=F.rdp; F.classify(d,'cdn','p1-ip','cdn_edge'); reseal(d)
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d))
    d['query']['parameters']['exclude_cdn_address']=true
    r=empties(d,'suppressed'); assert r['diagnostics'].any?{|x|x['projected_result']}
    F.classify(d,'opposition','p1-ip','cdn_edge','not_member')
    r=evaluate(reseal(d)); assert_equal %w[p1-domain p1-ip],targets(r)
    assert_equal 'qualified_evidence_with_gaps',r['outcome']
  end
  def test_explicit_contested_classification_cannot_be_cleared_by_nonmembership
    d=F.rdp; F.classify(d,'nonmember','p1-ip','cdn_edge','not_member')
    d['query']['parameters']['exclude_cdn_address']=true
    r=evaluate(reseal(d)); assert_equal %w[p1-domain p1-ip],targets(r)
    assert_equal 'qualified_evidence',r['outcome']
    F.classify(d,'contested','p1-ip','cdn_edge','contested')
    r=evaluate(reseal(d)); assert_equal %w[p1-domain p1-ip],targets(r)
    assert_equal 'qualified_evidence_with_gaps',r['outcome']
    assert r['results'].all?{|v|v['policy_evaluations'].any?{|p|p.dig('decision','status')=='unresolved'}}
    d=F.rdp; F.classify(d,'contested','p1-ip','cdn_edge','contested'); d['query']['parameters']['exclude_cdn_address']=true
    r=evaluate(reseal(d)); assert_equal %w[p1-domain p1-ip],targets(r)
    assert_equal 'qualified_evidence_with_gaps',r['outcome']
  end
  def test_nonmembership_of_a_different_class_cannot_clear_the_selected_filter
    d=F.rdp; F.classify(d,'cdn','p1-ip','cdn_edge','member')
    F.classify(d,'not-a-sensor','p1-ip','research_sensor','not_member')
    d['query']['parameters']['exclude_cdn_address']=true
    empties(reseal(d),'suppressed')
  end
  def test_old_selected_seed_reference_does_not_require_a_new_seed_presentation
    %w[certificate_name observed_presentation].each do |basis|
      d=F.reuse(basis); r=evaluate(d)
      assert_equal ['p1-domain'],targets(r),r['diagnostics'].inspect
      assert_equal [basis],r['results'].map{|x|x.dig('fields','reference_basis')}.uniq
      get(d,'p1')['times']['occurred']['value']='2024-12-03T12:00:00Z'
      empties(reseal(d),'outside_scope')
    end
  end
  def test_renewed_certificate_sharing_key_is_only_explicit_SPKI_reuse
    d=F.reuse
    get(d,'certificate')['attributes']['certificate_selector']['value']='d'*64
    get(d,'p1')['attributes']['certificate_selector']['value']='d'*64
    empties(reseal(d))
    d['query']['parameters']['selector']=get(d,'seed')['attributes']['spki_selector']
    assert_equal ['p1-domain'],targets(evaluate(d))
    assert_equal ['spki_sha256'],evaluate(d)['results'].map{|v|v.dig('fields','comparison_kind')}.uniq
    get(d,'certificate')['attributes']['spki_selector']['value']='e'*64
    empties(reseal(d))
  end
  def test_seed_domain_association_and_candidate_presentation_are_separate_required_legs
    d=F.reuse; get(d,'historical-reference')['attributes']['name_selector']['value']='unrelated.test'; empties(reseal(d))
    d=F.reuse; get(d,'historical-reference')['attributes']['association_basis']='report_co_mention'; empties(reseal(d))
    d=F.reuse; get(d,'p1-name')['attributes']['service_context_id']='different-vhost'; empties(reseal(d))
  end
  def test_intermediate_certificate_exclusion_leaves_an_independent_path
    d=F.reuse; F.classify(d,'managed','certificate','mass_managed_certificate')
    F.cert(d,'other-certificate','a'*64,'b'*64); F.present(d,'p2','other-certificate')
    d['query']['parameters']['exclude_certificate_class']=true
    r=evaluate(reseal(d)); assert_equal ['p2-domain'],targets(r)
    assert r['diagnostics'].any?{|x|x['status']=='suppressed'}
  end
  def test_CT_names_and_wildcards_are_distinct_and_unrelated_SAN_is_out_of_scope
    r=evaluate(F.ct_names)
    assert_equal ['domain'],r['results'].select{|v|v['form']=='inet:fqdn'}.map{|v|v['id']}
    clue=r['results'].find{|v|v['form']=='evidence:ct_wildcard_scope'}
    assert_equal '*.example.test',clue.dig('fields','name','value')
    refute r['results'].any?{|v|v['id']=='unrelated'}
    d=F.ct_names; get(d,'concrete-name')['attributes']['name_selector']['value']='guessed.example.test'; empties_concrete=evaluate(reseal(d))['results'].select{|v|v['form']=='inet:fqdn'}
    assert_empty empties_concrete
    assert_equal 1,evaluate(d)['results'].count{|v|v['form']=='evidence:ct_wildcard_scope'}
  end
  def test_CT_record_history_is_not_validity_or_collection_receipt
    d=F.ct_names; get(d,'ct-record')['times']['occurred']['value']='2024-12-03T12:00:00Z'; empties(reseal(d),'outside_scope')
    d['query']['parameters']['period']={'start'=>'2024-12-01','end'=>'2024-12-31'}
    assert_equal 2,evaluate(d)['results'].length
    get(d,'ct-record')['attributes']['event_meaning']='certificate_not_before'
    empties(reseal(d))
  end
  def test_CT_record_correspondence_and_wildcard_grammar_are_required
    d=F.ct_names; get(d,'concrete-name')['attributes']['ct_record']='another-record'
    assert_equal ['evidence:ct_wildcard_scope'],evaluate(reseal(d))['results'].map{|r|r['form']}
    d=F.ct_names; get(d,'wildcard-name')['attributes']['name_selector']['value']='*foo.example.test'
    assert_raises(EveryPivot::SemanticCertificateProfiles::InvalidInput){evaluate(reseal(d))}
    d=F.ct_names; get(d,'ct-record')['attributes']['certificate_selector']['value']='e'*64; empties(reseal(d))
  end
  def test_CT_class_context_is_not_implied_by_wildcard_or_common_issuer
    d=F.ct_names; d['query']['parameters']['exclude_shared_hosting']=true
    assert_equal 2,evaluate(d)['results'].length
    F.classify(d,'shared','certificate','shared_cdn_or_hosting_certificate')
    empties(reseal(d),'suppressed')
  end
  def test_each_characteristic_profile_is_computed_from_its_selected_fields
    d=F.profile; get(d,'certificate')['attributes']['profile_fields']['subject.common_name']['value']='anything.test'
    assert_equal %w[p1-domain p1-ip],targets(evaluate(reseal(d)))
    get(d,'certificate')['attributes']['profile_fields']['subject.organization']['value']='Different Organization'; empties(reseal(d))
    d=F.profile('issuer_validity'); get(d,'certificate')['attributes']['profile_fields']['issuer.organization']['value']='Different Issuer'; empties(reseal(d))
    d=F.profile('short_lived'); get(d,'certificate')['attributes']['profile_fields']['declared_validity.not_after']['value']='2026-10-01T00:00:00Z'; empties(reseal(d))
  end
  def test_profile_definition_and_matching_material_must_be_preserved_and_joined
    d=F.profile; d['preserved_source_bytes'].delete('bytes-profile'); empties(d,'unresolved')
    d=F.profile; d['preserved_source_bytes']['bytes-profile']+=' '
    assert_raises(EveryPivot::SemanticCertificateProfiles::InvalidInput){evaluate(d)}
    d=F.profile; get(d,'p1')['attributes']['certificate_selector']['value']='e'*64; empties(reseal(d))
    d=F.profile; get(d,'certificate')['attributes']['profile_fields'].delete('subject.organization'); empties(reseal(d),'unresolved')
  end
  def test_profile_duration_and_presentation_period_do_not_substitute_for_each_other
    d=F.profile('short_lived')
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d)) # September17 after declared September7 expiry remains factual presentation.
    get(d,'p1')['times']['occurred']['value']='2019-05-15T12:00:00Z'; empties(reseal(d),'outside_scope')
    d['query']['parameters']['period']={'start'=>'2019-04-01','end'=>'2019-06-30'}
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d)) # Applying today's profile does not assert it existed in2019.
  end
  def test_matching_duration_does_not_manufacture_ACME_classification
    d=F.profile('short_lived'); d['query']['parameters']['exclude_certificate_class']=true
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d))
    F.classify(d,'acme','certificate','common_acme_short_lived_certificate')
    empties(reseal(d),'suppressed')
  end
  def test_marketplace_selected_historical_sale_allows_preexisting_certificate_and_mixed_name
    d=F.marketplace; r=evaluate(d)
    assert_equal %w[p1-domain p1-ip],targets(r)
    assert_equal ['sold-domain'],r['results'].map{|v|v.dig('fields','sold_domain')}.uniq
    assert_equal 'candidate.example.test',get(d,'p1-domain').dig('attributes','selector','value')
    assert r['results'].all?{|v|v.dig('fields','sale_claim').include?('not confirmed sale')}
  end
  def test_marketplace_offer_wrong_domain_and_newer_sale_cannot_qualify
    d=F.marketplace; get(d,'sale')['attributes']['assertion_kind']='offer'; empties(reseal(d))
    d=F.marketplace; get(d,'sale')['attributes']['domain_selector']['value']='different.test'; empties(reseal(d))
    d=F.marketplace; get(d,'sale')['times']['reported_event']['value']='2026-09-20T00:00:00Z'; empties(reseal(d))
    d=F.marketplace; get(d,'sale')['times'].delete('reported_event'); empties(reseal(d),'unresolved')
  end
  def test_marketplace_exact_material_not_same_key_or_CT_only
    d=F.marketplace; get(d,'p1')['attributes']['certificate_selector']['value']='d'*64; empties(reseal(d))
    d=F.marketplace; get(d,'p1')['attributes']['observed_state']='certificate_named_in_CT'; empties(reseal(d))
    d=F.marketplace; get(d,'p1')['times']['occurred']['value']='2024-12-03T12:00:00Z'; empties(reseal(d),'outside_scope')
  end
  def test_marketplace_literal_withdrawn_report_is_retained_unless_filter_selected
    d=F.marketplace; get(d,'sale')['attributes']['report_status']='withdrawn'; reseal(d)
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d))
    d['query']['parameters']['exclude_withdrawn_reports']=true; empties(d,'suppressed')
    get(d,'sale')['attributes']['report_status']='cancelled'; assert_equal %w[p1-domain p1-ip],targets(evaluate(reseal(d)))
  end
  def test_marketplace_actual_withdrawal_context_and_filter_use_the_selected_sale
    d=F.marketplace; amendment(d); reseal(d)
    r=evaluate(d); assert_equal %w[p1-domain p1-ip],targets(r)
    assert_equal 'reported',get(d,'sale').dig('attributes','report_status') # Immutable original is not rewritten.
    assert r['results'].all?{|v|v.dig('amendment_evaluation','states').any?{|s|s['assertion_id']=='sale' && s['state']=='withdrawn'}}
    d['query']['parameters']['exclude_withdrawn_reports']=true
    r=empties(d,'suppressed')
    assert r['diagnostics'].any?{|v|v['projected_result']}
    d=F.marketplace; amendment(d,'presentation-withdrawal','p1'); d['query']['parameters']['exclude_withdrawn_reports']=true
    assert_equal %w[p1-domain p1-ip],targets(evaluate(reseal(d))) # Other-witness context is retained but not a sale-status filter.
  end
  def test_marketplace_amendment_publication_is_not_collection_knowledge
    d=F.marketplace; amendment(d); d['query']['parameters']['exclude_withdrawn_reports']=true; reseal(d)
    d['query']['knowledge_cutoff']=cutoff('2026-09-21T00:00:00Z')
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d)) # Published18th, received25th.
    d['query']['knowledge_cutoff']=cutoff('2026-09-26T00:00:00Z')
    empties(d,'suppressed')
    d=F.marketplace; amendment(d,'withdrawal','sale','withdraw',nil); d['query']['parameters']['exclude_withdrawn_reports']=true
    d['query']['knowledge_cutoff']=cutoff('2026-09-26T00:00:00Z')
    empties(reseal(d),'unresolved')
  end
  def test_marketplace_dispute_and_conflicting_reinstatement_do_not_choose_a_winner
    d=F.marketplace; amendment(d); amendment(d,'dispute','sale','dispute'); reseal(d)
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d))
    d['query']['parameters']['exclude_withdrawn_reports']=true; empties(d,'unresolved')
    d=F.marketplace; amendment(d); amendment(d,'reinstatement','sale','reinstate'); d['query']['parameters']['exclude_withdrawn_reports']=true
    empties(reseal(d),'unresolved')
    get(d,'reinstatement')['attributes']['supersedes_amendments']=['withdrawal']
    assert_equal %w[p1-domain p1-ip],targets(evaluate(reseal(d)))
  end
  def test_as_known_queries_need_actual_support_availability_after_occurrence
    d=F.rdp; d['query']['knowledge_cutoff']=cutoff('2026-09-19T00:00:00Z'); empties(d)
    d['query']['knowledge_cutoff']=cutoff('2026-09-21T00:00:00Z')
    assert_equal %w[p1-domain p1-ip],targets(evaluate(d))
    get(d,'p1')['times']['collection_available']['value']='2026-09-01T00:00:00Z'
    empties(reseal(d)) # Impossible source chronology does not backdate known presentation.
  end
  def test_C2_direct_encounter_and_indirect_address_lead_have_separate_finding_claims
    direct=evaluate(F.c2); assert_equal ['sample'],targets(direct)
    assert_equal 'sample_associated_certificate_encounter',direct['results'][0].dig('fields','claim')
    indirect=evaluate(F.c2('endpoint_lead','address')); assert_equal ['sample'],targets(indirect)
    assert_equal 'endpoint_mediated_certificate_association_lead',indirect['results'][0].dig('fields','claim')
    refute_equal direct['results'][0]['identity'],indirect['results'][0]['identity']
  end
  def test_C2_finding_period_retains_old_activity_and_does_not_refresh_on_replay
    d=F.c2; r=evaluate(d); assert_equal ['sample'],targets(r)
    assert_equal '2024-12-03T12:00:00Z',r['results'][0].dig('fields','contact_time','value')
    d['claims'][0]['at']='2024-12-10T00:00:00Z'
    # Required source facts were first available2026, so a purported2024 completion cannot backdate them.
    empties(reseal(d))
    d=F.c2; d['query']['parameters']['period']={'start'=>'2026-09-12','end'=>'2026-09-30'}
    empties(d,'outside_scope')
    d['claims'] << d['claims'][0].merge('event'=>'replay','at'=>'2026-09-20T00:00:00Z')
    empties(reseal(d),'outside_scope')
  end
  def test_C2_scan_or_report_cooccurrence_cannot_supply_sample_attribution
    d=F.c2; get(d,'encounter')['attributes']['connection_id']='another-connection'; empties(reseal(d))
    d=F.c2; get(d,'contact')['attributes']['attribution']='same_sandbox_report'; empties(reseal(d))
    d=F.c2; get(d,'sample')['attributes']['artifact_selector']['value']='d'*64; empties(reseal(d))
    d=F.c2('endpoint_lead','address'); get(d,'contact')['attributes']['service_context_id']='other-vhost'
    assert_equal ['sample'],targets(evaluate(reseal(d)))
    d=F.c2('endpoint_lead','service_context'); get(d,'contact')['attributes']['service_context_id']='other-vhost'; empties(reseal(d))
  end
  def test_C2_missing_or_unknown_complete_history_cannot_be_first_availability
    d=F.c2; d['preserved_source_bytes'].delete('manifest'); empties(d,'unresolved')
    d=F.c2; X.seal(d,'unknown'); empties(d,'unresolved')
    d=F.c2; get(d,'encounter')['times'].delete('collection_available'); empties(reseal(d),'unresolved')
  end
  def test_C2_controlled_context_is_supported_occurrence_scope_not_lab_provenance
    d=F.c2; d['query']['parameters']['exclude_controlled_occurrence']=true
    assert_equal ['sample'],targets(evaluate(d))
    F.classify(d,'controlled','contact','controlled_sample_connection')
    empties(reseal(d),'suppressed')
  end
  def test_C2_normalized_alias_rows_and_processing_versions_do_not_refresh_same_occurrence
    d=F.c2
    %w[p1 contact encounter].each do |id|
      copy=X.deep(get(d,id)); copy['id']=id+'-copy'
      copy['subject']='contact-copy' if id=='encounter'
      copy['object']='p1-copy' if id=='encounter'
      copy['evidence']=[{'source_id'=>'report','field'=>'/records/'+copy['id']}]
      copy['attributes']['tool_version']='later-parser-version'
      copy['attributes'].each_value do |value|
        next unless value.is_a?(Hash) && value['provenance']
        value['provenance']['record_id']=copy['id']; value['provenance']['field']='/records/'+copy['id']+'/selector'
      end
      copy['times'].each do |key,time|
        time['field']='/records/'+copy['id']+'/'+key
        time['binding']['object']=copy['id'] if time['binding']['object']==id
        time['binding']['occurrence']=copy['id'] if time['binding']['occurrence']==id
      end
      d['evidence']['records'] << copy
    end
    d['claims'] << d['claims'][0].merge('event'=>'later-materialization','at'=>'2026-09-20T00:00:00Z',
      'support'=>%w[certificate sample p1-copy p1-service p1-ip contact-copy encounter-copy])
    d['query']['parameters']['period']={'start'=>'2026-09-12','end'=>'2026-09-30'}
    empties(reseal(d),'outside_scope')
  end
  def test_C2_direct_encounter_has_no_irrelevant_endpoint_scope_switch
    d=F.c2; d['query']['parameters']['endpoint_scope']='address'
    assert_raises(EveryPivot::SemanticEvaluator::InvalidInput){evaluate(d)}
    d=F.c2('endpoint_lead','address'); d['query']['parameters'].delete('endpoint_scope')
    assert_raises(EveryPivot::SemanticEvaluator::InvalidInput){evaluate(d)}
  end
  def test_invalid_scope_and_partial_work_do_not_appear_as_complete_absence
    d=F.rdp; d['query']['parameters'].delete('period')
    assert_raises(EveryPivot::SemanticEvaluator::InvalidInput){evaluate(d)}
    d=F.rdp; d['query']['limits']['max_bindings']=1
    r=evaluate(d); assert_equal 'partial',r['status']; assert_equal false,r['coverage']['exhaustive_for_supplied_input']
    d=F.ct_names; d['query']['limits']['max_results']=1
    r=evaluate(d); assert_equal 'partial',r['status']; assert_equal true,r['coverage']['result_selection']['truncated']
  end
end
