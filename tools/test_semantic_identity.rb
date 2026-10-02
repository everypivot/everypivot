#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require_relative 'semantic_identity'

class SemanticIdentityTest < Minitest::Test
  S = EveryPivot::SemanticIdentity

  def provenance
    {'source' => 'synthetic-fixture', 'record_id' => 'record-1', 'source_revision' => 'r1',
     'field' => '/fixture/selector', 'basis' => 'reported'}
  end

  def selector(kind, attrs = {})
    {'kind' => kind, 'provenance' => provenance}.merge(attrs)
  end

  def certificate(serial, key, subject = '/CN=fixture.example.test')
    cert = OpenSSL::X509::Certificate.new
    cert.version = 2
    cert.serial = serial
    cert.subject = OpenSSL::X509::Name.parse(subject)
    cert.issuer = cert.subject
    cert.public_key = key.public_key
    cert.not_before = Time.utc(2024, 12, 3)
    cert.not_after = Time.utc(2026, 12, 3)
    cert.sign(key, OpenSSL::Digest::SHA256.new)
    cert
  end

  def cert_selector(cert, kind = 'certificate_sha256')
    selector(kind, 'algorithm' => 'sha256', 'representation' => 'der', 'normalization' => 'exact_der_v1',
      'scope' => kind == 'certificate_sha256' ? 'whole_certificate' : 'subject_public_key_info',
      'certificate_pem' => cert.to_pem)
  end

  def test_renewed_certificate_same_key_is_not_same_certificate
    key = OpenSSL::PKey::RSA.new(1024)
    first = certificate(1001, key)
    renewed = certificate(1002, key)
    assert_equal 'no_match', S.compare(cert_selector(first), cert_selector(renewed))['status']
    assert_equal 'match', S.compare(cert_selector(first, 'spki_sha256'), cert_selector(renewed, 'spki_sha256'))['status']
    rekeyed = certificate(1003, OpenSSL::PKey::RSA.new(1024))
    assert_equal 'no_match', S.compare(cert_selector(first, 'spki_sha256'), cert_selector(rekeyed, 'spki_sha256'))['status']
  end

  def test_pem_formatting_and_der_are_same_content_but_distinct_preserved_artifacts
    cert = certificate(1001, OpenSSL::PKey::RSA.new(1024))
    pem = cert.to_pem
    wrapped = "-----BEGIN CERTIFICATE-----\n#{Base64.strict_encode64(cert.to_der).scan(/.{1,48}/).join("\n")}\n-----END CERTIFICATE-----\n"
    refute_equal Digest::SHA256.hexdigest(pem), Digest::SHA256.hexdigest(wrapped)
    left = cert_selector(cert)
    right = left.merge('certificate_pem' => wrapped)
    assert_equal 'match', S.compare(left, right)['status']
    der = left.reject { |name, _| name == 'certificate_pem' }.merge('certificate_der_base64' => Base64.strict_encode64(cert.to_der))
    assert_equal 'match', S.compare(left, der)['status']
    assert_equal Digest::SHA256.hexdigest(cert.to_der), S.normalize(left)['value']
  end

  def test_digest_and_spki_independently_reproduced_by_openssl_cli
    cert = certificate(4001, OpenSSL::PKey::RSA.new(1024))
    out, error, status = Open3.capture3('openssl', 'x509', '-outform', 'DER', :stdin_data => cert.to_pem)
    assert status.success?, error
    assert_equal cert.to_der, out.b
    sha, error, status = Open3.capture3('openssl', 'dgst', '-sha256', :stdin_data => out)
    assert status.success?, error
    assert_equal sha.split.last, S.normalize(cert_selector(cert))['value']
    public_key, error, status = Open3.capture3('openssl', 'x509', '-pubkey', '-noout', :stdin_data => cert.to_pem)
    assert status.success?, error
    spki, error, status = Open3.capture3('openssl', 'pkey', '-pubin', '-outform', 'DER', :stdin_data => public_key)
    assert status.success?, error
    sha, error, status = Open3.capture3('openssl', 'dgst', '-sha256', :stdin_data => spki)
    assert status.success?, error
    assert_equal sha.split.last, S.normalize(cert_selector(cert, 'spki_sha256'))['value']
    standalone = cert_selector(cert, 'spki_sha256').reject { |name, _| name == 'certificate_pem' }.merge('spki_der_base64' => Base64.strict_encode64(spki))
    assert_equal 'match', S.compare(cert_selector(cert, 'spki_sha256'), standalone)['status']
  end

  def test_exact_spki_includes_algorithm_parameters
    oid = OpenSSL::ASN1::ObjectId.new('1.2.840.113549.1.1.1')
    key = OpenSSL::ASN1::BitString.new("\x01\x02\x03".b)
    with_null = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Sequence.new([oid, OpenSSL::ASN1::Null.new(nil)]), key]).to_der
    without_null = OpenSSL::ASN1::Sequence.new([OpenSSL::ASN1::Sequence.new([oid]), key]).to_der
    make = lambda { |der| selector('spki_sha256', 'algorithm' => 'sha256', 'representation' => 'der', 'normalization' => 'exact_der_v1', 'scope' => 'subject_public_key_info', 'spki_der_base64' => Base64.strict_encode64(der)) }
    assert_equal 'no_match', S.compare(make.call(with_null), make.call(without_null))['status']
  end

  def test_reported_digest_is_not_locally_reproduced_or_verified
    item = selector('certificate_sha256', 'algorithm' => 'sha256', 'representation' => 'der', 'normalization' => 'exact_der_v1', 'scope' => 'whole_certificate', 'value' => 'A' * 64)
    got = S.compare(item, item.merge('value' => 'a' * 64))
    assert_equal 'match', got['status']
    assert_equal false, got['left_locally_reproduced']
    assert_equal 'not_performed', got['verification']
    assert_equal 'evidence_only', got['assessment_mode']
  end

  def test_reported_digest_conflict_is_retained_without_repair
    item = cert_selector(certificate(1001, OpenSSL::PKey::RSA.new(1024))).merge('value' => '0' * 64)
    got = S.normalize(item)
    assert_equal 'unresolved', got['status']
    assert_equal '0' * 64, got['reported_value']
    refute_equal got['reported_value'], got['reproduced_value']
  end

  def test_container_or_tbs_digest_cannot_substitute_for_certificate_identity
    item = selector('certificate_sha256', 'algorithm' => 'sha256', 'representation' => 'der', 'normalization' => 'exact_der_v1', 'scope' => 'tbs_certificate', 'value' => 'a' * 64)
    assert_equal 'unsupported', S.compare(item, item)['status']
  end

  def test_invalid_certificate_material_and_trailing_objects_rejected
    item = cert_selector(certificate(1001, OpenSSL::PKey::RSA.new(1024)))
    assert_raises(S::InvalidInput) { S.normalize(item.merge('certificate_pem' => item['certificate_pem'] * 2)) }
    assert_raises(S::InvalidInput) { S.normalize(item.merge('certificate_pem' => 'not a certificate')) }
    assert_raises(S::InvalidInput) { S.normalize(item.merge('certificate_der_base64' => 'AAAA')) }
    assert_raises(S::InvalidInput) { S.normalize(item.reject { |name, _| name == 'certificate_pem' }.merge('certificate_der_base64' => '%%%')) }
  end

  def issuer_selector(serial, radix, namespace = 'reported_name', issuer = 'CN=Issuer,O=Example')
    selector('issuer_serial', 'issuer_namespace' => {'kind' => namespace, 'value' => issuer, 'matching_rule' => 'exact_v1'}, 'serial' => serial, 'serial_radix' => radix)
  end

  def test_explicit_issuer_namespace_and_serial_radix
    first = issuer_selector('1001', 10)
    assert_equal 'match', S.compare(first, issuer_selector('03E9', 16))['status']
    assert_equal 'match', S.compare(first, issuer_selector('03E9', 16.0))['status']
    assert_equal 'no_match', S.compare(first, issuer_selector('1001', 16))['status']
    assert_equal 'no_match', S.compare(first, issuer_selector('1001', 10, 'reported_name', 'cn=issuer,o=example'))['status']
    assert_equal 'unresolved', S.compare(first, issuer_selector('1001', 10, 'authority_id'))['status']
    assert_equal 'issuer_serial_link_only', S.normalize(first)['identity_claim']
    assert_raises(S::InvalidInput) { S.normalize(first.reject { |name, _| name == 'serial_radix' }) }
    assert_raises(S::InvalidInput) { S.normalize(first.merge('serial' => '0x03E9', 'serial_radix' => 16)) }
  end

  def material(kind = 'authenticode_image_digest', attrs = {})
    selector(kind, {'algorithm' => 'sha256', 'representation' => 'digest_hex', 'normalization' => 'explicit-fixture-recipe',
      'scope' => 'fixture-covered-image-bytes-v1', 'method_version' => 'fixture-method-1', 'value' => 'a' * 64}.merge(attrs))
  end

  def test_whole_artifact_exact_bytes_have_distinct_typed_scope
    # SHA-256("abc") is an independently specified published test vector.
    digest = 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad'
    reported = selector('artifact_sha256', 'algorithm' => 'sha256', 'representation' => 'bytes',
      'normalization' => 'exact_bytes_v1', 'scope' => 'whole_artifact', 'value' => digest)
    actual = reported.merge('content_base64' => 'YWJj')
    assert_equal 'match', S.compare(reported, actual)['status']
    assert_equal false, S.normalize(reported)['locally_reproduced']
    assert_equal true, S.normalize(actual)['locally_reproduced']
    assert_equal 'not_performed', S.compare(reported, actual)['verification']
    assert_equal 'no_match', S.compare(reported, material('authenticode_image_digest', 'value' => digest))['status']
    assert_equal 'unsupported', S.normalize(reported.merge('scope' => 'signed_content'))['status']
    assert_equal 'unresolved', S.normalize(actual.merge('value' => '0' * 64))['status']
    assert_raises(S::InvalidInput) { S.normalize(actual.merge('content_base64' => '%%%')) }
    assert_raises(S::InvalidInput) { S.normalize(reported.reject { |key, _| key == 'value' }) }
    assert_raises(S::InvalidInput) { S.normalize(reported.reject { |key, _| key == 'provenance' }) }
  end

  def test_image_digest_does_not_transfer_verification_or_require_signing
    signed = material.merge('verification' => 'verified')
    failed = material.merge('verification' => 'failed')
    missing = material
    assert_equal 'match', S.compare(signed, failed)['status']
    assert_equal 'match', S.compare(signed, missing)['status']
    assert_equal 'not_performed', S.compare(signed, failed)['verification']
  end

  def test_scheme_covered_content_is_not_artifact_or_signature_material
    image = material
    apk = material('scheme_content_digest', 'scheme' => 'apk_v2')
    assert_equal 'match', S.compare(apk, apk)['status']
    assert_equal 'no_match', S.compare(apk, image)['status']
    assert_equal 'unresolved', S.compare(apk, apk.merge('scheme' => 'apk_v3'))['status']
    assert_equal 'not_performed', S.compare(apk, apk)['verification']
    assert_equal false, S.normalize(apk)['locally_reproduced']
    assert_raises(S::InvalidInput) { S.normalize(apk.reject { |key, _| key == 'scheme' }) }
  end
  def test_empty_artifact_bytes_reproduce_the_known_empty_sha256_without_relaxing_certificates
    empty_sha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'
    reported = selector('artifact_sha256', 'algorithm' => 'sha256', 'representation' => 'bytes',
      'normalization' => 'exact_bytes_v1', 'scope' => 'whole_artifact', 'value' => empty_sha256)
    preserved = reported.merge('content_base64' => '')
    assert_equal 'match', S.compare(reported, preserved)['status']
    assert_equal true, S.normalize(preserved)['locally_reproduced']
    assert_equal empty_sha256, S.normalize(preserved.reject { |key, _| key == 'value' })['value']
    assert_equal 'unresolved', S.normalize(preserved.merge('value' => 'a' * 64))['status']
    assert_raises(S::InvalidInput) { S.normalize(preserved.merge('content_base64' => nil)) }
    cert = selector('certificate_sha256', 'algorithm' => 'sha256', 'representation' => 'der',
      'normalization' => 'exact_der_v1', 'scope' => 'whole_certificate', 'certificate_der_base64' => '')
    assert_raises(S::InvalidInput) { S.normalize(cert) }
    key = cert.merge('kind' => 'spki_sha256', 'scope' => 'subject_public_key_info', 'spki_der_base64' => '').reject { |k, _| k == 'certificate_der_base64' }
    assert_raises(S::InvalidInput) { S.normalize(key) }
  end

  def test_material_kinds_scopes_and_roles_do_not_collapse
    image = material
    signature = material('signature_material_digest', 'signature_role' => 'primary_signer')
    assert_equal 'no_match', S.compare(image, signature)['status']
    assert_equal 'unresolved', S.compare(image, material('authenticode_image_digest', 'scope' => 'different-covered-bytes'))['status']
    assert_equal 'unresolved', S.compare(signature, signature.merge('signature_role' => 'timestamp'))['status']
    assert_equal 'unsupported', S.compare(image.merge('algorithm' => 'vendor_unknown'), image)['status']
    assert_raises(S::InvalidInput) { S.normalize(image.merge('value' => 'abc')) }
    assert_raises(S::InvalidInput) { S.normalize(signature.reject { |name, _| name == 'signature_role' }) }
  end

  def fingerprint(kind = 'ja3')
    selector(kind, 'role' => kind == 'ja3' ? 'client' : 'server', 'algorithm' => 'md5', 'normalization' => 'hex_case_v1',
      'method_version' => 'source-ja3-extractor-v1', 'representation' => 'hex',
      'scope' => kind == 'ja3' ? 'client_hello' : 'server_hello', 'value' => 'b' * 32)
  end

  def test_ja3_and_ja3s_equal_hex_are_distinct_typed_observations
    assert_equal 'no_match', S.compare(fingerprint, fingerprint('ja3s'))['status']
    assert_equal 'match', S.compare(fingerprint, fingerprint.merge('value' => 'B' * 32))['status']
    assert_equal 'unresolved', S.compare(fingerprint, fingerprint.merge('method_version' => 'other-recipe'))['status']
    assert_raises(S::InvalidInput) { S.normalize(fingerprint.merge('role' => 'server')) }
    assert_raises(S::InvalidInput) { S.normalize(fingerprint('ja3s').merge('scope' => 'client_hello')) }
  end

  def test_provenance_is_mandatory_but_does_not_establish_source_truth
    item = fingerprint
    %w[source record_id source_revision field basis].each do |field|
      broken = item.merge('provenance' => provenance.reject { |name, _| name == field })
      assert_raises(S::InvalidInput, field) { S.normalize(broken) }
    end
    assert_raises(S::InvalidInput) { S.normalize(item.merge('provenance' => provenance.merge('basis' => 'derived'))) }
    derived = provenance.merge('basis' => 'derived', 'method' => 'fixture-extractor', 'method_version' => '1')
    assert_equal false, S.normalize(item.merge('provenance' => derived))['locally_reproduced']
    assert_equal 'unsupported', S.normalize(item.merge('kind' => 'unknown_vendor_hash'))['status']
    assert_raises(S::InvalidInput) { S.normalize(item.merge('provenance' => provenance.merge('field' => '   '))) }
    assert_raises(S::InvalidInput) { S.normalize(item.merge('provenance' => provenance.merge('source' => "\xff".b))) }
  end

  def test_opaque_uri_without_host_and_url_preservation
    urn = S.parse_uri('urn:example:artifact:42?version=2#part')
    assert_equal 'example:artifact:42', urn['path']
    assert_equal 'version=2', urn['query']
    assert_equal 'part', urn['fragment']
    refute urn.key?('authority')
    refute urn.key?('url')
    assert_equal 'text/plain;base64,aGVsbG8=', S.parse_uri('data:text/plain;base64,aGVsbG8=')['path']
    url = 'https://192.0.2.10/r?x=1#p'
    parsed = S.parse_uri(url)
    assert_equal url, parsed['url']
    assert_equal url, parsed['uri']
    assert_equal '192.0.2.10', parsed['authority']
    refute parsed.key?('domain')
    assert_equal 'file:/evidence/sample', S.parse_uri('file:/evidence/sample')['url']
    assert_equal '[2001:db8::1]:443', S.parse_uri('https://[2001:db8::1]:443/r')['authority']
    assert_equal '[fe80::1%25en0]', S.parse_uri('custom://[fe80::1%25en0]/r')['authority']
    assert_equal '[v1.example:service]', S.parse_uri('custom://[v1.example:service]/r')['authority']
    assert_equal '', S.parse_uri('custom:?')['query']
    assert_equal '', S.parse_uri('custom:#')['fragment']
  end

  def test_uri_comparison_preserves_literal_scope_and_rejects_malformed_inputs
    first = selector('uri', 'value' => 'https://example.test/a%2Fb#one', 'normalization' => 'literal_rfc3986_v1')
    assert_equal 'match', S.compare(first, first)['status']
    assert_equal 'no_match', S.compare(first, first.merge('value' => 'https://example.test/a/b#one'))['status']
    assert_equal 'no_match', S.compare(first, first.merge('value' => 'https://example.test/a%2Fb#two'))['status']
    ['example.test/path', 'custom:bad space', 'custom:bad%G0', "custom:bad\nline", 'custom:a#b#c',
     'https://host:not-a-port/path', 'https://[nonsense]/path', 'https://[2001:db8::1/path',
     'custom:unescaped[brackets]', 'custom://user@user@host/path'].each do |bad|
      assert_raises(S::InvalidInput, bad) { S.parse_uri(bad) }
    end
  end

  def test_dns_name_profile_normalizes_only_declared_case_and_root_dot
    name = selector('dns_name', 'value' => 'Alpha.Example.TEST.', 'representation' => 'ascii', 'normalization' => 'dns_ascii_lower_v1')
    assert_equal 'match', S.compare(name, name.merge('value' => 'alpha.example.test'))['status']
    assert_equal 'no_match', S.compare(name, name.merge('value' => 'beta.example.test'))['status']
    ['*.example.test', '192.0.2.10', '192.000.002.010', '2001:db8::1', 'éxample.test',
     'alpha..test', '-alpha.test', 'alpha-.test', 'alpha.example.test..', ('a' * 64) + '.test'].each do |bad|
      assert_raises(S::InvalidInput, bad) { S.normalize(name.merge('value' => bad)) }
    end
    assert_equal 'unsupported', S.normalize(name.merge('normalization' => 'unversioned-idna'))['status']
    assert_equal 'dns_name_only_no_resolution_or_endpoint_identity', S.normalize(name)['identity_claim']
  end

  def test_ipv4_profile_rejects_ambiguous_forms_without_resolving_dns
    ip = selector('ipv4', 'value' => '192.0.2.10', 'representation' => 'dotted_decimal', 'normalization' => 'strict_dotted_decimal_v1')
    assert_equal 'match', S.compare(ip, ip)['status']
    assert_equal 'no_match', S.compare(ip, ip.merge('value' => '192.0.2.11'))['status']
    ['192.000.2.10', '0xc000020a', '3221225994', '192.0.2', '256.0.2.10', '192.0.2.10/32', '192.0.2.10 '].each do |bad|
      assert_raises(S::InvalidInput, bad) { S.normalize(ip.merge('value' => bad)) }
    end
    name = selector('dns_name', 'value' => 'alpha.example.test', 'representation' => 'ascii', 'normalization' => 'dns_ascii_lower_v1')
    assert_equal 'no_match', S.compare(ip, name)['status']
    assert_equal 'ipv4_address_only_no_host_or_control_identity', S.normalize(ip)['identity_claim']
  end
end
