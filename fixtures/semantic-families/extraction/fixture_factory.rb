# frozen_string_literal: true

# Independent synthetic evidence authoring. These values and support paths are
# specified explicitly, rather than inferred by executing contract predicates.
require_relative '../../../tools/semantic_contract'
require_relative '../../../tools/semantic_finding'
module ExtractionFixtures
  C = EveryPivot::SemanticContract
  ROOT = File.expand_path('../../..', __dir__)
  module_function
  def deep(v); Marshal.load(Marshal.dump(v)); end
  def source(id, document = id)
    {'id' => id, 'publisher' => 'synthetic laboratory fixture', 'document' => document,
     'revision' => 'r1', 'collection' => 'fixture-collection', 'independent_origin' => nil}
  end
  def time(value, object, occurrence, field)
    {'binding' => {'object' => object, 'occurrence' => occurrence}, 'field' => field,
     'source_revision' => 'r1', 'clock' => {'id' => 'fixture-utc', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end
  def rec(data, id, kind, type, attrs = {}, subject: nil, object: nil, available: '2026-09-10T00:00:00Z', occurred: nil)
    r = {'id' => id, 'kind' => kind, 'type' => type, 'attributes' => deep(attrs), 'times' => {},
         'evidence' => [{'source_id' => 'report', 'field' => '/records/' + id}]}
    r['subject'], r['object'] = subject, object if subject && object
    r['subject'] = subject if subject
    r['object'] = object if object
    if available
      receipt = 'receipt-' + id
      r['attributes']['availability_occurrence'] = receipt
      r['times']['collection_available'] = time(available, id, receipt, '/records/' + id + '/available')
      data['evidence']['records'] << {'id' => receipt, 'kind' => 'occurrence', 'type' => 'evidence:availability',
        'attributes' => {'collection_id' => 'fixture-collection'}, 'times' => {},
        'evidence' => [{'source_id' => 'report', 'field' => '/records/' + receipt}]}
    end
    r['times']['occurred'] = time(occurred, subject || id, id, '/records/' + id + '/occurred') if occurred
    data['evidence']['records'] << r
    r
  end
  def artifact(data, id, type, bytes, attrs = {}, available: '2026-09-10T00:00:00Z')
    r = rec(data, id, 'entity', type, attrs, available: available)
    preserve(data, r, bytes)
    r
  end
  def preserve(data, record, bytes)
    sid = 'bytes-' + record['id']
    sha = Digest::SHA256.hexdigest(bytes)
    record['attributes']['content'] = {'source_id' => sid, 'sha256' => sha, 'byte_length' => bytes.bytesize,
      'representation' => 'exact_source_bytes', 'locator' => 'fixture:' + record['id']}
    record['evidence'] << {'source_id' => sid, 'field' => '/'}
    s = source(sid)
    s['content_hash'] = {'algorithm' => 'sha256', 'value' => sha, 'scope' => 'exact_source_bytes'}
    data['evidence']['sources'] << s
    data['preserved_source_bytes'][sid] = bytes
  end
  def get(data, id); data['evidence']['records'].find { |r| r['id'] == id }; end
  def hash_of(data, id); get(data, id).dig('attributes', 'content', 'sha256'); end
  def selector(namespace, representation = 'utf8_literal', value = 'distinct-fixture-token')
    {'namespace' => namespace, 'representation' => representation, 'profile' => 'literal_exact_v1', 'value' => value}
  end
  def typed(kind, value, carrier)
    x = {'kind' => kind, 'normalization' => kind == 'uri' ? 'literal_rfc3986_v1' : 'dns_ascii_lower_v1', 'value' => value,
      'provenance' => {'source' => 'report', 'record_id' => carrier, 'source_revision' => 'r1',
                      'field' => '/records/' + carrier + '/selector', 'basis' => 'reported'}}
    x['representation'] = 'ascii' if kind == 'dns_name'
    x
  end
  def typed_identity(kind, value)
    kind == 'uri' ? {'kind' => 'uri', 'comparison' => ['literal_rfc3986_v1'], 'value' => value} :
      {'kind' => 'dns_name', 'comparison' => ['ascii', 'dns_ascii_lower_v1'], 'value' => value.downcase}
  end
  def selector_identity(s); s.values_at('namespace', 'representation', 'profile', 'value'); end
  def extraction(data, type, semantics, input = 'input', output = 'output', attrs = {})
    rec(data, 'extraction', 'occurrence', type,
      {'profile' => 'preserved_extraction_v1', 'output_semantics' => semantics, 'run_id' => 'run-original',
       'method' => 'fixture-source-reported-analysis', 'method_version' => '1', 'source_location' => 'bytes:0..15',
       'normalization_method' => 'retain-declared-output-bytes', 'normalization_version' => '1'}.merge(attrs),
      subject: input, object: output, occurred: '2026-09-09T12:00:00Z')
  end
  def base(id)
    contract = JSON.parse(File.read(File.join(ROOT, 'contracts/semantics', id + '.json')))
    data = {'pattern' => id, 'contract' => contract,
      'evidence' => {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0', 'collection_id' => 'fixture-collection',
        'sources' => [source('report'), source('manifest')], 'records' => []},
      'query' => {'parameters' => {'seed' => 'seed', 'history' => 'history', 'query_date' => '2026-09-14'}, 'limits' => {'max_bindings' => 20000, 'max_results' => 100}},
      'preserved_source_bytes' => {}, 'claims' => []}
    contract['parameters'].keys.select { |name| name.end_with?('_revision') }.each { |name| data['query']['parameters'][name] = 'policy-r1' }
    origin = rec(data, 'origin', 'occurrence', 'collection:origin', {'collection_id' => 'fixture-collection'}, available: nil)
    origin['times']['origin'] = time('2020-01-01T00:00:00Z', 'origin', 'origin', '/records/origin/origin')
    snapshot = rec(data, 'snapshot', 'occurrence', 'collection:history_snapshot', {'collection_id' => 'fixture-collection'}, available: nil)
    snapshot['times']['through'] = time('2026-09-14T23:59:59Z', 'snapshot', 'snapshot', '/records/snapshot/through')
    history = rec(data, 'history', 'assertion', 'finding:history', {'manifest_source_id' => 'manifest', 'manifest_field' => '/history'}, available: nil)
    history['evidence'] = [{'source_id' => 'manifest', 'field' => '/history'}]
    data
  end
  def claim(data, identity, support, event = 'established', at = '2026-09-11T00:00:00Z')
    data['claims'] << {'identity' => identity, 'support' => support, 'event' => event, 'at' => at}
  end
  def qualification(data)
    {'id' => data['pattern'].downcase, 'revision' => '1.0', 'contract_sha256' => C.digest(data['contract'])}
  end
  def seal(data, coverage = 'complete_declared_scope')
    data['evidence']['records'].reject! { |r| r['type'] == 'finding:establishment' }
    data['evidence']['records'].each do |r|
      r['times'].each_value do |t|
        ref = {'source_id' => 'report', 'field' => t['field']}
        r['evidence'] << ref unless r['evidence'].include?(ref)
      end
    end
    events = data['claims'].map do |c|
      q = qualification(data)
      key = C.digest({'qualification' => [q['id'], q['revision']], 'identity' => c['identity']})
      event = rec(data, c['event'], 'occurrence', 'finding:establishment',
        {'claim_key' => key, 'collection_id' => 'fixture-collection', 'history_id' => 'history', 'qualification' => q,
         'support' => c['support'].map { |id| {'record_id' => id, 'sha256' => C.digest(get(data, id))} }}, available: nil)
      event['times']['established'] = time(c['at'], event['id'], event['id'], '/records/' + event['id'] + '/established')
      event['evidence'] << {'source_id' => 'report', 'field' => event['times']['established']['field']}
      event
    end
    manifest = {'contract' => 'everypivot.finding_history', 'version' => '1.0', 'history_id' => 'history',
      'revision' => 'r1', 'collection_id' => 'fixture-collection', 'scope_id' => 'synthetic-declared-origin-through-snapshot',
      'origin_id' => 'origin', 'origin_sha256' => C.digest(get(data, 'origin')),
      'through_id' => 'snapshot', 'through_sha256' => C.digest(get(data, 'snapshot')),
      'coverage' => coverage, 'qualification' => qualification(data),
      'establishments' => events.map { |r| {'record_id' => r['id'], 'sha256' => C.digest(r)} }}
    bytes = JSON.generate('history' => manifest)
    data['preserved_source_bytes']['manifest'] = bytes
    data['evidence']['sources'].find { |s| s['id'] == 'manifest' }['content_hash'] =
      {'algorithm' => 'sha256', 'value' => Digest::SHA256.hexdigest(bytes), 'scope' => 'exact_source_bytes'}
    data
  end
  CLUSTERS = {
    'CTI_FILE_SOURCE_PATH_CLUSTER' => ['file:source_path', 'file:hash', 'source_path'],
    'CTI_SAMPLE_UNIQUE_STRING_CLUSTER' => ['file:feature:string', 'file:hash', 'string'],
    'CTI_SAMPLE_FUNCTION_NAME_CLUSTER' => ['file:feature:function_name', 'file:hash', 'function_name'],
    'CTI_SAMPLE_RESOURCE_SECTION_HASH_CLUSTER' => ['file:resource_section:hash', 'file:hash', 'resource_section'],
    'CTI_EMAIL_HEADER_VALUE_CLUSTER' => ['email:header:value', 'email:message', 'header_value'],
    'CTI_EMAIL_MESSAGE_ID_HOST_CLUSTER' => ['email:message:id:host', 'email:message', 'message_id_host']
  }.freeze
  def cluster(id)
    source_type, target, kind = CLUSTERS.fetch(id)
    data = base(id)
    s = selector(source_type)
    if kind == 'resource_section'
      s = selector(source_type, 'sha256_exact_section_bytes', Digest::SHA256.hexdigest('retained resource section'))
    end
    rec(data, 'seed', 'entity', source_type, {'selector' => s, 'selector_context' => 'contained_value', 'field_name' => 'X-Campaign'}, available: nil)
    artifact(data, 'input', target, 'original 2024 artifact bytes',
      {'capture_id' => 'capture-dec-2024', 'capture_kind' => 'original', 'original_context' => {'sighted' => '2024-12-15', 'location' => 'original-endpoint'}}, available: '2024-12-16T00:00:00Z')
    artifact(data, 'output', 'evidence:extracted_value', kind == 'resource_section' ? 'retained resource section' : s['value'], {'selector' => s})
    extraction(data, 'analysis:' + kind + '_extraction', kind, 'input', 'output',
      {'selector' => s, 'symbol_origin' => 'recovered_original', 'section_identity' => '.rsrc/icon:1', 'hash_algorithm' => 'sha256', 'selection_recipe' => 'exact_named_section_bytes_v1',
       'field_name' => kind == 'message_id_host' ? 'Message-ID' : 'X-Campaign', 'field_occurrence' => 0})
    sighting = rec(data, 'historical-sighting', 'occurrence', 'artifact:sighting', {'location' => 'original-endpoint'}, subject: 'input', available: nil)
    sighting['times']['observed'] = time('2024-12-15T00:00:00Z', 'input', sighting['id'], '/records/historical-sighting/observed')
    identity = [kind, target == 'file:hash' ? hash_of(data, 'input') : 'capture-dec-2024'] + selector_identity(s)
    identity << 'X-Campaign' if kind == 'header_value'
    claim(data, identity, %w[extraction input output])
    controls = {
      'source_path' => 'common_build_system_paths', 'string' => 'common_library_or_compiler_strings',
      'function_name' => 'common_library_or_framework_function_names', 'resource_section' => 'common_packer_or_icon_resource_hashes',
      'header_value' => 'common_mailer_or_gateway_headers', 'message_id_host' => 'common_mail_platform_message_id_hosts'}
    add_control(data, controls[kind], 'seed', 'not_member', 'policy-r1', 'clear-selector')
    add_control(data, target == 'email:message' ? 'bulk_or_marketing_messages' : 'common_benign_file_hashes', 'input', 'not_member', 'policy-r1', 'clear-input')
    seal(data)
  end
  def ocr(page: false)
    data = base('CTI_IMAGE_TEXT_REUSE_CLUSTER')
    s = selector('image:ocr:text_hash', 'sha256_exact_ocr_output_bytes', Digest::SHA256.hexdigest('OCR fixture text'))
    rec(data, 'seed', 'entity', 'image:ocr:text_hash', {'selector' => s, 'selector_context' => 'contained_value'}, available: nil)
    artifact(data, 'input', 'file:image', 'synthetic image input bytes', {'image_role' => 'crop', 'capture_id' => 'image-capture'})
    artifact(data, 'output', 'evidence:extracted_value', 'OCR fixture text', {'selector' => s})
    extraction(data, 'analysis:ocr_extraction', 'ocr_text', 'input', 'output', {'selector' => s})
    identity = ['ocr_image', 'image-capture', hash_of(data, 'input')] + selector_identity(s)
    claim(data, identity, %w[extraction input output], 'image-established')
    if page
      rec(data, 'association', 'assertion', 'capture:page_image', {'image_capture_id' => 'image-capture', 'page_capture_id' => 'page-capture',
        'basis' => 'exact_capture_resource_trace', 'source_location' => 'request:7'}, subject: 'page', object: 'input')
      artifact(data, 'page', 'web:page:capture', '<html>retained exact page capture</html>', {'capture_id' => 'page-capture', 'url_id' => 'url', 'uri' => typed('uri', 'https://fixture.example/page', 'page')})
      rec(data, 'url', 'entity', 'inet:url', {'value' => 'https://fixture.example/page'})
      rec(data, 'page_host', 'assertion', 'uri:dns_host', {'selector' => typed('dns_name', 'fixture.example', 'page_host')}, subject: 'url')
      add_control(data, 'common_hosting_or_cdn_domains', 'page_host', 'not_member', 'policy-r1', 'clear-page-host')
      claim(data, ['ocr_page', 'page-capture', hash_of(data, 'page')] + identity[1..-1], %w[extraction input output association page url], 'page-established', '2026-09-12T00:00:00Z')
    end
    add_control(data, 'common_logo_boilerplate_or_template_text_hashes', 'seed', 'not_member', 'policy-r1', 'clear-selector')
    add_control(data, 'stock_image_or_meme_assets', 'input', 'not_member', 'policy-r1', 'clear-image')
    seal(data)
  end
  def web(uri: 'https://fixture.example/path', domain: false)
    data = base('CTI_WEB_CONTENT_EMBEDDED_CONFIG_STRING_CLUSTER')
    s = selector('web:content:token')
    rec(data, 'seed', 'entity', 'web:content:token', {'selector' => s, 'selector_context' => 'contained_value'}, available: nil)
    artifact(data, 'input', 'evidence:resource_content', 'this resource itself contains distinct-fixture-token', {'capture_id' => 'resource-capture'})
    artifact(data, 'output', 'evidence:extracted_value', 'distinct-fixture-token', {'selector' => s})
    extraction(data, 'analysis:web_token_extraction', 'contained_token', 'input', 'output', {'selector' => s})
    is_url = uri.start_with?('https:', 'http:', 'file:')
    rec(data, 'identifier', 'assertion', 'capture:resource_identifier', {'capture_id' => 'resource-capture', 'uri' => typed('uri', uri, 'identifier')}, subject: 'input', object: is_url ? 'url' : 'input')
    rec(data, 'url', 'entity', 'inet:url', {'value' => uri}) if is_url
    identity = ['resource_token', 'resource-capture', hash_of(data, 'input'), typed_identity('uri', uri)] + selector_identity(s)
    claim(data, identity, %w[extraction input output identifier] + (is_url ? ['url'] : []), 'resource-established')
    if domain
      rec(data, 'host', 'assertion', 'uri:dns_host', {'selector' => typed('dns_name', 'fixture.example', 'host')}, subject: 'identifier', object: 'domain')
      rec(data, 'domain', 'entity', 'inet:fqdn', {'selector' => typed('dns_name', 'fixture.example', 'domain')})
      claim(data, ['resource_token_dns_host'] + identity[1..-1] + [typed_identity('dns_name', 'fixture.example')],
        %w[extraction input output identifier host domain], 'domain-established')
      add_control(data, 'common_hosting_or_cdn_domains', 'domain', 'not_member', 'policy-r1', 'clear-domain')
    end
    add_control(data, 'common_framework_or_analytics_tokens', 'seed', 'not_member', 'policy-r1', 'clear-selector')
    seal(data)
  end
  def email_urls
    data = base('CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS')
    input = artifact(data, 'seed', 'email:message', 'gateway rewritten body https://protect.example/B',
      {'capture_id' => 'gateway-capture', 'capture_kind' => 'gateway_modified'}, available: '2024-12-16T00:00:00Z')
    artifact(data, 'output', 'evidence:extracted_value', 'https://protect.example/B', {'uri' => typed('uri', 'https://protect.example/B', 'output')})
    extraction(data, 'analysis:message_url_extraction', 'message_content_url', 'seed', 'output',
      {'url_id' => 'url', 'content_location' => 'body', 'derivation_relation' => 'contained_in_supplied_representation'})
    rec(data, 'url', 'entity', 'inet:url', {'value' => 'https://protect.example/B'})
    rec(data, 'host', 'assertion', 'uri:dns_host', {'selector' => typed('dns_name', 'protect.example', 'host')}, subject: 'url')
    add_control(data, 'common_email_service_links', 'url', 'not_member', 'policy-r1', 'clear-url')
    add_control(data, 'common_cdn_domains', 'host', 'not_member', 'policy-r1', 'clear-host')
    claim(data, ['message_content_url', 'gateway-capture', input['attributes']['content']['sha256'], typed_identity('uri', 'https://protect.example/B')], %w[seed extraction output url])
    seal(data)
  end
  def sourcemap(referenced: false, surface: false)
    data = base('ADTECH_WEBAPP_SOURCEMAP_TO_ADMIN_SURFACE')
    artifact(data, 'seed', 'web:asset', referenced ? 'exact bundled application' : 'exact source map route config', {'original_context' => {'locator' => 'https://cdn.example/assets/map'}})
    input_id = 'seed'
    if referenced
      artifact(data, 'input', 'web:asset', 'exact source map route config')
      rec(data, 'correspondence', 'assertion', 'web:asset_correspondence',
        {'basis' => 'content_bound_manifest', 'bundle_sha256' => hash_of(data, 'seed'), 'map_sha256' => hash_of(data, 'input'), 'source_location' => '/build/map'}, subject: 'seed', object: 'input')
      input_id = 'input'
    end
    artifact(data, 'output', 'evidence:extracted_value', '/admin', {'value' => '/admin'})
    extraction(data, 'analysis:route_extraction', 'application_route', input_id, 'output', {'route_id' => 'route', 'route_basis' => 'route_configuration'})
    rec(data, 'route', 'entity', 'web:route', {'route' => '/admin', 'application_scope' => 'application-build-42', 'artifact_sha256' => hash_of(data, input_id)})
    identity = ['recovered_route', hash_of(data, input_id), 'application-build-42', '/admin']
    support = referenced ? %w[correspondence seed input extraction output route] : %w[seed extraction output route]
    claim(data, identity, support, 'route-established')
    if surface
      rec(data, 'surface_evidence', 'assertion', 'web:route_admin_interface', {'capture_id' => 'interface_capture', 'basis' => 'preserved_interface_content',
        'application_scope' => 'application-build-42', 'role' => 'administrative_interface', 'source_location' => 'capture:body'}, subject: 'route', object: 'surface')
      rec(data, 'surface', 'entity', 'web:admin:surface', {'origin' => 'https://application.example'})
      artifact(data, 'interface_capture', 'evidence:resource_content', 'captured management interface', {'capture_id' => 'interface-capture'})
      claim(data, ['administrative_surface'] + identity[1..-1] + ['https://application.example', 'interface-capture'],
        support + %w[surface_evidence surface interface_capture], 'surface-established', '2026-09-12T00:00:00Z')
      add_control(data, 'known_benign_saas_panels', 'surface', 'not_member', 'policy-r1', 'clear-surface')
    end
    add_control(data, 'common_frontend_framework_assets', input_id, 'not_member', 'policy-r1', 'clear-input')
    add_control(data, 'common_frontend_framework_assets', 'seed', 'not_member', 'policy-r1', 'clear-bundle') if referenced
    seal(data)
  end
  def response(kind = 'payload')
    data = base('CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_PAYLOADS')
    artifact(data, 'seed', 'network:service:probe_response', 'exact response R1', {'occurrence_id' => 'response'}, available: '2024-12-16T00:00:00Z')
    rec(data, 'response', 'occurrence', 'network:response_occurrence', {'occurrence_key' => 'exchange-R1', 'vantage' => 'fixture sensor'},
      subject: 'seed', available: '2024-12-16T00:00:00Z', occurred: '2024-12-15T00:00:00Z')
    direct = kind == 'direct_config'
    artifact(data, 'output', direct ? 'malware:config' : 'malware:payload', direct ? 'synthetic configuration' : 'synthetic payload')
    extraction(data, direct ? 'analysis:response_config_extraction' : 'analysis:response_payload_extraction', direct ? 'configuration' : 'payload', 'seed', 'output',
      {'response_occurrence' => 'response', 'derivation_relation' => 'derived_from_exact_response_bytes',
       'qualification_method' => 'source-reported-format-analysis', 'qualification_version' => '1'})
    identity = [direct ? 'response_config' : 'response_payload', 'exchange-R1', hash_of(data, 'seed'), hash_of(data, 'output')]
    support = %w[seed response extraction output]
    claim(data, identity, support, 'output-established')
    if kind == 'payload_hash'
      rec(data, 'digest', 'entity', 'file:hash', {'sha256' => hash_of(data, 'output'), 'algorithm' => 'sha256'})
      claim(data, identity, support + ['digest'], 'hash-view-established', '2026-09-12T00:00:00Z')
    elsif kind == 'payload_config'
      rec(data, 'config_extraction', 'occurrence', 'analysis:payload_config_extraction',
        {'profile' => 'preserved_extraction_v1', 'output_semantics' => 'configuration', 'method' => 'fixture-config-parser',
         'method_version' => '1', 'source_location' => 'payload:section', 'qualification_method' => 'source-reported-format-analysis', 'qualification_version' => '1'},
        subject: 'output', object: 'config', occurred: '2026-09-10T00:00:00Z')
      artifact(data, 'config', 'malware:config', 'configuration in payload')
      claim(data, ['response_payload_config'] + identity[1..-1] + [hash_of(data, 'config')], support + %w[config_extraction config], 'config-established', '2026-09-12T00:00:00Z')
    end
    unless direct
      add_control(data, 'known_test_or_decoy_payloads', 'output', 'not_member', 'policy-r1', 'clear-payload')
      add_control(data, 'common_benign_payload_hashes', 'output', 'not_member', 'policy-r1', 'clear-payload-hash')
    end
    seal(data)
  end
  def add_control(data, policy, subject, membership = 'member', revision = 'policy-r1', id = 'policy')
    target = get(data, subject)
    attrs = {'policy' => policy, 'list_id' => policy, 'matching_profile' => 'exact_subject_v1',
      'coverage' => 'complete_for_evaluated_subject', 'revision' => revision, 'membership' => membership}
    if target.dig('attributes', 'selector', 'namespace')
      attrs['selector'] = deep(target['attributes']['selector'])
      attrs['selector_context'] = target['attributes']['selector_context']
    elsif %w[common_benign_file_hashes stock_image_or_meme_assets common_frontend_framework_assets known_test_or_decoy_payloads common_benign_payload_hashes].include?(policy)
      attrs['subject_kind'], attrs['value'] = 'content_sha256', target.dig('attributes', 'content', 'sha256')
    elsif %w[common_hosting_or_cdn_domains common_cdn_domains commodity_ad_verification_pixels known_cdn_static_assets].include?(policy)
      attrs['subject_kind'] = 'dns_name'
      attrs['selector'] = typed('dns_name', target.dig('attributes', 'selector', 'value'), id)
    elsif policy == 'known_benign_saas_panels'
      attrs['subject_kind'], attrs['value'] = 'administrative_surface_origin', target.dig('attributes', 'origin')
    elsif policy == 'bulk_or_marketing_messages'
      attrs['subject_kind'], attrs['value'] = 'message_capture', target.dig('attributes', 'capture_id')
    else
      attrs['subject_kind'], attrs['value'] = 'url', target.dig('attributes', 'value')
    end
    type = attrs.dig('selector', 'namespace') ? 'policy:selector_membership' : attrs['subject_kind'] == 'dns_name' ? 'policy:dns_membership' : 'policy:membership'
    r = rec(data, id, 'assertion', type, attrs, subject: subject, available: nil)
    preserve(data, r, JSON.generate(attrs.merge('subject' => subject)))
    data
  end
  def all
    CLUSTERS.keys.map { |id| [id, cluster(id)] }.to_h.merge(
      'CTI_IMAGE_TEXT_REUSE_CLUSTER' => ocr,
      'CTI_WEB_CONTENT_EMBEDDED_CONFIG_STRING_CLUSTER' => web,
      'CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS' => email_urls,
      'ADTECH_WEBAPP_SOURCEMAP_TO_ADMIN_SURFACE' => sourcemap,
      'CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_PAYLOADS' => response)
  end
end
