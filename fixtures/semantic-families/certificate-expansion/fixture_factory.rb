# frozen_string_literal: true
require_relative '../extraction/fixture_factory'
require_relative 'contract_factory'
module CertificateExpansionFixtures
  X=ExtractionFixtures
  C=CertificateExpansionContracts
  module_function
  def get(d,id); X.get(d,id); end
  def base(id)
    d=X.base(id)
    d['query']['parameters']={'period'=>{'start'=>'2026-09-01','end'=>'2026-09-30'},'source_ids'=>%w[report manifest]}
    d
  end
  def provenance(id,field)
    {'source'=>'report','record_id'=>id,'source_revision'=>'r1','field'=>'/records/'+id+'/'+field,'basis'=>'reported'}
  end
  def selector(d,id,field,kind,value)
    s={'kind'=>kind,'value'=>value,'provenance'=>provenance(id,field)}
    case kind
    when 'certificate_sha256','spki_sha256'
      s.merge!('algorithm'=>'sha256','representation'=>'der','normalization'=>'exact_der_v1','scope'=>kind=='certificate_sha256' ? 'whole_certificate' : 'subject_public_key_info')
    when 'artifact_sha256' then s.merge!('algorithm'=>'sha256','representation'=>'bytes','normalization'=>'exact_bytes_v1','scope'=>'whole_artifact')
    when 'ipv4' then s.merge!('representation'=>'dotted_decimal','normalization'=>'strict_dotted_decimal_v1')
    else s.merge!('representation'=>'ascii','normalization'=>'dns_ascii_lower_v1')
    end
    s
  end
  def cert(d,id='certificate',digest='a'*64,key='b'*64)
    X.rec(d,id,'entity','x509:cert',{'artifact_role'=>'certificate','certificate_selector'=>selector(d,id,'certificate_selector','certificate_sha256',digest),
      'spki_selector'=>selector(d,id,'spki_selector','spki_sha256',key)})
  end
  def domain(d,id,value)
    X.rec(d,id,'entity','inet:fqdn',{'selector'=>selector(d,id,'selector','dns_name',value)})
  end
  def copy_selector(d,target,field,origin,origin_field='certificate_selector')
    s=X.deep(get(d,origin)['attributes'][origin_field]); s['provenance']=provenance(target,field); s
  end
  def present(d,id='p1',certificate='certificate',protocol='tls',at='2026-09-17T12:00:00Z',ip='192.0.2.10',name='candidate.example.test')
    sid=id+'-service'; iid=id+'-ip'; did=id+'-domain'; nid=id+'-name'
    X.rec(d,iid,'entity','inet:ipv4',{'selector'=>selector(d,iid,'selector','ipv4',ip)})
    X.rec(d,sid,'entity','inet:service',{'context_id'=>id+'-context','address_record'=>iid,'protocol'=>protocol,'port'=>protocol=='rdp' ? 3389 : 443})
    p=X.rec(d,id,'occurrence','network:certificate_presentation',{'certificate_selector'=>copy_selector(d,id,'certificate_selector',certificate),
      'address_selector'=>selector(d,id,'address_selector','ipv4',ip),'service_context_id'=>id+'-context','occurrence_id'=>id+'-actual-occurrence',
      'observed_state'=>'certificate_presented','certificate_role'=>'leaf','vantage'=>'synthetic-observer'},subject:certificate,object:sid,available: at.start_with?('2024') ? '2026-09-10T00:00:00Z' : '2026-09-20T00:00:00Z')
    p['times']['occurred']=X.time(at,id,id,'/records/'+id+'/occurred')
    domain(d,did,name)
    X.rec(d,nid,'assertion','network:presentation_name',{'service_record'=>sid,'service_context_id'=>id+'-context','basis'=>'requested_sni',
      'name_selector'=>selector(d,nid,'name_selector','dns_name',name)},subject:id,object:did,available: at.start_with?('2024') ? '2026-09-10T00:00:00Z' : '2026-09-20T00:00:00Z')
    p
  end
  def named(d,id,certificate,domain_id,ct=nil,kind='dns_name',value=nil)
    value ||= get(d,domain_id).dig('attributes','selector','value') if domain_id
    attrs={'certificate_selector'=>copy_selector(d,id,'certificate_selector',certificate),'name_selector'=>selector(d,id,'name_selector',kind,value),
      'field_kind'=>'san_dns','association_basis'=>ct ? 'ct_reported_certificate_field' : 'reported_certificate_field'}
    attrs['ct_record']=ct if ct
    X.rec(d,id,'assertion','x509:certificate_name',attrs,subject:certificate,object:domain_id)
  end
  def classify(d,id,subject,klass,membership='member')
    X.rec(d,id,'assertion','evidence:classification',{'class_id'=>klass,'membership'=>membership,'policy_basis'=>'selected_source_revision'},subject:subject)
  end
  def seal(d)
    d['query']['parameters']['source_ids']=d['evidence']['sources'].map{|s|s['id']}
    X.seal(d)
  end
  def rdp
    d=base('OSINT_RDP_CERT_THUMBPRINT_CLUSTER'); cert(d)
    present(d,'p1','certificate','rdp')
    d['query']['parameters']['selector']=X.deep(get(d,'certificate').dig('attributes','certificate_selector'))
    seal(d)
  end
  def reuse(basis='certificate_name',kind='certificate_sha256')
    d=base('CTI_CERT_REUSE_FQDN_CLUSTER'); cert(d,'seed'); cert(d)
    domain(d,'seed-domain','seed.example.test')
    if basis=='certificate_name'
      named(d,'historical-reference','seed','seed-domain')
      reference='historical-reference'
    else
      present(d,'reference','seed','tls','2024-12-03T12:00:00Z','192.0.2.20','seed.example.test')
      get(d,'reference-name')['object']='seed-domain'
      reference='reference-name'
    end
    present(d)
    field=kind=='spki_sha256' ? 'spki_selector' : 'certificate_selector'
    d['query']['parameters'].merge!('source_domain'=>'seed-domain','source_certificate'=>'seed','reference'=>reference,'reference_basis'=>basis,
      'selector'=>X.deep(get(d,'seed').dig('attributes',field)))
    seal(d)
  end
  def ct_names
    d=base('OSINT_CRT_SH_SUBDOMAINS'); cert(d)
    ct=X.rec(d,'ct-record','occurrence','x509:ct_record',{'certificate_selector'=>copy_selector(d,'ct-record','certificate_selector','certificate'),
      'log_id'=>'synthetic-log','record_id'=>'entry-17','event_meaning'=>'source_reported_record_date','verification'=>'source_reported_not_log_verified'},subject:'certificate',available:'2026-09-20T00:00:00Z')
    ct['times']['occurred']=X.time('2026-09-17T12:00:00Z','certificate','ct-record','/records/ct-record/occurred')
    domain(d,'domain','login.example.test'); named(d,'concrete-name','certificate','domain','ct-record')
    named(d,'wildcard-name','certificate',nil,'ct-record','dns_wildcard','*.example.test')
    domain(d,'unrelated','elsewhere.test'); named(d,'other-name','certificate','unrelated','ct-record')
    d['query']['parameters']['seed_selector']=selector(d,'query','selector','dns_name','example.test')
    seal(d)
  end
  def profile(family='subject')
    id={'subject'=>'CTI_TLS_CERT_SUBJECT_PROFILE_TO_INFRA','issuer_validity'=>'CTI_CERT_ISSUER_VALIDITY_CLUSTER','short_lived'=>'CTI_SHORT_LIVED_CERT_INFRA_CLUSTER'}[family]
    d=base(id); certificate=cert(d); present(d)
    fields={'subject.organization'=>['Example Organization','utf8_string'],'subject.common_name'=>['different.example.test','utf8_string'],
      'issuer.organization'=>['Example Issuer','utf8_string'],'declared_validity.not_before'=>['2026-09-01T00:00:00Z','x509_utc_second'],
      'declared_validity.not_after'=>['2026-09-07T00:00:00Z','x509_utc_second']}
    certificate['attributes']['profile_fields']=fields.each_with_object({}){|(key,pair),out|out[key]={'value'=>pair[0],'representation'=>pair[1],'provenance'=>provenance('certificate','profile_fields/'+key)}}
    criteria=[]
    criteria << {'field'=>'subject.organization','comparison'=>'literal_utf8_v1','value'=>'Example Organization'} if family=='subject'
    criteria << {'field'=>'issuer.organization','comparison'=>'literal_utf8_v1','value'=>'Example Issuer'} if family=='issuer_validity'
    criteria << {'field'=>'declared_validity.duration_seconds','comparison'=>'inclusive_seconds_range_v1','min'=>0,'max'=>604800} unless family=='subject'
    definition={'contract'=>'everypivot.certificate_profile','version'=>'1.0','id'=>'selected-fixture-profile','revision'=>'profile-r1','family'=>family,'combination'=>'all','criteria'=>criteria}
    profile=X.artifact(d,'profile','x509:comparison_profile',JSON.generate(definition))
    profile['attributes']['content'].merge!('source_revision'=>'r1','field'=>'/')
    profile['attributes']['content'].delete('locator')
    d['query']['parameters']['profile']='profile'
    seal(d)
  end
  def marketplace
    d=base('CTI_MARKETPLACE_SOLD_DOMAIN_CERT_CLUSTER'); cert(d); present(d)
    domain(d,'sold-domain','sold.example.test'); named(d,'sale-name','certificate','sold-domain')
    sale=X.rec(d,'sale','assertion','marketplace:sale_report',{'assertion_kind'=>'reported_sale','assertion_namespace'=>'synthetic-marketplace',
      'report_status'=>'reported','domain_selector'=>selector(d,'sale','domain_selector','dns_name','sold.example.test')},subject:'sold-domain')
    sale['times']['reported_event']=X.time('2024-12-01T12:00:00Z','sale','sale','/records/sale/reported_event')
    d['query']['parameters']['sale']='sale'
    seal(d)
  end
  def c2(purpose='encounter',scope='service_context',kind='certificate_sha256')
    d=base('CTI_C2_CERT_TO_SAMPLE_CLUSTER'); cert(d)
    present(d,'p1','certificate','tls','2024-12-03T12:00:00Z')
    X.rec(d,'sample','entity','file:bytes',{'artifact_selector'=>selector(d,'sample','artifact_selector','artifact_sha256','c'*64)})
    contact=X.rec(d,'contact','occurrence','sample:network_contact',{'artifact_selector'=>copy_selector(d,'contact','artifact_selector','sample','artifact_selector'),
      'address_selector'=>selector(d,'contact','address_selector','ipv4','192.0.2.10'),'sample_execution_id'=>'actual-run-1','connection_id'=>'actual-connection-1','occurrence_namespace'=>'synthetic-attributed-run-source',
      'attribution'=>'source_reported_sample_connection','service_context_id'=>'p1-context'},subject:'sample',object:'p1-service')
    contact['times']['occurred']=X.time('2024-12-03T12:00:00Z','sample','contact','/records/contact/occurred')
    if purpose=='encounter'
      X.rec(d,'encounter','assertion','sample:certificate_encounter',{'sample_execution_id'=>'actual-run-1','connection_id'=>'actual-connection-1','certificate_role'=>'leaf',
        'certificate_selector'=>copy_selector(d,'encounter','certificate_selector','certificate'),'evidence_status'=>'attributable_source_report'},subject:'contact',object:'p1')
    end
    field=kind=='spki_sha256' ? 'spki_selector' : 'certificate_selector'
    scope='service_context' if purpose=='encounter'
    d['query']['parameters'].merge!('selector'=>X.deep(get(d,'certificate').dig('attributes',field)),'purpose'=>purpose,'history'=>'history')
    d['query']['parameters']['endpoint_scope']=scope if purpose=='endpoint_lead'
    identity=[{'kind'=>'artifact_sha256','comparison'=>['sha256','bytes','exact_bytes_v1','whole_artifact'],'value'=>'c'*64},
      {'kind'=>kind,'comparison'=>['sha256','der','exact_der_v1',kind=='spki_sha256' ? 'subject_public_key_info' : 'whole_certificate'],'value'=>kind=='spki_sha256' ? 'b'*64 : 'a'*64},
      purpose,scope,'synthetic-attributed-run-source','actual-run-1','actual-connection-1','p1-actual-occurrence','leaf']
    support=%w[certificate sample p1 p1-service p1-ip contact]
    support << 'encounter' if purpose=='encounter'
    X.claim(d,identity,support)
    seal(d)
  end
end
