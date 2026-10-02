#!/usr/bin/env ruby
# frozen_string_literal: true
require 'minitest/autorun'
require_relative 'semantic_certificate_profiles'

class SemanticCertificateProfilesTest < Minitest::Test
  P = EveryPivot::SemanticCertificateProfiles
  def setup
    @index = {'records' => {}, 'sources' => {}}
    @bytes = {}
    %w[cert profile].each do |id|
      @index['sources'][id] = {'id' => id, 'publisher' => 'synthetic', 'document' => id, 'revision' => 'r1', 'collection' => 'case', 'independent_origin' => nil}
      @index['records'][id] = {'id' => id, 'kind' => 'entity', 'type' => id == 'cert' ? 'x509:cert' : 'x509:comparison_profile',
        'attributes' => {}, 'times' => {}, 'evidence' => [{'source_id' => id, 'field' => '/fields'}]}
    end
    @fields = @index['records']['cert']['attributes']['profile_fields'] = {}
    @index['records']['cert']['attributes']['certificate_selector'] = {'kind' => 'certificate_sha256', 'algorithm' => 'sha256',
      'representation' => 'der', 'normalization' => 'exact_der_v1', 'scope' => 'whole_certificate', 'value' => 'a' * 64,
      'provenance' => provenance('cert', '/fields/certificate_sha256')}
    field('subject.organization', 'Example Organization')
    field('subject.common_name', 'one.example.test')
    field('issuer.organization', 'Example Issuer')
    field('declared_validity.not_before', '2026-09-01T00:00:00Z', 'x509_utc_second')
    field('declared_validity.not_after', '2026-09-07T00:00:00Z', 'x509_utc_second')
  end
  def provenance(id, path = '/fields/value')
    {'source' => id, 'record_id' => id, 'source_revision' => 'r1', 'field' => path, 'basis' => 'reported'}
  end
  def field(name, value, representation = 'utf8_string')
    @fields[name] = {'value' => value, 'representation' => representation, 'provenance' => provenance('cert', '/fields/' + name)}
  end
  def criterion(name, value)
    {'field' => name, 'comparison' => 'literal_utf8_v1', 'value' => value}
  end
  def duration(min = 0, max = 604800)
    {'field' => 'declared_validity.duration_seconds', 'comparison' => 'inclusive_seconds_range_v1', 'min' => min, 'max' => max}
  end
  def definition(family = 'subject', criteria = [criterion('subject.organization', 'Example Organization')])
    {'contract' => P::ID, 'version' => '1.0', 'id' => 'deliberate-fixture-definition', 'revision' => 'profile-r7',
     'family' => family, 'combination' => 'all', 'criteria' => criteria}
  end
  def run_profile(value = definition, family = value['family'])
    bytes = JSON.generate(value)
    sha = Digest::SHA256.hexdigest(bytes)
    @bytes['profile'] = bytes
    @index['sources']['profile']['content_hash'] = {'algorithm' => 'sha256', 'value' => sha, 'scope' => 'exact_source_bytes'}
    @index['records']['profile']['attributes']['content'] = {'source_id' => 'profile', 'source_revision' => 'r1', 'field' => '/fields', 'sha256' => sha,
      'byte_length' => bytes.bytesize, 'representation' => 'exact_source_bytes'}
    P.profile_matches(certificate: 'cert', profile: 'profile', family: family, evidence: @index, preserved_source_bytes: @bytes)
  end
  def dns_name(value, kind = 'dns_name')
    {'kind' => kind, 'value' => value, 'representation' => 'ascii', 'normalization' => 'dns_ascii_lower_v1', 'provenance' => provenance('query')}
  end
  def in_scope(value, kind = 'dns_name', seed = 'example.test')
    P.name_in_scope(name: dns_name(value, kind), seed: dns_name(seed))
  end
  def test_subject_profile_selects_only_its_actual_fields
    assert_equal 'match', run_profile['status']
    field('subject.common_name', 'entirely-different.test')
    assert_equal 'match', run_profile['status']
    field('subject.organization', 'example organization')
    assert_equal 'no_match', run_profile['status']
    @fields.delete('subject.organization')
    field('issuer.organization', 'Example Organization')
    assert_equal 'unresolved', run_profile['status']
  end
  def test_duration_has_explicit_inclusive_seconds_and_is_not_use_or_window
    d = definition('short_lived', [duration])
    result = run_profile(d)
    assert_equal 'match', result['status']
    assert_equal 518400, result['evaluations'][0]['actual_seconds']
    field('declared_validity.not_after', '2026-09-08T00:00:00Z', 'x509_utc_second')
    assert_equal 'match', run_profile(d)['status']
    field('declared_validity.not_after', '2026-09-08T00:00:01Z', 'x509_utc_second')
    assert_equal 'no_match', run_profile(d)['status']
    field('declared_validity.not_after', '2026-10-01T00:00:00Z', 'x509_utc_second')
    assert_equal 'no_match', run_profile(d)['status']
    assert_equal 'match', run_profile(definition('short_lived', [duration(0, 30 * 86400)]))['status']
  end
  def test_issuer_profile_requires_both_issuer_and_declared_duration
    d = definition('issuer_validity', [criterion('issuer.organization', 'Example Issuer'), duration])
    assert_equal 'match', run_profile(d)['status']
    field('issuer.organization', 'Different Issuer')
    assert_equal 'no_match', run_profile(d)['status']
    assert_raises(P::InvalidInput) { run_profile(definition('issuer_validity', [duration])) }
    assert_raises(P::InvalidInput) { run_profile(definition('short_lived', [criterion('subject.organization', 'Example Organization')])) }
  end
  def test_unknown_and_malformed_validity_are_not_short_lifetime
    d = definition('short_lived', [duration])
    @fields.delete('declared_validity.not_after')
    assert_equal 'unresolved', run_profile(d)['status']
    field('declared_validity.not_after', '2026-02-30T00:00:00Z', 'x509_utc_second')
    assert_raises(P::InvalidInput) { run_profile(d) }
    field('declared_validity.not_after', '2026-08-01T00:00:00Z', 'x509_utc_second')
    assert_equal 'unresolved', run_profile(d)['status']
    field('declared_validity.not_after', '2026-09-07', 'date_only')
    assert_equal 'unsupported', run_profile(d)['status']
  end
  def test_profile_revision_is_hashed_and_no_undeclared_fallback_occurs
    d = definition
    a = run_profile(d)
    d['revision'] = 'profile-r8'; d['criteria'][0]['value'] = 'Different'
    b = run_profile(d)
    assert_equal 'no_match', b['status']
    refute_equal a['profile_sha256'], b['profile_sha256']
    assert_equal 'profile-r7', a['profile_revision']
    d['criteria'][0]['comparison'] = 'fuzzy_contains'
    assert_equal 'unsupported', run_profile(d)['status']
    d['criteria'][0]['match'] = true
    assert_raises(P::InvalidInput) { run_profile(d) }
  end
  def test_exact_DER_subject_names_are_not_text_labels
    der = OpenSSL::X509::Name.parse('/O=Example/CN=one.example.test').to_der
    field('subject.distinguished_name_der', Base64.strict_encode64(der), 'der_base64')
    d = definition('subject', [{'field' => 'subject.distinguished_name_der', 'comparison' => 'exact_der_v1', 'value' => Base64.strict_encode64(der)}])
    assert_equal 'match', run_profile(d)['status']
    d['criteria'][0]['value'] = Base64.strict_encode64(OpenSSL::X509::Name.parse('/CN=one.example.test/O=Example').to_der)
    assert_equal 'no_match', run_profile(d)['status']
    d['criteria'][0]['value'] = 'not base64'
    assert_raises(P::InvalidInput) { run_profile(d) }
  end
  def test_source_field_revision_and_unknown_origins_are_preserved
    @fields['subject.organization']['provenance']['source_revision'] = 'r2'
    assert_equal 'no_match', run_profile['status']
    @fields['subject.organization']['provenance']['source_revision'] = 'r1'
    @fields['subject.organization']['provenance']['field'] = '/fields_alias/value'
    assert_equal 'no_match', run_profile['status']
    @fields['subject.organization']['provenance']['field'] = '/fields/subject.organization'
    @index['sources']['cert']['revision'] = nil
    assert_equal 'unresolved', run_profile['status']
  end
  def test_profile_content_cannot_be_replaced_by_reported_match_boolean
    run_profile
    assert_equal 'unresolved', P.profile_matches(certificate: 'cert', profile: 'profile', family: 'subject', evidence: @index, preserved_source_bytes: {})['status']
    @bytes['profile'] += ' '
    assert_raises(P::InvalidInput) { P.profile_matches(certificate: 'cert', profile: 'profile', family: 'subject', evidence: @index, preserved_source_bytes: @bytes) }
    assert_raises(P::InvalidInput) { run_profile(definition('subject', [criterion('subject.organization', false)])) }
    assert_raises(P::InvalidInput) { run_profile(definition('short_lived', [duration(0, false)])) }
  end
  def test_named_certificate_and_wildcard_clues_are_separate
    assert_equal 'match', in_scope('LOGIN.Example.TEST.')['status']
    assert_equal 'dns_name', in_scope('login.example.test')['kind']
    result = in_scope('*.example.test', 'dns_wildcard')
    assert_equal 'match', result['status']
    assert_equal 'dns_wildcard', result['kind']
    assert_equal '*.example.test', result['normalized_name']
    assert_match(/not_concrete_name/, result['claim'])
    assert_equal 'match', in_scope('*.a.example.test', 'dns_wildcard')['status']
    assert_equal 'match', in_scope('example.test')['status'] # Explicit apex field, not inferred from suffix seed.
    %w[notexample.test example.test.invalid unrelated.test].each { |v| assert_equal 'no_match', in_scope(v)['status'] }
  end
  def test_no_wildcard_repair_IP_names_or_guessed_children
    %w[*.example.test login.*.example.test 192.0.2.1].each { |value| assert_raises(P::InvalidInput) { in_scope(value) } }
    %w[foo.example.test *foo.example.test *.*.example.test].each { |value| assert_raises(P::InvalidInput) { in_scope(value, 'dns_wildcard') } }
    assert_equal 'unresolved', P.name_in_scope(name: nil, seed: dns_name('example.test'))['status']
    assert_equal 'no_match', in_scope('*.other.test', 'dns_wildcard')['status']
  end
  def test_reported_issuer_label_and_exact_issuer_certificate_or_key_are_distinct
    %w[certificate_sha256 spki_sha256].each do |kind|
      selector={'kind'=>kind,'algorithm'=>'sha256','representation'=>'der','normalization'=>'exact_der_v1',
        'scope'=>kind=='certificate_sha256' ? 'whole_certificate' : 'subject_public_key_info','value'=>'b'*64,
        'provenance'=>provenance('cert','/fields/issuer_identity')}
      field('issuer.'+kind,selector,'typed_selector')
      criterion={'field'=>'issuer.'+kind,'comparison'=>'typed_identity_v1','value'=>Marshal.load(Marshal.dump(selector))}
      d=definition('issuer_validity',[criterion,duration])
      assert_equal 'match',run_profile(d)['status']
      @fields['issuer.'+kind]['value']['value']='c'*64
      assert_equal 'no_match',run_profile(d)['status']
      @fields['issuer.'+kind]['value']['provenance']['record_id']='other-certificate'
      assert_equal 'no_match',run_profile(d)['status']
    end
    d=definition('issuer_validity',[criterion('issuer.organization','Example Issuer'),duration])
    assert_equal 'match',run_profile(d)['status'] # Name comparison makes no issuing-key claim.
  end
  def test_profile_definition_is_finite_and_bound_to_actual_certificate_identity
    d=definition
    d['criteria']*=33
    assert_equal 'unsupported',run_profile(d)['status']
    d=definition; d['criteria']*=2
    assert_raises(P::InvalidInput){run_profile(d)}
    @index['records']['cert']['attributes'].delete('certificate_selector')
    assert_equal 'unresolved',run_profile['status']
  end
end
