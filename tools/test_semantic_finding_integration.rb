#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative 'semantic_evaluator'

# Synthetic records exercise the complete portable engine, not native adapters
# or actual extraction. Expectations come from the accepted finding/observation
# distinction: a 2024 file can gain a 2026 finding; equivalent replay cannot make
# an August finding recent in September; unrelated files cannot borrow support.
class SemanticFindingIntegrationTest < Minitest::Test
  E = EveryPivot::SemanticEvaluator
  C = EveryPivot::SemanticContract

  def eq(ref, other)
    {'op' => 'eq', 'left' => {'ref' => ref}, 'right' => other}
  end

  def contract
    {'contract' => 'everypivot.semantic_pattern', 'version' => '1.0',
     'pattern' => {'id' => 'SYNTHETIC_EXTRACTED_URI_FINDING', 'version' => '1.0.0'},
     'parameters' => {
       'seed' => {'type' => 'record_id', 'required' => true, 'description' => 'Exact supplied selector record'},
       'history' => {'type' => 'record_id', 'required' => true, 'description' => 'Declared preserved collection history'},
       'period' => {'type' => 'period', 'required' => true, 'description' => 'Complete finding availability dates'}},
     'branches' => [{'id' => 'file_reference', 'bindings' => [
       {'name' => 'seed', 'kind' => 'entity', 'types' => ['selector:uri'], 'query_seed' => true,
        'where' => eq('seed.id', {'param' => 'seed'})},
       {'name' => 'extraction', 'kind' => 'assertion', 'types' => ['extraction:uri'],
        'where' => eq('extraction.object', {'ref' => 'seed.id'})},
       {'name' => 'artifact', 'kind' => 'entity', 'types' => ['file:hash'],
        'where' => eq('artifact.id', {'ref' => 'extraction.subject'})}],
       'where' => {'op' => 'all', 'args' => [
         {'op' => 'typed_equal', 'left' => {'ref' => 'extraction.attributes.selector'}, 'right' => {'ref' => 'seed.attributes.selector'}},
         eq('extraction.attributes.scope', {'literal' => 'preserved_file_bytes'}),
         {'op' => 'present', 'value' => {'ref' => 'extraction.attributes.run_id'}},
         {'op' => 'present', 'value' => {'ref' => 'extraction.attributes.location'}}]},
       'knowledge' => [{'ref' => 'artifact.times.collection_available'}, {'ref' => 'extraction.times.collection_available'}],
       'time_bindings' => [
         {'value' => {'ref' => 'artifact.times.collection_available'}, 'object' => {'ref' => 'artifact.id'}, 'occurrence' => {'ref' => 'artifact.attributes.availability_occurrence'}},
         {'value' => {'ref' => 'extraction.times.collection_available'}, 'object' => {'ref' => 'extraction.id'}, 'occurrence' => {'ref' => 'extraction.attributes.availability_occurrence'}}],
       'finding' => {'id' => 'file-contained-uri', 'revision' => '1.0',
                     'identity' => [{'literal' => 'file_content_uri'}, {'ref' => 'artifact.attributes.sha256'}, {'selector_identity' => 'extraction.attributes.selector'}],
                     'support' => %w[artifact extraction], 'history' => {'param' => 'history'}, 'period' => {'param' => 'period'}},
       'result' => {'mode' => 'bound', 'binding' => 'artifact', 'form' => 'file:hash',
                    'identity' => [{'ref' => 'artifact.attributes.sha256'}],
                    'fields' => {'relationship' => {'literal' => 'contains_uri'}, 'run' => {'ref' => 'extraction.attributes.run_id'}}}}]}
  end

  def envelope(value, object, occurrence, field)
    {'binding' => {'object' => object, 'occurrence' => occurrence}, 'field' => field, 'source_revision' => 'r1',
     'clock' => {'id' => 'lab-clock', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end

  def selector(carrier, value = 'urn:example:token:a', method = 'extract-v1')
    {'kind' => 'uri', 'normalization' => 'literal_rfc3986_v1', 'value' => value,
     'provenance' => {'source' => 's1', 'record_id' => carrier, 'source_revision' => 'r1',
                      'field' => "/records/#{carrier}/selector", 'basis' => 'derived', 'method' => method, 'method_version' => '1'}}
  end

  def record(id, kind, type, attrs = {}, times = {})
    {'id' => id, 'kind' => kind, 'type' => type, 'attributes' => attrs, 'times' => times,
     'evidence' => (["/records/#{id}"] + times.values.map { |time| time['field'] }).uniq.map { |field| {'source_id' => 's1', 'field' => field} }}
  end

  def fixture
    c = contract
    source = {'id' => 's1', 'publisher' => 'synthetic laboratory', 'document' => 'preserved-log', 'revision' => 'r1', 'collection' => 'C', 'independent_origin' => nil}
    origin = record('origin', 'occurrence', 'collection:origin', {'collection_id' => 'C'},
                    {'origin' => envelope('2020-01-01T00:00:00Z', 'origin', 'origin', '/origin')})
    snapshot = record('snapshot', 'occurrence', 'collection:history_snapshot', {'collection_id' => 'C'},
                      {'through' => envelope('2026-10-01T00:00:00Z', 'snapshot', 'snapshot', '/through')})
    artifact = record('artifact', 'entity', 'file:hash', {'sha256' => 'a' * 64, 'availability_occurrence' => 'receipt-file'},
                      {'collection_available' => envelope('2024-12-15T13:00:00Z', 'artifact', 'receipt-file', '/records/artifact/available')})
    sighting = record('sighting-2024', 'occurrence', 'file:sighting', {'location' => 'endpoint-A'},
                      {'observed' => envelope('2024-12-15T12:00:00Z', 'artifact', 'sighting-2024', '/records/sighting-2024/observed')})
    sighting['subject'] = 'artifact'
    history = record('history', 'assertion', 'finding:history', {'manifest_source_id' => 'manifest', 'manifest_field' => '/history'})
    history['evidence'] = [{'source_id' => 'manifest', 'field' => '/history'}]
    data = {contract: c, evidence: {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0', 'collection_id' => 'C',
      'sources' => [source, source.merge('id' => 'manifest', 'document' => 'history-manifest')],
      'records' => [origin, snapshot, artifact, sighting, history,
                    record('seed', 'entity', 'selector:uri', {'selector' => selector('seed')}),
                    record('receipt-file', 'occurrence', 'evidence:availability', {'collection_id' => 'C'})]},
      query: {'parameters' => {'seed' => 'seed', 'history' => 'history', 'period' => {'start' => '2026-08-15', 'end' => '2026-09-14'}},
              'limits' => {'max_bindings' => 1000, 'max_results' => 100}}}
    add_extraction(data, 'extraction-september', '2026-09-10T00:00:00Z', '2026-09-11T00:00:00Z')
    seal(data)
  end

  def find(data, id)
    data[:evidence]['records'].find { |item| item['id'] == id }
  end

  def qualification(data, branch_index = 0)
    finding = data[:contract]['branches'][branch_index]['finding']
    {'id' => finding['id'], 'revision' => finding['revision'], 'contract_sha256' => C.digest(data[:contract])}
  end

  # These expected semantic components are written independently of evaluator
  # operand resolution. Provenance, run ID and processing method are excluded.
  def claim_key(data, output_kind = 'file_content_uri', digest = 'a' * 64)
    C.digest({'qualification' => ['file-contained-uri', '1.0'],
              'identity' => [output_kind, digest, {'kind' => 'uri', 'comparison' => ['literal_rfc3986_v1'], 'value' => 'urn:example:token:a'}]})
  end

  def add_extraction(data, id, available, established, artifact: 'artifact', output_kind: 'file_content_uri')
    receipt = 'receipt-' + id
    data[:evidence]['records'] << record(receipt, 'occurrence', 'evidence:availability', {'collection_id' => 'C'})
    extraction = record(id, 'assertion', 'extraction:uri',
                        {'selector' => selector(id), 'scope' => 'preserved_file_bytes', 'run_id' => 'run-' + id,
                         'location' => 'bytes:128-147', 'availability_occurrence' => receipt},
                        {'collection_available' => envelope(available, id, receipt, "/records/#{id}/available")})
    extraction['subject'], extraction['object'] = artifact, 'seed'
    data[:evidence]['records'] << extraction
    add_establishment(data, 'establishment-' + id, established, [artifact, id], output_kind)
  end

  def add_establishment(data, id, established, support_ids, output_kind = 'file_content_uri')
    event = record(id, 'occurrence', 'finding:establishment',
                   {'claim_key' => claim_key(data, output_kind), 'collection_id' => 'C', 'history_id' => 'history',
                    'qualification' => qualification(data), 'support' => support_ids.map { |sid| {'record_id' => sid, 'sha256' => '0' * 64} }},
                   {'established' => envelope(established, id, id, "/records/#{id}/established")})
    data[:evidence]['records'] << event
  end

  def seal(data, coverage: 'complete_declared_scope')
    events = data[:evidence]['records'].select { |item| item['type'] == 'finding:establishment' }
    events.each do |event|
      event['attributes']['qualification'] = qualification(data)
      event['attributes']['support'].each { |ref| ref['sha256'] = C.digest(find(data, ref['record_id'])) }
    end
    manifest = {'contract' => EveryPivot::SemanticFinding::ID, 'version' => '1.0', 'history_id' => 'history',
                'revision' => 'r1', 'collection_id' => 'C', 'scope_id' => 'C-origin-through-snapshot',
                'origin_id' => 'origin', 'origin_sha256' => C.digest(find(data, 'origin')),
                'through_id' => 'snapshot', 'through_sha256' => C.digest(find(data, 'snapshot')),
                'coverage' => coverage, 'qualification' => qualification(data),
                'establishments' => events.map { |event| {'record_id' => event['id'], 'sha256' => C.digest(event)} }}
    bytes = JSON.generate('history' => manifest)
    data[:evidence]['sources'].find { |source| source['id'] == 'manifest' }['content_hash'] =
      {'algorithm' => 'sha256', 'value' => Digest::SHA256.hexdigest(bytes), 'scope' => 'exact_source_bytes'}
    data[:bytes] = {'manifest' => bytes}
    data
  end

  def evaluate(data)
    E.new(data[:contract]).evaluate(data[:evidence], data[:query], preserved_source_bytes: data[:bytes])
  end

  def test_old_file_and_later_extraction_produce_a_new_complete_finding_without_a_new_sighting
    data = fixture
    before = Marshal.load(Marshal.dump(data[:evidence]))
    answer = evaluate(data)
    assert_equal 'complete', answer['status']
    assert_equal 'qualified_evidence', answer['outcome']
    assert_equal ['artifact'], answer['results'].map { |item| item['id'] }
    finding = answer['results'][0]['finding_evaluation']
    assert_equal claim_key(data), finding['claim_key']
    assert_equal '2026-09-11T00:00:00Z', finding['first_scoped_time']['value']
    assert_equal before, data[:evidence]
    assert_equal ['sighting-2024'], data[:evidence]['records'].select { |r| r['type'] == 'file:sighting' }.map { |r| r['id'] }
    assert_equal '2024-12-15T12:00:00Z', find(data, 'sighting-2024').dig('times', 'observed', 'value')
  end

  def test_replay_and_new_run_do_not_refresh_the_earliest_equivalent_claim
    data = fixture
    add_extraction(data, 'extraction-august', '2026-08-09T00:00:00Z', '2026-08-10T00:00:00Z')
    find(data, 'extraction-september')['attributes']['selector']['provenance']['method'] = 'different-tool'
    find(data, 'extraction-september')['attributes']['selector']['provenance']['method_version'] = '99'
    seal(data)
    answer = evaluate(data)
    assert_empty answer['results']
    assert_equal 'outside_scope', answer['outcome']
    findings = answer['diagnostics'].map { |item| item['finding_evaluation'] }.compact
    refute_empty findings
    assert findings.all? { |item| item['claim_key'] == claim_key(data) }
    assert findings.all? { |item| item['first_scoped_time']['value'] == '2026-08-10T00:00:00Z' }
    data[:query]['parameters']['period']['start'] = '2026-08-01'
    widened = evaluate(data)
    assert_equal 2, widened['results'].length
    assert_equal 1, widened['results'].map { |item| item['finding_evaluation']['claim_key'] }.uniq.length
  end

  def test_wrong_file_or_selector_cannot_borrow_an_establishment
    data = fixture
    wrong = Marshal.load(Marshal.dump(find(data, 'artifact')))
    wrong['id'] = 'unrelated-file'
    wrong['attributes']['sha256'] = 'b' * 64
    wrong['times']['collection_available']['binding']['object'] = 'unrelated-file'
    data[:evidence]['records'] << wrong
    find(data, 'extraction-september')['subject'] = 'unrelated-file'
    answer = evaluate(seal(data))
    assert_empty answer['results']
    assert_equal 'unresolved', answer['outcome']
    data = fixture
    find(data, 'extraction-september')['attributes']['selector']['value'] = 'urn:example:token:other'
    answer = evaluate(seal(data))
    assert_empty answer['results']
    assert_equal 'no_qualifying_result', answer['outcome']
  end

  def test_raw_timestamp_maximum_or_complete_flag_cannot_create_missing_history
    data = fixture
    data[:evidence]['records'].reject! { |record| record['type'] == 'finding:establishment' }
    find(data, 'extraction-september')['attributes']['complete'] = true
    answer = evaluate(seal(data))
    assert_empty answer['results']
    assert_equal 'unresolved', answer['outcome']
    data = fixture
    data[:bytes] = {}
    assert_equal 'unresolved', evaluate(data)['outcome']
  end

  def test_earlier_equivalent_with_unknown_time_blocks_claimed_freshness
    data = fixture
    add_extraction(data, 'extraction-earlier', '2026-08-09T00:00:00Z', '2026-08-10T00:00:00Z')
    find(data, 'establishment-extraction-earlier')['times']['established'].delete('timezone')
    answer = evaluate(seal(data))
    assert_empty answer['results']
    assert_equal 'unresolved', answer['outcome']
    assert answer['diagnostics'].any? { |item| item['reason'].include?('later event cannot manufacture freshness') }
  end

  def test_independently_typed_output_claims_have_distinct_availability
    data = fixture
    companion = Marshal.load(Marshal.dump(data[:contract]['branches'][0]))
    companion['id'] = 'context_reference'
    companion['finding']['identity'][0] = {'literal' => 'file_context_uri'}
    companion['result']['fields']['relationship'] = {'literal' => 'context_association'}
    data[:contract]['branches'] << companion
    add_establishment(data, 'context-established', '2026-09-13T00:00:00Z', %w[artifact extraction-september], 'file_context_uri')
    answer = evaluate(seal(data))
    assert_equal 2, answer['results'].length
    by_branch = answer['results'].map { |item| [item['branch'], item['finding_evaluation']] }.to_h
    assert_equal '2026-09-11T00:00:00Z', by_branch['file_reference']['first_scoped_time']['value']
    assert_equal '2026-09-13T00:00:00Z', by_branch['context_reference']['first_scoped_time']['value']
    refute_equal by_branch['file_reference']['claim_key'], by_branch['context_reference']['claim_key']
  end

  def test_partial_join_search_cannot_assert_earliest_finding
    data = fixture
    add_extraction(data, 'z-later-extraction', '2026-09-12T00:00:00Z', '2026-09-13T00:00:00Z')
    seal(data)
    data[:query]['limits']['max_bindings'] = 3
    answer = evaluate(data)
    assert_equal 'partial', answer['status']
    assert_empty answer['results']
    refute answer['coverage']['exhaustive_for_supplied_input']
    assert answer['diagnostics'].any? { |item| item['reason'].include?('partial qualification search') }
  end

  def test_finding_support_cannot_omit_a_required_nonseed_binding
    c = contract
    c['branches'][0]['finding']['support'] = ['extraction']
    error = assert_raises(C::InvalidContract) { E.new(c) }
    assert_match(/omits required binding artifact/, error.message)
    c = contract
    c['branches'][0]['finding']['identity'] << {'ref' => 'extraction.attributes.run_id'}
    assert_raises(C::InvalidContract) { E.new(c) }
  end

  def test_known_by_cutoff_requires_complete_finding_not_just_components
    data = fixture
    data[:query]['knowledge_cutoff'] = envelope('2026-09-10T12:00:00Z', 'query', 'query', '/cutoff')
    answer = evaluate(data)
    assert_empty answer['results']
    data[:query]['knowledge_cutoff']['value'] = '2026-09-11T00:00:00Z'
    assert_equal ['artifact'], evaluate(data)['results'].map { |item| item['id'] }
  end

  def test_later_material_does_not_erase_an_established_as_known_finding
    data = fixture
    add_extraction(data, 'later-replay', '2026-09-13T00:00:00Z', '2026-09-14T00:00:00Z')
    seal(data)
    data[:query]['knowledge_cutoff'] = envelope('2026-09-11T00:00:00Z', 'query', 'query', '/cutoff')
    answer = evaluate(data)
    assert_equal ['artifact'], answer['results'].map { |item| item['id'] }
    assert_equal ['extraction-september'], answer['results'].map { |item| item['bindings']['extraction'] }
  end

  def test_equivalent_claim_history_includes_independently_qualified_alternative_branches
    data = fixture
    first = data[:contract]['branches'][0]
    first['where']['args'] << eq('extraction.attributes.derivation_path', {'literal' => 'direct'})
    alternative = Marshal.load(Marshal.dump(first))
    alternative['id'] = 'decoded_reference'
    alternative['where']['args'][-1] = eq('extraction.attributes.derivation_path', {'literal' => 'decoded'})
    data[:contract]['branches'] << alternative
    find(data, 'extraction-september')['attributes']['derivation_path'] = 'direct'
    add_extraction(data, 'older-decoded', '2026-08-09T00:00:00Z', '2026-08-10T00:00:00Z')
    find(data, 'older-decoded')['attributes']['derivation_path'] = 'decoded'
    answer = evaluate(seal(data))
    assert_empty answer['results']
    assert_equal 'outside_scope', answer['outcome']
    findings = answer['diagnostics'].map { |item| item['finding_evaluation'] }.compact
    refute_empty findings
    assert findings.all? { |finding| finding['first_scoped_time']['value'] == '2026-08-10T00:00:00Z' }
  end
end
