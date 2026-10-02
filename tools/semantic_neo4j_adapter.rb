# frozen_string_literal: true

require 'json'
require 'digest'
require 'base64'
require 'net/http'
require 'uri'
require 'securerandom'
require_relative 'semantic_evaluator'

module EveryPivot
  # Hybrid adapter: Neo4j persists the normalized evidence graph; the portable
  # evaluator executes its semantics. No legacy traversal or Cypher DSL fallback.
  module SemanticNeo4j
    class InvalidMapping < StandardError; end
    class Unsupported < StandardError; end
    class NativeError < StandardError; end
    PROFILE_PATH = File.expand_path('../adapters/semantic-profiles/neo4j_semantic_evidence_v1.json', __dir__)
    RELATIONS = %w[EVIDENCE SUBJECT OBJECT TIME_OBJECT TIME_OCCURRENCE].freeze
    TOKEN = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/

    module_function

    def canonical(value)
      JSON.generate(SemanticContract.canonical(value))
    end

    def digest(value)
      SemanticContract.digest(value)
    end

    def parse(text)
      JSON.parse(text, object_class: SemanticFinding::UniqueObject, max_nesting: 64)
    rescue JSON::ParserError, SemanticFinding::InvalidInput => e
      raise InvalidMapping, e.message
    end

    def node(id, role, ordinal, value, extra = {})
      payload = canonical(value)
      {'id' => id, 'role' => role, 'ordinal' => ordinal, 'payload_json' => payload,
       'payload_sha256' => Digest::SHA256.hexdigest(payload)}.merge(extra)
    end

    def edge(from, to, type, properties)
      {'from' => from, 'to' => to, 'type' => type, 'properties' => properties}
    end

    def time_links(time, carrier, path, record_ids, edges)
      return unless time.is_a?(Hash)
      if time.key?('alternatives')
        time['alternatives'].each_with_index { |alternative, i| time_links(alternative, carrier, path + "/alternatives/#{i}", record_ids, edges) }
      else
        %w[object occurrence].each do |role|
          target = time.dig('binding', role)
          next if target.nil?
          edges << edge(carrier, record_ids.fetch(target), 'TIME_' + role.upcase, {'path' => path})
        end
      end
    end

    def encode(evidence, source_bytes = {})
      SemanticRecords.index(evidence)
      raise InvalidMapping, 'preserved source bytes must be a source-ID map' unless source_bytes.is_a?(Hash) && source_bytes.keys.all? { |key| key.is_a?(String) && !key.empty? }
      source_ids = evidence['sources'].each_with_index.map { |s, i| [s['id'], "source:#{i}"] }.to_h
      record_ids = evidence['records'].each_with_index.map { |r, i| [r['id'], "record:#{i}"] }.to_h
      header = evidence.reject { |k, _| %w[sources records].include?(k) }
      nodes = [node('envelope', 'envelope', 0, header)]
      edges = []
      evidence['sources'].each_with_index { |s, i| nodes << node(source_ids.fetch(s['id']), 'source', i, s) }
      evidence['records'].each_with_index do |record, i|
        id = record_ids.fetch(record['id'])
        nodes << node(id, 'record', i, record, 'kind' => record['kind'], 'record_type' => record['type'])
        record['evidence'].each_with_index do |ref, ordinal|
          edges << edge(id, source_ids.fetch(ref['source_id']), 'EVIDENCE', {'ordinal' => ordinal, 'field' => ref['field']})
        end
        %w[subject object].each do |role|
          edges << edge(id, record_ids.fetch(record[role]), role.upcase, {}) if record.key?(role)
        end
        record['times'].each { |name, time| time_links(time, id, '/times/' + name.gsub('~', '~0').gsub('/', '~1'), record_ids, edges) }
      end
      source_bytes.keys.sort.each_with_index do |id, i|
        raise InvalidMapping, "unknown preserved source #{id.inspect}" unless source_ids.key?(id)
        bytes = source_bytes[id]
        raise InvalidMapping, 'preserved source content must be a byte string' unless bytes.is_a?(String)
        source = evidence['sources'].find { |s| s['id'] == id }
        declared = source['content_hash']
        if declared && declared['value'] != Digest::SHA256.hexdigest(bytes)
          raise InvalidMapping, "preserved bytes do not match declared source hash: #{id}"
        end
        nodes << node("bytes:#{i}", 'source_bytes', i, {'source_id' => id, 'base64' => Base64.strict_encode64(bytes)})
      end
      {'nodes' => nodes, 'relationships' => edges}
    end

    def graph_identity(graph)
      raise InvalidMapping, 'mapping must have nodes and relationships only' unless graph.is_a?(Hash) && graph.keys.sort == %w[nodes relationships]
      raise InvalidMapping, 'mapping collections must be arrays' unless graph.values.all? { |v| v.is_a?(Array) }
      digest(graph.transform_values { |values| values.sort_by { |value| canonical(value) } })
    end

    def decode(graph, expected_graph_sha256:)
      raise InvalidMapping, 'native mapping differs from imported graph identity' unless graph_identity(graph) == expected_graph_sha256
      roles = Hash.new { |h, k| h[k] = [] }
      graph['nodes'].each do |item|
        raise InvalidMapping, 'invalid node payload identity' unless item.is_a?(Hash) && item['payload_json'].is_a?(String) && Digest::SHA256.hexdigest(item['payload_json']) == item['payload_sha256']
        roles[item['role']] << [item['ordinal'], parse(item['payload_json'])]
      end
      raise InvalidMapping, 'unknown mapping role' unless (roles.keys - %w[envelope source record source_bytes]).empty?
      raise InvalidMapping, 'exactly one envelope is required' unless roles['envelope'].size == 1 && roles['envelope'][0][0] == 0
      values = lambda do |role|
        sorted = roles[role].sort_by(&:first)
        raise InvalidMapping, "invalid #{role} ordinal sequence" unless sorted.map(&:first) == (0...sorted.size).to_a
        sorted.map(&:last)
      end
      evidence = values.call('envelope').first.merge('sources' => values.call('source'), 'records' => values.call('record'))
      bytes = {}
      values.call('source_bytes').each do |blob|
        raise InvalidMapping, 'invalid or duplicate preserved content mapping' unless blob.is_a?(Hash) && blob.keys.sort == %w[base64 source_id] && !bytes.key?(blob['source_id'])
        bytes[blob['source_id']] = Base64.strict_decode64(blob['base64'])
      end
      # Rebuilding from the returned payloads checks each typed edge, direction,
      # multiplicity, source field, record kind/type and exact occurrence binding.
      rebuilt = encode(evidence, bytes)
      raise InvalidMapping, 'native relationship or payload projection is inconsistent' unless graph_identity(rebuilt) == graph_identity(graph)
      [evidence, bytes]
    rescue KeyError, TypeError, ArgumentError => e
      raise InvalidMapping, e.message
    end

    def admit(contract, profile_path: PROFILE_PATH)
      profile = parse(File.read(profile_path))
      unless profile.is_a?(Hash) && profile.keys.sort == %w[contract version id adapter_version mapping_version execution backend inputs semantics outputs mapping supported unsupported admissions].sort &&
             profile['contract'] == 'everypivot.semantic_adapter' && profile['version'] == '1.0' && profile['id'] == 'neo4j_semantic_evidence_v1' && profile['adapter_version'] == '0.1.0' &&
             profile['mapping_version'] == '1.0' && profile['execution'] == 'hybrid_normalized_evidence' &&
             profile['backend'] == {'product' => 'Neo4j Community', 'version' => '5.26.0', 'transport' => 'transactional_http', 'database' => 'neo4j'} &&
             profile['inputs'] == {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0'} &&
             profile['outputs'] == {'contract' => 'everypivot.semantic_results', 'version' => '1.0'} &&
             profile['semantics'] == {'contract' => 'everypivot.semantic_pattern', 'version' => '1.0', 'executor' => 'tools/semantic_evaluator.rb'}
        raise Unsupported, 'unknown semantic adapter profile contract/version'
      end
      unless profile['admissions'].is_a?(Array) && !profile['admissions'].empty? && profile['admissions'].all? do |entry|
        entry.is_a?(Hash) && entry.keys.sort == %w[pattern contract_sha256 hash_scope independent_fixture family_oracle adapter_oracle native_acceptance_runner].sort &&
          entry['pattern'].is_a?(Hash) && entry['pattern'].keys.sort == %w[id version] && entry['pattern'].values.all? { |v| v.is_a?(String) && !v.empty? } &&
          entry['contract_sha256'].is_a?(String) && /\A[0-9a-f]{64}\z/.match?(entry['contract_sha256']) && entry['hash_scope'] == 'canonical_json_v1' &&
          %w[independent_fixture family_oracle adapter_oracle native_acceptance_runner].all? { |k| entry[k].is_a?(String) && !entry[k].empty? }
      end
        raise Unsupported, 'invalid semantic adapter admission manifest'
      end
      identities = profile['admissions'].map { |entry| canonical(entry['pattern']) }
      raise Unsupported, 'duplicate adapter admission identity' unless identities.uniq == identities
      expected_mapping = {'node_label' => 'EveryPivotSemanticItem', 'roles' => %w[envelope record source source_bytes],
                          'payload' => 'canonical_json_v1_with_sha256', 'source_bytes' => 'strict_base64_with_declared_hash_verification_when_present',
                          'relationships' => RELATIONS, 'order' => 'zero_based_ordinal_preserves_sources_records_and_evidence_references',
                          'scope' => 'one_owned_import_batch_with_full_relationship_reconstruction'}
      raise Unsupported, 'unknown normalized evidence mapping' unless profile['mapping'] == expected_mapping
      unless %w[supported unsupported].all? { |key| profile[key].is_a?(Array) && profile[key].all? { |v| v.is_a?(String) && !v.empty? } }
        raise Unsupported, 'profile capability descriptions must be explicit text arrays'
      end
      compiled = SemanticContract.compile(contract)
      match = profile.fetch('admissions').find { |entry| entry['pattern'] == compiled['pattern'] && entry['contract_sha256'] == digest(compiled) }
      raise Unsupported, 'pattern/contract revision has not been admitted to this adapter profile' unless match
      [compiled, profile]
    end

    def evaluate(contract, query, graph, receipt, profile_path: PROFILE_PATH)
      compiled, profile = admit(contract, profile_path: profile_path)
      evidence, bytes = decode(graph, expected_graph_sha256: receipt.fetch('graph_sha256'))
      raise InvalidMapping, 'returned normalized evidence changed' unless digest(evidence) == receipt.fetch('input_sha256')
      result = SemanticEvaluator.new(compiled).evaluate(evidence, query, preserved_source_bytes: bytes)
      result['adapter'] = {'id' => profile['id'], 'version' => profile['adapter_version'],
                           'profile_sha256' => Digest::SHA256.file(profile_path).hexdigest,
                           'execution' => 'portable_evaluator_after_verified_evidence_mapping',
                           'native_execution' => 'requires_separate_transaction_attestation',
                           'graph_sha256' => receipt['graph_sha256'], 'native_predicate_execution' => false,
                           'raw_source_normalization' => 'not_performed', 'assessment_acceptance' => 'not_evaluated'}
      result
    end

    class Native
      attr_reader :journal

      def initialize(endpoint:, owner:, journal: nil, timeout: 30)
        @uri = URI.parse(endpoint)
        unless @uri.is_a?(URI::HTTP) && @uri.scheme == 'http' && @uri.host == '127.0.0.1' && @uri.path == '/db/neo4j/tx/commit' && @uri.port != 80 && !@uri.userinfo && !@uri.query && !@uri.fragment
          raise InvalidMapping, 'explicit HTTP loopback port and /db/neo4j/tx/commit are required'
        end
        raise InvalidMapping, 'task ownership must be a UUIDv4' unless owner.is_a?(String) && TOKEN.match?(owner)
        raise InvalidMapping, 'bounded HTTP timeout required' unless timeout.is_a?(Integer) && timeout.between?(1, 120)
        @owner, @journal, @timeout = owner, journal, timeout
      rescue URI::InvalidURIError, URI::InvalidComponentError => e
        raise InvalidMapping, e.message
      end

      def run(statements)
        request = Net::HTTP::Post.new(@uri.request_uri, 'Content-Type' => 'application/json')
        request.body = JSON.generate('statements' => statements.map { |q, p| {'statement' => q, 'parameters' => p || {}, 'resultDataContents' => ['row']} })
        entry = {'request' => SemanticNeo4j.parse(request.body)}
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        response = Net::HTTP.start(@uri.host, @uri.port, nil, open_timeout: @timeout, read_timeout: @timeout) { |http| http.request(request) }
        entry['http_status'] = response.code.to_i
        raise NativeError, "HTTP #{response.code}" unless response.code == '200'
        body = SemanticNeo4j.parse(response.body)
        entry['response'] = body
        raise NativeError, "native transaction errors: #{body['errors'].inspect}" unless body['errors'] == []
        raise NativeError, 'native result count mismatch' unless body['results'].is_a?(Array) && body['results'].size == statements.size
        body['results'].map do |result|
          raise NativeError, 'invalid native result shape' unless result['columns'].is_a?(Array) && result['columns'].all? { |c| c.is_a?(String) } && result['columns'].uniq == result['columns'] && result['data'].is_a?(Array)
          result['data'].map do |row|
            raise NativeError, 'invalid native row width' unless row['row'].is_a?(Array) && row['row'].size == result['columns'].size
            result['columns'].zip(row['row']).to_h
          end
        end
      rescue StandardError => e
        entry['failure'] = "#{e.class}: #{e.message}" if entry
        raise
      ensure
        if entry && @journal
          entry['seconds'] = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
          @journal.puts(SemanticNeo4j.canonical(entry))
          @journal.flush
        end
      end

      def one(query, params = {})
        run([[query, params]]).first
      end

      def claim_empty!
        runtime
        counts = one('MATCH (n) RETURN count(n) AS nodes').first
        raise NativeError, 'refusing to claim a nonempty database' unless counts == {'nodes' => 0}
        one('CREATE (:EveryPivotSemanticOwner {owner: $owner, profile: $profile})', 'owner' => @owner, 'profile' => 'neo4j_semantic_evidence_v1')
        verify_owner!
      end

      def verify_owner!
        runtime
        rows = one('MATCH (n:EveryPivotSemanticOwner) RETURN properties(n) AS owner')
        expected = [{'owner' => {'owner' => @owner, 'profile' => 'neo4j_semantic_evidence_v1'}}]
        raise NativeError, 'task ownership marker absent, duplicated or different' unless rows == expected
        foreign = one('MATCH (n) WHERE NOT n:EveryPivotSemanticOwner AND NOT (n:EveryPivotSemanticItem AND coalesce(n.owner, "") = $owner AND size(labels(n)) = 1) RETURN count(n) AS foreign', 'owner' => @owner)
        raise NativeError, 'foreign nodes in task database' unless foreign == [{'foreign' => 0}]
        foreign_edges = one('MATCH (a)-[r]->(b) WHERE NOT (a:EveryPivotSemanticItem AND b:EveryPivotSemanticItem AND coalesce(a.owner, "") = $owner AND coalesce(b.owner, "") = $owner) RETURN count(r) AS foreign', 'owner' => @owner)
        raise NativeError, 'foreign relationships in task database' unless foreign_edges == [{'foreign' => 0}]
        true
      end

      def runtime
        rows = one('CALL dbms.components() YIELD name, versions, edition RETURN name, versions, edition')
        unless rows == [{'name' => 'Neo4j Kernel', 'versions' => ['5.26.0'], 'edition' => 'community'}]
          raise Unsupported, 'native runtime differs from the explicit Neo4j Community5.26.0 mapping profile'
        end
        rows
      end

      def write(evidence, source_bytes = {})
        graph = SemanticNeo4j.encode(evidence, source_bytes)
        verify_owner!
        batch = SecureRandom.uuid
        statements = [['UNWIND $nodes AS item CREATE (n:EveryPivotSemanticItem) SET n = item, n.owner = $owner, n.batch = $batch',
                       {'nodes' => graph['nodes'], 'owner' => @owner, 'batch' => batch}]]
        graph['relationships'].group_by { |edge| edge['type'] }.each do |type, edges|
          raise InvalidMapping, 'undeclared relationship type' unless RELATIONS.include?(type)
          statements << ["UNWIND $edges AS edge MATCH (a:EveryPivotSemanticItem {owner: $owner, batch: $batch, id: edge.from}), (b:EveryPivotSemanticItem {owner: $owner, batch: $batch, id: edge.to}) CREATE (a)-[r:#{type}]->(b) SET r = edge.properties",
                         {'edges' => edges, 'owner' => @owner, 'batch' => batch}]
        end
        run(statements)
        {'batch_id' => batch, 'graph_sha256' => SemanticNeo4j.graph_identity(graph), 'input_sha256' => SemanticNeo4j.digest(evidence)}
      end

      def read(receipt)
        verify_owner!
        batch = receipt.fetch('batch_id')
        raise InvalidMapping, 'batch identity must be a UUIDv4' unless batch.is_a?(String) && TOKEN.match?(batch)
        result = run([
          ['MATCH (n:EveryPivotSemanticItem {owner: $owner, batch: $batch}) RETURN properties(n) AS item', {'owner' => @owner, 'batch' => batch}],
          ['MATCH (a:EveryPivotSemanticItem)-[r]->(b:EveryPivotSemanticItem) WHERE (a.owner = $owner AND a.batch = $batch) OR (b.owner = $owner AND b.batch = $batch) RETURN a.id AS from, b.id AS to, a.owner AS from_owner, b.owner AS to_owner, a.batch AS from_batch, b.batch AS to_batch, type(r) AS type, properties(r) AS properties', {'owner' => @owner, 'batch' => batch}]
        ])
        graph = {'nodes' => result[0].map { |r| r.fetch('item').reject { |k, _| %w[owner batch].include?(k) } },
                 'relationships' => result[1].map do |r|
                   raise InvalidMapping, 'cross-collection native relationship' unless r.values_at('from_owner', 'to_owner') == [@owner, @owner] && r.values_at('from_batch', 'to_batch') == [batch, batch]
                   r.reject { |k, _| %w[from_owner to_owner from_batch to_batch].include?(k) }
                 end}
        SemanticNeo4j.decode(graph, expected_graph_sha256: receipt.fetch('graph_sha256'))
        graph
      end

      def state
        run([
          ['MATCH (n) RETURN elementId(n) AS identity, labels(n) AS labels, properties(n) AS properties', {}],
          ['MATCH (a)-[r]->(b) RETURN elementId(r) AS identity, elementId(a) AS from, elementId(b) AS to, type(r) AS type, properties(r) AS properties', {}]
        ]).map { |rows| rows.sort_by { |row| SemanticNeo4j.canonical(row) } }
      end
    end
  end
end
