# frozen_string_literal: true
require 'json'
module CertificateExpansionContracts
  ROOT = File.expand_path('../../..', __dir__)
  module_function
  def ref(x); {'ref' => x}; end
  def lit(x); {'literal' => x}; end
  def par(x); {'param' => x}; end
  def all(*x); {'op' => 'all', 'args' => x.flatten}; end
  def eq(a,b); {'op' => 'eq', 'left' => a, 'right' => b}; end
  def one(a,b); {'op' => 'in', 'left' => a, 'right' => lit(b)}; end
  def text(a); {'op' => 'nonblank_text', 'value' => a}; end
  def typed(a,b,kind)
    all(eq(ref(a+'.kind'),lit(kind)),eq(ref(b+'.kind'),lit(kind)),{'op'=>'typed_equal','left'=>ref(a),'right'=>ref(b)})
  end
  def self_typed(a,kind); typed(a,a,kind); end
  def bind(name,kind,type,*predicates)
    predicates << {'op'=>'all_in','left'=>{'evidence_sources'=>name},'right'=>par('source_ids')}
    {'name'=>name,'kind'=>kind,'types'=>Array(type),'where'=>all(*predicates)}
  end
  def parameter(type,description,required=true,extra={}); {'type'=>type,'required'=>required,'description'=>description}.merge(extra); end
  def scope_parameters
    {'period'=>parameter('period','Explicit analyst/case inclusive UTC period; this pattern declares its own event purpose.'),
     'source_ids'=>parameter('string_array','Exact admitted source-revision IDs; no external or independent-source completeness claim.',true,{'min_items'=>1,'unique_items'=>true,'item_reference'=>'source'})}
  end
  def certificate_binding(name='certificate')
    bind(name,'entity','x509:cert',self_typed(name+'.attributes.certificate_selector','certificate_sha256'),
      eq(ref(name+'.attributes.artifact_role'),lit('certificate')))
  end
  def selector_binding(name='certificate',kind='certificate_sha256')
    field=kind=='spki_sha256' ? 'spki_selector' : 'certificate_selector'
    bind(name,'entity','x509:cert',self_typed(name+'.attributes.certificate_selector','certificate_sha256'),
      eq(ref(name+'.attributes.artifact_role'),lit('certificate')),
      eq(ref(name+'.attributes.'+field+'.kind'),lit(kind)),{'op'=>'typed_equal','left'=>ref(name+'.attributes.'+field),'right'=>par('selector')})
  end
  def presentation(form,prefix='',certificate='certificate',protocol=nil)
    p,s,ip,n,d=%w[presentation service ip name_association domain].map{|v|prefix+v}
    predicates=[eq(ref(p+'.subject'),ref(certificate+'.id')),typed(p+'.attributes.certificate_selector',certificate+'.attributes.certificate_selector','certificate_sha256'),
      eq(ref(p+'.attributes.observed_state'),lit('certificate_presented')),text(ref(p+'.attributes.occurrence_id')),
      text(ref(p+'.attributes.vantage')),one(ref(p+'.attributes.certificate_role'),%w[leaf intermediate chain_member])]
    bindings=[bind(p,'occurrence','network:certificate_presentation',*predicates),
      bind(s,'entity','inet:service',eq(ref(s+'.id'),ref(p+'.object')),eq(ref(s+'.attributes.context_id'),ref(p+'.attributes.service_context_id')),
        text(ref(s+'.attributes.context_id')),text(ref(s+'.attributes.protocol')))]
    bindings.last['where']['args'] << eq(ref(s+'.attributes.protocol'),lit(protocol)) if protocol
    ipbind=bind(ip,'entity','inet:ipv4',eq(ref(ip+'.id'),ref(s+'.attributes.address_record')),
      typed(ip+'.attributes.selector',p+'.attributes.address_selector','ipv4'))
    ipbind['optional']=true if form=='inet:fqdn'
    bindings << ipbind
    if form=='inet:fqdn'
      bindings << bind(n,'assertion','network:presentation_name',eq(ref(n+'.subject'),ref(p+'.id')),
        eq(ref(n+'.attributes.service_record'),ref(s+'.id')),eq(ref(n+'.attributes.service_context_id'),ref(s+'.attributes.context_id')),
        one(ref(n+'.attributes.basis'),%w[requested_sni requested_host source_reported_same_presentation]))
      bindings << bind(d,'entity','inet:fqdn',eq(ref(d+'.id'),ref(n+'.object')),typed(d+'.attributes.selector',n+'.attributes.name_selector','dns_name'))
    end
    bindings
  end
  def time_binding(value,object,occurrence); {'value'=>ref(value),'object'=>ref(object),'occurrence'=>ref(occurrence)}; end
  def finish(branch)
    branch['time_bindings'] ||= []
    branch['knowledge'] ||= []
    branch['knowledge_checks'] ||= []
    branch['bindings'].reject{|b|b['optional']}.each do |binding|
      name=binding['name']; value=name+'.times.collection_available'
      branch['knowledge'] << ref(value)
      branch['time_bindings'] << time_binding(value,name+'.id',name+'.attributes.availability_occurrence')
    end
    branch['time_bindings'].select{|b| b['value']['ref'].end_with?('.times.occurred')}.each do |binding|
      event=binding['value']['ref']; carrier=event.split('.').first
      next unless branch['bindings'].any?{|b|b['name']==carrier && !b['optional']}
      branch['knowledge_checks'] << {'op'=>'time_compare','operator'=>'lte','left'=>ref(event),'right'=>ref(carrier+'.times.collection_available')}
    end
    branch.delete('knowledge_checks') if branch['knowledge_checks'].empty?
    branch
  end
  def within(value); {'op'=>'within','value'=>ref(value),'period'=>par('period'),'quantifier'=>'contained'}; end
  def target_result(form,claim)
    target=form=='inet:ipv4' ? 'ip' : 'domain'
    {'mode'=>'bound','binding'=>target,'form'=>form,'identity'=>[ref(target+'.id'),ref('certificate.id'),ref('presentation.id')],
      'fields'=>{'claim'=>lit(claim),'certificate'=>ref('certificate.id'),'certificate_selector'=>ref('certificate.attributes.certificate_selector'),
        'presentation'=>ref('presentation.id'),'presentation_time'=>ref('presentation.times.occurred'),
        'certificate_role'=>ref('presentation.attributes.certificate_role'),'service'=>ref('service.id'),'service_context'=>ref('service.attributes.context_id'),
        'protocol'=>ref('service.attributes.protocol'),'reported_port'=>ref('service.attributes.port'),'vantage'=>ref('presentation.attributes.vantage'),
        'reported_requested_name'=>ref('presentation.attributes.requested_name'),
        'reported_termination_role'=>ref('presentation.attributes.termination_role'),'reported_intermediaries'=>ref('presentation.attributes.intermediaries'),
        'target_selector'=>ref(target+'.attributes.selector'),'evidence_mode'=>lit('evidence_only')}}
  end
  def add_class(branch,name,subject,class_id,filter_parameter,scope='path')
    binding=bind(name,'assertion','evidence:classification',eq(ref(name+'.subject'),ref(subject)),eq(ref(name+'.attributes.class_id'),lit(class_id)),
      eq(ref(name+'.attributes.policy_basis'),lit('selected_source_revision')))
    binding['optional']=true; branch['bindings'] << binding
    branch['policies'] ||= []
    branch['policies'] << {'id'=>name,'revision'=>'1','scope'=>scope,'subject'=>ref(subject),'default_enabled'=>false,'enabled_parameter'=>filter_parameter,
      'when'=>eq(ref(name+'.attributes.membership'),lit('member')),
      'allow_when'=>eq(ref(name+'.attributes.membership'),lit('not_member')),
      'conflict_when'=>eq(ref(name+'.attributes.membership'),lit('contested')),
      'reason'=>'Explicit selected-source-revision class filter; membership has no implicit historical, key, service-role or ownership transfer.'}
    branch['result']['fields'][name+'_membership']=ref(name+'.attributes.membership')
  end
  def contract(id,description,parameters,branches,anchor)
    {'contract'=>'everypivot.semantic_pattern','version'=>'1.0','pattern'=>{'id'=>id,'version'=>'3.0.0'},'description'=>description,
      'authority'=>'docs/UNRESOLVED_SEMANTICS.md#'+anchor,'parameters'=>parameters,'branches'=>branches.map{|b|finish(b)}}
  end
  def presentation_branch(id,form,bindings,claim,protocol=nil)
    {'id'=>id,'bindings'=>bindings+presentation(form,'','certificate',protocol),'where'=>within('presentation.times.occurred'),
      'time_bindings'=>[time_binding('presentation.times.occurred','presentation.id','presentation.id')],'result'=>target_result(form,claim)}
  end
  def rdp
    params=scope_parameters.merge('selector'=>parameter('selector','Exact whole-certificate SHA256; SPKI/key reuse is not this RDP thumbprint question.',true,{'selector_kinds'=>['certificate_sha256']}),
      'exclude_cdn_address'=>parameter('boolean','Explicit address-class filter; default retains contextual observations.',false))
    branches=%w[inet:ipv4 inet:fqdn].map do |form|
      b=presentation_branch(form=='inet:ipv4' ? 'rdp_ipv4' : 'rdp_fqdn',form,[selector_binding], 'observed_rdp_certificate_presentation','rdp')
      add_class(b,'cdn_address','ip.id','cdn_edge','exclude_cdn_address','occurrence'); b
    end
    contract('OSINT_RDP_CERT_THUMBPRINT_CLUSTER','Exact selected whole-certificate identity on actual RDP presentations in the selected occurrence period; no TLS-only, endpoint-control or current-use inference.',params,branches,'accepted-rdp-presentation-occurrence-window-purpose')
  end
  def profiles(id,family)
    class_id={'subject'=>'common_self_signed_or_default_subject','issuer_validity'=>'common_managed_certificate_profile','short_lived'=>'common_acme_short_lived_certificate'}[family]
    params=scope_parameters.merge('profile'=>parameter('record_id','Selected preserved versioned characteristic profile; no silent broadening.'),
      'exclude_certificate_class'=>parameter('boolean','Explicit supported class filter; profile match does not establish this class.',false),
      'exclude_infrastructure_class'=>parameter('boolean','Explicit supported shared-termination or CDN-address class filter.',false))
    branches=%w[inet:ipv4 inet:fqdn].map do |form|
      profile=bind('profile','entity','x509:comparison_profile',eq(ref('profile.id'),par('profile')))
      cert=certificate_binding
      cert['where']['args'] << {'op'=>'certificate_profile_matches','certificate'=>ref('certificate.id'),'profile'=>ref('profile.id'),'family'=>family}
      b=presentation_branch(family+'_'+form.split(':').last,form,[profile,cert],'profile_matched_certificate_presentation')
      b['result']['identity'].unshift(ref('profile.id'),ref('profile.attributes.content.sha256'))
      b['result']['fields']['profile']=ref('profile.id'); b['result']['fields']['profile_content']=ref('profile.attributes.content')
      b['result']['fields']['evaluated_profile_fields']=ref('certificate.attributes.profile_fields')
      subject=family=='subject' ? 'profile.id' : 'certificate.id'
      add_class(b,'certificate_class',subject,class_id,'exclude_certificate_class',family=='subject' ? 'source' : 'path')
      if family=='subject'
        add_class(b,'infrastructure_class','service.id','shared_tls_termination_service','exclude_infrastructure_class','occurrence')
      else
        add_class(b,'infrastructure_class','ip.id','cdn_edge','exclude_infrastructure_class','occurrence')
      end
      b
    end
    contract(id,'Presentation of an actual identified certificate meeting an explicitly preserved '+family+' profile; profile revision, field criteria and candidate occurrence period remain distinct.',params,branches,'accepted-explicit-reusable-certificate-characteristic-profiles')
  end
  def name_binding(name,certificate,domain=nil)
    b=bind(name,'assertion','x509:certificate_name',eq(ref(name+'.subject'),ref(certificate+'.id')),
      typed(name+'.attributes.certificate_selector',certificate+'.attributes.certificate_selector','certificate_sha256'),
      one(ref(name+'.attributes.field_kind'),%w[subject_common_name san_dns]),one(ref(name+'.attributes.association_basis'),%w[reported_certificate_field locally_extracted_certificate_field ct_reported_certificate_field]))
    b['where']['args'] << typed(name+'.attributes.name_selector',domain+'.attributes.selector','dns_name') if domain
    b
  end
  def reuse
    params=scope_parameters.merge('source_domain'=>parameter('record_id','Selected concrete seed domain record.'),'source_certificate'=>parameter('record_id','Explicit selected certificate reference; no enumeration of all past material.'),
      'reference'=>parameter('record_id','Exact selected historical name association or presentation-name association record.'),
      'reference_basis'=>parameter('string','Seed relationship meaning.',true,{'enum'=>%w[certificate_name observed_presentation]}),
      'selector'=>parameter('selector','Explicit whole certificate or independently selected SPKI comparison.',true,{'selector_kinds'=>%w[certificate_sha256 spki_sha256]}),
      'exclude_certificate_class'=>parameter('boolean','Explicit intermediate certificate class filter; unrelated qualifying paths remain.',false))
    branches=%w[certificate_sha256 spki_sha256].product(%w[certificate_name observed_presentation]).map do |kind,basis|
      seed=selector_binding('seed',kind); seed['where']['args'] << eq(ref('seed.id'),par('source_certificate'))
      domain=bind('seed_domain','entity','inet:fqdn',eq(ref('seed_domain.id'),par('source_domain')),self_typed('seed_domain.attributes.selector','dns_name'))
      references=[]
      if basis=='certificate_name'
        n=name_binding('reference','seed','seed_domain'); n['where']['args'] += [eq(ref('reference.id'),par('reference')),eq(ref('reference.object'),ref('seed_domain.id'))]
        references << n
      else
        references=presentation('inet:fqdn','reference_','seed')
        references.last['where']['args'] << eq(ref('reference_domain.id'),ref('seed_domain.id'))
        references.find{|b|b['name']=='reference_name_association'}['where']['args'] << eq(ref('reference_name_association.id'),par('reference'))
      end
      candidate=selector_binding('certificate',kind)
      b=presentation_branch(kind+'_'+basis,'inet:fqdn',[seed,domain]+references+[candidate],'certificate_reference_to_candidate_presentation')
      b['select_when']={'parameter'=>'reference_basis','values'=>[basis]}
      if basis=='observed_presentation'
        b['time_bindings'] << time_binding('reference_presentation.times.occurred','reference_presentation.id','reference_presentation.id')
      end
      b['where']=all(eq(par('reference_basis'),lit(basis)),b['where'])
      b['result']['identity'] += [ref('seed.id'),ref('seed_domain.id'),par('reference'),lit(kind)]
      b['result']['fields'].merge!('seed_domain'=>ref('seed_domain.id'),'selected_reference'=>par('reference'),'reference_basis'=>lit(basis),'comparison_kind'=>lit(kind),
        'reference_claim'=>lit('selected historical relationship; no claim of current, simultaneous or continuous seed use'))
      if basis=='observed_presentation'
        b['result']['fields']['reference_occurrence']=ref('reference_presentation.id')
        b['result']['fields']['reference_time']=ref('reference_presentation.times.occurred')
      else
        b['result']['fields']['reference_name']=ref('reference.attributes.name_selector')
        b['result']['fields']['reference_name_basis']=ref('reference.attributes.association_basis')
      end
      add_class(b,'certificate_class','certificate.id','mass_managed_certificate','exclude_certificate_class'); b
    end
    contract('CTI_CERT_REUSE_FQDN_CLUSTER','Selected evidenced historical seed relationship to candidate presentations. Whole-certificate and SPKI comparisons, name and presentation reference bases remain separate.',params,branches,'accepted-historical-certificate-cluster-seed-references')
  end
  def ct_names
    params=scope_parameters.merge('seed_selector'=>parameter('selector','Explicit concrete DNS suffix scope; no public-suffix inference.',true,{'selector_kinds'=>['dns_name']}),
      'exclude_shared_hosting'=>parameter('boolean','Explicit supported certificate-class filter; wildcard alone is not membership.',false))
    branches=%w[dns_name dns_wildcard].map do |kind|
      cert=bind('certificate','entity','x509:cert',self_typed('certificate.attributes.certificate_selector','certificate_sha256'),one(ref('certificate.attributes.artifact_role'),%w[certificate precertificate]))
      ct=bind('ct_record','occurrence','x509:ct_record',eq(ref('ct_record.subject'),ref('certificate.id')),
        typed('ct_record.attributes.certificate_selector','certificate.attributes.certificate_selector','certificate_sha256'),text(ref('ct_record.attributes.log_id')),
        text(ref('ct_record.attributes.record_id')),one(ref('ct_record.attributes.event_meaning'),%w[source_reported_record_date log_inclusion_observed]))
      n=name_binding('certificate_name','certificate')
      n['where']['args'] += [eq(ref('certificate_name.attributes.ct_record'),ref('ct_record.id')),eq(ref('certificate_name.attributes.name_selector.kind'),lit(kind)),
        {'op'=>'ct_name_in_scope','name'=>ref('certificate_name.attributes.name_selector'),'seed'=>par('seed_selector')}]
      binds=[cert,ct,n]
      if kind=='dns_name'
        binds << bind('domain','entity','inet:fqdn',eq(ref('domain.id'),ref('certificate_name.object')),typed('domain.attributes.selector','certificate_name.attributes.name_selector','dns_name'))
        result={'mode'=>'bound','form'=>'inet:fqdn','binding'=>'domain','identity'=>[ref('domain.id'),ref('certificate.id'),ref('ct_record.id'),ref('certificate_name.id')]}
      else
        result={'mode'=>'construct','form'=>'evidence:ct_wildcard_scope','identity'=>[ref('certificate.id'),ref('ct_record.id'),ref('certificate_name.id'),ref('certificate_name.attributes.name_selector.value')]}
      end
      result['fields']={'claim'=>lit(kind=='dns_name' ? 'explicit_CT_certificate_name' : 'literal_CT_wildcard_scope_clue'),'name'=>ref('certificate_name.attributes.name_selector'),
        'certificate'=>ref('certificate.id'),'artifact_role'=>ref('certificate.attributes.artifact_role'),'ct_record'=>ref('ct_record.id'),
        'record_time'=>ref('ct_record.times.occurred'),'event_meaning'=>ref('ct_record.attributes.event_meaning'),
        'reported_log'=>ref('ct_record.attributes.log_id'),'source_record_id'=>ref('ct_record.attributes.record_id'),
        'record_verification'=>ref('ct_record.attributes.verification'),'field_kind'=>ref('certificate_name.attributes.field_kind'),'evidence_mode'=>lit('evidence_only')}
      b={'id'=>kind,'bindings'=>binds,'where'=>within('ct_record.times.occurred'),'time_bindings'=>[time_binding('ct_record.times.occurred','certificate.id','ct_record.id')],'result'=>result}
      add_class(b,'hosting_class','certificate.id','shared_cdn_or_hosting_certificate','exclude_shared_hosting'); b
    end
    contract('OSINT_CRT_SH_SUBDOMAINS','Explicit names and separately typed wildcard clues from source-bound CT records in the chosen record-occurrence period. No wildcard expansion, DNS answer or service presentation is inferred.',params,branches,'accepted-ct-name-record-occurrence-window-purpose')
  end
  def marketplace
    params=scope_parameters.merge('sale'=>parameter('record_id','Exact selected immutable historical sale-report assertion; an offer is not a sale.'),
      'exclude_withdrawn_reports'=>parameter('boolean','Explicit historical-report status filter; retention does not assert the sale occurred.',false),
      'exclude_certificate_class'=>parameter('boolean','Explicit supported intermediate certificate class filter.',false),
      'exclude_cdn_address'=>parameter('boolean','Explicit supported endpoint address-class filter.',false))
    branches=%w[inet:ipv4 inet:fqdn].map do |form|
      sale=bind('sale','assertion','marketplace:sale_report',eq(ref('sale.id'),par('sale')),
        eq(ref('sale.attributes.assertion_kind'),lit('reported_sale')),text(ref('sale.attributes.assertion_namespace')),text(ref('sale.attributes.report_status')))
      domain=bind('sold_domain','entity','inet:fqdn',eq(ref('sold_domain.id'),ref('sale.subject')),typed('sold_domain.attributes.selector','sale.attributes.domain_selector','dns_name'))
      certificate=certificate_binding
      name=name_binding('sale_name','certificate','sold_domain'); name['where']['args'] << eq(ref('sale_name.object'),ref('sold_domain.id'))
      b=presentation_branch('reported_sale_'+form.split(':').last,form,[sale,domain,certificate,name],'historical_reported_sale_certificate_linked_presentation_lead')
      b['where']=all(b['where'],{'op'=>'time_compare','operator'=>'lte','left'=>ref('sale.times.reported_event'),'right'=>ref('presentation.times.occurred')})
      b['time_bindings'] << time_binding('sale.times.reported_event','sale.id','sale.id')
      b['result']['identity'].unshift(ref('sale.id'))
      b['result']['fields'].merge!('sale_report'=>ref('sale.id'),'reported_event'=>ref('sale.times.reported_event'),'report_status'=>ref('sale.attributes.report_status'),
        'sold_domain'=>ref('sold_domain.id'),'association_basis'=>ref('sale_name.attributes.association_basis'),'sale_claim'=>lit('source reported assertion, not confirmed sale, transfer, buyer use or domain deployment'))
      add_class(b,'certificate_class','certificate.id','mass_managed_certificate','exclude_certificate_class')
      add_class(b,'cdn_address','ip.id','cdn_edge','exclude_cdn_address','occurrence')
      b['policies'] << {'id'=>'reported_status','revision'=>'1','scope'=>'source','subject'=>ref('sale.id'),'default_enabled'=>false,
        'enabled_parameter'=>'exclude_withdrawn_reports','when'=>eq(ref('sale.attributes.report_status'),lit('withdrawn')),
        'conflict_when'=>eq(ref('sale.attributes.report_status'),lit('contested')),'reason'=>'Explicit literal report-status exclusion; transaction cancellation and report withdrawal are distinct.'}
      b['amendments']={'support'=>b['bindings'].reject{|v|v['optional']}.select{|v|%w[assertion occurrence].include?(v['kind'])}.map{|v|v['name']},'sources'=>par('source_ids'),'mode'=>'retain_reports',
        'exclusion_parameter'=>'exclude_withdrawn_reports','exclusion_support'=>['sale'],'excluded_states'=>['withdrawn']}
      b
    end
    contract('CTI_MARKETPLACE_SOLD_DOMAIN_CERT_CLUSTER','Selected genuine historical reported sale, exact domain-to-certificate association and later candidate presentation. Pre-existing certificates are eligible; revisions, status and asserted chronology remain visible.',params,branches,'accepted-historical-marketplace-sale-report-leads-with-visible-revisions-and-status-filters')
  end
  def c2
    params=scope_parameters.merge('selector'=>parameter('selector','Explicit whole-certificate or exact SPKI comparison; no role or actor inference.',true,{'selector_kinds'=>%w[certificate_sha256 spki_sha256]}),
      'purpose'=>parameter('string','Encounter and endpoint-mediated discovery lead are distinct claims.',true,{'enum'=>%w[encounter endpoint_lead]}),
      'endpoint_scope'=>parameter('string','Indirect association correspondence only; service-context identity never follows merely from the same address.',false,
        {'enum'=>%w[address service_context],'requires_when'=>{'parameter'=>'purpose','values'=>['endpoint_lead']},'allowed_when'=>{'parameter'=>'purpose','values'=>['endpoint_lead']}}),
      'history'=>parameter('record_id','Preserved complete declared collection history of the typed finding.'),
      'exclude_shared_certificate'=>parameter('boolean','Explicit supported certificate-class filter.',false),
      'exclude_controlled_occurrence'=>parameter('boolean','Explicit supported sinkhole/simulated/intercepted occurrence filter; laboratory provenance alone is insufficient.',false))
    branches=%w[certificate_sha256 spki_sha256].product(%w[encounter endpoint_lead]).product(%w[address service_context]).reject{|pair,scope|pair[1]=='encounter' && scope=='address'}.map do |pair,scope|
      kind,purpose=pair
      sample=bind('sample','entity','file:bytes',self_typed('sample.attributes.artifact_selector','artifact_sha256'))
      b=presentation_branch(kind+'_'+purpose+'_'+scope,'inet:ipv4',[selector_binding('certificate',kind),sample],'placeholder')
      contact=bind('contact','occurrence','sample:network_contact',eq(ref('contact.subject'),ref('sample.id')),
        typed('contact.attributes.artifact_selector','sample.attributes.artifact_selector','artifact_sha256'),
        typed('contact.attributes.address_selector','ip.attributes.selector','ipv4'),
        text(ref('contact.attributes.sample_execution_id')),text(ref('contact.attributes.connection_id')),text(ref('contact.attributes.occurrence_namespace')),
        one(ref('contact.attributes.attribution'),%w[source_reported_sample_connection locally_attributed_sample_connection]))
      contact['where']['args'] += [eq(ref('contact.object'),ref('service.id')),eq(ref('contact.attributes.service_context_id'),ref('service.attributes.context_id'))] if scope=='service_context' || purpose=='encounter'
      b['bindings'] << contact
      if purpose=='encounter'
        b['bindings'] << bind('encounter','assertion','sample:certificate_encounter',eq(ref('encounter.subject'),ref('contact.id')),eq(ref('encounter.object'),ref('presentation.id')),
          eq(ref('encounter.attributes.sample_execution_id'),ref('contact.attributes.sample_execution_id')),eq(ref('encounter.attributes.connection_id'),ref('contact.attributes.connection_id')),
          eq(ref('encounter.attributes.certificate_role'),ref('presentation.attributes.certificate_role')),
          typed('encounter.attributes.certificate_selector','certificate.attributes.certificate_selector','certificate_sha256'),
          one(ref('encounter.attributes.evidence_status'),%w[attributable_source_report locally_checked_occurrence]))
      end
      b['where']=purpose=='encounter' ? eq(par('purpose'),lit(purpose)) : all(eq(par('purpose'),lit(purpose)),eq(par('endpoint_scope'),lit(scope)))
      b['select_when']={'parameter'=>'purpose','values'=>[purpose]}
      b['time_bindings'] << time_binding('contact.times.occurred','sample.id','contact.id')
      identity=[{'selector_identity'=>'sample.attributes.artifact_selector'},{'selector_identity'=>'certificate.attributes.'+(kind=='spki_sha256' ? 'spki_selector' : 'certificate_selector')},
        lit(purpose),lit(scope),ref('contact.attributes.occurrence_namespace'),ref('contact.attributes.sample_execution_id'),ref('contact.attributes.connection_id'),
        ref('presentation.attributes.occurrence_id'),ref('presentation.attributes.certificate_role')]
      b['result']={'mode'=>'bound','form'=>'file:bytes','binding'=>'sample','identity'=>identity,'fields'=>{
        'claim'=>lit(purpose=='encounter' ? 'sample_associated_certificate_encounter' : 'endpoint_mediated_certificate_association_lead'),
        'sample'=>ref('sample.id'),'artifact_selector'=>ref('sample.attributes.artifact_selector'),'comparison_kind'=>lit(kind),
        'contact'=>ref('contact.id'),'contact_time'=>ref('contact.times.occurred'),'sample_execution_id'=>ref('contact.attributes.sample_execution_id'),
        'connection_id'=>ref('contact.attributes.connection_id'),'attribution_basis'=>ref('contact.attributes.attribution'),
        'presentation'=>ref('presentation.id'),'presentation_time'=>ref('presentation.times.occurred'),
        'certificate'=>ref('certificate.id'),'certificate_role'=>ref('presentation.attributes.certificate_role'),
        'service'=>ref('service.id'),'service_context'=>ref('service.attributes.context_id'),'protocol'=>ref('service.attributes.protocol'),
        'reported_port'=>ref('service.attributes.port'),'observed_address'=>ref('ip.attributes.selector'),'vantage'=>ref('presentation.attributes.vantage'),
        'reported_requested_name'=>ref('presentation.attributes.requested_name'),'reported_termination_role'=>ref('presentation.attributes.termination_role'),
        'reported_intermediaries'=>ref('presentation.attributes.intermediaries'),
        'endpoint_scope'=>lit(scope),'evidence_mode'=>lit('evidence_only'),
        'limitation'=>lit('No malicious C2 function, actor, continuity or direct encounter is inferred from an indirect path.')}}
      b['result']['fields']['encounter_status']=ref('encounter.attributes.evidence_status') if purpose=='encounter'
      support=b['bindings'].reject{|v|v['optional']}.map{|v|v['name']}
      b['finding']={'id'=>'cti_c2_cert_to_sample_cluster','revision'=>'1.0','identity'=>identity,'support'=>support,'history'=>par('history'),'period'=>par('period')}
      add_class(b,'shared_certificate','certificate.id','shared_cdn_certificate','exclude_shared_certificate')
      add_class(b,'controlled_occurrence','contact.id','controlled_sample_connection','exclude_controlled_occurrence','occurrence')
      b
    end
    contract('CTI_C2_CERT_TO_SAMPLE_CLUSTER','Collection-scoped first availability of separately supported sample encounters and endpoint-mediated leads. Actual event dates remain separate; a later scan alone is never a sample encounter.',params,branches,'accepted-c2-finding-availability-window-purpose')
  end
  def all_contracts
    [rdp,reuse,ct_names,marketplace,c2,profiles('CTI_TLS_CERT_SUBJECT_PROFILE_TO_INFRA','subject'),
      profiles('CTI_CERT_ISSUER_VALIDITY_CLUSTER','issuer_validity'),profiles('CTI_SHORT_LIVED_CERT_INFRA_CLUSTER','short_lived')]
  end
end

if $PROGRAM_NAME == __FILE__
  CertificateExpansionContracts.all_contracts.each do |contract|
    path=File.join(CertificateExpansionContracts::ROOT,'contracts/semantics',contract['pattern']['id']+'.json')
    File.write(path,JSON.pretty_generate(contract)+"\n")
  end
end
