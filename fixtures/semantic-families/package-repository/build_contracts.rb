# frozen_string_literal: true
require 'json'
module PackageTraversalContracts
  ROOT = File.expand_path('../../..', __dir__)
  module_function
  def r(x); {'ref'=>x}; end
  def l(x); {'literal'=>x}; end
  def p(x); {'param'=>x}; end
  def eq(x,y); {'op'=>'eq','left'=>r(x),'right'=>y}; end
  def all(*v); {'op'=>'all','args'=>v.flatten}; end
  def text(x); {'op'=>'nonblank_text','value'=>r(x)}; end
  def binding(name,kind,type,where=nil,optional=false)
    d={'name'=>name,'kind'=>kind,'types'=>[type]};d['where']=where if where;d['optional']=true if optional;d
  end
  def content(n)
    {'op'=>'content_matches','record'=>r(n+'.id'),'source'=>r(n+'.attributes.content.source_id'),'sha256'=>r(n+'.attributes.content.sha256'),'byte_length'=>r(n+'.attributes.content.byte_length'),'representation'=>r(n+'.attributes.content.representation')}
  end
  def build(id)
    supply=id.start_with?('SUPPLY_'); anchor=supply ? 'repository' : 'package'; list=supply ? 'mass_mirror_repositories' : 'mass_fork_mirrors'
    doc={'contract'=>'everypivot.semantic_pattern','version'=>'1.0','pattern'=>{'id'=>id,'version'=>'3.0.0'},
      'description'=>'Preserved version-specific registry declaration plus an independently evidenced observation of this particular infrastructure relationship. UTC3650day scope dates the observation, not creation, publication, import or replay; snapshot provenance remains separate.',
      'authority'=>'docs/PACKAGE_REPOSITORY_PROVENANCE.md',
      'parameters'=>{'seed'=>{'type'=>'record_id','required'=>true,'description'=>'Exact source package version or repository record.'},
        'query_date'=>{'type'=>'date','required'=>true,'description'=>'Explicit inclusive UTC observation-window end date.'},
        'policy_revision'=>{'type'=>'string','required'=>true,'description'=>'Pinned '+list+' revision; required scoped eligibility is not inferred from absent list membership.'}},'branches'=>[]}
    %w[inet:fqdn inet:ipv4].each do |form|
      source_type=supply ? 'it:prod:softver' : 'code:repo'
      bindings=[binding('seed','entity',source_type,eq('seed.id',p('seed'))).merge('query_seed'=>true),
        binding('declaration','assertion','package:repository_declaration',eq('declaration.'+(supply ? 'subject' : 'object'),r('seed.id'))),
        binding('package','entity','it:prod:softver',eq('package.id',r('declaration.subject'))),
        binding('repository','entity','code:repo',eq('repository.id',r('declaration.object'))),
        binding('sidecar','entity','evidence:package_repository_provenance',eq('sidecar.id',r('declaration.attributes.sidecar_id'))),
        binding('metadata','entity','evidence:registry_document',eq('metadata.id',r('declaration.attributes.metadata_id'))),
        binding('observation','occurrence',supply ? 'repository:infrastructure_observation' : 'package:infrastructure_observation',eq('observation.subject',r(anchor+'.id'))),
        binding('endpoint','entity',form,eq('endpoint.id',r('observation.object'))),
        binding('control','assertion','policy:repository_membership',all(eq('control.attributes.policy',l(list)),eq('control.attributes.revision',p('policy_revision')),
          {'op'=>'typed_equal','left'=>r('control.attributes.repository_uri'),'right'=>r('repository.attributes.uri')}),true)]
      times=bindings.reject{|b|b['optional']||b['query_seed']}.map{|b|n=b['name'];{'value'=>r(n+'.times.collection_available'),'object'=>r(n+'.id'),'occurrence'=>r(n+'.attributes.availability_occurrence')}}
      times<<{'value'=>r('observation.times.observed'),'object'=>r(anchor+'.id'),'occurrence'=>r('observation.id')}
      period={'calendar_period'=>{'query_date'=>p('query_date'),'days'=>l(3650)}}
      predicate={'op'=>'package_repository_declaration'}
      %w[declaration package repository sidecar metadata].each{|n|predicate[n]=r(n+'.id')}
      selector_kind=form=='inet:fqdn' ? 'dns_name' : 'ipv4'
      identity=[r('package.attributes.package.registry'),r('package.attributes.package.name'),r('package.attributes.package.version'),{'selector_identity'=>'repository.attributes.uri'},
        r('observation.attributes.occurrence_key'),r('observation.attributes.collector'),r('observation.attributes.relation'),{'selector_identity'=>'endpoint.attributes.selector'}]
      d={'id'=>form.split(':').last,'bindings'=>bindings,'time_bindings'=>times,
        'knowledge'=>times.reject{|t|t.dig('value','ref')=='observation.times.observed'}.map{|t|t['value']},
        'where'=>all(predicate,eq('observation.attributes.profile',l('relationship_observation_v1')),
          {'op'=>'in','left'=>r('observation.attributes.relation'),'right'=>l(supply ? %w[operated_via distributed_from] : %w[distributed_from referenced_by])},
          text('observation.attributes.occurrence_key'),text('observation.attributes.collector'),
          eq('observation.attributes.basis',l('direct_relationship_observation')),eq('endpoint.attributes.selector.kind',l(selector_kind)),
          {'op'=>'typed_equal','left'=>r('endpoint.attributes.selector'),'right'=>r('observation.attributes.endpoint_selector')},
          {'op'=>'package_repository_observation','observation'=>r('observation.id'),'period'=>period}),
        'result'=>{'mode'=>'bound','binding'=>'endpoint','form'=>form,'identity'=>identity,
          'fields'=>{'relationship_observation'=>r('observation.id'),'occurrence_key'=>r('observation.attributes.occurrence_key'),'observation_time'=>r('observation.times.observed'),
            'relation'=>r('observation.attributes.relation'),'package'=>r('package.attributes.package'),'repository_uri'=>r('repository.attributes.uri'),
            'preserved_provenance'=>r('sidecar.attributes.document'),'snapshot_scope'=>l('source-reported sidecar; manifest self-consistency checked, local Git content reproduction separate'),
            'inference_boundary'=>l('declaration and observed relationship only; no build provenance, ownership, continuous service, independence or accepted assessment')}}}
      base=[content('control'),eq('control.attributes.profile',l('literal_uri_membership_v1'))]
      d['policies']=[{'id'=>list,'revision'=>'1.0','scope'=>'source','subject'=>{'selector_identity'=>'repository.attributes.uri'},'default_enabled'=>true,
        'required_evaluation'=>true,'when'=>all(base,eq('control.attributes.state',l('member'))),
        'allow_when'=>all(base,eq('control.attributes.state',l('not_member')),eq('control.attributes.coverage',l('complete_for_evaluated_subject'))),
        'conflict_when'=>all(base,eq('control.attributes.state',l('contested'))),'reason'=>'Preserved legacy repository exclusion with explicit exact-URI applicability and selected list revision.'}]
      doc['branches']<<d
    end
    doc
  end
end
if $PROGRAM_NAME==__FILE__
 %w[SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA CROSS_PACKAGE_REPO_TO_DOMAIN_INFRA].each{|id|File.write(File.join(PackageTraversalContracts::ROOT,'contracts/semantics',id+'.json'),JSON.pretty_generate(PackageTraversalContracts.build(id))+"\n")}
end
