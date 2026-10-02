#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'fileutils'
require 'time'
require_relative 'semantic_neo4j_adapter'

module EveryPivot
  module SemanticNeo4jAcceptance
    M = SemanticNeo4j
    ROOT = File.expand_path('..', __dir__)
    class Failure < StandardError; end
    module_function

    def read(relative)
      JSON.parse(JSON.generate(M.parse(File.read(File.join(ROOT, relative)))))
    end

    def record(data, id)
      data.fetch('records').find { |r| r['id'] == id } || raise(Failure, "missing case record #{id}")
    end

    def cutoff(value)
      {'binding' => {'object' => 'case-question', 'occurrence' => 'case-cutoff'},
       'field' => '/query/cutoff', 'source_revision' => 'case-1',
       'clock' => {'id' => 'case-utc-clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
       'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
    end

    # Expected outcomes are declared independently, before any evaluator call.
    # Each mutation is an explicit synthetic case, not an external observation.
    def cases
      specifications = [
        ['client-attempt', 'client', 'complete', 1, nil],
        ['server-response', 'server', 'complete', 1, nil],
        ['client-after-period', 'client', 'complete', 0, 'outside_scope'],
        ['server-before-period', 'server', 'complete', 0, 'outside_scope'],
        ['planned-client', 'client', 'complete', 0, nil],
        ['server-borrowed-client-role', 'server', 'complete', 0, nil],
        ['wrong-exchange-leg', 'client', 'complete', 0, nil],
        ['san-is-not-observed-name', 'server', 'complete', 0, nil],
        ['unknown-source-revision', 'client', 'complete', 0, 'unresolved'],
        ['unknown-clock', 'client', 'complete', 0, 'unresolved'],
        ['late-knowledge', 'client', 'complete', 0, nil],
        ['established-knowledge', 'client', 'complete', 1, nil],
        ['explicit-scanner-exclusion', 'client', 'complete', 0, 'suppressed'],
        ['unselected-scanner-context', 'server', 'complete', 1, nil],
        ['binding-budget', 'client', 'partial', 0, nil],
        ['swapped-time-occurrence', 'client', 'complete', 0, nil],
        ['unsupported-clock', 'client', 'complete', 0, 'unsupported'],
        ['wrong-fingerprint-query', 'client', 'unsupported', nil, nil, 'EveryPivot::SemanticEvaluator::UnsupportedInput'],
        ['invalid-budget', 'client', 'invalid_input', nil, nil, 'EveryPivot::SemanticEvaluator::InvalidInput']
      ]
      specifications.map do |id, role, status, count, outcome, error|
        data = read('fixtures/semantic-families/ja3/evidence.json')
        query = read("fixtures/semantic-families/ja3/#{role}-query.json")
        case id
        when 'client-after-period' then query['parameters']['period'] = {'start' => '2026-10-01', 'end' => '2026-10-01'}
        when 'server-before-period' then query['parameters']['period'] = {'start' => '2026-09-30', 'end' => '2026-09-30'}
        when 'planned-client' then record(data, 'm-client')['attributes']['observed_state'] = 'planned'
        when 'server-borrowed-client-role' then record(data, 'm-server')['attributes']['message_role'] = 'client'
        when 'wrong-exchange-leg' then record(data, 'n-client')['attributes']['leg_id'] = 'different-leg'
        when 'san-is-not-observed-name' then record(data, 'n-server')['attributes']['basis'] = 'certificate_san'
        when 'unknown-source-revision' then data['sources'].first['revision'] = nil
        when 'unknown-clock' then record(data, 'm-client')['times']['occurred']['clock']['uncertainty_seconds'] = nil
        when 'late-knowledge' then query['knowledge_cutoff'] = cutoff('2026-09-30T23:59:55Z')
        when 'established-knowledge' then query['knowledge_cutoff'] = cutoff('2026-10-01T00:05:00Z')
        when 'explicit-scanner-exclusion' then query['parameters']['exclude_scanner_exchange'] = true
        when 'binding-budget' then query['limits']['max_bindings'] = 1
        when 'swapped-time-occurrence' then record(data, 'm-client')['times']['occurred']['binding']['occurrence'] = 'm-server'
        when 'unsupported-clock' then record(data, 'm-client')['times']['occurred']['clock']['reference'] = 'unmapped-clock'
        when 'wrong-fingerprint-query' then query['parameters']['selector'] = read('fixtures/semantic-families/ja3/server-query.json')['parameters']['selector']
        when 'invalid-budget' then query['limits']['max_bindings'] = true
        end
        # Preserve the authored case's content separately from its mapping. This
        # is fixture construction, not an independent raw-source normalization test.
        source = {'fixture_type' => 'synthetic_adapter_case', 'case' => id, 'claims' => {}}
        data['records'].each do |r|
          source['claims'][r['id']] = r['attributes'].merge('type' => r['type'], 'normalized_time_metadata' => r['times'])
          %w[subject object].each { |key| source['claims'][r['id']][key] = r[key] if r.key?(key) }
          r['times'].each { |key, time| source['claims'][r['id']][key] = time['value'] }
        end
        bytes = JSON.pretty_generate(source) + "\n"
        data['sources'].first['document'] = "synthetic-adapter-case/#{id}/source.json"
        data['sources'].first['content_hash'] = {'algorithm' => 'sha256', 'value' => Digest::SHA256.hexdigest(bytes), 'scope' => 'exact bytes of this preserved synthetic source.json'}
        pattern = role == 'client' ? 'OSINT_TLS_JA3_TO_FQDNS' : 'OSINT_TLS_JA3S_TO_FQDNS'
        {'id' => id, 'role' => role, 'contract' => read("contracts/semantics/#{pattern}.json"), 'evidence' => data,
         'query' => query, 'source_bytes' => {data['sources'].first['id'] => bytes},
         'expected' => {'status' => status, 'result_count' => count, 'outcome' => outcome, 'error' => error}}
      end
    end

    def assert(value, message)
      raise Failure, message unless value
      1
    end

    def check_result(result, test)
      expected = test['expected']
      count = assert(result['status'] == expected['status'], 'wrong completion/partial status')
      return count + assert(result['error_class'] == expected['error'], 'wrong typed request rejection') if expected['error']
      count += assert(result['results'].length == expected['result_count'], 'wrong independently expected result count')
      count += assert(result['outcome'] == expected['outcome'], 'wrong independently expected semantic outcome') if expected['outcome']
      result['results'].each do |item|
        role = test['role']
        count += assert(item['id'] == 'd-alpha' && item['form'] == 'inet:fqdn' && item['mode'] == 'bound', 'wrong bound result identity/form')
        count += assert(item['identity'] == ['d-alpha', "network-message-#{role}", 'connection-17', 'observer-to-edge'], 'wrong complete result identity')
        count += assert(item['fields']['named_domain'] == 'alpha.example.test', 'wrong observed name')
        count += assert(item['fields']['observed_state'] == (role == 'client' ? 'attempt_observed' : 'response_observed'), 'wrong observed message state')
        count += assert(item['fields']['fingerprint_kind'] == (role == 'client' ? 'ja3' : 'ja3s'), 'client/server fingerprint kind conflated')
        count += assert(item['fields']['domain_basis'] == 'same_exchange_sni', 'wrong naming witness')
        count += assert(item['fields']['message_record'] == "m-#{role}" && item['fields']['domain_association'] == "n-#{role}", 'wrong path bindings')
        count += assert(item['evidence_mode'] == 'evidence_only' && item['assessment_acceptance'] == 'not_evaluated', 'assessment status manufactured')
        count += assert(item['sources'] == test['evidence']['sources'], 'source revision or content identity lost')
        count += assert(item['evidence'].any? { |edge| edge == {'source_id' => 'synthetic-ja3-report', 'field' => "/claims/m-#{role}"} }, 'named-message source witness missing')
        count += assert(item['sources'].all? { |source| source['independent_origin'].nil? }, 'unknown source independence changed')
      end
      count
    end

    def capture(expected)
      yield
    rescue SemanticEvaluator::InvalidInput, SemanticEvaluator::UnsupportedInput => e
      raise unless expected['error'] == e.class.to_s
      {'status' => expected['status'], 'error_class' => e.class.to_s, 'errors' => [e.message], 'results' => [], 'assessment_acceptance' => 'not_evaluated'}
    end

    def run(options)
      output = File.expand_path(options.fetch(:output))
      raise Failure, 'output directory must not already exist' if File.exist?(output)
      FileUtils.mkdir_p(output)
      report = {'contract' => 'everypivot.semantic_native_acceptance', 'version' => '1.0', 'passed' => false,
                'started_utc' => Time.now.utc.iso8601, 'command' => [$PROGRAM_NAME] + options.fetch(:argv),
                'ruby' => RUBY_DESCRIPTION, 'cases' => [], 'structural_checks' => [],
                'native_predicate_execution' => false, 'native_evidence_store_read_executed' => false, 'raw_source_normalization' => 'not_performed',
                'assessment_acceptance' => 'not_evaluated', 'cross_backend_acceptance' => 'not_evaluated'}
      journal_path = File.join(output, 'native-transactions.jsonl')
      begin
        profile = read('adapters/semantic-profiles/neo4j_semantic_evidence_v1.json')
        report['profile'] = profile
        inputs = Dir.glob(File.join(ROOT, 'tools/semantic_*.rb')) + [__FILE__, M::PROFILE_PATH] +
                 Dir.glob(File.join(ROOT, 'contracts/semantics/OSINT_TLS_JA3*.json')) +
                 Dir.glob(File.join(ROOT, 'fixtures/semantic-families/ja3/*.json'))
        report['input_files'] = inputs.sort.map { |path| {'path' => path.sub(ROOT + '/', ''), 'sha256' => Digest::SHA256.file(path).hexdigest} }
        File.open(journal_path, 'w') do |journal|
          native = M::Native.new(endpoint: options.fetch(:endpoint), owner: options.fetch(:owner), journal: journal)
          report['runtime'] = native.runtime
          options[:claim_empty] ? native.claim_empty! : native.verify_owner!
          report['owner'] = options[:owner]
          report['initial_state_sha256'] = M.digest(native.state)
          cases.each do |test|
            dir = File.join(output, test['id'])
            FileUtils.mkdir_p(dir)
            %w[contract evidence query expected].each { |key| File.write(File.join(dir, key + '.json'), JSON.pretty_generate(test[key]) + "\n") }
            File.binwrite(File.join(dir, 'source.json'), test['source_bytes'].values.first)
            M.admit(test['contract']) # Refuse unknown semantics before database writes.
            receipt = native.write(test['evidence'], test['source_bytes'])
            before = native.state
            graph = native.read(receipt)
            report['native_evidence_store_read_executed'] = true
            result = capture(test['expected']) { M.evaluate(test['contract'], test['query'], graph, receipt) }
            after = native.state
            assertions = assert(before == after, 'adapter read/evaluation mutated native database')
            returned, bytes = M.decode(graph, expected_graph_sha256: receipt['graph_sha256'])
            assertions += assert(returned == test['evidence'] && bytes == test['source_bytes'], 'native evidence/source-byte roundtrip differs')
            assertions += check_result(result, test)
            direct = capture(test['expected']) { SemanticEvaluator.new(test['contract']).evaluate(test['evidence'], test['query'], preserved_source_bytes: test['source_bytes']) }
            assertions += assert(result.reject { |key, _| key == 'adapter' } == direct, 'full portable result differs after native mapping')
            File.write(File.join(dir, 'result.json'), JSON.pretty_generate(result) + "\n")
            File.write(File.join(dir, 'receipt.json'), JSON.pretty_generate(receipt) + "\n")
            report['cases'] << {'id' => test['id'], 'passed' => true, 'assertions' => assertions,
                                'input_sha256' => receipt['input_sha256'], 'graph_sha256' => receipt['graph_sha256'],
                                'query_sha256' => M.digest(test['query']), 'contract_sha256' => M.digest(test['contract']),
                                'result_sha256' => M.digest(result), 'native_state_sha256' => M.digest(before),
                                'expected' => test['expected'], 'actual_status' => result['status'], 'actual_outcome' => result['outcome'],
                                'nodes' => graph['nodes'].size, 'relationships' => graph['relationships'].size}
          end
          # Actual native faults, not just edited in-memory snapshots. Each is
          # confined to newly imported task-owned synthetic batches.
          base = cases.first
          %w[EVIDENCE SUBJECT OBJECT TIME_OBJECT TIME_OCCURRENCE].each do |type|
            receipt = native.write(base['evidence'], base['source_bytes'])
            native.one("MATCH (a:EveryPivotSemanticItem {owner: $owner, batch: $batch})-[r:#{type}]->() WITH r LIMIT 1 DELETE r", 'owner' => options[:owner], 'batch' => receipt['batch_id'])
            before = native.state
            rejected = false
            begin
              native.read(receipt)
            rescue M::InvalidMapping
              rejected = true
            end
            assert(rejected, "missing native #{type} edge was accepted")
            assert(before == native.state, 'failed read mutated native database')
            report['structural_checks'] << {'id' => 'missing_native_' + type.downcase, 'passed' => true, 'assertions' => 2}
          end
          left = native.write(base['evidence'], base['source_bytes'])
          right = native.write(base['evidence'], base['source_bytes'])
          native.one('MATCH (a:EveryPivotSemanticItem {owner: $owner, batch: $left, id: "record:0"}), (b:EveryPivotSemanticItem {owner: $owner, batch: $right, id: "record:0"}) CREATE (a)-[:SUBJECT]->(b)', 'owner' => options[:owner], 'left' => left['batch_id'], 'right' => right['batch_id'])
          rejected = false
          begin
            native.read(left)
          rescue M::InvalidMapping
            rejected = true
          end
          assert(rejected, 'cross-batch native edge accepted')
          report['structural_checks'] << {'id' => 'cross_batch_relationship', 'passed' => true, 'assertions' => 1}
          bad_owner = M::Native.new(endpoint: options[:endpoint], owner: SecureRandom.uuid, journal: journal)
          before = native.state
          rejected = false
          begin
            bad_owner.write(base['evidence'])
          rescue M::NativeError
            rejected = true
          end
          assert(rejected && before == native.state, 'wrong owner mutated or admitted database')
          report['structural_checks'] << {'id' => 'wrong_owner_write', 'passed' => true, 'assertions' => 1}
          rejected = false
          begin
            native.claim_empty!
          rescue M::NativeError
            rejected = true
          end
          assert(rejected && before == native.state, 'nonempty database was claimed')
          report['structural_checks'] << {'id' => 'nonempty_database_claim', 'passed' => true, 'assertions' => 1}
          report['final_state_sha256'] = M.digest(native.state)
        end
        report['input_files_after'] = inputs.sort.map { |path| {'path' => path.sub(ROOT + '/', ''), 'sha256' => Digest::SHA256.file(path).hexdigest} }
        assert(report['input_files'] == report['input_files_after'], 'implementation or fixture source changed during native acceptance; rerun exact final inputs')
        report['passed'] = report['cases'].size == 19 && report['structural_checks'].size == 8
      rescue StandardError => e
        report['failure'] = {'class' => e.class.to_s, 'message' => e.message, 'backtrace' => e.backtrace.first(5)}
      ensure
        report['ended_utc'] = Time.now.utc.iso8601
        report['journal_sha256'] = Digest::SHA256.file(journal_path).hexdigest if File.file?(journal_path)
        report['assertions'] = (report['cases'] + report['structural_checks']).sum { |item| item['assertions'] }
        report['skips'] = 0
        File.write(File.join(output, 'acceptance.json'), JSON.pretty_generate(report) + "\n")
      end
      puts JSON.pretty_generate(report.slice('passed', 'assertions', 'failure').merge('cases' => report['cases'].size, 'structural_checks' => report['structural_checks'].size, 'report' => File.join(output, 'acceptance.json')))
      report['passed'] ? 0 : 1
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  options = {argv: ARGV.dup}
  parser = OptionParser.new do |p|
    p.banner = 'Usage: accept_semantic_neo4j.rb --endpoint HTTP_LOOPBACK --owner UUID --output NEW_DIR [--claim-empty]'
    p.on('--endpoint URL') { |v| options[:endpoint] = v }
    p.on('--owner UUID') { |v| options[:owner] = v }
    p.on('--output PATH') { |v| options[:output] = v }
    p.on('--claim-empty', 'Claim only a verified empty task-owned synthetic database') { options[:claim_empty] = true }
  end
  begin
    parser.parse!
    raise OptionParser::InvalidArgument, 'unexpected arguments' unless ARGV.empty?
    %i[endpoint owner output].each { |key| raise OptionParser::MissingArgument, key.to_s unless options[key] }
    exit EveryPivot::SemanticNeo4jAcceptance.run(options)
  rescue OptionParser::ParseError, EveryPivot::SemanticNeo4jAcceptance::Failure => e
    warn e.message
    exit 2
  end
end
