# frozen_string_literal: true

require 'base64'
require 'digest'
require 'ipaddr'
require 'openssl'

module EveryPivot
  # Typed comparisons of supported evidence values, not signature verification,
  # entity resolution, source authentication, or an assessment acceptance engine.
  module SemanticIdentity
    class InvalidInput < StandardError; end

    KINDS = %w[certificate_sha256 spki_sha256 issuer_serial artifact_sha256 scheme_content_digest authenticode_image_digest signature_material_digest ja3 ja3s dns_name ipv4 uri].freeze
    DIGEST_LENGTHS = {'sha1' => 40, 'sha256' => 64, 'sha384' => 96, 'sha512' => 128, 'md5' => 32}.freeze
    module_function

    def compare(left, right)
      a = normalize(left)
      b = normalize(right)
      [a, b].each do |item|
        return result(item['status'], item['reason']) unless item['status'] == 'ready'
      end
      return result('no_match', 'different_selector_kinds') unless a['kind'] == b['kind']
      return result('unresolved', 'incomparable_declared_comparison_scopes') unless a['comparison'] == b['comparison']
      result(a['value'] == b['value'] ? 'match' : 'no_match', a['value'] == b['value'] ? 'equal_typed_values' : 'different_typed_values').merge(
        'kind' => a['kind'], 'comparison' => a['comparison'],
        'left_locally_reproduced' => a['locally_reproduced'], 'right_locally_reproduced' => b['locally_reproduced'],
        'left_provenance' => a['provenance'], 'right_provenance' => b['provenance'],
        'identity_claim' => a['identity_claim'] || 'typed_value_comparison_only',
        'verification' => 'not_performed', 'assessment_mode' => 'evidence_only'
      )
    end

    # Provenance fields identify the supplied assertion. Their presence does not
    # authenticate its source. Local reproduction is set only by this method.
    def normalize(record)
      object!(record, 'selector')
      kind = string!(record, 'kind')
      provenance!(record['provenance'])
      return result('unsupported', 'unsupported_selector_kind') unless KINDS.include?(kind)
      base = {'status' => 'ready', 'kind' => kind, 'provenance' => record['provenance'].dup,
              'locally_reproduced' => false}
      case kind
      when 'certificate_sha256', 'spki_sha256'
        normalize_certificate(record, base)
      when 'issuer_serial'
        normalize_issuer_serial(record, base)
      when 'artifact_sha256'
        normalize_artifact(record, base)
      when 'scheme_content_digest', 'authenticode_image_digest', 'signature_material_digest'
        normalize_material_digest(record, base)
      when 'ja3', 'ja3s'
        normalize_fingerprint(record, base)
      when 'dns_name'
        normalize_dns_name(record, base)
      when 'ipv4'
        normalize_ipv4(record, base)
      when 'uri'
        return result('unsupported', 'unsupported_uri_normalization') unless string!(record, 'normalization') == 'literal_rfc3986_v1'
        uri = parse_uri(string!(record, 'value'))
        base.merge('comparison' => ['literal_rfc3986_v1'], 'value' => uri['uri'], 'reference' => uri)
      end
    end

    # Exact whole-artifact bytes are distinct from a format's signed-content
    # digest and from certificate or signature material. Reported values remain
    # reported unless this call actually hashes the supplied bytes.
    def normalize_artifact(record, base)
      %w[algorithm representation normalization scope].each { |name| string!(record, name) }
      unless record.values_at('algorithm', 'representation', 'normalization', 'scope') == ['sha256', 'bytes', 'exact_bytes_v1', 'whole_artifact']
        return result('unsupported', 'unsupported_artifact_comparison_recipe')
      end
      supplied = record.key?('value') ? digest_value!(record['value'], 'sha256') : nil
      # Empty Base64 is the exact representation of a valid zero-byte artifact.
      # Certificate/SPKI decoding keeps its separate nonempty-material rule.
      bytes = if record.key?('content_base64')
                record['content_base64'] == '' ? ''.b : decode_base64!(record['content_base64'], 'content_base64')
              end
      raise InvalidInput, 'a whole-artifact digest or exact artifact bytes are required' unless supplied || bytes
      computed = bytes && Digest::SHA256.hexdigest(bytes)
      if supplied && computed && supplied != computed
        return result('unresolved', 'reported_digest_conflicts_with_preserved_material').merge('reported_value' => supplied, 'reproduced_value' => computed)
      end
      base.merge('comparison' => record.values_at('algorithm', 'representation', 'normalization', 'scope'),
                 'value' => computed || supplied, 'locally_reproduced' => !computed.nil?,
                 'identity_claim' => 'whole_artifact_bytes_only_no_signature_verification')
    end

    def provenance!(value)
      object!(value, 'provenance')
      %w[source record_id source_revision field basis].each { |name| string!(value, name) }
      raise InvalidInput, 'provenance basis must be reported or derived' unless %w[reported derived].include?(value['basis'])
      if value['basis'] == 'derived'
        %w[method method_version].each { |name| string!(value, name) }
      end
    end

    def normalize_certificate(record, base)
      %w[algorithm representation normalization scope].each { |name| string!(record, name) }
      expected_scope = record['kind'] == 'certificate_sha256' ? 'whole_certificate' : 'subject_public_key_info'
      unless record.values_at('algorithm', 'representation', 'normalization', 'scope') == ['sha256', 'der', 'exact_der_v1', expected_scope]
        return result('unsupported', 'unsupported_certificate_comparison_recipe')
      end
      supplied = record.key?('value') ? digest_value!(record['value'], 'sha256') : nil
      cert_inputs = %w[certificate_pem certificate_der_base64].select { |key| record.key?(key) }
      raise InvalidInput, 'supply one certificate representation' if cert_inputs.length > 1
      if record.key?('spki_der_base64') && (!cert_inputs.empty? || record['kind'] != 'spki_sha256')
        raise InvalidInput, 'standalone SPKI requires spki_sha256 and no certificate input'
      end
      bytes = nil
      unless cert_inputs.empty?
        der = certificate_der(record, cert_inputs.first)
        bytes = record['kind'] == 'certificate_sha256' ? der : certificate_spki(der)
      end
      if record.key?('spki_der_base64')
        bytes = decode_base64!(record['spki_der_base64'], 'spki_der_base64')
        validate_spki!(bytes)
      end
      raise InvalidInput, 'a digest value or corresponding material is required' unless supplied || bytes
      computed = bytes && Digest::SHA256.hexdigest(bytes)
      if supplied && computed && supplied != computed
        return result('unresolved', 'reported_digest_conflicts_with_preserved_material').merge('reported_value' => supplied, 'reproduced_value' => computed)
      end
      base.merge('comparison' => record.values_at('algorithm', 'representation', 'normalization', 'scope'),
                 'value' => computed || supplied, 'locally_reproduced' => !computed.nil?)
    end

    def certificate_der(record, key)
      value = string!(record, key)
      if key == 'certificate_pem'
        match = /\A\s*-----BEGIN CERTIFICATE-----\s*([A-Za-z0-9+\/=\r\n\t ]+)\s*-----END CERTIFICATE-----\s*\z/.match(value)
        raise InvalidInput, 'expected exactly one PEM certificate' unless match
        der = decode_base64!(match[1].gsub(/\s/, ''), key)
      else
        der = decode_base64!(value, key)
      end
      begin
        certificate = OpenSSL::X509::Certificate.new(der)
        raise InvalidInput, 'certificate input must be one exact DER object' unless certificate.to_der == der
      rescue OpenSSL::OpenSSLError, ArgumentError => error
        raise InvalidInput, "invalid certificate: #{error.class}"
      end
      der
    end

    # Preserve the SPKI algorithm identifier and parameters from the certificate.
    # key.to_der can be a bare PKCS#1 key and is not an SPKI representation.
    def certificate_spki(der)
      decoded = OpenSSL::ASN1.decode(der)
      tbs = decoded.value[0].value
      offset = tbs[0].tag_class == :CONTEXT_SPECIFIC ? 1 : 0
      spki = tbs[offset + 5].to_der
      validate_spki!(spki)
      spki
    end

    def validate_spki!(bytes)
      begin
        decoded = OpenSSL::ASN1.decode(bytes)
        valid = decoded.is_a?(OpenSSL::ASN1::Sequence) && decoded.value.length == 2 &&
          decoded.value[0].is_a?(OpenSSL::ASN1::Sequence) &&
          decoded.value[0].value[0].is_a?(OpenSSL::ASN1::ObjectId) &&
          decoded.value[1].is_a?(OpenSSL::ASN1::BitString) && decoded.to_der == bytes
        raise InvalidInput, 'expected exact DER SubjectPublicKeyInfo, including algorithm identifier' unless valid
      rescue OpenSSL::OpenSSLError, ArgumentError, NoMethodError => error
        raise InvalidInput, "invalid SPKI: #{error.class}"
      end
    end

    def normalize_issuer_serial(record, base)
      namespace = record['issuer_namespace']
      object!(namespace, 'issuer_namespace')
      %w[kind value matching_rule].each { |name| string!(namespace, name) }
      unless %w[reported_name authority_id certificate_sha256 spki_sha256].include?(namespace['kind']) && namespace['matching_rule'] == 'exact_v1'
        return result('unsupported', 'unsupported_issuer_namespace_rule')
      end
      issuer = namespace['value']
      issuer = digest_value!(issuer, 'sha256') if %w[certificate_sha256 spki_sha256].include?(namespace['kind'])
      serial = string!(record, 'serial')
      radix = record['serial_radix']
      raise InvalidInput, 'serial_radix must explicitly be 10 or 16' unless [10, 16].include?(radix)
      syntax = radix == 10 ? /\A[0-9]+\z/ : /\A[0-9a-fA-F]+\z/
      raise InvalidInput, 'serial does not conform to declared radix' unless serial.ascii_only? && syntax.match?(serial)
      base.merge('comparison' => [namespace['kind'], namespace['matching_rule']], 'value' => [issuer, serial.to_i(radix.to_i)],
                 'identity_claim' => 'issuer_serial_link_only')
    end

    def normalize_material_digest(record, base)
      %w[algorithm representation normalization scope method_version].each { |name| string!(record, name) }
      algorithm = record['algorithm']
      return result('unsupported', 'unsupported_digest_algorithm') unless %w[sha1 sha256 sha384 sha512].include?(algorithm)
      # These are declared source/method recipes, not a request to compute or
      # verify Authenticode. Unknown vendor labels must never become this kind.
      comparison = record.values_at('algorithm', 'representation', 'normalization', 'scope', 'method_version')
      comparison << string!(record, 'scheme') if record['kind'] == 'scheme_content_digest'
      if record['kind'] == 'signature_material_digest'
        comparison << string!(record, 'signature_role')
        return result('unsupported', 'unsupported_signature_role') unless %w[primary_signer timestamp chain_member other].include?(record['signature_role'])
      end
      base.merge('comparison' => comparison, 'value' => digest_value!(record['value'], algorithm))
    end

    def normalize_fingerprint(record, base)
      %w[role algorithm normalization method_version representation scope].each { |name| string!(record, name) }
      role = record['kind'] == 'ja3' ? 'client' : 'server'
      raise InvalidInput, 'fingerprint kind conflicts with its message role' unless record['role'] == role
      unless record['algorithm'] == 'md5' && record['representation'] == 'hex' && record['normalization'] == 'hex_case_v1'
        return result('unsupported', 'unsupported_fingerprint_recipe')
      end
      expected_scope = record['kind'] == 'ja3' ? 'client_hello' : 'server_hello'
      raise InvalidInput, 'fingerprint kind conflicts with message scope' unless record['scope'] == expected_scope
      base.merge('comparison' => record.values_at('role', 'algorithm', 'normalization', 'method_version', 'representation', 'scope'),
                 'value' => digest_value!(record['value'], 'md5'))
    end

    # This finite profile compares ASCII hostname-style DNS labels. It does not
    # expand wildcards, resolve names, infer a suffix scope or perform IDNA. The
    # final root dot and ASCII case have explicit normalization here only.
    def normalize_dns_name(record, base)
      unless string!(record, 'representation') == 'ascii' && string!(record, 'normalization') == 'dns_ascii_lower_v1'
        return result('unsupported', 'unsupported_dns_name_recipe')
      end
      original = string!(record, 'value')
      raise InvalidInput, 'DNS name needs a pinned ASCII representation; Unicode/IDNA is not inferred' unless original.ascii_only?
      value = original.downcase.sub(/\.$/, '')
      labels = value.split('.', -1)
      valid = value.bytesize <= 253 && !labels.empty? && labels.all? do |label|
        label.bytesize.between?(1, 63) && /\A[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\z/.match?(label)
      end
      raise InvalidInput, 'invalid concrete DNS hostname labels or wildcard' unless valid
      raise InvalidInput, 'dotted address text is not a DNS name' if /\A[0-9]+(?:\.[0-9]+){3}\z/.match?(value)
      base.merge('comparison' => ['ascii', 'dns_ascii_lower_v1'], 'value' => value,
                 'identity_claim' => 'dns_name_only_no_resolution_or_endpoint_identity')
    end

    # Decimal octets only: no octal-looking leading zeros, integer addresses,
    # hexadecimal spellings, inferred CIDR or alternate address representations.
    def normalize_ipv4(record, base)
      unless string!(record, 'representation') == 'dotted_decimal' && string!(record, 'normalization') == 'strict_dotted_decimal_v1'
        return result('unsupported', 'unsupported_ipv4_recipe')
      end
      value = string!(record, 'value')
      valid = value.ascii_only? && /\A(?:0|[1-9][0-9]{0,2})(?:\.(?:0|[1-9][0-9]{0,2})){3}\z/.match?(value)
      valid &&= value.split('.').all? { |octet| octet.to_i <= 255 }
      raise InvalidInput, 'invalid or ambiguous dotted-decimal IPv4 address' unless valid
      base.merge('comparison' => ['dotted_decimal', 'strict_dotted_decimal_v1'], 'value' => value,
                 'identity_claim' => 'ipv4_address_only_no_host_or_control_identity')
    end

    # Generic RFC 3986 component parsing. Literal comparison deliberately makes
    # no DNS, percent-decoding, default-port, path or fragment equivalence claim.
    def parse_uri(value)
      raise InvalidInput, 'URI must be a nonempty string' unless value.is_a?(String) && !value.empty?
      raise InvalidInput, 'URI must contain ASCII URI characters without whitespace' unless value.ascii_only? && !/[\x00-\x20\x7f<>"{}|\\^`]/.match?(value)
      raise InvalidInput, 'invalid percent encoding' if /%(?![0-9a-fA-F]{2})/.match?(value)
      match = /\A([A-Za-z][A-Za-z0-9+.-]*):(?:(\/\/)([^\/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#([^#]*))?\z/.match(value)
      raise InvalidInput, 'invalid URI components' unless match
      scheme, slash, authority, path, query, fragment = match.captures
      raise InvalidInput, 'URI path must be absolute when authority is present' if slash && !path.empty? && !path.start_with?('/')
      raise InvalidInput, 'invalid URI path characters' unless /\A[A-Za-z0-9._~!$&'()*+,;=:@%\/\-]*\z/.match?(path)
      [query, fragment].compact.each do |component|
        raise InvalidInput, 'invalid URI query or fragment characters' unless /\A[A-Za-z0-9._~!$&'()*+,;=:@%\/?\-]*\z/.match?(component)
      end
      if slash
        raise InvalidInput, 'invalid URI authority characters' unless /\A[A-Za-z0-9._~!$&'()*+,;=:@%\[\]\-]*\z/.match?(authority)
        raise InvalidInput, 'multiple unescaped userinfo separators' if authority.count('@') > 1
        host_port = authority.split('@', -1).last.to_s
        if host_port.include?('[') || host_port.include?(']')
          literal = /\A\[([^\[\]]+)\](?::[0-9]*)?\z/.match(host_port)
          raise InvalidInput, 'invalid bracketed URI host' unless literal
          validate_ip_literal!(literal[1])
        elsif host_port.include?(':')
          raise InvalidInput, 'invalid URI port or unbracketed IP literal' unless /\A[^:]*:[0-9]*\z/.match?(host_port)
        end
      end
      result = {'uri' => value, 'scheme' => scheme, 'path' => path}
      result['authority'] = authority if slash
      result['query'] = query unless query.nil?
      result['fragment'] = fragment unless fragment.nil?
      # This is a conservative mapping capability, not a claim that other URI
      # schemes cannot locate resources. Keep their full URI reference intact.
      locator = %w[http https ftp ftps ws wss].include?(scheme.downcase) && slash && !authority.empty?
      locator ||= scheme.downcase == 'file' && path.start_with?('/')
      result['url'] = value if locator
      result
    end

    def validate_ip_literal!(literal)
      return if /\Av[0-9A-Fa-f]+\.[A-Za-z0-9._~!$&'()*+,;=:\-]+\z/i.match?(literal)
      address, zone = literal.split('%25', 2)
      if zone && (zone.empty? || !/\A(?:[A-Za-z0-9._~\-]|%[0-9A-Fa-f]{2})+\z/.match?(zone))
        raise InvalidInput, 'invalid encoded IPv6 zone identifier'
      end
      raise InvalidInput, 'URI IP literal must be IPv6 or IPvFuture' unless IPAddr.new(address).ipv6?
    rescue IPAddr::InvalidAddressError
      raise InvalidInput, 'invalid URI IP literal'
    end

    def digest_value!(value, algorithm)
      raise InvalidInput, 'digest value must be a hexadecimal string of the declared length' unless value.is_a?(String) && value.ascii_only? && /\A[0-9a-fA-F]+\z/.match?(value) && value.length == DIGEST_LENGTHS.fetch(algorithm)
      value.downcase
    end

    def decode_base64!(value, label)
      raise InvalidInput, "#{label} must be a nonempty base64 string" unless value.is_a?(String) && !value.empty?
      Base64.strict_decode64(value)
    rescue ArgumentError
      raise InvalidInput, "#{label} is not canonical base64"
    end

    def object!(value, label)
      raise InvalidInput, "#{label} must be an object" unless value.is_a?(Hash)
    end

    def string!(record, name)
      value = record[name]
      valid = value.is_a?(String) && value.dup.force_encoding(Encoding::UTF_8).valid_encoding?
      raise InvalidInput, "#{name} must be a nonblank UTF-8 string" unless valid && !value.strip.empty?
      value
    end

    def result(status, reason)
      {'status' => status, 'reason' => reason}
    end
  end
end
