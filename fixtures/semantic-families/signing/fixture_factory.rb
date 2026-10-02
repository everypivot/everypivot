# frozen_string_literal: true

# Synthetic source assertions with independently specified identities, support
# sets and complete-finding establishment dates. No contract predicate is used
# to choose an expected result or invent an establishment event.
require 'base64'
require_relative '../../../tools/semantic_contract'
module SigningFixtures
  C = EveryPivot::SemanticContract
  ROOT = File.expand_path('../../..', __dir__)
  IDS = %w[CTI_APK_SIGNING_CERT_CLUSTER CTI_SAMPLE_CODESIGN_CERT_CLUSTER CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT SUPPLY_CODESIGN_CERT_TO_PACKAGES CTI_AUTHENTICODE_HASH_CLUSTER].freeze
  CERT_FIELDS = {'certificate_sha256' => 'certificate_selector', 'spki_sha256' => 'spki_selector', 'issuer_serial' => 'issuer_serial_selector'}.freeze
  module_function
  def deep(value); Marshal.load(Marshal.dump(value)); end
  def get(data, id); data['evidence']['records'].find { |r| r['id'] == id }; end
  def source(id)
    {'id' => id, 'publisher' => 'independent synthetic signing fixture', 'document' => 'fixture:' + id,
     'revision' => 'r1', 'collection' => 'signing-fixture-collection', 'independent_origin' => nil}
  end
  def time(value, object, occurrence, field)
    {'binding' => {'object' => object, 'occurrence' => occurrence}, 'field' => field, 'source_revision' => 'r1',
     'clock' => {'id' => 'fixture-utc', 'reference' => 'UTC', 'uncertainty_seconds' => 0},
     'timezone' => 'UTC', 'precision' => 'instant', 'interval_role' => 'occurrence', 'value' => value}
  end
  def rec(data, id, kind, type, attrs = {}, subject: nil, object: nil, available: '2026-09-10T00:00:00Z')
    r = {'id' => id, 'kind' => kind, 'type' => type, 'attributes' => deep(attrs), 'times' => {},
      'evidence' => [{'source_id' => 'report', 'field' => '/records/' + id}]}
    r['subject'] = subject if subject
    r['object'] = object if object
    if type.start_with?('signature:', 'analysis:') || %w[artifact:certificate_presence package:distribution_artifact].include?(type)
      r['attributes']['assertion_namespace'] = 'synthetic-signing-reports'
    end
    if available
      receipt = 'receipt-' + id
      r['attributes']['availability_occurrence'] = receipt
      r['times']['collection_available'] = time(available, id, receipt, '/records/' + id + '/available')
      data['evidence']['records'] << {'id' => receipt, 'kind' => 'occurrence', 'type' => 'evidence:availability',
        'attributes' => {'collection_id' => 'signing-fixture-collection'}, 'times' => {},
        'evidence' => [{'source_id' => 'report', 'field' => '/records/' + receipt}]}
    end
    data['evidence']['records'] << r
    r
  end
  def provenance(carrier, field)
    {'source' => 'report', 'record_id' => carrier, 'source_revision' => 'r1',
     'field' => '/records/' + carrier + '/attributes/' + field, 'basis' => 'reported'}
  end
  def rehome(selector, carrier, field)
    deep(selector).merge('provenance' => provenance(carrier, field))
  end
  def vector(number = 0)
    @vectors ||= JSON.parse(File.read(File.join(__dir__, '../certificate-presentation/certificates.json')))['certificates']
    @vectors.fetch(number)
  end
  def cert_selector(kind, carrier, field, number = 0)
    v = vector(number)
    if kind == 'issuer_serial'
      return {'kind' => kind, 'issuer_namespace' => {'kind' => 'reported_name', 'value' => 'CN=beta.example.test,O=Synthetic Fixture', 'matching_rule' => 'exact_v1'},
        'serial' => v['serial'], 'serial_radix' => 10, 'provenance' => provenance(carrier, field)}
    end
    {'kind' => kind, 'algorithm' => 'sha256', 'representation' => 'der', 'normalization' => 'exact_der_v1',
     'scope' => kind == 'certificate_sha256' ? 'whole_certificate' : 'subject_public_key_info',
     'value' => v[kind == 'certificate_sha256' ? 'sha256' : 'spki_sha256'], 'provenance' => provenance(carrier, field)}
  end
  def certificate(data, id, number = 0, available: '2024-12-16T00:00:00Z')
    rec(data, id, 'entity', 'x509:cert', CERT_FIELDS.each_with_object({}) { |(kind, field), h| h[field] = cert_selector(kind, id, field, number) }, available: available)
  end
  def artifact_identity(carrier, bytes = 'historically retained artifact A', field = 'identity')
    {'kind' => 'artifact_sha256', 'algorithm' => 'sha256', 'representation' => 'bytes', 'normalization' => 'exact_bytes_v1',
     'scope' => 'whole_artifact', 'value' => Digest::SHA256.hexdigest(bytes), 'provenance' => provenance(carrier, field)}
  end
  def material(carrier, field = 'identity', kind = 'signature_material_digest', role = 'primary_signer', scheme = 'cms_authenticode')
    s = {'kind' => kind, 'algorithm' => 'sha256', 'representation' => 'digest_hex',
      'normalization' => kind == 'signature_material_digest' ? 'exact_selected_blob_bytes_v1' : 'declared_signed_content_recipe_v1',
      'scope' => kind == 'signature_material_digest' ? 'selected_signature_blob' : 'declared_format_covered_bytes_excluding_signature_storage',
      'method_version' => 'fixture-recipe-1', 'value' => Digest::SHA256.hexdigest(kind + role + scheme), 'provenance' => provenance(carrier, field)}
    s['signature_role'] = role if kind == 'signature_material_digest'
    s['scheme'] = scheme if kind == 'scheme_content_digest'
    s
  end
  def typed_identity(selector)
    kind = selector['kind']
    case kind
    when 'issuer_serial'
      ns = selector['issuer_namespace']
      {'kind' => kind, 'comparison' => [ns['kind'], ns['matching_rule']], 'value' => [ns['value'], selector['serial'].to_i(selector['serial_radix'])]}
    when 'artifact_sha256', 'certificate_sha256', 'spki_sha256'
      {'kind' => kind, 'comparison' => selector.values_at('algorithm', 'representation', 'normalization', 'scope'), 'value' => selector['value'].downcase}
    else
      comparison = selector.values_at('algorithm', 'representation', 'normalization', 'scope', 'method_version')
      comparison << selector['signature_role'] if kind == 'signature_material_digest'
      comparison << selector['scheme'] if kind == 'scheme_content_digest'
      {'kind' => kind, 'comparison' => comparison, 'value' => selector['value'].downcase}
    end
  end
  def base(id, purpose, role)
    contract = JSON.parse(File.read(File.join(ROOT, 'contracts/semantics', id + '.json')))
    data = {'pattern' => id, 'contract' => contract,
      'evidence' => {'contract' => 'everypivot.semantic_evidence', 'version' => '1.0', 'collection_id' => 'signing-fixture-collection',
        'sources' => [source('report'), source('manifest')], 'records' => []},
      'query' => {'parameters' => {'purpose' => purpose, 'period' => {'start' => '2026-09-01', 'end' => '2026-09-30'}, 'history' => 'history', 'amendment_sources' => ['report']},
        'limits' => {'max_bindings' => 50000, 'max_results' => 100}},
      'preserved_source_bytes' => {}, 'claims' => []}
    data['query']['parameters']['role'] = role unless purpose == 'image_content'
    origin = rec(data, 'origin', 'occurrence', 'collection:origin', {'collection_id' => 'signing-fixture-collection'}, available: nil)
    origin['times']['origin'] = time('2020-01-01T00:00:00Z', 'origin', 'origin', '/records/origin/origin')
    snapshot = rec(data, 'snapshot', 'occurrence', 'collection:history_snapshot', {'collection_id' => 'signing-fixture-collection'}, available: nil)
    snapshot['times']['through'] = time('2026-10-02T23:59:59Z', 'snapshot', 'snapshot', '/records/snapshot/through')
    history = rec(data, 'history', 'assertion', 'finding:history', {'manifest_source_id' => 'manifest', 'manifest_field' => '/history'}, available: nil)
    history['evidence'] = [{'source_id' => 'manifest', 'field' => '/history'}]
    data
  end
  def add_path(data, prefix, purpose, kind, role, number: 0, bytes: 'historically retained artifact A')
    n = ->(s) { prefix + s }
    auth = data['pattern'] == 'CTI_AUTHENTICODE_HASH_CLUSTER'
    apk = data['pattern'] == 'CTI_APK_SIGNING_CERT_CLUSTER'
    format, scheme = apk ? ['apk', 'apk_v2'] : ['pe', 'cms_authenticode']
    artifact = rec(data, n.call('artifact'), 'entity', auth ? 'file:hash' : 'file:bytes',
      {'identity' => artifact_identity(n.call('artifact'), bytes), 'format' => format, 'capture_context' => 'original endpoint Dec 2024'}, available: '2024-12-16T00:00:00Z')
    sighting = rec(data, n.call('sighting'), 'occurrence', 'artifact:sighting', {'location' => 'original endpoint'}, subject: artifact['id'], available: nil)
    sighting['times']['observed'] = time('2024-12-15T00:00:00Z', artifact['id'], sighting['id'], '/records/' + sighting['id'] + '/observed')
    a = artifact['attributes']['identity']
    if purpose == 'image_content'
      s = material(n.call('analysis'), 'selector', 'authenticode_image_digest', role, scheme)
      rec(data, n.call('analysis'), 'occurrence', 'analysis:authenticode_image_digest',
        {'selector' => s, 'artifact_identity' => rehome(a, n.call('analysis'), 'artifact_identity'),
         'input_status' => 'scope_and_digest_established', 'method' => 'reported image digest analysis', 'method_version' => s['method_version'],
         'covered_scope' => s['scope'], 'excluded_scope' => 'checksum, certificate table directory and certificate table per declared recipe'}, subject: artifact['id'])
      return [[purpose, typed_identity(a), typed_identity(s)], [n.call('analysis'), artifact['id']], s]
    end
    sig = material(n.call('signature'), 'identity', 'signature_material_digest', role, scheme)
    if purpose == 'signature_material'
      signature = rec(data, n.call('signature'), 'entity', 'code:signature:material', {'identity' => sig, 'role' => role})
      s = rehome(sig, n.call('analysis'), 'selector')
      rec(data, n.call('analysis'), 'occurrence', 'analysis:signature_material_digest',
        {'selector' => s, 'artifact_identity' => rehome(a, n.call('analysis'), 'artifact_identity'), 'source_location' => 'selected container blob 0',
         'method' => 'reported selected-material extraction', 'method_version' => '1', 'input_status' => 'selected_material_and_digest_established'}, subject: artifact['id'], object: signature['id'])
      return [[purpose, typed_identity(a), typed_identity(sig), role], [n.call('analysis'), artifact['id'], signature['id']], s]
    end
    cert = certificate(data, n.call('certificate'), number)
    ca = cert['attributes']
    selected = ca.fetch(CERT_FIELDS.fetch(kind))
    identity = [purpose, typed_identity(a), typed_identity(ca['certificate_selector']), typed_identity(selected), role]
    if purpose == 'certificate_presence'
      rec(data, n.call('association'), 'assertion', 'artifact:certificate_presence',
        {'certificate_selector' => rehome(ca['certificate_selector'], n.call('association'), 'certificate_selector'), 'artifact_identity' => rehome(a, n.call('association'), 'artifact_identity'),
         'role' => role, 'basis' => 'reported_extraction_from_exact_artifact', 'source_location' => 'embedded certificate container offset 64', 'method' => 'fixture source extraction', 'method_version' => '1'}, subject: artifact['id'], object: cert['id'])
      return [identity, [cert['id'], n.call('association'), artifact['id']], selected]
    end
    rec(data, n.call('signature'), 'entity', 'code:signature:material', {'identity' => sig, 'role' => role})
    rec(data, n.call('signer'), 'assertion', 'signature:signer_binding',
      {'certificate_selector' => rehome(ca['certificate_selector'], n.call('signer'), 'certificate_selector'), 'spki_selector' => rehome(ca['spki_selector'], n.call('signer'), 'spki_selector'),
       'role' => role, 'basis' => 'reported_selected_signature_signer', 'source_location' => 'signature 0 signer 0'}, subject: n.call('signature'), object: cert['id'])
    covered = material(n.call('association'), 'covered_content', 'scheme_content_digest', role, scheme)
    association = rec(data, n.call('association'), 'assertion', 'signature:artifact_binding',
      {'artifact_identity' => rehome(a, n.call('association'), 'artifact_identity'), 'signature_selector' => rehome(sig, n.call('association'), 'signature_selector'),
       'covered_content' => covered, 'format' => format, 'scheme' => scheme, 'correspondence' => 'embedded_signature_exact_artifact',
       'covered_object' => 'declared scheme-covered artifact content', 'source_location' => 'selected signature directory 0', 'method' => 'fixture attachment mapper', 'method_version' => '1'}, subject: artifact['id'], object: n.call('signature'))
    check = rec(data, n.call('verification'), 'occurrence', 'signature:verification_check',
      {'artifact_identity' => rehome(a, n.call('verification'), 'artifact_identity'), 'signature_selector' => rehome(sig, n.call('verification'), 'signature_selector'),
       'certificate_selector' => rehome(ca['certificate_selector'], n.call('verification'), 'certificate_selector'), 'spki_selector' => rehome(ca['spki_selector'], n.call('verification'), 'spki_selector'),
       'covered_content' => rehome(covered, n.call('verification'), 'covered_content'), 'format' => format, 'scheme' => scheme, 'role' => role,
       'check_status' => 'success', 'basis' => 'source_reported_scoped_check', 'crypto_check' => 'selected_signature_over_declared_content',
       'verifier' => 'synthetic reporting laboratory', 'method' => 'source-report verifier', 'method_version' => '1',
       'limitations' => 'Synthetic source report only; no cryptographic operation, trust chain, platform policy or signing-time verification executed by evaluator.',
       'report_location' => '/records/' + n.call('verification')}, subject: artifact['id'], object: n.call('signature'))
    check['times']['checked'] = time('2026-09-09T00:00:00Z', artifact['id'], check['id'], '/records/' + check['id'] + '/checked')
    identity += [typed_identity(sig), typed_identity(covered), scheme, association['attributes']['correspondence'], association['attributes']['covered_object']]
    support = [cert['id'], n.call('signer'), n.call('signature'), n.call('association'), artifact['id']]
    support << check['id'] if purpose == 'scoped_verified_signature'
    [identity, support, selected]
  end
  def build(id = 'CTI_SAMPLE_CODESIGN_CERT_CLUSTER', purpose: 'reported_signer', kind: nil, role: 'primary_signer', reference: false)
    kind ||= id == 'CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT' ? 'issuer_serial' : 'certificate_sha256'
    data = base(id, purpose, role)
    identity, support, selector = add_path(data, '', purpose, kind, role)
    params = data['query']['parameters']
    param = purpose == 'image_content' ? 'image_selector' : purpose == 'signature_material' ? 'material_selector' : 'certificate_selector'
    params[param] = deep(selector)
    if id == 'CTI_AUTHENTICODE_HASH_CLUSTER'
      params['reference_mode'] = reference ? 'artifact_derived' : 'selector_only'
      if reference
        ref_identity, ref_support, = add_path(data, 'reference_', purpose, kind, role, bytes: 'different historical reference file R')
        reference_claim = {'identity' => ref_identity, 'support' => ref_support, 'event' => 'reference-established', 'at' => '2024-12-21T00:00:00Z'}
        params['reference_artifact'] = 'reference_artifact'
        data['evidence']['records'].select { |r| r['id'].start_with?('reference_') }.each do |r|
          r['times'].each_value { |t| t['value'] = '2024-12-20T00:00:00Z' if t['value'] }
        end
      end
    else
      certificate(data, 'seed')
      params['seed'] = 'seed'
      params['certificate_selector'] = deep(get(data, 'seed')['attributes'].fetch(CERT_FIELDS.fetch(kind)))
    end
    if id == 'SUPPLY_CODESIGN_CERT_TO_PACKAGES'
      rec(data, 'package', 'entity', 'it:prod:softver', {'ecosystem' => 'fixture-registry', 'namespace' => '@fixture', 'name' => 'one-product', 'version' => '1.4'}, available: '2019-01-01T00:00:00Z')
      rec(data, 'package_link', 'assertion', 'package:distribution_artifact', {'artifact_identity' => rehome(get(data, 'artifact')['attributes']['identity'], 'package_link', 'artifact_identity'),
        'variant' => 'windows-x64-installer', 'basis' => 'reported_exact_distribution_artifact', 'source_location' => 'release manifest artifact 7'}, subject: 'artifact', object: 'package', available: '2026-09-15T00:00:00Z')
      support += %w[package_link package]
      identity += ['fixture-registry', '@fixture', 'one-product', '1.4', 'windows-x64-installer']
    end
    data['claims'] << {'identity' => identity, 'support' => support, 'event' => 'established', 'at' => id == 'SUPPLY_CODESIGN_CERT_TO_PACKAGES' ? '2026-09-15T12:00:00Z' : '2026-09-11T00:00:00Z'}
    data['claims'] << reference_claim if reference_claim
    seal(data)
  end
  def qualification(data)
    {'id' => data['pattern'].downcase, 'revision' => '1.0', 'contract_sha256' => C.digest(data['contract'])}
  end
  def seal(data, coverage = 'complete_declared_scope')
    data['evidence']['records'].reject! { |r| r['type'] == 'finding:establishment' }
    data['evidence']['records'].each do |r|
      r['times'].each_value do |t|
        pointer = {'source_id' => 'report', 'field' => t['field']}
        r['evidence'] << pointer unless r['evidence'].include?(pointer)
      end
    end
    events = data['claims'].map do |claim|
      q = qualification(data)
      event = rec(data, claim['event'], 'occurrence', 'finding:establishment', {'claim_key' => C.digest({'qualification' => [q['id'], q['revision']], 'identity' => claim['identity']}),
        'collection_id' => 'signing-fixture-collection', 'history_id' => 'history', 'qualification' => q,
        'support' => claim['support'].map { |id| {'record_id' => id, 'sha256' => C.digest(get(data, id))} }}, available: nil)
      event['times']['established'] = time(claim['at'], event['id'], event['id'], '/records/' + event['id'] + '/established')
      event['evidence'] << {'source_id' => 'report', 'field' => event['times']['established']['field']}
      event
    end
    manifest = {'contract' => 'everypivot.finding_history', 'version' => '1.0', 'history_id' => 'history', 'revision' => 'r1',
      'collection_id' => 'signing-fixture-collection', 'scope_id' => 'synthetic-origin-through-snapshot', 'origin_id' => 'origin', 'origin_sha256' => C.digest(get(data, 'origin')),
      'through_id' => 'snapshot', 'through_sha256' => C.digest(get(data, 'snapshot')), 'coverage' => coverage, 'qualification' => qualification(data),
      'establishments' => events.map { |r| {'record_id' => r['id'], 'sha256' => C.digest(r)} }}
    data['preserved_source_bytes']['manifest'] = JSON.generate('history' => manifest)
    data['preserved_source_bytes']['report'] = JSON.generate('records' => data['evidence']['records'].each_with_object({}) { |r, h| h[r['id']] = r })
    data['preserved_source_bytes'].each do |id, bytes|
      s = data['evidence']['sources'].find { |v| v['id'] == id }
      s['content_hash'] = {'algorithm' => 'sha256', 'value' => Digest::SHA256.hexdigest(bytes), 'scope' => 'exact_source_bytes'} if s
    end
    data
  end
end
