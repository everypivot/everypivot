# frozen_string_literal: true
require 'date'
require 'base64'
require 'openssl'
require_relative 'semantic_result_primitives'

module EveryPivot
  # Closed profile recipes over actual source-qualified certificate fields.
  # This evaluates criteria, not trust, issuance method, ownership or assessment.
  module SemanticCertificateProfiles
    class InvalidInput < StandardError; end
    P = SemanticResultPrimitives
    ID = 'everypivot.certificate_profile'.freeze
    TEXT_FIELDS = %w[subject.common_name subject.organization subject.organizational_unit subject.country issuer.common_name issuer.organization].freeze
    DER_FIELDS = %w[subject.distinguished_name_der issuer.distinguished_name_der].freeze
    IDENTITY_FIELDS = {'issuer.certificate_sha256' => 'certificate_sha256', 'issuer.spki_sha256' => 'spki_sha256'}.freeze
    DURATION = 'declared_validity.duration_seconds'.freeze
    module_function

    def result(status, reason, extra = {})
      P.result(status, reason, extra)
    end

    def field(record, name, index)
      fields = record['attributes']['profile_fields']
      return [nil, result('unresolved', 'certificate_profile_fields_unknown', 'field' => name)] if fields.nil?
      P.object!(fields, 'certificate profile fields')
      value = fields[name]
      return [nil, result('unresolved', 'required_certificate_field_unknown', 'field' => name)] if value.nil?
      P.object!(value, 'certificate field', %w[value representation provenance])
      P.text!(value['representation'], 'field representation') unless value['representation'].nil?
      P.provenance_shape!(value['provenance'])
      return [nil, result('unresolved', 'required_certificate_field_unknown', 'field' => name)] if value['value'].nil? || value['representation'].nil?
      backing = P.backed(record, value['provenance'], index)
      [value, backing['status'] == 'match' ? nil : backing]
    end

    def der_name(value)
      P.text!(value, 'DER distinguished-name base64')
      der = Base64.strict_decode64(value)
      parsed = OpenSSL::X509::Name.new(der)
      raise InvalidInput, 'distinguished name must be one exact DER object' unless parsed.to_der == der
      der
    rescue ArgumentError, OpenSSL::OpenSSLError
      raise InvalidInput, 'invalid DER distinguished-name encoding'
    end

    def validity_instant(value)
      P.text!(value, 'declared validity endpoint')
      raise InvalidInput, 'declared validity requires exact UTC second representation' unless /\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z\z/.match?(value)
      parsed = DateTime.iso8601(value)
      raise InvalidInput, 'invalid declared validity second' unless parsed.strftime('%Y-%m-%dT%H:%M:%SZ') == value
      parsed
    rescue ArgumentError
      raise InvalidInput, 'invalid declared validity endpoint'
    end

    def duration(record, index)
      parts = %w[declared_validity.not_before declared_validity.not_after].map { |name| field(record, name, index) }
      errors = parts.map(&:last).compact
      return [nil, errors.first] unless errors.empty?
      return [nil, result('unsupported', 'unsupported_validity_endpoint_representation')] unless parts.all? { |pair| pair.first['representation'] == 'x509_utc_second' }
      before, after = parts.map { |pair| validity_instant(pair.first['value']) }
      return [nil, result('unresolved', 'declared_validity_end_precedes_start')] if after < before
      [((after - before) * 86_400).to_i, nil]
    end

    def criterion_shape!(criterion)
      P.object!(criterion, 'profile criterion', %w[field comparison value min max])
      %w[field comparison].each { |key| P.text!(criterion[key], "criterion.#{key}") }
      if criterion['comparison'] == 'inclusive_seconds_range_v1'
        raise InvalidInput, 'duration range cannot also contain a value' if criterion.key?('value')
        P.integer!(criterion['min'], 'criterion.min')
        P.integer!(criterion['max'], 'criterion.max')
        raise InvalidInput, 'duration range minimum exceeds maximum' if criterion['min'] > criterion['max']
      else
        raise InvalidInput, 'exact criteria cannot contain range bounds' if criterion.key?('min') || criterion.key?('max')
        raise InvalidInput, 'exact criterion value is required' unless criterion.key?('value') && !criterion['value'].nil?
      end
    end

    def compare_criterion(record, criterion, index)
      name, recipe = criterion.values_at('field', 'comparison')
      if name == DURATION
        return result('unsupported', 'unsupported_duration_comparison') unless recipe == 'inclusive_seconds_range_v1'
        value, error = duration(record, index)
        return error if error
        matched = value >= criterion['min'] && value <= criterion['max']
        return result(matched ? 'match' : 'no_match', 'declared_validity_duration_comparison', 'field' => name, 'actual_seconds' => value,
                      'minimum_seconds' => criterion['min'], 'maximum_seconds' => criterion['max'])
      end
      return result('unsupported', 'unsupported_certificate_profile_field', 'field' => name) unless (TEXT_FIELDS + DER_FIELDS + IDENTITY_FIELDS.keys).include?(name)
      envelope, error = field(record, name, index)
      return error if error
      actual, expected = envelope['value'], criterion['value']
      if TEXT_FIELDS.include?(name)
        P.text!(actual, 'certificate text value'); P.text!(expected, 'criterion text value')
        return result('unsupported', 'unsupported_text_comparison_recipe') unless recipe == 'literal_utf8_v1' && envelope['representation'] == 'utf8_string'
        matched = actual == expected
      elsif DER_FIELDS.include?(name)
        return result('unsupported', 'unsupported_name_comparison_recipe') unless recipe == 'exact_der_v1' && envelope['representation'] == 'der_base64'
        matched = der_name(actual) == der_name(expected)
      else
        return result('unsupported', 'unsupported_issuer_identity_recipe') unless recipe == 'typed_identity_v1' && envelope['representation'] == 'typed_selector'
        a, b = SemanticIdentity.normalize(actual), SemanticIdentity.normalize(expected)
        return result('unsupported', 'issuer_identity_kind_does_not_match_selected_field') unless a['kind'] == IDENTITY_FIELDS[name] && b['kind'] == IDENTITY_FIELDS[name]
        backing = P.backed(record, actual['provenance'], index)
        return backing unless backing['status'] == 'match'
        return SemanticIdentity.compare(actual, expected).merge('field' => name)
      end
      result(matched ? 'match' : 'no_match', 'explicit_certificate_field_comparison', 'field' => name,
             'comparison' => recipe, 'actual_value' => actual, 'expected_value' => expected,
             'field_evidence' => 'source_qualified_reported_value_not_locally_reparsed_certificate')
    end

    # profile is an entity x509:comparison_profile with a preserved content
    # descriptor (SemanticResultPrimitives), never a reported matched=true flag.
    # JSON: {contract,version,id,revision,family,combination:'all',criteria:[...]}
    # Definition identity/revision are distinct from source revision and schema.
    def profile_matches(certificate:, profile:, family:, evidence:, preserved_source_bytes:)
      raise InvalidInput, 'unsupported profile family' unless %w[subject issuer_validity short_lived].include?(family)
      index = P.indexed(evidence)
      P.object!(preserved_source_bytes, 'preserved source bytes')
      return result('unresolved', 'profile_or_certificate_unknown') if certificate.nil? || profile.nil?
      record, error = P.record!(index, certificate, 'x509:cert', 'entity')
      return error if error
      selector = record['attributes']['certificate_selector']
      return result('unresolved', 'whole_certificate_identity_unknown') if selector.nil?
      material = SemanticIdentity.normalize(selector)
      return result(material['status'], material['reason']) unless material['status'] == 'ready'
      return result('no_match', 'profile_fields_require_whole_certificate_identity') unless material['kind'] == 'certificate_sha256'
      backed = P.backed(record, selector['provenance'], index)
      return backed unless backed['status'] == 'match'
      definition_record, error = P.record!(index, profile, 'x509:comparison_profile', 'entity')
      return error if error
      bytes, error = P.content(definition_record, index, preserved_source_bytes, 1_048_576)
      return error if error
      definition = P.json_document!(bytes, 'certificate profile definition')
      P.object!(definition, 'profile definition', %w[contract version id revision family combination criteria])
      %w[contract version id revision family combination].each { |key| P.text!(definition[key], "profile.#{key}") }
      criteria = definition['criteria']
      raise InvalidInput, 'profile criteria must be a nonempty array' unless criteria.is_a?(Array) && !criteria.empty?
      return result('unsupported', 'profile_criterion_budget_exceeded') if criteria.size > 32
      criteria.each { |criterion| criterion_shape!(criterion) }
      return result('unsupported', 'unsupported_profile_definition_recipe') unless definition.values_at('contract', 'version', 'combination') == [ID, '1.0', 'all']
      return result('no_match', 'profile_has_different_selected_family') unless definition['family'] == family
      names = criteria.map { |criterion| criterion['field'] }
      raise InvalidInput, 'each profile field may appear only once' unless names.uniq == names
      required = case family
                 when 'subject' then names.any? { |name| name.start_with?('subject.') }
                 when 'issuer_validity' then names.include?(DURATION) && names.any? { |name| name.start_with?('issuer.') }
                 when 'short_lived' then names.include?(DURATION)
                 end
      raise InvalidInput, 'profile lacks criteria required for its family' unless required
      checks = criteria.map { |criterion| compare_criterion(record, criterion, index) }
      status = %w[no_match unsupported unresolved].find { |state| checks.any? { |check| check['status'] == state } } || 'match'
      result(status, 'all_explicit_profile_criteria', 'profile_id' => definition['id'], 'profile_revision' => definition['revision'],
             'profile_sha256' => Digest::SHA256.hexdigest(bytes), 'family' => family, 'evaluations' => checks,
             'claim' => 'explicit_selected_characteristics_only_no_implicit_other_identity_or_issuance_method')
    rescue P::InvalidInput, SemanticIdentity::InvalidInput => error
      raise InvalidInput, error.message
    end

    # One literal wildcard in the leftmost label is a separate contextual clue.
    # This operator never expands it into names, DNS answers or presentations.
    def name_in_scope(name:, seed:)
      return result('unresolved', 'CT_name_or_seed_unknown') if name.nil? || seed.nil?
      P.object!(name, 'CT name', %w[kind value representation normalization provenance])
      %w[kind value representation normalization].each { |key| P.text!(name[key], "name.#{key}") }
      SemanticIdentity.provenance!(name['provenance'])
      source = SemanticIdentity.normalize(seed)
      return result(source['status'], source['reason']) unless source['status'] == 'ready'
      return result('unsupported', 'CT_scope_seed_requires_concrete_dns_name') unless source['kind'] == 'dns_name'
      return result('unsupported', 'unsupported_CT_name_recipe') unless name.values_at('representation', 'normalization') == ['ascii', 'dns_ascii_lower_v1']
      return result('unsupported', 'unsupported_CT_name_kind') unless %w[dns_name dns_wildcard].include?(name['kind'])
      wildcard = name['kind'] == 'dns_wildcard'
      if wildcard
        raise InvalidInput, 'wildcard must have exactly one complete leftmost star label' unless name['value'].start_with?('*.') && name['value'].count('*') == 1
        host = name['value'][2..-1]
      else
        host = name['value']
      end
      normalized = SemanticIdentity.normalize(name.merge('kind' => 'dns_name', 'value' => host))
      return result(normalized['status'], normalized['reason']) unless normalized['status'] == 'ready'
      host = normalized['value']; root = source['value']
      contained = host == root || host.end_with?('.' + root)
      result(contained ? 'match' : 'no_match', 'literal_DNS_label_scope', 'kind' => name['kind'],
             'normalized_name' => wildcard ? '*.' + host : host, 'seed' => root,
             'claim' => wildcard ? 'wildcard_scope_clue_not_concrete_name_enumeration' : 'explicit_CT_name_only_not_DNS_or_service_presence')
    rescue P::InvalidInput, SemanticIdentity::InvalidInput => error
      raise InvalidInput, error.message
    end
  end
end
