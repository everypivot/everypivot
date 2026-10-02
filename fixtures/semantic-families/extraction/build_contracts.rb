#!/usr/bin/env ruby
# frozen_string_literal: true

# Authoring helper for the explicit portable contracts. This does not extract
# data, infer expected test outcomes, or generate fixture evidence.
require 'json'
module ExtractionContracts
  ROOT = File.expand_path('../../..', __dir__)
  module_function
  def r(v); {'ref' => v}; end
  def l(v); {'literal' => v}; end
  def p(v); {'param' => v}; end
  def eq(a, b); {'op' => 'eq', 'left' => r(a), 'right' => b}; end
  def one(a, values); {'op' => 'in', 'left' => r(a), 'right' => l(values)}; end
  def present(v); {'op' => 'nonblank_text', 'value' => r(v)}; end
  def all(*v); {'op' => 'all', 'args' => v.flatten}; end
  def bind(name, kind, type, where = nil, optional = false)
    x = {'name' => name, 'kind' => kind, 'types' => Array(type)}
    x['where'] = where if where
    x['optional'] = true if optional
    x
  end
  def seed(types)
    bind('seed', 'entity', types, eq('seed.id', p('seed'))).merge('query_seed' => true)
  end
  def content(name)
    {'op' => 'content_matches', 'record' => r(name + '.id'), 'source' => r(name + '.attributes.content.source_id'),
     'sha256' => r(name + '.attributes.content.sha256'), 'byte_length' => r(name + '.attributes.content.byte_length'),
     'representation' => r(name + '.attributes.content.representation')}
  end
  def selector_equal(a, b)
    %w[namespace representation profile value].map { |k| eq(a + '.' + k, r(b + '.' + k)) }
  end
  def selector_identity(prefix)
    %w[namespace representation profile value].map { |k| r(prefix + '.' + k) }
  end
  def parameters
    {'seed' => {'type' => 'record_id', 'required' => true, 'description' => 'Exact supplied source entity; global discovery time is not per-artifact extraction time.'},
     'history' => {'type' => 'record_id', 'required' => true, 'description' => 'Preserved collection-scoped finding history covering the declared origin through snapshot; no global novelty claim.'},
     'query_date' => {'type' => 'date', 'required' => true, 'description' => 'Explicit inclusive UTC calendar end date for this pattern\'s retained complete-finding lookback.'}}
  end
  def document(id, days, anchor)
    {'contract' => 'everypivot.semantic_pattern', 'version' => '1.0',
     'pattern' => {'id' => id, 'version' => id.include?('SOURCEMAP') ? '0.3.0' : '3.0.0'},
     'description' => "Source-qualified extraction findings over exact preserved content; #{days}-day inclusive UTC calendar lookback is applied to earliest complete finding in the supplied history, never to refreshed artifact sightings. Transformations are evidenced source reports, not extraction algorithms executed by this evaluator.",
     'authority' => 'docs/UNRESOLVED_SEMANTICS.md#' + anchor,
     'parameters' => parameters, 'branches' => []}
  end
  def finish(doc, id, bindings, predicates, identity, result, days, extra_times = [])
    support = bindings.reject { |b| b['optional'] || b['query_seed'] }.map { |b| b['name'] }
    knowledge = support.map { |n| r(n + '.times.collection_available') }
    times = support.map { |n| {'value' => r(n + '.times.collection_available'), 'object' => r(n + '.id'), 'occurrence' => r(n + '.attributes.availability_occurrence')} }
    bindings.select { |b| b['kind'] == 'occurrence' && !b['optional'] }.each do |b|
      n = b['name']
      knowledge << r(n + '.times.occurred')
      times << {'value' => r(n + '.times.occurred'), 'object' => r(n + '.subject'), 'occurrence' => r(n + '.id')}
      predicates << {'op' => 'time_compare', 'operator' => 'lte', 'left' => r(n + '.times.occurred'), 'right' => r(n + '.times.collection_available')}
    end
    branch = {'id' => id, 'bindings' => bindings, 'where' => all(predicates), 'knowledge' => knowledge,
              'time_bindings' => times + extra_times,
              'finding' => {'id' => doc['pattern']['id'].downcase, 'revision' => '1.0', 'identity' => identity,
                            'support' => support, 'history' => p('history'),
                            'period' => {'calendar_period' => {'query_date' => p('query_date'), 'days' => l(days)}}},
              'result' => result}
    doc['branches'] << branch
    branch
  end
  def result(binding, form, identity, fields)
    {'mode' => 'bound', 'binding' => binding, 'form' => form, 'identity' => identity,
     'fields' => {'claim_status' => l('evidence_only'), 'extraction' => r('extraction.id'),
                  'original_context' => r('input.attributes.original_context'),
                  'content_sha256' => r('input.attributes.content.sha256'),
                  'method' => r('extraction.attributes.method'), 'method_version' => r('extraction.attributes.method_version')}.merge(fields)}
  end
  def extraction_checks(kind)
    [eq('extraction.attributes.profile', l('preserved_extraction_v1')),
     eq('extraction.attributes.output_semantics', l(kind)),
     present('extraction.attributes.run_id'), present('extraction.attributes.method'), present('extraction.attributes.method_version'),
     present('extraction.attributes.normalization_method'), present('extraction.attributes.normalization_version'),
     present('extraction.attributes.source_location'), content('input'), content('output')]
  end
  HASH_CONTROLS = %w[common_benign_file_hashes stock_image_or_meme_assets common_frontend_framework_assets known_test_or_decoy_payloads common_benign_payload_hashes].freeze
  DNS_CONTROLS = %w[common_hosting_or_cdn_domains common_cdn_domains commodity_ad_verification_pixels known_cdn_static_assets].freeze
  def control_subject(name, subject, variable)
    base = subject['ref'].split('.').first
    if base == 'seed'
      [all(selector_equal(variable + '.attributes.selector', 'seed.attributes.selector'),
           eq(variable + '.attributes.selector_context', r('seed.attributes.selector_context'))), r('seed.attributes.selector')]
    elsif HASH_CONTROLS.include?(name)
      [all(eq(variable + '.attributes.subject_kind', l('content_sha256')),
           eq(variable + '.attributes.value', r(base + '.attributes.content.sha256'))), r(base + '.attributes.content.sha256')]
    elsif DNS_CONTROLS.include?(name)
      [all(eq(variable + '.attributes.subject_kind', l('dns_name')),
           {'op' => 'typed_equal', 'left' => r(variable + '.attributes.selector'), 'right' => r(base + '.attributes.selector')}), {'selector_identity' => base + '.attributes.selector'}]
    elsif name == 'known_benign_saas_panels'
      [all(eq(variable + '.attributes.subject_kind', l('administrative_surface_origin')),
           eq(variable + '.attributes.value', r(base + '.attributes.origin'))), r(base + '.attributes.origin')]
    elsif name == 'bulk_or_marketing_messages'
      [all(eq(variable + '.attributes.subject_kind', l('message_capture')),
           eq(variable + '.attributes.value', r(base + '.attributes.capture_id'))), r(base + '.attributes.capture_id')]
    else
      [all(eq(variable + '.attributes.subject_kind', l('url')),
           eq(variable + '.attributes.value', r(base + '.attributes.value'))), r(base + '.attributes.value')]
    end
  end
  # Required policy eligibility is separate from qualified extraction evidence.
  # Absence/conflict is retained as an unresolved candidate, never clearance.
  def control(doc, branch, name, subject, scope, suffix = '', applies_when = nil)
    parameter = name + '_revision'
    doc['parameters'][parameter] = {'type' => 'string', 'required' => true,
      'description' => 'Pinned ' + name + ' revision for this evaluation. A different selected revision is a new evaluation, not new finding availability.'}
    variable = 'control_' + branch['policies'].to_a.length.to_s
    applies, semantic_subject = control_subject(name, subject, variable)
    if name == 'common_framework_or_analytics_tokens'
      equivalence = variable + '_equivalence'
      branch['bindings'] << bind(equivalence, 'assertion', 'selector:equivalence', all(
        selector_equal(equivalence + '.attributes.left_selector', 'seed.attributes.selector'),
        eq(equivalence + '.attributes.left_context', r('seed.attributes.selector_context'))), true)
      cross = all(content(equivalence), eq(equivalence + '.attributes.profile', l('explicit_selector_equivalence_v1')),
        present(equivalence + '.attributes.method'), present(equivalence + '.attributes.method_version'),
        selector_equal(variable + '.attributes.selector', equivalence + '.attributes.right_selector'),
        eq(variable + '.attributes.selector_context', r(equivalence + '.attributes.right_context')))
      applies = {'op' => 'any', 'args' => [applies, cross]}
    end
    policy_type = if subject['ref'].split('.').first == 'seed'
                    'policy:selector_membership'
                  elsif DNS_CONTROLS.include?(name)
                    'policy:dns_membership'
                  else 'policy:membership'
                  end
    branch['bindings'] << bind(variable, 'assertion', policy_type, all(
      eq(variable + '.attributes.policy', l(name)), eq(variable + '.attributes.revision', p(parameter)), applies), true)
    base = all(content(variable), eq(variable + '.attributes.list_id', l(name)),
      eq(variable + '.attributes.matching_profile', l('exact_subject_v1')), applies)
    branch['policies'] ||= []
    policy = {'id' => name + suffix, 'revision' => '1.0', 'scope' => scope, 'subject' => semantic_subject,
      'required_evaluation' => true,
      'default_enabled' => true, 'reason' => 'Source-qualified membership in the exact preserved selected revision; scope is explicit and supplies no maliciousness or clearance.',
      'when' => all(base, eq(variable + '.attributes.membership', l('member'))),
      'allow_when' => all(base, eq(variable + '.attributes.membership', l('not_member')),
        eq(variable + '.attributes.coverage', l('complete_for_evaluated_subject'))),
      'conflict_when' => all(base, eq(variable + '.attributes.membership', l('contested')))}
    policy['applies_when'] = applies_when if applies_when
    branch['policies'] << policy
  end
  CLUSTERS = [
    ['CTI_FILE_SOURCE_PATH_CLUSTER', 'file:source_path', 'file:hash', 'source_path', 365, 'accepted-source-path-extraction-binding', 'common_build_system_paths', 'common_benign_file_hashes'],
    ['CTI_SAMPLE_UNIQUE_STRING_CLUSTER', 'file:feature:string', 'file:hash', 'string', 365, 'accepted-sample-selector-temporal-model', 'common_library_or_compiler_strings', 'common_benign_file_hashes'],
    ['CTI_SAMPLE_FUNCTION_NAME_CLUSTER', 'file:feature:function_name', 'file:hash', 'function_name', 365, 'accepted-sample-selector-temporal-model', 'common_library_or_framework_function_names', 'common_benign_file_hashes'],
    ['CTI_SAMPLE_RESOURCE_SECTION_HASH_CLUSTER', 'file:resource_section:hash', 'file:hash', 'resource_section', 365, 'accepted-sample-selector-temporal-model', 'common_packer_or_icon_resource_hashes', 'common_benign_file_hashes'],
    ['CTI_EMAIL_HEADER_VALUE_CLUSTER', 'email:header:value', 'email:message', 'header_value', 30, 'accepted-email-cluster-temporal-model', 'common_mailer_or_gateway_headers', 'bulk_or_marketing_messages'],
    ['CTI_EMAIL_MESSAGE_ID_HOST_CLUSTER', 'email:message:id:host', 'email:message', 'message_id_host', 30, 'accepted-email-cluster-temporal-model', 'common_mail_platform_message_id_hosts', 'bulk_or_marketing_messages']
  ].freeze
  REPRESENTATIONS = {
    'source_path' => %w[utf8_literal utf8_normalized_path],
    'string' => %w[utf8_literal utf8_decoded],
    'function_name' => %w[utf8_literal],
    'resource_section' => %w[sha256_exact_section_bytes],
    'header_value' => %w[utf8_literal unfolded_utf8],
    'message_id_host' => %w[utf8_literal ascii_dns_host]
  }.freeze
  def cluster(spec)
    id, source, target, kind, days, anchor, sc, tc = spec
    doc = document(id, days, anchor)
    bindings = [seed(source), bind('extraction', 'occurrence', 'analysis:' + kind + '_extraction',
      all(selector_equal('extraction.attributes.selector', 'seed.attributes.selector'))),
      bind('input', 'entity', target, eq('input.id', r('extraction.subject'))),
      bind('output', 'entity', 'evidence:extracted_value', eq('output.id', r('extraction.object')))]
    predicates = extraction_checks(kind) + selector_equal('output.attributes.selector', 'extraction.attributes.selector') + [
      eq('seed.attributes.selector.namespace', l(source)), eq('seed.attributes.selector.profile', l('literal_exact_v1')),
      present('seed.attributes.selector.value'), one('seed.attributes.selector.representation', REPRESENTATIONS.fetch(kind))]
    predicates << one('extraction.attributes.symbol_origin', %w[export recovered_original]) if kind == 'function_name'
    if kind == 'resource_section'
      predicates += [eq('seed.attributes.selector.representation', l('sha256_exact_section_bytes')),
                     eq('seed.attributes.selector.value', r('output.attributes.content.sha256')), present('extraction.attributes.section_identity'),
                     present('extraction.attributes.selection_recipe'), eq('extraction.attributes.hash_algorithm', l('sha256'))]
    end
    if target == 'email:message'
      predicates += [present('input.attributes.capture_id'), one('input.attributes.capture_kind', %w[original gateway_modified mailbox_export]),
                     present('extraction.attributes.field_name'), {'op' => 'nonnegative_integer', 'value' => r('extraction.attributes.field_occurrence')}]
      predicates << eq('extraction.attributes.field_name', l('Message-ID')) if kind == 'message_id_host'
      predicates << eq('extraction.attributes.field_name', r('seed.attributes.field_name')) if kind == 'header_value'
    end
    object_identity = target == 'file:hash' ? r('input.attributes.content.sha256') : r('input.attributes.capture_id')
    identity = [l(kind), object_identity] + selector_identity('extraction.attributes.selector')
    identity << r('extraction.attributes.field_name') if kind == 'header_value'
    b = finish(doc, 'particular_artifact', bindings, predicates, identity,
      result('input', target, [object_identity], {'relationship' => l('contains_extracted_selector'),
        'selector' => r('extraction.attributes.selector'), 'extracted_bytes_sha256' => r('output.attributes.content.sha256'),
        'source_location' => r('extraction.attributes.source_location')}), days)
    if kind == 'function_name'
      bindings[1]['where'] = all(bindings[1]['where'], one('extraction.attributes.symbol_origin', %w[export recovered_original]))
      debug_bindings = Marshal.load(Marshal.dump(bindings))
      debug_bindings[1]['where'] = all(selector_equal('extraction.attributes.selector', 'seed.attributes.selector'), eq('extraction.attributes.symbol_origin', l('debug_symbol')))
      debug_bindings += [bind('symbol_association', 'assertion', 'debug:artifact_symbols', all(
        eq('symbol_association.subject', r('input.id')), eq('symbol_association.id', r('extraction.attributes.symbol_association')))),
        bind('symbol_material', 'entity', 'evidence:debug_symbols', eq('symbol_material.id', r('symbol_association.object')))]
      debug_predicates = predicates.reject { |x| x.dig('left', 'ref') == 'extraction.attributes.symbol_origin' }
      debug_predicates += [eq('extraction.attributes.symbol_origin', l('debug_symbol')), content('symbol_material'),
                          eq('symbol_association.attributes.artifact_sha256', r('input.attributes.content.sha256')),
                          eq('symbol_association.attributes.symbol_sha256', r('symbol_material.attributes.content.sha256')),
                          present('symbol_association.attributes.correspondence_method')]
      finish(doc, 'with_external_debug_material', debug_bindings, debug_predicates, identity,
        Marshal.load(Marshal.dump(b['result'])), days)
    end
    doc['branches'].each do |branch|
      control(doc, branch, sc, r('seed.id'), 'source')
      control(doc, branch, tc, r('input.id'), 'result')
    end
    doc
  end
  def ocr
    doc = document('CTI_IMAGE_TEXT_REUSE_CLUSTER', 365, 'accepted-independently-supported-ocr-image-results')
    %w[image page].each do |kind|
      bindings = [seed('image:ocr:text_hash'), bind('extraction', 'occurrence', 'analysis:ocr_extraction',
        all(selector_equal('extraction.attributes.selector', 'seed.attributes.selector'))),
        bind('input', 'entity', 'file:image', eq('input.id', r('extraction.subject'))),
        bind('output', 'entity', 'evidence:extracted_value', eq('output.id', r('extraction.object')))]
      predicates = extraction_checks('ocr_text') + selector_equal('output.attributes.selector', 'extraction.attributes.selector') + [
        eq('seed.attributes.selector.namespace', l('image:ocr:text_hash')), eq('seed.attributes.selector.profile', l('literal_exact_v1')),
        eq('seed.attributes.selector.representation', l('sha256_exact_ocr_output_bytes')),
        eq('seed.attributes.selector.value', r('output.attributes.content.sha256')),
        one('input.attributes.image_role', %w[original crop render]), present('input.attributes.capture_id')]
      identity = [l('ocr_image'), r('input.attributes.capture_id'), r('input.attributes.content.sha256')] + selector_identity('extraction.attributes.selector')
      output_result = result('input', 'file:image', [r('input.attributes.capture_id')], {'relationship' => l('ocr_selector_in_actual_input_image'), 'image_role' => r('input.attributes.image_role')})
      if kind == 'page'
        bindings += [bind('association', 'assertion', 'capture:page_image', eq('association.object', r('input.id'))),
                     bind('page', 'entity', 'web:page:capture', eq('page.id', r('association.subject'))),
                     bind('url', 'entity', 'inet:url', eq('url.id', r('page.attributes.url_id')))]
        predicates += [content('page'), present('page.attributes.capture_id'), eq('association.attributes.image_capture_id', r('input.attributes.capture_id')),
                       eq('association.attributes.page_capture_id', r('page.attributes.capture_id')),
                       one('association.attributes.basis', %w[embedded_content_bytes preserved_render_trace exact_capture_resource_trace]), present('association.attributes.source_location'),
                       uri_component('page.attributes.uri', 'url', r('url.attributes.value'))]
        identity = [l('ocr_page'), r('page.attributes.capture_id'), r('page.attributes.content.sha256')] + identity[1..-1]
        output_result = result('url', 'inet:url', [r('url.attributes.value'), r('page.attributes.capture_id')],
          {'relationship' => l('exact_captured_page_contains_ocr_image'), 'page_capture' => r('page.id'), 'image' => r('input.id'), 'association' => r('association.id')})
      end
      b = finish(doc, kind, bindings, predicates, identity, output_result, 365)
      control(doc, b, 'common_logo_boilerplate_or_template_text_hashes', r('seed.id'), 'source')
      control(doc, b, 'stock_image_or_meme_assets', r('input.id'), 'result')
      if kind == 'page'
        b['bindings'] << bind('page_host', 'assertion', 'uri:dns_host', all(eq('page_host.subject', r('url.id')),
          uri_component('page.attributes.uri', 'dns_host', r('page_host.attributes.selector'))), true)
        control(doc, b, 'common_hosting_or_cdn_domains', r('page_host.id'), 'result', '',
          uri_component('page.attributes.uri', 'host_kind', l('dns')))
      end
    end
    doc
  end
  def uri_component(uri, component, right)
    {'op' => 'uri_component_equal', 'uri' => r(uri), 'component' => component, 'right' => right}
  end
  def web
    doc = document('CTI_WEB_CONTENT_EMBEDDED_CONFIG_STRING_CLUSTER', 90, 'accepted-general-uri-scope-for-resource-findings')
    %w[url resource domain].each do |kind|
      bindings = [seed(%w[malware:config:string web:content:token]),
        bind('extraction', 'occurrence', 'analysis:web_token_extraction', all(selector_equal('extraction.attributes.selector', 'seed.attributes.selector'))),
        bind('input', 'entity', 'evidence:resource_content', eq('input.id', r('extraction.subject'))),
        bind('output', 'entity', 'evidence:extracted_value', eq('output.id', r('extraction.object'))),
        bind('identifier', 'assertion', 'capture:resource_identifier', eq('identifier.subject', r('input.id')))]
      predicates = extraction_checks('contained_token') + selector_equal('output.attributes.selector', 'extraction.attributes.selector') + [
        one('seed.attributes.selector.namespace', %w[malware:config:string web:content:token]),
        eq('seed.attributes.selector.profile', l('literal_exact_v1')), present('seed.attributes.selector.value'),
        one('seed.attributes.selector.representation', %w[utf8_literal utf8_decoded]),
        present('input.attributes.capture_id'), eq('identifier.attributes.capture_id', r('input.attributes.capture_id')),
        eq('identifier.attributes.uri.kind', l('uri'))]
      identity = [l('resource_token'), r('input.attributes.capture_id'), r('input.attributes.content.sha256'),
                  {'selector_identity' => 'identifier.attributes.uri'}] + selector_identity('extraction.attributes.selector')
      if kind == 'resource'
        predicates << {'op' => 'not', 'arg' => uri_component('identifier.attributes.uri', 'url', r('identifier.attributes.uri.value'))}
        output_result = result('input', 'evidence:resource_content', [r('input.attributes.capture_id')], {'relationship' => l('preserved_resource_contains_token'), 'uri' => r('identifier.attributes.uri')})
      elsif kind == 'url'
        bindings << bind('url', 'entity', 'inet:url', eq('url.id', r('identifier.object')))
        predicates << uri_component('identifier.attributes.uri', 'url', r('url.attributes.value'))
        output_result = result('url', 'inet:url', [r('url.attributes.value'), r('input.attributes.capture_id')],
          {'relationship' => l('preserved_resource_contains_token'), 'uri' => r('identifier.attributes.uri'), 'capture' => r('input.id')})
      else
        bindings += [bind('host', 'assertion', 'uri:dns_host', eq('host.subject', r('identifier.id'))),
                     bind('domain', 'entity', 'inet:fqdn', eq('domain.id', r('host.object')))]
        predicates += [uri_component('identifier.attributes.uri', 'dns_host', r('host.attributes.selector')),
                       {'op' => 'typed_equal', 'left' => r('host.attributes.selector'), 'right' => r('domain.attributes.selector')}]
        identity = [l('resource_token_dns_host')] + identity[1..-1] + [{'selector_identity' => 'host.attributes.selector'}]
        output_result = result('domain', 'inet:fqdn', [r('domain.id'), r('input.attributes.capture_id')],
          {'relationship' => l('dns_hostname_component_of_resource_identifier'), 'uri' => r('identifier.attributes.uri'), 'capture' => r('input.id'), 'association' => r('host.id')})
      end
      b = finish(doc, kind, bindings, predicates, identity, output_result, 90)
      control(doc, b, 'common_framework_or_analytics_tokens', r('seed.id'), 'source')
      control(doc, b, 'common_hosting_or_cdn_domains', r('domain.id'), 'result') if kind == 'domain'
    end
    doc
  end
  def email_urls
    doc = document('CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS', 7, 'accepted-email-url-ordinary-output-boundary')
    bindings = [seed('email:message'), bind('input', 'entity', 'email:message', eq('input.id', r('seed.id'))),
      bind('extraction', 'occurrence', 'analysis:message_url_extraction', eq('extraction.subject', r('input.id'))),
      bind('output', 'entity', 'evidence:extracted_value', eq('output.id', r('extraction.object'))),
      bind('url', 'entity', 'inet:url', eq('url.id', r('extraction.attributes.url_id')))]
    predicates = extraction_checks('message_content_url') + [present('input.attributes.capture_id'),
      one('input.attributes.capture_kind', %w[original gateway_modified mailbox_export]),
      one('extraction.attributes.content_location', %w[body header attachment declared_render]),
      eq('extraction.attributes.derivation_relation', l('contained_in_supplied_representation')),
      uri_component('output.attributes.uri', 'url', r('url.attributes.value'))]
    identity = [l('message_content_url'), r('input.attributes.capture_id'), r('input.attributes.content.sha256'), {'selector_identity' => 'output.attributes.uri'}]
    b = finish(doc, 'ordinary_content_url', bindings, predicates, identity,
      result('url', 'inet:url', [r('url.attributes.value'), r('input.attributes.capture_id')],
        {'relationship' => l('url_in_exact_message_representation'), 'capture' => r('input.id'), 'uri' => r('output.attributes.uri'), 'content_location' => r('extraction.attributes.content_location')}), 7)
    control(doc, b, 'common_email_service_links', r('url.id'), 'result')
    # Conditional DNS controls bind only an actual parsed hostname; absent host
    # (including IP-literal URL) does not invalidate the independent URL claim.
    b['bindings'] << bind('host', 'assertion', 'uri:dns_host', all(eq('host.subject', r('url.id')),
      uri_component('output.attributes.uri', 'dns_host', r('host.attributes.selector'))), true)
    control(doc, b, 'common_cdn_domains', r('host.id'), 'result', '', uri_component('output.attributes.uri', 'host_kind', l('dns')))
    doc
  end
  def sourcemap
    doc = document('ADTECH_WEBAPP_SOURCEMAP_TO_ADMIN_SURFACE', 30, 'accepted-direct-and-referenced-asset-extraction-paths')
    %w[direct referenced].product(%w[route surface]).each do |path, kind|
      bindings = [seed('web:asset')]
      predicates = []
      if path == 'referenced'
        bindings << bind('correspondence', 'assertion', 'web:asset_correspondence', eq('correspondence.subject', r('seed.id')))
        bindings << bind('bundle', 'entity', 'web:asset', eq('bundle.id', r('seed.id')))
        bindings << bind('input', 'entity', 'web:asset', eq('input.id', r('correspondence.object')))
        predicates += [content('bundle'), one('correspondence.attributes.basis', %w[content_bound_manifest exact_build_trace preserved_bundle_map_pair]),
                       eq('correspondence.attributes.bundle_sha256', r('bundle.attributes.content.sha256')),
                       eq('correspondence.attributes.map_sha256', r('input.attributes.content.sha256')), present('correspondence.attributes.source_location')]
      else
        bindings << bind('input', 'entity', 'web:asset', eq('input.id', r('seed.id')))
      end
      bindings += [bind('extraction', 'occurrence', 'analysis:route_extraction', eq('extraction.subject', r('input.id'))),
                   bind('output', 'entity', 'evidence:extracted_value', eq('output.id', r('extraction.object'))),
                   bind('route', 'entity', 'web:route', eq('route.id', r('extraction.attributes.route_id')))]
      predicates += extraction_checks('application_route') + [
        one('extraction.attributes.route_basis', %w[route_configuration application_route_registration]),
        present('route.attributes.route'), present('route.attributes.application_scope'),
        eq('route.attributes.artifact_sha256', r('input.attributes.content.sha256')),
        eq('output.attributes.value', r('route.attributes.route'))]
      identity = [l('recovered_route'), r('input.attributes.content.sha256'), r('route.attributes.application_scope'), r('route.attributes.route')]
      output_result = result('route', 'web:route', identity, {'relationship' => l('recovered_route_in_artifact_scope'), 'route' => r('route.attributes.route'), 'application_scope' => r('route.attributes.application_scope')})
      if kind == 'surface'
        bindings += [bind('surface_evidence', 'assertion', 'web:route_admin_interface', eq('surface_evidence.subject', r('route.id'))),
                     bind('surface', 'entity', 'web:admin:surface', eq('surface.id', r('surface_evidence.object'))),
                     bind('interface_capture', 'entity', 'evidence:resource_content', eq('interface_capture.id', r('surface_evidence.attributes.capture_id')))]
        predicates += [one('surface_evidence.attributes.basis', %w[preserved_interface_content observed_application_response documented_interface_role]),
                       eq('surface_evidence.attributes.application_scope', r('route.attributes.application_scope')),
                       eq('surface_evidence.attributes.role', l('administrative_interface')), content('interface_capture'),
                       present('surface_evidence.attributes.source_location'), present('surface.attributes.origin')]
        identity = [l('administrative_surface')] + identity[1..-1] + [r('surface.attributes.origin'), r('interface_capture.attributes.capture_id')]
        output_result = result('surface', 'web:admin:surface', identity,
          {'relationship' => l('separately_evidenced_administrative_interface'), 'route' => r('route.id'), 'interface_evidence' => r('surface_evidence.id'), 'origin' => r('surface.attributes.origin')})
      end
      b = finish(doc, path + '_' + kind, bindings, predicates, identity, output_result, 30)
      control(doc, b, 'common_frontend_framework_assets', r('input.id'), 'source')
      control(doc, b, 'common_frontend_framework_assets', r('bundle.id'), 'source', '_starting_bundle') if path == 'referenced'
      control(doc, b, 'known_benign_saas_panels', r('surface.id'), 'result') if kind == 'surface'
    end
    doc
  end
  def response
    doc = document('CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_PAYLOADS', 30, 'accepted-independently-supported-response-derived-outputs')
    %w[payload payload_hash direct_config payload_config].each do |kind|
      bindings = [seed('network:service:probe_response'),
        bind('input', 'entity', 'network:service:probe_response', eq('input.id', r('seed.id'))),
        bind('response', 'occurrence', 'network:response_occurrence', eq('response.id', r('input.attributes.occurrence_id'))),
        bind('extraction', 'occurrence', kind == 'direct_config' ? 'analysis:response_config_extraction' : 'analysis:response_payload_extraction', eq('extraction.subject', r('input.id'))),
        bind('output', 'entity', kind == 'direct_config' ? 'malware:config' : 'malware:payload', eq('output.id', r('extraction.object')))]
      predicates = extraction_checks(kind == 'direct_config' ? 'configuration' : 'payload') + [
        eq('response.subject', r('input.id')), eq('extraction.attributes.response_occurrence', r('response.id')),
        present('response.attributes.occurrence_key'), present('response.attributes.vantage'),
        eq('extraction.attributes.derivation_relation', l('derived_from_exact_response_bytes')),
        present('extraction.attributes.qualification_method'), present('extraction.attributes.qualification_version'),
        {'op' => 'time_compare', 'operator' => 'lte', 'left' => r('response.times.occurred'), 'right' => r('extraction.times.occurred')}]
      identity = [l(kind == 'direct_config' ? 'response_config' : 'response_payload'), r('response.attributes.occurrence_key'),
                  r('input.attributes.content.sha256'), r('output.attributes.content.sha256')]
      output_result = result('output', kind == 'direct_config' ? 'malware:config' : 'malware:payload', identity,
        {'relationship' => l(kind == 'direct_config' ? 'configuration_from_particular_response' : 'payload_from_particular_response'),
         'response_occurrence' => r('response.id'), 'output_sha256' => r('output.attributes.content.sha256')})
      if kind == 'payload_hash'
        bindings << bind('digest', 'entity', 'file:hash', eq('digest.attributes.sha256', r('output.attributes.content.sha256')))
        predicates << eq('digest.attributes.algorithm', l('sha256'))
        output_result = result('digest', 'file:hash', identity,
          {'relationship' => l('hash_view_of_same_payload_finding'), 'payload' => r('output.id'), 'response_occurrence' => r('response.id')})
      elsif kind == 'payload_config'
        bindings += [bind('config_extraction', 'occurrence', 'analysis:payload_config_extraction', eq('config_extraction.subject', r('output.id'))),
                     bind('config', 'entity', 'malware:config', eq('config.id', r('config_extraction.object')))]
        predicates += [content('config'), eq('config_extraction.attributes.profile', l('preserved_extraction_v1')),
                       eq('config_extraction.attributes.output_semantics', l('configuration')), present('config_extraction.attributes.method'),
                       present('config_extraction.attributes.method_version'), present('config_extraction.attributes.source_location'),
                       present('config_extraction.attributes.qualification_method'), present('config_extraction.attributes.qualification_version')]
        identity = [l('response_payload_config')] + identity[1..-1] + [r('config.attributes.content.sha256')]
        output_result = result('config', 'malware:config', identity,
          {'relationship' => l('configuration_derived_from_particular_payload'), 'payload' => r('output.id'), 'config_extraction' => r('config_extraction.id'), 'response_occurrence' => r('response.id')})
      end
      b = finish(doc, kind, bindings, predicates, identity, output_result, 30)
      control(doc, b, 'known_test_or_decoy_payloads', r('output.id'), 'path') unless kind == 'direct_config'
      control(doc, b, 'common_benign_payload_hashes', r('output.id'), 'path') unless kind == 'direct_config'
    end
    doc
  end
  def documents
    CLUSTERS.map { |spec| cluster(spec) } + [ocr, web, email_urls, sourcemap, response]
  end
  def write
    documents.each do |doc|
      File.write(File.join(ROOT, 'contracts/semantics', doc['pattern']['id'] + '.json'), JSON.pretty_generate(doc) + "\n")
    end
  end
end
ExtractionContracts.write if $PROGRAM_NAME == __FILE__
