#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require_relative 'semantic_neo4j_adapter'

# Offline structural and semantic oracle. This test does not contact Neo4j and
# cannot establish native acceptance. Native checks have a separate explicit CLI.
class SemanticNeo4jAdapterTest < Minitest::Test
  M = EveryPivot::SemanticNeo4j
  ROOT = File.expand_path('..', __dir__)
  OWNER = '11111111-1111-4111-8111-111111111111'

  def evidence
    JSON.parse(File.read(File.join(ROOT, 'fixtures/semantic-families/ja3/evidence.json')))
  end

  def source_bytes
    {'synthetic-ja3-report' => File.binread(File.join(ROOT, 'fixtures/semantic-families/ja3/source.json'))}
  end

  def contract(role = 'client')
    id = role == 'client' ? 'OSINT_TLS_JA3_TO_FQDNS' : 'OSINT_TLS_JA3S_TO_FQDNS'
    JSON.parse(File.read(File.join(ROOT, 'contracts/semantics', id + '.json')))
  end

  def query(role = 'client')
    JSON.parse(File.read(File.join(ROOT, 'fixtures/semantic-families/ja3', role + '-query.json')))
  end

  def receipt(graph, data = evidence)
    {'graph_sha256' => M.graph_identity(graph), 'input_sha256' => M.digest(data)}
  end

  def decode(graph, expected = M.graph_identity(graph))
    M.decode(graph, expected_graph_sha256: expected)
  end

  def test_exact_source_record_and_byte_round_trip_without_numeric_or_null_coercion
    data = evidence
    data['records'].first['attributes']['opaque'] = {'null' => nil, 'bool' => false, 'number' => 2.0, 'string' => '2', 'array' => [true, {'x' => 'é\u0000'}]}
    graph = M.encode(data, source_bytes)
    assert_equal [data, source_bytes], decode(graph)
    shuffled = graph.transform_values(&:reverse)
    assert_equal M.graph_identity(graph), M.graph_identity(shuffled)
    assert_equal [data, source_bytes], decode(shuffled)
    assert_nil decode(graph).first['sources'].first['independent_origin']
  end

  def test_native_projection_contains_explicit_directional_witness_relationships
    graph = M.encode(evidence)
    records = evidence['records']
    expected_evidence = records.sum { |r| r['evidence'].length }
    assert_equal expected_evidence, graph['relationships'].count { |e| e['type'] == 'EVIDENCE' }
    assert_equal records.count { |r| r.key?('subject') }, graph['relationships'].count { |e| e['type'] == 'SUBJECT' }
    assert_equal records.count { |r| r.key?('object') }, graph['relationships'].count { |e| e['type'] == 'OBJECT' }
    assert_equal records.sum { |r| r['times'].length }, graph['relationships'].count { |e| e['type'] == 'TIME_OBJECT' }
    assert_equal records.sum { |r| r['times'].length }, graph['relationships'].count { |e| e['type'] == 'TIME_OCCURRENCE' }
    carrier = records.index { |r| r['id'] == 'receive-client' }
    object = records.index { |r| r['id'] == 'derive-client' }
    assert_includes graph['relationships'], {'from' => "record:#{carrier}", 'to' => "record:#{object}", 'type' => 'TIME_OBJECT', 'properties' => {'path' => '/times/received'}}
    assert_includes graph['relationships'], {'from' => "record:#{carrier}", 'to' => "record:#{carrier}", 'type' => 'TIME_OCCURRENCE', 'properties' => {'path' => '/times/received'}}
  end

  def test_actual_record_order_source_order_and_duplicate_witness_refs_are_preserved
    data = evidence
    data['sources'] << data['sources'].first.merge('id' => 'syndicated-copy', 'independent_origin' => nil)
    data['records'].first['evidence'] << data['records'].first['evidence'].first.dup
    data['records'].first['evidence'] << {'source_id' => 'syndicated-copy', 'field' => '/copy'}
    assert_equal data, decode(M.encode(data)).first
    edges = M.encode(data)['relationships'].select { |e| e['from'] == 'record:0' && e['type'] == 'EVIDENCE' }
    assert_equal [0, 1, 2], edges.map { |e| e['properties']['ordinal'] }
    assert_equal ['source:0', 'source:0', 'source:1'], edges.map { |e| e['to'] }
  end

  def test_time_alternatives_keep_both_edges_and_do_not_choose_a_winner
    data = evidence
    r = data['records'].find { |v| v['id'] == 'm-client' }
    other = Marshal.load(Marshal.dump(r['times']['occurred']))
    other['value'] = '2026-10-01T01:00:00Z'
    r['times']['occurred'] = {'alternatives' => [r['times']['occurred'], other]}
    graph = M.encode(data)
    assert_equal data, decode(graph).first
    paths = graph['relationships'].select { |e| e['type'] == 'TIME_OCCURRENCE' }.map { |e| e['properties']['path'] }
    assert_includes paths, '/times/occurred/alternatives/0'
    assert_includes paths, '/times/occurred/alternatives/1'
  end

  def test_missing_duplicated_swapped_and_extra_native_edges_are_rejected_even_with_new_graph_digest
    %w[EVIDENCE SUBJECT OBJECT TIME_OBJECT TIME_OCCURRENCE].each do |type|
      [:missing, :duplicate, :reverse, :field].each do |mutation|
        graph = M.encode(evidence)
        edge = graph['relationships'].find { |e| e['type'] == type && e['from'] != e['to'] } || graph['relationships'].find { |e| e['type'] == type }
        case mutation
        when :missing then graph['relationships'].delete(edge)
        when :duplicate then graph['relationships'] << Marshal.load(Marshal.dump(edge))
        when :reverse
          if edge['from'] == edge['to']
            edge['to'] = 'record:0'
          else
            edge['from'], edge['to'] = edge['to'], edge['from']
          end
        when :field then edge['properties']['invented'] = 'extra'
        end
        assert_raises(M::InvalidMapping, "#{type} #{mutation}") { decode(graph) }
      end
    end
  end

  def test_external_receipt_defeats_rewritten_payload_and_unknown_projections
    graph = M.encode(evidence)
    original = M.graph_identity(graph)
    graph['nodes'].first['payload_json'] = '{}'
    graph['nodes'].first['payload_sha256'] = Digest::SHA256.hexdigest('{}')
    assert_raises(M::InvalidMapping) { decode(graph, original) }
    graph = M.encode(evidence)
    graph['nodes'].last['record_type'] = 'invented:type'
    assert_raises(M::InvalidMapping) { decode(graph) }
    graph = M.encode(evidence)
    graph['nodes'] << graph['nodes'].last.dup
    assert_raises(M::InvalidMapping) { decode(graph) }
  end

  def test_unknown_source_metadata_is_preserved_not_repaired
    data = evidence
    data['sources'].first['revision'] = nil
    graph = M.encode(data)
    assert_nil decode(graph).first['sources'].first['revision']
    result = M.evaluate(contract, query, graph, receipt(graph, data))
    assert_empty result['results']
    assert_equal 'unresolved', result['outcome']
  end

  def test_invalid_evidence_and_changed_source_bytes_fail_before_native_mapping
    data = evidence
    data['records'] << data['records'].first
    assert_raises(EveryPivot::SemanticRecords::InvalidInput) { M.encode(data) }
    assert_raises(M::InvalidMapping) { M.encode(evidence, 'absent-source' => 'bytes') }
    assert_raises(M::InvalidMapping) { M.encode(evidence, 'synthetic-ja3-report' => 'wrong bytes') }
    assert_raises(M::InvalidMapping) { M.encode(evidence, 'synthetic-ja3-report' => false) }
  end

  def test_opaque_claims_do_not_establish_match_or_assessment
    data = evidence
    r = data['records'].find { |v| v['id'] == 'm-client' }
    r['attributes'].merge!('match' => true, 'confidence' => 100, 'accepted_assessment' => true, 'observed_state' => 'planned')
    graph = M.encode(data)
    result = M.evaluate(contract, query, graph, receipt(graph, data))
    assert_empty result['results']
    assert_equal false, result['adapter']['native_predicate_execution']
    assert_equal 'requires_separate_transaction_attestation', result['adapter']['native_execution']
    assert_equal 'not_evaluated', result['adapter']['assessment_acceptance']
  end

  def test_separate_admitted_client_and_server_results_and_shared_hex_role_defeat
    graph = M.encode(evidence, source_bytes)
    %w[client server].each do |role|
      result = M.evaluate(contract(role), query(role), graph, receipt(graph))
      assert_equal 'complete', result['status']
      assert_equal 1, result['results'].length
      assert_equal "network-message-#{role}", result['results'][0]['fields']['occurrence_id']
      assert_equal 'alpha.example.test', result['results'][0]['fields']['named_domain']
      assert_equal 'evidence_only', result['results'][0]['evidence_mode']
      assert_equal 'not_evaluated', result['results'][0]['assessment_acceptance']
    end
    q = query('server')
    q['parameters']['selector'] = query('client')['parameters']['selector']
    assert_raises(EveryPivot::SemanticEvaluator::UnsupportedInput) { M.evaluate(contract('server'), q, graph, receipt(graph)) }
  end

  def test_unadmitted_identity_version_or_contract_mutation_is_unsupported
    mutations = [lambda { |c| c['pattern']['version'] = '3.0.1' },
                 lambda { |c| c['pattern']['id'] = 'SOME_OTHER_PATTERN' },
                 lambda { |c| c['description'] += ' changed' }]
    mutations.each do |mutate|
      c = contract
      mutate.call(c)
      assert_raises(M::Unsupported) { M.admit(c) }
    end
  end

  def test_native_endpoint_and_owner_validation_does_not_connect
    good = 'http://127.0.0.1:27474/db/neo4j/tx/commit'
    native = M::Native.new(endpoint: good, owner: OWNER)
    assert_instance_of M::Native, native
    ['http://example.test:27474/db/neo4j/tx/commit', 'http://localhost:27474/db/neo4j/tx/commit',
     'http://127.0.0.1/db/neo4j/tx/commit', good + '?x=y', good + '#fragment',
     'http://user@127.0.0.1:27474/db/neo4j/tx/commit', good.sub('/neo4j/', '/other/')].each do |url|
      assert_raises(M::InvalidMapping) { M::Native.new(endpoint: url, owner: OWNER) }
    end
    [nil, '', true, 'any-token'].each { |owner| assert_raises(M::InvalidMapping) { M::Native.new(endpoint: good, owner: owner) } }
    [0, 121, 1.5, true].each { |timeout| assert_raises(M::InvalidMapping) { M::Native.new(endpoint: good, owner: OWNER, timeout: timeout) } }
  end

  def test_profile_versions_mapping_shape_and_admissions_are_explicit
    base = JSON.parse(File.read(M::PROFILE_PATH))
    changes = [lambda { |p| p['surprise'] = true }, lambda { |p| p['version'] = '2.0' },
               lambda { |p| p['mapping_version'] = '2.0' }, lambda { |p| p['backend']['version'] = '5.27.0' },
               lambda { |p| p['mapping']['relationships'].delete('TIME_OBJECT') },
               lambda { |p| p['admissions'][0]['confidence'] = 100 },
               lambda { |p| p['admissions'] << p['admissions'].first },
               lambda { |p| p['inputs']['version'] = '1.1' }, lambda { |p| p['execution'] = 'native_cypher' }]
    Dir.mktmpdir('ep-semantic-adapter-') do |dir|
      path = File.join(dir, 'profile.json')
      changes.each do |change|
        profile = Marshal.load(Marshal.dump(base))
        change.call(profile)
        File.write(path, JSON.generate(profile))
        assert_raises(M::Unsupported) { M.admit(contract, profile_path: path) }
      end
    end
  end

  def test_native_response_protocol_errors_fail_instead_of_returning_empty_results
    native = M::Native.new(endpoint: 'http://127.0.0.1:27474/db/neo4j/tx/commit', owner: OWNER)
    bodies = [
      {'errors' => [{'code' => 'Synthetic.Error'}], 'results' => []},
      {'errors' => [], 'results' => []},
      {'errors' => [], 'results' => [{'columns' => ['x', 'x'], 'data' => [{'row' => [1, 2]}]}]},
      {'errors' => [], 'results' => [{'columns' => ['x'], 'data' => [{'row' => []}]}]}
    ]
    bodies.each do |body|
      response = Struct.new(:code, :body).new('200', JSON.generate(body))
      client = Object.new
      client.define_singleton_method(:request) { |_request| response }
      factory = lambda { |*_args, &block| block.call(client) }
      Net::HTTP.stub(:start, factory) do
        assert_raises(M::NativeError) { native.one('RETURN 1 AS x') }
      end
    end
    assert_raises(M::InvalidMapping) { M.parse('{"id":1,"id":2}') }
    assert_raises(M::InvalidMapping) { M.encode(evidence, 1 => 'bytes', 'source' => 'bytes') }
  end
end
