# frozen_string_literal: true
require_relative '../extraction/fixture_factory'
module ResultBindingFixtures
  F = ExtractionFixtures
  module_function
  def interval(start_value, end_value, object, occurrence, field, role = 'validity')
    x = F.time(start_value, object, occurrence, field)
    x.delete('value')
    x.merge('start' => start_value, 'end' => end_value, 'start_inclusive' => true, 'end_inclusive' => true, 'precision' => 'interval', 'interval_role' => role)
  end
  def base(id)
    d = F.base(id)
    d['query']['parameters'].delete('history')
    d
  end
  def role(data, id, phases, exclusive, basis = 'declared')
    input_id = id + '-input'
    F.artifact(data, input_id, 'evidence:endpoint_role', 'preserved ' + id + ' ' + phases.join(','), {}, available: '2026-09-10T00:00:00Z')
    r = F.rec(data, id, 'assertion', basis == 'declared' ? 'adtech:endpoint_role_declaration' : 'adtech:endpoint_role_inference',
      {'basis' => basis, 'input_id' => input_id, 'phases' => phases, 'exclusive' => exclusive,
       'method' => 'POST', 'tenant' => 'tenant-7', 'api_version' => 'v3', 'inference_method' => 'integration_and_correlated_exchange_v1',
       'inference_version' => '1', 'exchange_input_id' => id + '-exchange'}, subject: 'endpoint')
    r['times']['applicable'] = interval('2026-01-01T00:00:00Z', '2026-12-31T23:59:59Z', 'endpoint', id, '/records/' + id + '/applicable')
    F.artifact(data, id + '-exchange', 'evidence:role_exchange', 'preserved independent workflow exchange ' + id, {'endpoint_id' => 'endpoint'}) if basis == 'inferred'
    r
  end
  def phase(method: 'request_trace', basis: 'declared', outcome: 'mismatch')
    d = base('ADTECH_PIPELINE_PHASE_MISMATCH')
    d['query']['parameters']['query_date'] = '2026-09-15'
    d['query']['parameters']['rule'] = 'rule'
    F.rec(d, 'seed', 'entity', 'http:request', {}, available: nil)
    F.rec(d, 'request', 'occurrence', 'http:request_occurrence',
      {'occurrence_key' => 'request-R17', 'endpoint_id' => 'endpoint', 'method' => 'POST', 'tenant' => 'tenant-7', 'api_version' => 'v3'},
      subject: 'seed', available: '2026-09-14T13:00:00Z', occurred: '2026-09-14T12:00:01Z')
    F.rec(d, 'phase', 'assertion', 'adtech:request_phase', {'method' => method + '_phase_v1', 'method_version' => '1',
      'phase' => 'post_impression', 'input_id' => 'request-input', 'context_id' => 'context'}, subject: 'request', available: '2026-09-14T13:00:00Z')
    F.artifact(d, 'request-input', 'evidence:request_trace', 'preserved particular R17 request context', {'request_occurrence' => 'request-R17'}, available: '2026-09-14T13:00:00Z')
    F.rec(d, 'endpoint', 'entity', 'inet:url', {'value' => 'https://delivery.example/auction'})
    F.artifact(d, 'rule', 'comparison:phase_rule', 'exclusive phase set comparison rule revision1',
      {'profile' => 'exclusive_phase_set_v1', 'revision' => '1', 'phases' => %w[pre_auction post_impression]})
    role(d, 'role', outcome == 'compatible' ? %w[pre_auction post_impression] : ['pre_auction'], outcome != 'compatible', basis)
    role(d, 'contrary-role', ['post_impression'], false) if outcome == 'contested'
    if method != 'request_trace'
      context = F.rec(d, 'context', 'occurrence', 'web:page_context', {}, available: '2026-09-14T13:00:00Z')
      context['times']['started'] = F.time('2026-09-14T12:00:00Z', 'context', 'context', '/records/context/started')
      context['times']['completed'] = F.time('2026-09-14T12:00:03Z', 'context', 'context', '/records/context/completed')
      F.rec(d, 'context-link', 'assertion', 'http:request_context', {}, subject: 'request', object: 'context', available: '2026-09-14T13:00:00Z')
    end
    F.add_control(d, 'known_multi_phase_ad_endpoints', 'endpoint', 'not_member', 'policy-r1', 'clear-endpoint')
    F.add_control(d, 'major_ad_exchange_canonical_hosts', 'endpoint', 'not_member', 'policy-r1', 'clear-host')
    F.seal(d)
  end
  def officer
    d = base('FIN_ORG_OFFICER_SHARE_CLUSTER')
    d['query']['parameters']['scope'] = 'default_3650_day_service'
    F.rec(d, 'seed', 'entity', 'person', {'identity_scope' => 'registry-person-Alice'}, available: nil)
    F.rec(d, 'bob', 'entity', 'person', {'identity_scope' => 'registry-person-Bob'}, available: nil)
    %w[A B C].each { |id| F.rec(d, id, 'entity', 'org:org', {'identity_scope' => 'registry-company-' + id}) }
    [['Alice-A', 'seed', 'A', '2018', '2020'], ['Alice-B', 'seed', 'B', '2024', '2026'], ['Bob-A', 'bob', 'A', '2023', '2026'], ['Bob-C', 'bob', 'C', '2024', '2026']].each do |id, person, org, first, last|
      F.rec(d, id, 'assertion', 'org:appointment', {'role' => 'director', 'person_scope' => person == 'seed' ? 'registry-person-Alice' : 'registry-person-Bob',
        'organisation_scope' => 'registry-company-' + org, 'appointment_key' => id}, subject: person, object: org)
      service = F.rec(d, id + '-service', 'assertion', 'org:service_interval', {}, subject: id)
      service['times']['held'] = interval(first + '-01-01T00:00:00Z', last + '-01-01T00:00:00Z', id, service['id'], '/records/' + service['id'] + '/held', 'service')
    end
    F.seal(d)
  end
  def creative(path: 'direct', kind: 'reference', uri: 'https://delivery.example/pixel')
    d = F.base('ADTECH_CREATIVE_SCRIPT_TO_DELIVERY_ENDPOINT')
    d['query']['parameters']['query_date'] = '2026-09-16'
    F.get(d, 'snapshot')['times']['through']['value'] = '2026-09-16T23:59:59Z'
    F.artifact(d, 'seed', 'web:creative', 'exact creative C1 markup', {'capture_id' => 'creative-C1'}, available: '2026-01-10T00:00:00Z')
    input_id = 'seed'
    support = ['seed']
    if path == 'script'
      input_id = 'script'
      F.artifact(d, 'script', 'web:script', 'exact script S1 code', {}, available: '2026-01-10T00:00:00Z')
      F.rec(d, 'embed', 'assertion', 'creative:script_correspondence',
        {'creative_capture' => 'creative-C1', 'script_sha256' => F.hash_of(d, 'script'), 'source_location' => 'script:1',
         'basis' => 'exact_capture_resource_correspondence'}, subject: 'seed', object: 'script')
      support += %w[embed script]
    end
    if kind == 'reference'
      F.artifact(d, 'output', 'evidence:extracted_value', uri, {'uri' => F.typed('uri', uri, 'output')})
      F.extraction(d, 'analysis:creative_reference_extraction', 'qualified_creative_reference', input_id, 'output',
        {'reference_basis' => path == 'script' ? 'script_operation' : 'markup_attribute', 'reference_role' => 'impression_endpoint', 'creative_capture' => 'creative-C1'})
      identity = ['creative_reference', 'creative-C1', F.hash_of(d, input_id), F.typed_identity('uri', uri), 'impression_endpoint']
      support += %w[extraction output]
    else
      F.rec(d, 'request', 'occurrence', 'http:creative_request', {'creative_capture' => 'creative-C1', 'trace_id' => 'trace',
        'occurrence_key' => 'request-R1', 'stage' => 'initiated_attempt', 'uri' => F.typed('uri', uri, 'request')},
        subject: 'request', occurred: '2026-01-10T00:01:00Z')
      F.rec(d, 'correlation', 'assertion', 'creative:request_correspondence', {'input_id' => input_id, 'creative_capture' => 'creative-C1',
        'input_sha256' => F.hash_of(d, input_id), 'basis' => 'correlated_source_exchange', 'method' => 'capture-event-correlation', 'method_version' => '1'},
        subject: 'seed', object: 'request')
      F.artifact(d, 'trace', 'evidence:request_trace', 'preserved request R1 event', {'request_occurrence' => 'request-R1'})
      identity = ['creative_request', 'creative-C1', 'request-R1', F.typed_identity('uri', uri), 'initiated_attempt']
      support += %w[request correlation trace]
    end
    if uri.start_with?('https://')
      F.rec(d, 'url', 'entity', 'inet:url', {'value' => uri})
      support << 'url'
      unless uri.include?('192.0.2.')
        F.rec(d, 'host', 'assertion', 'uri:dns_host', {'selector' => F.typed('dns_name', 'delivery.example', 'host')}, subject: 'url')
        support << 'host'
        F.add_control(d, 'commodity_ad_verification_pixels', 'host', 'not_member', 'policy-r1', 'clear-pixel')
        F.add_control(d, 'known_cdn_static_assets', 'host', 'not_member', 'policy-r1', 'clear-cdn')
      end
    end
    F.claim(d, identity, support, 'creative-established', '2026-09-15T00:00:00Z')
    F.seal(d)
  end
  def ipv4(value, carrier)
    F.typed('uri', value, carrier).merge('kind' => 'ipv4', 'normalization' => 'strict_dotted_decimal_v1', 'representation' => 'dotted_decimal')
  end
  def sbl(question = 'ip', covering: false, network_start: '2024-01-01T00:00:00Z')
    names = {'ip' => 'CTI_IP_TO_LISTING_ASSERTIONS', 'asn' => 'CTI_ASN_TO_EXPLICIT_LISTING_ASSERTIONS', 'network' => 'CTI_ASN_TO_LISTED_INFRASTRUCTURE'}
    d = base(names.fetch(question))
    d['query']['parameters'].delete('query_date')
    d['query']['parameters'].merge!('period' => {'start' => '2024-04-01', 'end' => '2024-04-30'},
      'period_origin' => 'case', 'claim_kind' => question == 'asn' ? 'explicit_asn_assertion' : 'listing_status', 'reference_sources' => ['report'])
    F.rec(d, 'seed', 'entity', question == 'ip' ? 'inet:ipv4' : 'net:asn',
      question == 'ip' ? {'selector' => ipv4('192.0.2.20', 'seed')} : {'number' => 64500}, available: nil)
    subject = 'seed'
    subject_kind = question == 'asn' ? 'asn' : 'ipv4'
    if question == 'network' || covering
      subject = 'infrastructure'
      subject_kind = covering ? 'ipv4_prefix' : 'ipv4'
      F.rec(d, subject, 'entity', covering ? 'inet:net4' : 'inet:ipv4', covering ? {'value' => '192.0.2.0/24'} : {'selector' => ipv4('192.0.2.20', subject)})
    end
    F.rec(d, 'entry', 'entity', 'reputation:entry', {'collection_identity' => 'publisher-list-A', 'entry_identity' => 'entry-17', 'entry_revision' => 'entry-r1'})
    claim = F.rec(d, 'claim', 'assertion', 'reputation:assertion', {'subject_kind' => subject_kind,
      'claim_kind' => d['query']['parameters']['claim_kind'], 'time_basis' => 'established_state', 'assertion_namespace' => 'publisher-list-A',
      'statement' => 'source reports listed status during April2024', 'source_scope' => 'specified entry subject only', 'entry_revision' => 'entry-r1'}, subject: subject, object: 'entry')
    claim['times']['applies'] = interval('2024-04-01T00:00:00Z', '2024-04-30T23:59:59Z', subject, 'claim', '/records/claim/applies')
    if covering && question == 'ip'
      provenance = {'source' => 'report', 'record_id' => 'prefix-scope', 'source_revision' => 'r1', 'field' => '/records/prefix-scope/prefix', 'basis' => 'reported'}
      F.rec(d, 'prefix-scope', 'assertion', 'network:prefix_scope', {'prefix' => {'value' => '192.0.2.0/24', 'representation' => 'ipv4_cidr',
        'normalization' => 'strict_network_cidr_v1', 'provenance' => provenance},
        'applicability' => {'value' => 'all_addresses_in_prefix', 'provenance' => provenance.merge('field' => '/records/prefix-scope/applicability')},
        'assertion_namespace' => 'publisher-list-A'}, subject: 'claim')
    end
    if question == 'network'
      association = F.rec(d, 'association', 'assertion', 'network:asn_association', {'role' => 'bgp_origin', 'vantage' => 'retained-route-observer',
        'coverage' => 'entire_subject_scope', 'assertion_namespace' => 'route-source-A'}, subject: subject, object: 'seed')
      association['times']['applicable'] = interval(network_start, '2026-12-31T23:59:59Z', subject, 'association', '/records/association/applicable')
    end
    F.seal(d)
  end
  def manifest(d, id, files)
    scope = {'identity' => 'explicit-collected-kit-scope-1', 'kind' => 'collected_file_set', 'description' => 'all paths in this supplied collection; deployment completeness unknown'}
    entries = files.each_with_index.map do |(path, bytes), i|
      member = F.artifact(d, id + '-file-' + i.to_s, 'kit:file_set_member', bytes)
      member['attributes']['content'].merge!('source_revision' => 'r1', 'field' => '/')
      member['attributes']['content'].delete('locator')
      {'path' => path, 'record_id' => member['id'], 'sha256' => F.hash_of(d, member['id']), 'byte_length' => bytes.bytesize}
    end
    body = {'contract' => 'everypivot.file_set_manifest', 'version' => '1.0', 'profile' => 'exact_manifest_v1', 'scope' => scope,
      'path_mapping' => 'exact_relative_posix_v1', 'normalization' => 'none', 'exclusions' => [], 'transformations' => [], 'entries' => entries}
    record = F.artifact(d, id, 'kit:file_set_manifest', JSON.generate(body), {'coverage_record_id' => id + '-coverage'})
    record['attributes']['content'].merge!('source_revision' => 'r1', 'field' => '/')
    record['attributes']['content'].delete('locator')
    coverage = F.rec(d, id + '-coverage', 'assertion', 'kit:file_set_coverage', {}, subject: id)
    F.preserve(d, coverage, JSON.generate({'contract' => 'everypivot.file_set_coverage', 'version' => '1.0', 'manifest_sha256' => F.hash_of(d, id),
      'scope' => scope, 'method' => 'explicit_path_inventory_v1', 'method_version' => '1.0', 'coverage' => 'complete_for_declared_scope', 'paths' => files.keys}))
    coverage['attributes']['content'].merge!('source_revision' => 'r1', 'field' => '/')
    coverage['attributes']['content'].delete('locator')
    record
  end
  def phishkit(match: 'archive', receipt: true, network: 'dns', source: 'preserved_historical_report')
    d = base('CTI_PHISHKIT_TO_HOSTING_CLUSTER')
    d['query']['parameters'].merge!('reference_deployments' => [], 'include_controlled' => false, 'query_date' => '2026-09-16')
    F.rec(d, 'seed', 'entity', 'phish:kit', {}, available: nil)
    F.rec(d, 'candidate', 'entity', 'phish:kit', {})
    %w[left right].each do |id|
      if match == 'archive'
        F.artifact(d, id, 'file:bytes', 'exact preserved kit archive bytes')
      else
        manifest(d, id, {'campaign/Q7Z/index.php' => id == 'right' && match == 'paths' ? 'different configuration; same distinctive literal path' : 'same config bytes', 'readme.txt' => 'same documentation'})
      end
    end
    F.rec(d, 'seed-representation', 'assertion', 'kit:representation', {'scope' => match == 'archive' ? 'preserved_archive' : 'declared_file_set'}, subject: 'seed', object: 'left')
    F.rec(d, 'candidate-representation', 'assertion', 'kit:representation', {'scope' => match == 'archive' ? 'preserved_archive' : 'declared_file_set'}, subject: 'candidate', object: 'right')
    if match == 'paths'
      F.rec(d, 'path-comparison', 'assertion', 'kit:shared_path_interpretation', {'paths' => ['campaign/Q7Z/index.php'],
        'profile' => 'literal_shared_paths_v1', 'qualification' => 'supported_specific_shared_feature', 'scope' => 'exact retained member paths',
        'interpretation_basis' => 'source documents same case-specific campaign path in both captured sets',
        'ordinary_explanations' => 'source checked retained stock template revision; public copying remains possible'}, subject: 'left', object: 'right')
    end
    if receipt
      arrival = F.rec(d, 'arrival', 'occurrence', 'evidence:kit_receipt', {'collection_id' => 'fixture-collection',
        'original_evidence_identity' => 'report-r1:candidate-deployment', 'collector' => 'fixture-analyst'}, subject: 'candidate', available: '2026-09-15T00:00:00Z')
      arrival['times']['received'] = F.time('2026-09-15T00:00:00Z', 'candidate', 'arrival', '/records/arrival/received')
    end
    F.rec(d, 'deployment', 'occurrence', 'kit:deployment', {'occurrence_key' => 'source-event-Dec2024-17', 'source_scope' => 'report-r1-events', 'origin_source_id' => 'report',
      'collection_id' => 'fixture-collection', 'resource_scope' => 'campaign/Q7Z application revision1', 'location_id' => 'location', 'stage' => 'served'},
      subject: 'candidate', occurred: '2024-12-10T12:00:00Z')
    F.artifact(d, 'deployment-input', 'evidence:deployment_record', 'preserved source report of candidate resources served Dec2024', {'occurrence_key' => 'source-event-Dec2024-17'})
    F.rec(d, 'resource', 'assertion', 'kit:deployment_correspondence', {'input_id' => 'deployment-input', 'representation_id' => 'right',
      'resource_scope' => 'campaign/Q7Z application revision1', 'location_id' => 'location', 'correspondence_basis' => 'source identifies deployed revision and retained candidate representation',
      'method' => 'source-reported-resource-correspondence', 'method_version' => '1', 'reliability_basis' => 'collector preserved original response and explicitly scoped source statement',
      'collection_scope' => 'one stated resource response', 'known_gaps' => 'complete deployment and origin not established', 'evidence_kind' => source,
      'delivery_provenance' => 'actual_network_response'}, subject: 'candidate', object: 'deployment')
    F.rec(d, 'location', 'entity', 'inet:url', {'value' => 'https://app.example/campaign/Q7Z/index.php'})
    F.rec(d, 'infrastructure', 'entity', network == 'dns' ? 'inet:fqdn' : 'inet:ipv4', {'selector' => network == 'dns' ? F.typed('dns_name', 'app.example', 'infrastructure') : ipv4('192.0.2.20', 'infrastructure')})
    F.rec(d, 'delivery', 'assertion', 'kit:delivery_identity', {'location_id' => 'location', 'occurrence_key' => 'source-event-Dec2024-17',
      'correspondence_basis' => 'specific response resource delivery association', 'vantage' => 'source collection endpoint',
      'role' => network == 'dns' ? 'application_domain' : 'delivery_endpoint', 'uri' => F.typed('uri', 'https://app.example/campaign/Q7Z/index.php', 'delivery'),
      'address' => ipv4('192.0.2.20', 'delivery'), 'resource_delivery_basis' => 'same response and matched resource bytes through this endpoint', 'origin_role' => 'unknown'},
      subject: 'deployment', object: 'infrastructure')
    F.rec(d, 'purpose', 'assertion', 'kit:occurrence_purpose', {'candidate_id' => 'candidate', 'resource_scope' => 'campaign/Q7Z application revision1',
      'location_id' => 'location', 'occurrence_key' => 'source-event-Dec2024-17', 'disposition' => 'not_controlled', 'purpose' => 'not_established',
      'reason' => 'source provides scoped not-controlled assertion for the particular event, without classifying maliciousness', 'rule_revision' => 'controlled-1'}, subject: 'deployment')
    F.seal(d)
  end
end
