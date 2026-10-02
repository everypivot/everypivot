#!/usr/bin/env ruby
# frozen_string_literal: true
require 'minitest/autorun'
require_relative 'semantic_evaluator'
require_relative '../fixtures/semantic-families/package-repository/fixture_factory'

class SemanticPackageRepositoryTest < Minitest::Test
  E=EveryPivot::SemanticEvaluator
  F=PackageTraversalFixtures
  IDS=%w[SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA CROSS_PACKAGE_REPO_TO_DOMAIN_INFRA].freeze
  def run_case(f,id=IDS[0])
    c=JSON.parse(File.read(File.expand_path('../contracts/semantics/'+id+'.json',__dir__)))
    E.new(c).evaluate(f['evidence'],f['query'],preserved_source_bytes:f['source_bytes'])
  end
  def rec(f,id);f['evidence']['records'].find{|r|r['id']==id};end
  def assert_ids(f,expected=['domain'],id=IDS[0])
    got=run_case(f,id);assert_equal expected,got['results'].map{|r|r['id']}.uniq,got['diagnostics'].inspect;got
  end
  def test_both_directions_have_their_own_infrastructure_subject
    IDS.each do |id|
      f=F.build(id);got=assert_ids(f,['domain'],id)
      assert_equal 'unresolved',got['results'][0].dig('fields','preserved_provenance','snapshot','status')
      assert_equal 'not_evaluated',got['results'][0]['assessment_acceptance']
      rec(f,'observation')['subject']=id==IDS[0] ? 'package' : 'repo'
      assert_ids(f,[],id)
    end
  end
  def test_original_creation_mirror_import_or_publication_does_not_order_relationship
    [['2010-03-01','2026-08-10'],['2026-09-01','2024-12-01'],[nil,nil],['2026-08-01','2026-08-01']].each do |repo_date,pub|
      f=F.build;rec(f,'repo')['attributes']['creation_context']=repo_date;rec(f,'package')['attributes']['publication_context']=pub
      rec(f,'repo')['attributes']['import_context']='2026-09-12'
      assert_ids(f)
    end
  end
  def test_observation_can_precede_or_follow_publication_but_cannot_be_future_or_old
    %w[2026-08-01T00:00:00Z 2026-08-12T00:00:00Z 2016-09-16T00:00:00Z 2026-09-14T23:59:59Z].each do |value|
      f=F.build;rec(f,'observation')['times']['observed']['value']=value;assert_ids(f)
    end
    %w[2016-09-15T23:59:59Z 2026-09-15T00:00:00Z].each do |value|
      f=F.build;rec(f,'observation')['times']['observed']['value']=value;assert_ids(f,[])
    end
  end
  def test_late_collection_is_retrospective_only_and_does_not_backdate_knowledge
    f=F.build;assert_ids(f)
    f['query']['knowledge_cutoff']=F.time('query','query','2026-09-14T23:59:59Z');assert_ids(f,[])
    f['query']['knowledge_cutoff']['value']='2026-09-21T00:00:00Z';assert_ids(f)
    rec(f,'declaration')['times'].delete('collection_available');assert_ids(f,[])
  end
  def test_import_replay_does_not_refresh_old_observation
    f=F.build;rec(f,'observation')['times']['observed']['value']='2015-08-01T00:00:00Z'
    rec(f,'observation')['attributes']['new_ingestion']='2026-09-13';assert_ids(f,[])
    rec(f,'observation')['attributes']['basis']='replay';rec(f,'observation')['times']['observed']['value']='2026-09-13T00:00:00Z';assert_ids(f,[])
  end

  def clone_observation(f, date, source_revision=nil)
    original=rec(f,'observation');copy=Marshal.load(Marshal.dump(original));copy['id']='observation-copy'
    copy['attributes']['endpoint_selector']['provenance']['record_id']=copy['id']
    copy['times']['observed']['binding']['occurrence']=copy['id']
    copy['times']['observed']['value']=date
    copy['times']['collection_available']['binding']['object']=copy['id']
    if source_revision
      source=Marshal.load(Marshal.dump(f['evidence']['sources'].find{|s|s['id']=='mapping'}));source['id']='mapping-copy';source['revision']=source_revision;f['evidence']['sources']<<source
      copy['attributes']['origin_source_id']=source['id'];copy['evidence']=[{'source_id'=>source['id'],'field'=>'/records/observation'}]
      copy['attributes']['endpoint_selector']['provenance'].merge!('source'=>source['id'],'source_revision'=>source_revision)
      copy['times'].each_value{|t|t['source_revision']=source_revision}
    end
    f['evidence']['records']<<copy
    copy
  end
  def test_same_actual_occurrence_cannot_be_refreshed_by_a_new_row_or_revision
    [nil,'mapping-v2'].each do |revision|
      f=F.build;rec(f,'observation')['times']['observed']['value']='2015-08-01T00:00:00Z'
      clone_observation(f,'2026-08-01T00:00:00Z',revision)
      got=assert_ids(f,[]);assert_equal 'unresolved',got['outcome']
    end
    f=F.build;clone_observation(f,'2026-08-01T00:00:00Z');assert_ids(f)
    f=F.build;copy=clone_observation(f,'2026-08-01T00:00:00Z');rec(f,'observation')['times']['observed']['value']='2015-08-01T00:00:00Z'
    copy['attributes']['occurrence_key']='separately-observed-2026-08-01';assert_ids(f)
  end
  def test_completed_observation_cannot_be_known_before_it_happened
    f=F.build
    f['evidence']['records'].each{|r|r['times']['collection_available']['value']='2026-07-01T00:00:00Z' if r['times']['collection_available']}
    f['query']['knowledge_cutoff']=F.time('query','query','2026-07-02T00:00:00Z')
    assert_ids(f,[])
    f['query'].delete('knowledge_cutoff');assert_ids(f,[])
  end
  def test_collection_receipt_can_use_its_own_independent_source_clock
    f=F.build;f['evidence']['sources']<<F.source('receipt','receipt-r1','local-receipt','package-case','Local collector')
    obs=rec(f,'observation');obs['evidence']<<{'source_id'=>'receipt','field'=>'/receipts/observation'}
    obs['times']['collection_available'].merge!('field'=>'/receipts/observation','source_revision'=>'receipt-r1','clock'=>{'id'=>'local-receipt-clock','reference'=>'UTC','uncertainty_seconds'=>0})
    assert_ids(f)
    obs['times']['collection_available']['value']='2026-07-01T00:00:00Z';assert_ids(f,[])
  end
  def test_equivalence_unknown_time_or_identity_is_retained_without_a_winner
    f=F.build;clone_observation(f,'2026-08-02T00:00:00Z');assert_ids(f,[])
    f=F.build;copy=clone_observation(f,'2026-08-01T00:00:00Z');copy['times']['observed']['clock'].delete('uncertainty_seconds');assert_ids(f,[])
    f=F.build;clone_observation(f,'2026-08-01T00:00:00Z')['attributes'].delete('origin_source_id');assert_ids(f,[])
    f=F.build;rec(f,'observation')['attributes'].delete('origin_source_id');assert_ids(f,[])
  end
  def test_missing_uncertain_or_incomparable_clocks_never_pass
    f=F.build;rec(f,'observation')['times']['observed'].delete('timezone');assert_ids(f,[])
    f=F.build;rec(f,'observation')['times']['observed']['clock']['reference']='unknown-clock';assert_ids(f,[])
    f=F.build;rec(f,'observation')['times']['observed']['value']='2016-09-16T00:00:00Z';rec(f,'observation')['times']['observed']['clock']['uncertainty_seconds']=60;assert_ids(f,[])
    f=F.build;inside=rec(f,'observation')['times']['observed'];outside=Marshal.load(Marshal.dump(inside));outside['value']='2015-08-01T00:00:00Z'
    rec(f,'observation')['times']['observed']={'alternatives'=>[inside,outside]};assert_ids(f,[])
  end
  def test_wrong_version_wrong_repository_and_only_mirror_pointer_do_not_qualify
    f=F.build;rec(f,'package')['attributes']['package']=rec(f,'package')['attributes']['package'].merge('version'=>'other');assert_ids(f,[])
    f=F.build;rec(f,'repo')['attributes']['uri']['value']='https://mirror.example/new';assert_ids(f,[])
    f=F.build;sc=rec(f,'sidecar');sc['attributes']['document']['declaration']['kind']='mirror_reference';F.preserve(f['evidence'],f['source_bytes'],sc,JSON.generate(sc['attributes']['document']));assert_ids(f,[])
  end
  def test_preserved_bytes_and_actual_anchor_are_required
    f=F.build;f['source_bytes'].delete('registry');assert_ids(f,[])
    f=F.build;f['source_bytes']['registry']+='altered';assert_raises(EveryPivot::SemanticPackageRepository::InvalidInput){run_case(f)}
    f=F.build;rec(f,'sidecar')['attributes']['document']['repository_uri']='https://substitute.example';assert_ids(f,[])
  end
  def test_missing_normalized_identity_is_unknown_not_a_negative_claim
    f=F.build;rec(f,'package')['attributes'].delete('package');got=assert_ids(f,[]);assert_equal 'unresolved',got['outcome']
    f=F.build;rec(f,'package')['attributes']['package']=false
    assert_raises(EveryPivot::SemanticPackageRepository::InvalidInput){run_case(f)}
    f=F.build;rec(f,'sidecar')['attributes'].delete('document');got=assert_ids(f,[]);assert_equal 'unresolved',got['outcome']
  end
  def test_policy_unknown_is_withheld_and_member_is_suppressed
    f=F.build;f['evidence']['records'].reject!{|r|r['id']=='control'};f['evidence']['records'].reject!{|r|r['subject']=='control'};assert_ids(f,[])
    f=F.build;rec(f,'control')['attributes']['state']='member';got=assert_ids(f,[]);assert got['diagnostics'].any?{|d|d['status']=='suppressed'}
  end
end
