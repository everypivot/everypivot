#!/usr/bin/env ruby
# frozen_string_literal: true
require_relative '../extraction/build_contracts'
module ResultBindingContracts
  X = ExtractionContracts
  ROOT = File.expand_path('../../..', __dir__)
  module_function
  def r(v); X.r(v); end
  def l(v); X.l(v); end
  def p(v); X.p(v); end
  def eq(a, b); X.eq(a, b); end
  def all(*a); X.all(*a); end
  def one(a, b); X.one(a, b); end
  def text(a); X.present(a); end
  def bind(*a); X.bind(*a); end
  def content(a); X.content(a); end
  def member(a, b); {'op' => 'contains', 'left' => r(a), 'right' => r(b)}; end
  def negate(a); {'op' => 'not', 'arg' => a}; end
  def param(type, description, required = true)
    value = {'type' => type, 'required' => required, 'description' => description}
    value['enum'] = [true, false] if type == 'boolean'
    value
  end
  def calendar(days); {'calendar_period' => {'query_date' => p('query_date'), 'days' => l(days)}}; end
  def within(value, period, quantifier, at = nil)
    x = {'op' => 'within', 'value' => r(value), 'period' => period, 'quantifier' => quantifier}
    x['at'] = r(at) if at
    x
  end
  def document(id, version, description, anchor)
    {'contract' => 'everypivot.semantic_pattern', 'version' => '1.0', 'pattern' => {'id' => id, 'version' => version},
     'description' => description, 'authority' => 'docs/UNRESOLVED_SEMANTICS.md#' + anchor,
     'parameters' => {'seed' => param('record_id', 'Exact source identity; labels alone cannot supply joins.')}, 'branches' => []}
  end
  def result(mode, form, identity, fields, binding = nil)
    x = {'mode' => mode, 'form' => form, 'identity' => identity,
      'fields' => {'claim_status' => l('evidence_only')}.merge(fields)}
    x['binding'] = binding if binding
    x
  end
  def times_for(bindings, additional)
    bindings.reject { |b| b['query_seed'] || b['optional'] }.map do |b|
      n = b['name']
      {'value' => r(n + '.times.collection_available'), 'object' => r(n + '.id'), 'occurrence' => r(n + '.attributes.availability_occurrence')}
    end + additional
  end
  def branch(doc, id, bindings, predicates, output, temporal = [], policies = [])
    times = times_for(bindings, temporal)
    optional_names = bindings.select { |b| b['optional'] }.map { |b| b['name'] }
    # Claimed service/applicability periods are not knowledge timestamps.
    # Source receipt/availability, rather than state end dates, binds a cutoff.
    knowledge = times.select { |t| t.dig('value', 'ref').end_with?('.times.collection_available') && !optional_names.include?(t.dig('value', 'ref').split('.').first) }.map { |t| t['value'] }
    b = {'id' => id, 'bindings' => bindings, 'where' => all(predicates), 'result' => output,
      'time_bindings' => times, 'knowledge' => knowledge, 'policies' => policies}
    doc['branches'] << b
    b
  end
  def tb(field, object, occurrence)
    {'value' => r(field), 'object' => r(object), 'occurrence' => r(occurrence)}
  end
  def phase
    doc = document('ADTECH_PIPELINE_PHASE_MISMATCH', '0.3.0',
      'Source-qualified comparisons of one actual request against applicable endpoint-role claims; compatible and contested context remain distinct from mismatch and never constitute accepted risk assessments.',
      'accepted-request-specific-phase-comparison-finding')
    doc['parameters'].merge!('query_date' => param('date', 'Explicit UTC calendar end date for the one-day request activity interval.'),
      'rule' => param('record_id', 'Preserved exclusive_phase_set_v1 rule with selected finite phase vocabulary and explicit revision.'))
    %w[request_trace page_start page_complete].product(%w[declared inferred], %w[mismatch compatible contested_declared contested_inferred]).each do |method, basis, outcome_variant|
      outcome = outcome_variant.start_with?('contested') ? 'contested' : outcome_variant
      contrary_basis = outcome_variant == 'contested_inferred' ? 'inferred' : 'declared'
      bindings = [X.seed('http:request'),
        bind('request', 'occurrence', 'http:request_occurrence', eq('request.subject', r('seed.id'))),
        bind('phase', 'assertion', 'adtech:request_phase', all(eq('phase.subject', r('request.id')),
          eq('phase.attributes.method', l(method + '_phase_v1')))),
        bind('request_evidence', 'entity', 'evidence:request_trace', eq('request_evidence.id', r('phase.attributes.input_id'))),
        bind('endpoint', 'entity', 'inet:url', eq('endpoint.id', r('request.attributes.endpoint_id'))),
        bind('role', 'assertion', basis == 'declared' ? 'adtech:endpoint_role_declaration' : 'adtech:endpoint_role_inference', eq('role.subject', r('endpoint.id'))),
        bind('role_evidence', 'entity', 'evidence:endpoint_role', eq('role_evidence.id', r('role.attributes.input_id'))),
        bind('rule', 'entity', 'comparison:phase_rule', eq('rule.id', p('rule')))]
      predicates = [content('request_evidence'), content('role_evidence'), content('rule'),
        eq('request_evidence.attributes.request_occurrence', r('request.attributes.occurrence_key')),
        text('request.attributes.occurrence_key'), text('phase.attributes.method_version'),
        text('phase.attributes.phase'), {'op' => 'nonblank_text_array', 'value' => r('role.attributes.phases')},
        {'op' => 'nonblank_text_array', 'value' => r('rule.attributes.phases')},
        eq('role.attributes.basis', l(basis)), eq('rule.attributes.profile', l('exclusive_phase_set_v1')),
        text('rule.attributes.revision'), {'op' => 'in', 'left' => r('phase.attributes.phase'), 'right' => r('rule.attributes.phases')},
        {'op' => 'all_in', 'left' => r('role.attributes.phases'), 'right' => r('rule.attributes.phases')},
        within('request.times.occurred', calendar(1), 'contained'),
        {'op' => 'time_compare', 'operator' => 'lte', 'left' => r('request.times.occurred'), 'right' => r('request.times.collection_available')},
        within('role.times.applicable', calendar(1), 'at', 'request.times.occurred')]
      %w[method tenant api_version].each { |f| predicates << eq('role.attributes.' + f, r('request.attributes.' + f)) }
      temporal = [tb('request.times.occurred', 'seed.id', 'request.id'), tb('role.times.applicable', 'endpoint.id', 'role.id')]
      if basis == 'inferred'
        bindings << bind('role_exchange', 'entity', 'evidence:role_exchange', eq('role_exchange.id', r('role.attributes.exchange_input_id')))
        predicates += [content('role_exchange'), eq('role.attributes.inference_method', l('integration_and_correlated_exchange_v1')),
                       text('role.attributes.inference_version'), eq('role_exchange.attributes.endpoint_id', r('endpoint.id')),
                       {'op' => 'ne', 'left' => r('role.attributes.input_id'), 'right' => r('phase.attributes.input_id')}]
      end
      if method != 'request_trace'
        bindings += [bind('context', 'occurrence', 'web:page_context', eq('context.id', r('phase.attributes.context_id'))),
          bind('context_link', 'assertion', 'http:request_context', all(eq('context_link.subject', r('request.id')), eq('context_link.object', r('context.id'))))]
        field = method == 'page_start' ? 'started' : 'completed'
        temporal << tb('context.times.' + field, 'context.id', 'context.id')
        predicates << {'op' => 'time_compare', 'operator' => 'lte', 'left' => r('context.times.' + field), 'right' => r('request.times.occurred')}
      end
      # Every contrary claim remains source qualified and actually applicable.
      contrary_types = outcome == 'contested' ? [contrary_basis == 'inferred' ? 'adtech:endpoint_role_inference' : 'adtech:endpoint_role_declaration'] : %w[adtech:endpoint_role_declaration adtech:endpoint_role_inference]
      bindings += [bind('contrary', 'assertion', contrary_types,
        all(eq('contrary.subject', r('endpoint.id')), member('contrary.attributes.phases', 'phase.attributes.phase'),
          %w[method tenant api_version].map { |f| eq('contrary.attributes.' + f, r('request.attributes.' + f)) },
          within('contrary.times.applicable', calendar(1), 'at', 'request.times.occurred')), outcome != 'contested'),
        bind('contrary_evidence', 'entity', 'evidence:endpoint_role', all(eq('contrary_evidence.id', r('contrary.attributes.input_id')),
          content('contrary_evidence')), outcome != 'contested')]
      temporal << tb('contrary.times.applicable', 'endpoint.id', 'contrary.id')
      if outcome == 'contested'
        predicates += [eq('contrary.attributes.basis', l(contrary_basis)),
          {'op' => 'nonblank_text_array', 'value' => r('contrary.attributes.phases')},
          {'op' => 'all_in', 'left' => r('contrary.attributes.phases'), 'right' => r('rule.attributes.phases')}]
        if contrary_basis == 'inferred'
          bindings << bind('contrary_exchange', 'entity', 'evidence:role_exchange', eq('contrary_exchange.id', r('contrary.attributes.exchange_input_id')))
          predicates += [content('contrary_exchange'), eq('contrary.attributes.inference_method', l('integration_and_correlated_exchange_v1')),
            text('contrary.attributes.inference_version'), eq('contrary_exchange.attributes.endpoint_id', r('endpoint.id')),
            {'op' => 'ne', 'left' => r('contrary.attributes.input_id'), 'right' => r('phase.attributes.input_id')}]
        end
      end
      if outcome == 'compatible'
        predicates += [eq('role.attributes.exclusive', l(false)), member('role.attributes.phases', 'phase.attributes.phase')]
      else
        predicates += [eq('role.attributes.exclusive', l(true)), negate(member('role.attributes.phases', 'phase.attributes.phase'))]
        predicates << {'op' => 'binding_absent', 'binding' => 'contrary'} if outcome == 'mismatch'
      end
      identity = [r('request.attributes.occurrence_key'), r('phase.id'), r('role.id'), r('rule.id'), r('rule.attributes.revision'), l(outcome)]
      identity << r('contrary.id') if outcome == 'contested'
      output = result('construct', outcome == 'mismatch' ? 'risk:observation' : 'evidence:phase_comparison', identity,
        {'comparison_outcome' => l(outcome), 'request_identity' => r('request.attributes.occurrence_key'),
         'observed_phase' => r('phase.attributes.phase'), 'role_phases' => r('role.attributes.phases'),
         'role_basis' => l(basis), 'role_exclusivity' => r('role.attributes.exclusive'),
         'contrary_role' => r('contrary.id'), 'rule' => r('rule.id'), 'rule_revision' => r('rule.attributes.revision'),
         'counting_scope' => l('one comparison witness; request identity is separate; context never adds a mismatch'),
         'occurrence_time' => r('request.times.occurred')})
      b = branch(doc, method + '_' + basis + '_' + outcome_variant, bindings, predicates, output, temporal)
      X.control(doc, b, 'known_multi_phase_ad_endpoints', r('endpoint.id'), 'result')
      X.control(doc, b, 'major_ad_exchange_canonical_hosts', r('endpoint.id'), 'result')
    end
    doc
  end
  def officer
    doc = document('FIN_ORG_OFFICER_SHARE_CLUSTER', '3.0.0',
      'Direct supported officer/director appointments of the selected person, including historical nonconcurrent service. No co-appointee expansion or shell/control inference.',
      'accepted-officerdirector-direct-appointment-organisation-results')
    doc['parameters'].merge!(
      'scope' => param('string', 'default_3650_day_service or explicit_service_period').merge('enum' => %w[default_3650_day_service explicit_service_period]),
      'query_date' => param('date', 'Recorded UTC anchor for default 3650-day service scope.'),
      'period' => param('period', 'Explicit analyst/case historical service range.', false),
      'apply_exclusions' => param('boolean', 'Apply explicitly selected appointment-specific investigation rules.', false),
      'exclusion_rules' => param('string_array', 'Explicit selected rule IDs; classifications alone are context.', false))
    doc['parameters']['period']['requires_when'] = {'parameter' => 'scope', 'values' => ['explicit_service_period']}
    doc['parameters']['exclusion_rules']['requires_when'] = {'parameter' => 'apply_exclusions', 'values' => [true]}
    %w[default_3650_day_service explicit_service_period].product(%w[interval status]).each do |scope, kind|
      period = scope == 'explicit_service_period' ? p('period') : calendar(3650)
      bindings = [X.seed('person'),
        bind('appointment', 'assertion', 'org:appointment', all(eq('appointment.subject', r('seed.id')), one('appointment.attributes.role', %w[officer director]))),
        bind('organisation', 'entity', 'org:org', eq('organisation.id', r('appointment.object'))),
        bind('service', 'assertion', kind == 'interval' ? 'org:service_interval' : 'org:dated_active_status', eq('service.subject', r('appointment.id'))),
        bind('capacity', 'assertion', 'org:appointment_capacity', eq('capacity.subject', r('appointment.id')), true),
        bind('exclusion', 'assertion', 'org:appointment_exclusion', all(eq('exclusion.subject', r('appointment.id')),
          {'op' => 'in', 'left' => r('exclusion.attributes.rule_id'), 'right' => p('exclusion_rules')}), true)]
      predicates = [eq('seed.attributes.identity_scope', r('appointment.attributes.person_scope')), text('seed.attributes.identity_scope'),
        eq('organisation.attributes.identity_scope', r('appointment.attributes.organisation_scope')), text('organisation.attributes.identity_scope'),
        text('appointment.attributes.appointment_key'), {'op' => 'eq', 'left' => p('scope'), 'right' => l(scope)}]
      if kind == 'interval'
        predicates << within('service.times.held', period, 'some')
        temporal = [tb('service.times.held', 'appointment.id', 'service.id')]
      else
        predicates += [eq('service.attributes.status', l('active_at_evidenced_time')), within('service.times.status_at', period, 'contained'),
          {'op' => 'time_compare', 'operator' => 'lte', 'left' => r('service.times.status_at'), 'right' => r('service.times.collection_available')}]
        temporal = [tb('service.times.status_at', 'appointment.id', 'service.id')]
      end
      temporal << tb('exclusion.times.applicable', 'appointment.id', 'exclusion.id')
      applies = kind == 'interval' ? within('exclusion.times.applicable', period, 'all') :
        within('exclusion.times.applicable', period, 'at', 'service.times.status_at')
      policy = {'id' => 'explicit_appointment_investigation_exclusion', 'revision' => '1.0', 'scope' => 'path', 'subject' => r('appointment.id'),
        'default_enabled' => false, 'enabled_parameter' => 'apply_exclusions', 'required_evaluation' => true,
        'when' => all(eq('exclusion.attributes.disposition', l('exclude')), text('exclusion.attributes.reason'), text('exclusion.attributes.rule_revision'), applies),
        'allow_when' => all(eq('exclusion.attributes.disposition', l('retain')), text('exclusion.attributes.reason'), text('exclusion.attributes.rule_revision'),
          {'op' => 'all_in', 'left' => p('exclusion_rules'), 'right' => r('exclusion.attributes.evaluated_rule_ids')}, applies),
        'conflict_when' => all(eq('exclusion.attributes.disposition', l('contested')), applies),
        'reason' => 'Only selected supported appointment/capacity/period exclusion; professional or nominee labels alone never exclude the whole person.'}
      output = result('bound', 'org:org', [r('organisation.id'), r('appointment.attributes.appointment_key'), r('service.id')],
        {'relationship' => l('direct_evidenced_appointment'), 'person' => r('seed.id'), 'appointment' => r('appointment.id'),
         'role' => r('appointment.attributes.role'), 'service_evidence' => r('service.id'), 'service_kind' => l(kind),
         'requested_period' => period, 'capacity_context' => r('capacity.attributes.capacity'),
         'temporal_claim' => l('service evidenced within selected period; no currentness, continuity or concurrency inference')}, 'organisation')
      branch(doc, scope + '_' + kind, bindings, predicates, output, temporal, [policy])
    end
    doc
  end
  def creative
    doc = document('ADTECH_CREATIVE_SCRIPT_TO_DELIVERY_ENDPOINT', '0.3.0',
      'Distinct creative-associated URI/URL reference and actual request findings. Direct and script-mediated paths preserve exact creative correspondence, supported stage, conditional DNS controls and thirty-day complete finding history. No advertiser-control or delivery-success inference.',
      'accepted-creative-reference-and-request-evidence-kinds')
    doc['parameters'].merge!('query_date' => param('date', 'Explicit UTC date for the thirty-day complete-finding window.'),
      'history' => param('record_id', 'Preserved declared collection history, including earliest equivalent establishments.'))
    %w[direct script].product(%w[reference request], %w[dns ip uri]).each do |path, kind, identifier|
      next if kind == 'request' && identifier == 'uri'
      bindings = [X.seed('web:creative'), bind('creative', 'entity', 'web:creative', eq('creative.id', r('seed.id')))]
      predicates = [content('creative'), text('creative.attributes.capture_id')]
      if path == 'script'
        bindings += [bind('embed', 'assertion', 'creative:script_correspondence', eq('embed.subject', r('creative.id'))),
                     bind('input', 'entity', 'web:script', eq('input.id', r('embed.object')))]
        predicates += [eq('embed.attributes.creative_capture', r('creative.attributes.capture_id')),
          eq('embed.attributes.script_sha256', r('input.attributes.content.sha256')), text('embed.attributes.source_location'),
          one('embed.attributes.basis', %w[preserved_embedded_script exact_capture_resource_correspondence]), content('input')]
      else
        bindings << bind('input', 'entity', 'web:creative', eq('input.id', r('creative.id')))
      end
      if kind == 'reference'
        bindings += [bind('extraction', 'occurrence', 'analysis:creative_reference_extraction', eq('extraction.subject', r('input.id'))),
                     bind('output', 'entity', 'evidence:extracted_value', eq('output.id', r('extraction.object')))]
        predicates += X.extraction_checks('qualified_creative_reference') + [
          one('extraction.attributes.reference_basis', %w[markup_attribute script_operation campaign_configuration]),
          one('extraction.attributes.reference_role', %w[delivery_endpoint impression_endpoint click_endpoint navigation campaign_identifier]),
          eq('extraction.attributes.creative_capture', r('creative.attributes.capture_id'))]
        uri = 'output.attributes.uri'
        identity = [l('creative_reference'), r('creative.attributes.capture_id'), r('input.attributes.content.sha256'),
          {'selector_identity' => uri}, r('extraction.attributes.reference_role')]
        fields = {'finding_kind' => l('URI reference'), 'reference_basis' => r('extraction.attributes.reference_basis'),
          'reference_role' => r('extraction.attributes.reference_role'), 'extraction' => r('extraction.id'),
          'source_location' => r('extraction.attributes.source_location')}
      else
        bindings += [bind('request', 'occurrence', 'http:creative_request', eq('request.attributes.creative_capture', r('creative.attributes.capture_id'))),
          bind('correlation', 'assertion', 'creative:request_correspondence', all(eq('correlation.subject', r('creative.id')),
            eq('correlation.object', r('request.id')), eq('correlation.attributes.input_id', r('input.id')))),
          bind('trace', 'entity', 'evidence:request_trace', eq('trace.id', r('request.attributes.trace_id')))]
        predicates += [content('trace'), eq('trace.attributes.request_occurrence', r('request.attributes.occurrence_key')),
          eq('correlation.attributes.creative_capture', r('creative.attributes.capture_id')),
          eq('correlation.attributes.input_sha256', r('input.attributes.content.sha256')),
          one('correlation.attributes.basis', %w[exact_capture_execution_trace correlated_source_exchange]),
          text('correlation.attributes.method'), text('correlation.attributes.method_version'), text('request.attributes.occurrence_key'),
          one('request.attributes.stage', %w[initiated_attempt proxy_observed_request server_received responded completed_delivery])]
        uri = 'request.attributes.uri'
        identity = [l('creative_request'), r('creative.attributes.capture_id'), r('request.attributes.occurrence_key'),
          {'selector_identity' => uri}, r('request.attributes.stage')]
        fields = {'finding_kind' => l('creative-associated request'), 'request_occurrence' => r('request.attributes.occurrence_key'),
          'request_stage' => r('request.attributes.stage'), 'correspondence' => r('correlation.id'), 'request_trace' => r('trace.id')}
      end
      if identifier == 'uri'
        predicates << negate(X.uri_component(uri, 'url', r(uri + '.value')))
        output = result('construct', 'evidence:creative_reference', identity,
          fields.merge('uri' => r(uri), 'creative_capture' => r('creative.attributes.capture_id'),
                       'mapping_scope' => l('qualified generic URI reference; no suitable native URL mapping; no destination-content or handler claim')))
      else
        bindings << bind('url', 'entity', 'inet:url', eq('url.attributes.value', r(uri + '.value')))
        predicates << X.uri_component(uri, 'url', r('url.attributes.value'))
        if identifier == 'dns'
          bindings += [bind('host', 'assertion', 'uri:dns_host', all(eq('host.subject', r('url.id')),
            X.uri_component(uri, 'dns_host', r('host.attributes.selector'))))]
          predicates << X.uri_component(uri, 'host_kind', l('dns'))
        else
          predicates << {'op' => 'any', 'args' => %w[ipv4 ipv6].map { |type| X.uri_component(uri, 'host_kind', l(type)) }}
        end
        output = result('bound', 'inet:url', identity, fields.merge('uri' => r(uri),
          'creative_capture' => r('creative.attributes.capture_id'), 'identifier_host_kind' => l(identifier),
          'dns_screening' => l(identifier == 'dns' ? 'required selected DNS controls' : 'not applicable to IP literal; no clearance claim')), 'url')
      end
      bindings << bind('control_context', 'assertion', 'creative:capability_context', eq('control_context.subject', r('creative.id')), true)
      output['fields']['separate_capability_context'] = r('control_context.id')
      b = X.finish(doc, path + '_' + kind + '_' + identifier, bindings, predicates, identity, output, 30)
      if identifier == 'dns'
        %w[commodity_ad_verification_pixels known_cdn_static_assets].each { |policy| X.control(doc, b, policy, r('host.id'), 'path') }
      end
    end
    doc
  end
  def sbl(question)
    ids = {'ip' => 'CTI_IP_TO_LISTING_ASSERTIONS', 'asn' => 'CTI_ASN_TO_EXPLICIT_LISTING_ASSERTIONS', 'network' => 'CTI_ASN_TO_LISTED_INFRASTRUCTURE'}
    doc = document(ids.fetch(question), '1.0.0',
      'Historical source-assertion inquiry over an explicit analyst/case period. Supplied-source correction reports are retained; history beyond that scope is unknown. No current or unwithdrawn-status assurance, publisher claim about neighbours, risk score, ownership or accepted assessment.',
      'accepted-sbl-replacement-family-as-three-distinct-questions')
    doc['parameters'].merge!('period' => param('period', 'Resolved analyst/case UTC dates selecting actual source-claim applicability, not receipt.'),
      'period_origin' => param('string', 'Recorded origin of the selected range.').merge('enum' => %w[analyst case]),
      'claim_kind' => param('string', 'The particular source claim under inquiry.').merge('enum' => question == 'asn' ? ['explicit_asn_assertion'] : %w[listing_status source_reported_activity]),
      'reference_sources' => param('string_array', 'Explicit supplied source/revision scope; does not certify complete correction history.').merge('item_reference' => 'source'),
      'apply_exclusions' => param('boolean', 'Apply explicitly selected investigation exclusions; shared-host classification alone is context.', false),
      'exclusion_rules' => param('string_array', 'Selected investigation rule IDs.', false))
    doc['parameters']['exclusion_rules']['requires_when'] = {'parameter' => 'apply_exclusions', 'values' => [true]}
    subjects = question == 'ip' ? %w[exact covering_prefix] : question == 'asn' ? ['explicit_asn'] : %w[address prefix]
    subjects.product(%w[event established_state]).each do |subject_kind, clock_kind|
      bindings = [X.seed(question == 'ip' ? 'inet:ipv4' : 'net:asn')]
      predicates = []
      if question == 'network'
        form = subject_kind == 'address' ? 'inet:ipv4' : 'inet:net4'
        bindings += [bind('association', 'assertion', 'network:asn_association', eq('association.object', r('seed.id'))),
          bind('infrastructure', 'entity', form, eq('infrastructure.id', r('association.subject'))),
          bind('claim', 'assertion', 'reputation:assertion', eq('claim.subject', r('infrastructure.id')))]
        predicates += [one('association.attributes.role', %w[bgp_origin allocation operator customer_assignment]), text('association.attributes.vantage'),
          eq('association.attributes.coverage', l('entire_subject_scope')),
          eq('claim.attributes.subject_kind', l(subject_kind == 'address' ? 'ipv4' : 'ipv4_prefix'))]
      else
        bindings << bind('claim', 'assertion', 'reputation:assertion', all(
          eq('claim.attributes.subject_kind', l(subject_kind == 'explicit_asn' ? 'asn' : subject_kind == 'exact' ? 'ipv4' : 'ipv4_prefix')),
          subject_kind == 'covering_prefix' ? text('claim.subject') : eq('claim.subject', r('seed.id'))))
      end
      bindings << bind('entry', 'entity', 'reputation:entry', eq('entry.id', r('claim.object')))
      if subject_kind == 'covering_prefix'
        bindings << bind('listed_prefix', 'entity', 'inet:net4', eq('listed_prefix.id', r('claim.subject')))
        bindings << bind('prefix_scope', 'assertion', 'network:prefix_scope', eq('prefix_scope.subject', r('claim.id')))
        predicates.concat [eq('prefix_scope.attributes.prefix.value', r('listed_prefix.attributes.value')),
          {'op' => 'ip_in_prefix', 'address' => r('seed.attributes.selector'), 'prefix' => r('prefix_scope.id')}]
      end
      predicates += [eq('claim.attributes.claim_kind', p('claim_kind')), eq('claim.attributes.time_basis', l(clock_kind)),
        text('claim.attributes.assertion_namespace'), text('claim.attributes.statement'), text('claim.attributes.source_scope'),
        text('entry.attributes.collection_identity'), text('entry.attributes.entry_identity'), text('entry.attributes.entry_revision'),
        eq('claim.attributes.entry_revision', r('entry.attributes.entry_revision')),
        {'op' => 'all_in', 'left' => {'evidence_sources' => 'claim'}, 'right' => p('reference_sources')},
        within('claim.times.applies', p('period'), clock_kind == 'event' ? 'contained' : 'some')]
      temporal = [tb('claim.times.applies', 'claim.subject', 'claim.id')]
      if question == 'network'
        temporal << tb('association.times.applicable', 'infrastructure.id', 'association.id')
        predicates << (clock_kind == 'event' ? within('association.times.applicable', p('period'), 'at', 'claim.times.applies') :
          {'op' => 'coexists', 'values' => [r('claim.times.applies'), r('association.times.applicable')], 'period' => p('period')})
      end
      bindings += [bind('classification', 'assertion', 'infrastructure:classification', eq('classification.subject', r('claim.subject')), true),
        bind('exclusion', 'assertion', 'investigation:exclusion', all(eq('exclusion.subject', r('claim.id')),
          {'op' => 'in', 'left' => r('exclusion.attributes.rule_id'), 'right' => p('exclusion_rules')}), true)]
      temporal << tb('exclusion.times.applicable', 'claim.subject', 'exclusion.id')
      policy_applies = clock_kind == 'event' ? within('exclusion.times.applicable', p('period'), 'at', 'claim.times.applies') :
        within('exclusion.times.applicable', p('period'), 'all')
      policy = {'id' => 'selected_investigation_exclusion', 'revision' => '1.0', 'scope' => 'path', 'subject' => r('claim.id'),
        'default_enabled' => false, 'enabled_parameter' => 'apply_exclusions', 'required_evaluation' => true,
        'when' => all(eq('exclusion.attributes.disposition', l('exclude')), text('exclusion.attributes.reason'), text('exclusion.attributes.rule_revision'), policy_applies),
        'allow_when' => all(eq('exclusion.attributes.disposition', l('retain')), text('exclusion.attributes.reason'), text('exclusion.attributes.rule_revision'),
          {'op' => 'all_in', 'left' => p('exclusion_rules'), 'right' => r('exclusion.attributes.evaluated_rule_ids')}, policy_applies),
        'conflict_when' => all(eq('exclusion.attributes.disposition', l('contested')), policy_applies),
        'reason' => 'Explicit selected claim/subject/period investigation exclusion; generic shared-hosting classifications do not exclude.'}
      fields = {'inquiry' => l(question), 'finding_kind' => l('historical_source_assertion'), 'source_assertion' => r('claim.id'),
        'statement' => r('claim.attributes.statement'), 'source_scope' => r('claim.attributes.source_scope'),
        'entry' => r('entry.id'), 'entry_revision' => r('entry.attributes.entry_revision'),
        'requested_period' => p('period'), 'period_origin' => p('period_origin'), 'claim_kind' => p('claim_kind'),
        'match_reason' => l(subject_kind), 'classification_context' => r('classification.attributes.classification'),
        'history_limit' => l('reported_in_supplied_scope; all supplied source amendments retained; history beyond supplied revisions unknown; not current or certified unwithdrawn')}
      if question == 'network'
        fields.merge!('association' => r('association.id'), 'association_role' => r('association.attributes.role'),
          'scope_limit' => l('listed subject associated with ASN for this claim; not an ASN-wide publisher assertion or individual observations of every address'))
        output = result('bound', form, [r('infrastructure.id'), r('claim.id'), r('association.id')], fields, 'infrastructure')
      else
        output = result('bound', 'reputation:assertion', [r('claim.id'), r('entry.attributes.entry_revision')], fields, 'claim')
      end
      b = branch(doc, subject_kind + '_' + clock_kind, bindings, predicates, output, temporal, [policy])
      b['amendments'] = {'support' => bindings.reject { |binding| binding['optional'] }.select { |binding| %w[assertion occurrence].include?(binding['kind']) }.map { |binding| binding['name'] },
        'sources' => p('reference_sources'), 'mode' => 'retain_reports'}
    end
    doc
  end
  def kit_match(bindings, predicates, match)
    representation = match == 'archive' ? 'file:bytes' : 'kit:file_set_manifest'
    bindings.concat [bind('seed_representation', 'assertion', 'kit:representation', eq('seed_representation.subject', r('seed.id'))),
      bind('candidate_representation', 'assertion', 'kit:representation', eq('candidate_representation.subject', r('candidate.id'))),
      bind('left', 'entity', representation, eq('left.id', r('seed_representation.object'))),
      bind('right', 'entity', representation, eq('right.id', r('candidate_representation.object')))]
    predicates.concat [eq('seed_representation.attributes.scope', l(match == 'archive' ? 'preserved_archive' : 'declared_file_set')),
      eq('candidate_representation.attributes.scope', r('seed_representation.attributes.scope'))]
    if match == 'archive'
      predicates.concat [content('left'), content('right'), eq('left.attributes.content.sha256', r('right.attributes.content.sha256'))]
    elsif match == 'file_set'
      predicates << {'op' => 'file_set_equal', 'left' => r('left.id'), 'right' => r('right.id'), 'scope_kind' => 'collected_file_set'}
    else
      bindings << bind('comparison', 'assertion', 'kit:shared_path_interpretation', all(eq('comparison.subject', r('left.id')), eq('comparison.object', r('right.id'))))
      predicates.concat [{'op' => 'file_set_shared_paths', 'left' => r('left.id'), 'right' => r('right.id'), 'paths' => r('comparison.attributes.paths')},
        eq('comparison.attributes.profile', l('literal_shared_paths_v1')), text('comparison.attributes.interpretation_basis'),
        text('comparison.attributes.ordinary_explanations'), text('comparison.attributes.scope'),
        eq('comparison.attributes.qualification', l('supported_specific_shared_feature'))]
    end
  end
  def phishkit
    doc = document('CTI_PHISHKIT_TO_HOSTING_CLUSTER', '3.0.0',
      'Independently compared kit representations joined to the same candidate deployment. Actual receipt gives bounded search priority only; historical and undated deployments remain eligible. Source-qualified delivery and controlled-purpose evidence never establish an assessment.',
      'accepted-phish-kit-deployment-boundary-and-evidence-sources')
    doc['parameters'].merge!('query_date' => param('date', 'UTC calendar date for 180-day receipt search priority only; never an activity filter.'),
      'reference_deployments' => param('string_array', 'Explicit baseline deployment records; an empty array supplies no baseline.').merge('item_reference' => 'record'),
      'include_controlled' => param('boolean', 'Explicit analyst inclusion of otherwise evidenced controlled research/test/training/sinkhole occurrences; normal discovery supplies false.'))
    %w[archive file_set paths].product(%w[receipt derivation_candidate derivation_resource derivation_deployment undated], %w[dns ipv4], %w[discovery reference]).each do |match, priority, network, view|
      bindings = [X.seed('phish:kit')]
      temporal = []
      if priority == 'receipt'
        receipt = bind('arrival', 'occurrence', 'evidence:kit_receipt', all(eq('arrival.attributes.collection_id', {'context' => 'collection_id'}),
          text('arrival.attributes.original_evidence_identity'), text('arrival.attributes.collector'),
          {'op' => 'time_compare_if_present', 'operator' => 'lte', 'left' => r('arrival.times.received'), 'right' => r('arrival.times.collection_available')}))
        receipt['priority'] = {'time' => r('arrival.times.received'), 'period' => calendar(180)}
        bindings << receipt
        bindings << bind('candidate', 'entity', 'phish:kit', eq('candidate.id', r('arrival.subject')))
      elsif priority.start_with?('derivation')
        changed = {'derivation_candidate' => 'candidate_id', 'derivation_resource' => 'representation_id', 'derivation_deployment' => 'location_id'}.fetch(priority)
        bindings.concat [bind('analysis_input', 'entity', 'evidence:analysis_input'), bind('prior_output', 'entity', 'evidence:analysis_output'), bind('new_output', 'entity', 'evidence:analysis_output')]
        arrival = bind('arrival', 'occurrence', 'analysis:kit_context_derivation', all(
          eq('arrival.attributes.collection_id', {'context' => 'collection_id'}),
          eq('arrival.attributes.input_id', r('analysis_input.id')), eq('arrival.attributes.prior_output_id', r('prior_output.id')),
          eq('arrival.object', r('new_output.id')), eq('arrival.subject', r('new_output.attributes.candidate_id')),
          eq('arrival.attributes.contribution_role', l(priority.sub('derivation_', '') + '_correspondence')),
          eq('arrival.attributes.profile', l('source_reported_changed_correspondence_v1')),
          text('arrival.attributes.run_id'), text('arrival.attributes.method'), text('arrival.attributes.method_version'),
          text('arrival.attributes.changed_contribution'), text('arrival.attributes.equivalence_limit'),
          text('prior_output.attributes.' + changed), text('new_output.attributes.' + changed),
          {'op' => 'ne', 'left' => r('prior_output.attributes.' + changed), 'right' => r('new_output.attributes.' + changed)},
          {'op' => 'ne', 'left' => r('prior_output.attributes.content.sha256'), 'right' => r('new_output.attributes.content.sha256')},
          {'op' => 'time_compare_if_present', 'operator' => 'lte', 'left' => r('arrival.times.occurred'), 'right' => r('arrival.times.collection_available')},
          {'op' => 'time_compare', 'operator' => 'lte', 'left' => r('analysis_input.times.collection_available'), 'right' => r('arrival.times.occurred')},
          {'op' => 'time_compare', 'operator' => 'lte', 'left' => r('prior_output.times.collection_available'), 'right' => r('arrival.times.occurred')},
          {'op' => 'time_compare', 'operator' => 'lte', 'left' => r('arrival.times.occurred'), 'right' => r('new_output.times.collection_available')},
          content('analysis_input'), content('prior_output'), content('new_output')))
        arrival['priority'] = {'time' => r('arrival.times.occurred'), 'period' => calendar(180)}
        bindings << arrival
        bindings << bind('candidate', 'entity', 'phish:kit', eq('candidate.id', r('arrival.subject')))
      else
        bindings << bind('candidate', 'entity', 'phish:kit')
      end
      temporal << tb(priority.start_with?('derivation') ? 'arrival.times.occurred' : 'arrival.times.received', 'arrival.subject', 'arrival.id') unless priority == 'undated'
      predicates = []
      kit_match(bindings, predicates, match)
      bindings.concat [bind('deployment', 'occurrence', 'kit:deployment', eq('deployment.subject', r('candidate.id'))),
        bind('resource', 'assertion', 'kit:deployment_correspondence', all(eq('resource.subject', r('candidate.id')), eq('resource.object', r('deployment.id')))),
        bind('deployment_evidence', 'entity', 'evidence:deployment_record', eq('deployment_evidence.id', r('resource.attributes.input_id'))),
        bind('location', 'entity', 'inet:url', eq('location.id', r('deployment.attributes.location_id'))),
        bind('delivery', 'assertion', 'kit:delivery_identity', eq('delivery.subject', r('deployment.id'))),
        bind('infrastructure', 'entity', network == 'dns' ? 'inet:fqdn' : 'inet:ipv4', eq('infrastructure.id', r('delivery.object'))),
        bind('purpose', 'assertion', 'kit:occurrence_purpose', all(eq('purpose.subject', r('deployment.id')),
          eq('purpose.attributes.candidate_id', r('candidate.id')), eq('purpose.attributes.resource_scope', r('deployment.attributes.resource_scope')),
          eq('purpose.attributes.location_id', r('location.id')), eq('purpose.attributes.occurrence_key', r('deployment.attributes.occurrence_key'))), true),
        bind('context', 'assertion', 'kit:deployment_context', eq('context.subject', r('deployment.id')), true)]
      predicates.concat [content('deployment_evidence'), text('deployment.attributes.occurrence_key'), text('deployment.attributes.source_scope'),
        {'op' => 'in', 'left' => r('deployment.attributes.origin_source_id'), 'right' => {'evidence_sources' => 'deployment'}},
        eq('deployment.attributes.collection_id', {'context' => 'collection_id'}), text('deployment.attributes.resource_scope'),
        one('deployment.attributes.stage', %w[served installed_serving_context]),
        eq('resource.attributes.representation_id', r('right.id')), eq('resource.attributes.resource_scope', r('deployment.attributes.resource_scope')),
        eq('resource.attributes.location_id', r('location.id')), text('resource.attributes.correspondence_basis'),
        text('resource.attributes.method'), text('resource.attributes.method_version'), text('resource.attributes.reliability_basis'),
        text('resource.attributes.collection_scope'), text('resource.attributes.known_gaps'),
        one('resource.attributes.evidence_kind', %w[preserved_historical_report content_pcap server_resource_log client_network_capture]),
        eq('deployment_evidence.attributes.occurrence_key', r('deployment.attributes.occurrence_key')),
        {'op' => 'any', 'args' => [negate(eq('resource.attributes.evidence_kind', l('client_network_capture'))),
          all(eq('resource.attributes.delivery_provenance', l('actual_network_response')), eq('deployment.attributes.stage', l('served')))]},
        eq('delivery.attributes.location_id', r('location.id')), eq('delivery.attributes.occurrence_key', r('deployment.attributes.occurrence_key')),
        text('delivery.attributes.correspondence_basis'), text('delivery.attributes.vantage')]
      if network == 'dns'
        predicates.concat [eq('delivery.attributes.role', l('application_domain')),
          {'op' => 'uri_component_equal', 'uri' => r('delivery.attributes.uri'), 'component' => 'url', 'right' => r('location.attributes.value')},
          {'op' => 'uri_component_equal', 'uri' => r('delivery.attributes.uri'), 'component' => 'dns_host', 'right' => r('infrastructure.attributes.selector')}]
      else
        predicates.concat [one('delivery.attributes.role', %w[delivery_endpoint installed_serving_endpoint]),
          {'op' => 'typed_equal', 'left' => r('delivery.attributes.address'), 'right' => r('infrastructure.attributes.selector')},
          text('delivery.attributes.resource_delivery_basis')]
      end
      if priority.start_with?('derivation')
        predicates.concat [eq('new_output.attributes.representation_id', r('right.id')), eq('new_output.attributes.location_id', r('location.id')),
          eq('new_output.attributes.resource_scope', r('deployment.attributes.resource_scope')),
          eq('new_output.attributes.input_sha256', r('analysis_input.attributes.content.sha256')),
          eq('new_output.attributes.correspondence_id', r('resource.id'))]
      end
      baseline = all({'op' => 'in', 'left' => r('baseline.id'), 'right' => p('reference_deployments')},
        eq('baseline.subject', r('candidate.id')), %w[occurrence_key source_scope origin_source_id collection_id location_id resource_scope].map { |f| eq('baseline.attributes.' + f, r('deployment.attributes.' + f)) },
        {'op' => 'in', 'left' => r('baseline.attributes.origin_source_id'), 'right' => {'evidence_sources' => 'baseline'}})
      bindings << bind('baseline', 'occurrence', 'kit:deployment', baseline, view == 'discovery')
      predicates << {'op' => 'binding_absent', 'binding' => 'baseline'} if view == 'discovery'
      if view == 'discovery'
        bindings << bind('baseline_comparison', 'assertion', 'kit:baseline_comparison', all(eq('baseline_comparison.subject', r('deployment.id')),
          eq('baseline_comparison.attributes.candidate_id', r('candidate.id')),
          %w[occurrence_key source_scope origin_source_id collection_id location_id resource_scope].map { |f| eq('baseline_comparison.attributes.' + f, r('deployment.attributes.' + f)) },
          {'op' => 'all_in', 'left' => p('reference_deployments'), 'right' => r('baseline_comparison.attributes.compared_baseline_ids')}), true)
      end
      temporal << tb('deployment.times.occurred', 'candidate.id', 'deployment.id')
      predicates << {'op' => 'time_compare_if_present', 'operator' => 'lte', 'left' => r('deployment.times.occurred'), 'right' => r('deployment.times.collection_available')}
      fields = {'match_reason' => l(match), 'candidate' => r('candidate.id'), 'seed_representation' => r('left.id'), 'candidate_representation' => r('right.id'),
        'deployment' => r('deployment.id'), 'deployment_stage' => r('deployment.attributes.stage'), 'activity_time' => r('deployment.times.occurred'),
        'occurrence_key' => r('deployment.attributes.occurrence_key'), 'resource_scope' => r('deployment.attributes.resource_scope'),
        'evidence_kind' => r('resource.attributes.evidence_kind'), 'reliability_basis' => r('resource.attributes.reliability_basis'),
        'infrastructure_role' => r('delivery.attributes.role'), 'origin_role' => r('delivery.attributes.origin_role'),
        'search_focus' => l('180-day collection receipt priority only; old/undated activity eligible; no discovery-order gate'),
        'arrival' => priority == 'undated' ? l(nil) : r('arrival.id'), 'priority_basis' => l(priority.start_with?('derivation') ? 'source_reported_substantive_derivation' : priority == 'undated' ? 'unranked_base_evidence' : priority),
        'priority_limit' => l('search order only; no independently verified novelty or first-ever availability; witnesses do not multiply deployments'),
        'context' => r('context.attributes.explanation'), 'purpose_context' => r('purpose.attributes.disposition'),
        'purpose_reason' => r('purpose.attributes.reason'), 'view' => l(view),
        'scope_limit' => l('same-candidate source-qualified deployment; no common operator, maliciousness or deployment of every file in a manifest')}
      identity = [r('candidate.id'), r('deployment.attributes.collection_id'), r('deployment.attributes.source_scope'), r('deployment.attributes.occurrence_key'), r('infrastructure.id'), l(match)]
      output = result(view == 'reference' ? 'construct' : 'bound', view == 'reference' ? 'evidence:deployment_reference' : network == 'dns' ? 'inet:fqdn' : 'inet:ipv4',
        identity, fields, view == 'reference' ? nil : 'infrastructure')
      policy = {'id' => 'controlled_deployment_occurrence', 'revision' => '1.0', 'scope' => 'occurrence', 'subject' => r('deployment.id'),
        'required_evaluation' => true, 'default_enabled' => true,
        'when' => all(eq('purpose.attributes.disposition', l('controlled')), one('purpose.attributes.purpose', %w[research training test sinkhole]),
          text('purpose.attributes.reason'), text('purpose.attributes.rule_revision')),
        'allow_when' => all(eq('purpose.attributes.disposition', l('not_controlled')), text('purpose.attributes.reason'), text('purpose.attributes.rule_revision')),
        'conflict_when' => eq('purpose.attributes.disposition', l('contested')),
        'reason' => 'Default exclusion applies only to this supported candidate/resource/location/occurrence; unknown/conflicting purpose remains unresolved.'}
      # Explicitly included controlled uses are still evidence, never cleared malicious candidates.
      policy['applies_when'] = {'op' => 'eq', 'left' => p('include_controlled'), 'right' => l(false)}
      policies = [policy]
      if view == 'discovery'
        policies << {'id' => 'selected_baseline_occurrence_distinction', 'revision' => '1.0', 'scope' => 'occurrence', 'subject' => r('deployment.id'),
          'required_evaluation' => true, 'default_enabled' => true,
          'applies_when' => {'op' => 'nonblank_text_array', 'value' => p('reference_deployments')},
          'when' => {'op' => 'eq', 'left' => l(true), 'right' => l(false)},
          'allow_when' => all(content('baseline_comparison'), eq('baseline_comparison.attributes.profile', l('source_qualified_occurrence_comparison_v1')),
            eq('baseline_comparison.attributes.disposition', l('distinct_occurrences')), text('baseline_comparison.attributes.method'),
            text('baseline_comparison.attributes.method_version'), text('baseline_comparison.attributes.comparison_basis')),
          'conflict_when' => all(content('baseline_comparison'), one('baseline_comparison.attributes.disposition', %w[same_occurrence contested])),
          'reason' => 'Different source/record/occurrence labels alone do not prove a deployment differs from selected baseline occurrences; required source-qualified distinction remains explicit.'}
      end
      branch(doc, [match, priority, network, view].join('_'), bindings, predicates, output, temporal, policies)
    end
    # Clues have their own projection and never enter the deployment result branch.
    bindings = [X.seed('phish:kit'), bind('candidate', 'entity', 'phish:kit')]
    predicates = [{'op' => 'ne', 'left' => r('candidate.id'), 'right' => r('seed.id')}]
    kit_match(bindings, predicates, 'paths')
    predicates.pop # replace only the source-qualified interpretation choice
    predicates << eq('comparison.attributes.qualification', l('only_generic_default_paths'))
    output = result('construct', 'evidence:kit_comparison_clue', [r('seed.id'), r('candidate.id'), r('comparison.id')],
      {'match_reason' => l('generic/default literal path overlap'), 'shared_paths' => r('comparison.attributes.paths'),
       'explanation' => r('comparison.attributes.ordinary_explanations'), 'scope_limit' => l('comparison clue only; no qualifying kit correspondence or deployment inference')})
    branch(doc, 'generic_path_clue', bindings, predicates, output)
    bindings = [X.seed('phish:kit'), bind('candidate', 'entity', 'phish:kit')]
    predicates = [{'op' => 'ne', 'left' => r('candidate.id'), 'right' => r('seed.id')}]
    kit_match(bindings, predicates, 'file_set')
    predicates.find { |predicate| predicate['op'] == 'file_set_equal' }['scope_kind'] = 'declared_subset'
    output = result('construct', 'evidence:kit_comparison_clue', [r('seed.id'), r('candidate.id'),
      r('left.attributes.content.sha256'), r('right.attributes.content.sha256')],
      {'match_reason' => l('exact preserved declared subset'), 'left_manifest' => r('left.id'), 'right_manifest' => r('right.id'),
       'scope_limit' => l('verified declared_subset equality only; not whole-kit identity or qualifying hosting correspondence; actual scope retained in comparator evidence')})
    branch(doc, 'exact_declared_subset_clue', bindings, predicates, output)
    bindings = [X.seed('phish:kit'), bind('candidate', 'entity', 'phish:kit'),
      bind('seed_component', 'assertion', 'kit:component', eq('seed_component.subject', r('seed.id'))),
      bind('candidate_component', 'assertion', 'kit:component', eq('candidate_component.subject', r('candidate.id'))),
      bind('left', 'entity', 'file:bytes', eq('left.id', r('seed_component.object'))),
      bind('right', 'entity', 'file:bytes', eq('right.id', r('candidate_component.object')))]
    predicates = [{'op' => 'ne', 'left' => r('candidate.id'), 'right' => r('seed.id')}, content('left'), content('right'), eq('left.attributes.content.sha256', r('right.attributes.content.sha256')),
      text('seed_component.attributes.component_scope'), text('candidate_component.attributes.component_scope')]
    output = result('construct', 'evidence:kit_comparison_clue', [r('seed.id'), r('candidate.id'), r('left.attributes.content.sha256'),
      r('seed_component.attributes.component_scope'), r('candidate_component.attributes.component_scope')],
      {'match_reason' => l('exact preserved component bytes'), 'left_scope' => r('seed_component.attributes.component_scope'),
       'right_scope' => r('candidate_component.attributes.component_scope'), 'scope_limit' => l('component clue only; whole-kit identity and deployment not established')})
    branch(doc, 'exact_component_clue', bindings, predicates, output)
    doc
  end
  def documents; [phase, officer, creative, phishkit] + %w[ip asn network].map { |q| sbl(q) }; end
  def write
    documents.each { |d| File.write(File.join(ROOT, 'contracts/semantics', d['pattern']['id'] + '.json'), JSON.pretty_generate(d) + "\n") }
  end
end
ResultBindingContracts.write if $PROGRAM_NAME == __FILE__
