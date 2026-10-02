# frozen_string_literal: true
require 'json'
require 'digest'
module PackageTraversalFixtures
  ROOT=File.expand_path('../../..',__dir__)
  module_function
  def time(object,occurrence,date)
    {'binding'=>{'object'=>object,'occurrence'=>occurrence},'field'=>'/records/'+object,'source_revision'=>'mapping-v1',
      'clock'=>{'id'=>'synthetic-observer','reference'=>'UTC','uncertainty_seconds'=>0},'timezone'=>'UTC','precision'=>'instant','interval_role'=>'occurrence','value'=>date}
  end
  def source(id,revision='mapping-v1',document=id,collection='package-case',publisher='Synthetic mapper')
    {'id'=>id,'revision'=>revision,'document'=>document,'collection'=>collection,'publisher'=>publisher,'independent_origin'=>nil}
  end
  def record(id,kind,type,attrs={})
    {'id'=>id,'kind'=>kind,'type'=>type,'attributes'=>attrs,'times'=>{},'evidence'=>[{'source_id'=>'mapping','field'=>'/records/'+id}]}
  end
  def selector(kind,value,id,field)
    {'kind'=>kind,'value'=>value,'normalization'=>kind=='uri' ? 'literal_rfc3986_v1' : kind=='ipv4' ? 'strict_dotted_decimal_v1' : 'dns_ascii_lower_v1',
      'provenance'=>{'source'=>'mapping','record_id'=>id,'source_revision'=>'mapping-v1','field'=>'/records/'+id+'/'+field,'basis'=>'reported'}}.tap{|x|x['representation']=kind=='ipv4' ? 'dotted_decimal' : 'ascii' unless kind=='uri'}
  end
  def preserve(data,bytes,record,body,src=nil)
    id=record['id']+'-bytes';src||=source(id,'content-v1');id=src['id'];bytes[id]=body
    src['content_hash']={'algorithm'=>'sha256','value'=>Digest::SHA256.hexdigest(body),'scope'=>'exact_source_bytes'}
    data['sources'].reject!{|s|s['id']==id};data['sources']<<src
    record['attributes']['content']={'source_id'=>id,'source_revision'=>src['revision'],'field'=>'/','sha256'=>Digest::SHA256.hexdigest(body),'byte_length'=>body.bytesize,'representation'=>'exact_source_bytes'}
    record['evidence'].reject!{|e|e['source_id']==id};record['evidence']<<{'source_id'=>id,'field'=>'/'}
  end
  def build(id='SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA')
    supply=id.start_with?('SUPPLY_');sidecar=JSON.parse(File.read(File.join(ROOT,'fixtures/package-repository-provenance/version-declaration.record.json')));sidecar['pattern_id']=id
    original=File.binread(File.join(ROOT,'fixtures/package-repository-provenance/version-declaration.source.json'))
    data={'contract'=>'everypivot.semantic_evidence','version'=>'1.0','collection_id'=>'package-case','sources'=>[source('mapping')],'records'=>[]};bytes={}
    pkg=record('package','entity','it:prod:softver',{'package'=>sidecar['package'],'creation_context'=>'2019-03-01','publication_context'=>'2026-08-10'})
    repo=record('repo','entity','code:repo',{'uri'=>selector('uri',sidecar['repository_uri'],'repo','uri'),'creation_context'=>'2010-03-01'})
    dec=record('declaration','assertion','package:repository_declaration',{'sidecar_id'=>'sidecar','metadata_id'=>'metadata'});dec.merge!('subject'=>'package','object'=>'repo')
    sc=record('sidecar','entity','evidence:package_repository_provenance',{'document'=>sidecar});preserve(data,bytes,sc,JSON.generate(sidecar))
    md=record('metadata','entity','evidence:registry_document');a=sidecar.dig('declaration','evidence')
    src=source('registry',a['revision'],a['uri'],a['collection'],a['publisher']);preserve(data,bytes,md,original,src)
    dec['evidence']<<{'source_id'=>'registry','field'=>a['field']}
    endpoint=record('domain','entity','inet:fqdn',{'selector'=>selector('dns_name','download.example.test','domain','selector')})
    obs=record('observation','occurrence',supply ? 'repository:infrastructure_observation' : 'package:infrastructure_observation',
      {'profile'=>'relationship_observation_v1','relation'=>'distributed_from','occurrence_key'=>'observer-capture-2026-08-01','collector'=>'fixture-observer','origin_source_id'=>'mapping','occurrence_namespace'=>'relationship-sightings',
       'basis'=>'direct_relationship_observation','endpoint_selector'=>selector('dns_name','download.example.test','observation','endpoint_selector')})
    obs.merge!('subject'=>supply ? 'repo' : 'package','object'=>'domain');obs['times']['observed']=time(obs['subject'],'observation','2026-08-01T00:00:00Z')
    # This field is carried by the occurrence, not the subject entity.
    obs['times']['observed']['field']='/records/observation/observed'
    list=supply ? 'mass_mirror_repositories' : 'mass_fork_mirrors'
    control=record('control','assertion','policy:repository_membership',{'policy'=>list,'revision'=>'list-1','profile'=>'literal_uri_membership_v1','state'=>'not_member',
      'coverage'=>'complete_for_evaluated_subject','repository_uri'=>selector('uri',sidecar['repository_uri'],'control','repository_uri')})
    preserve(data,bytes,control,JSON.generate(control['attributes']))
    data['records']=[pkg,repo,dec,sc,md,obs,endpoint,control]
    data['records'].dup.each do |r|
      rid=r['id'];aid=rid+'-available';r['attributes']['availability_occurrence']=aid
      r['times']['collection_available']=time(rid,aid,'2026-09-20T00:00:00Z')
      event=record(aid,'occurrence','evidence:availability',{'collection_id'=>'package-case'});event['subject']=rid;data['records']<<event
    end
    query={'parameters'=>{'seed'=>supply ? 'package' : 'repo','query_date'=>'2026-09-14','policy_revision'=>'list-1'},'limits'=>{'max_bindings'=>10000,'max_results'=>100}}
    {'evidence'=>data,'query'=>query,'source_bytes'=>bytes,'expected_result_ids'=>['domain']}
  end
end
if $PROGRAM_NAME==__FILE__
 %w[SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA CROSS_PACKAGE_REPO_TO_DOMAIN_INFRA].each{|id|File.write(File.join(__dir__,id+'.json'),JSON.pretty_generate(PackageTraversalFixtures.build(id))+"\n")}
end
