# frozen_string_literal: true

require_relative 'semantic_contract'
require_relative 'semantic_records'
require_relative 'semantic_time'
require_relative 'semantic_identity'
require_relative 'semantic_finding'
require_relative 'semantic_result_primitives'
require_relative 'semantic_package_repository'
require_relative 'semantic_certificate_profiles'
require_relative 'json_schema_validator'

module EveryPivot
  # Bounded joins over revision-specific normalized evidence records. This is an
  # evidence evaluator, not a source-truth, independence or assessment evaluator.
  class SemanticEvaluator
    MISSING = Object.new.freeze
    OPTIONAL_ABSENT = Object.new.freeze
    OPTIONAL_UNRESOLVED = Object.new.freeze
    class InvalidInput < StandardError; end
    class UnsupportedInput < StandardError; end

    def initialize(contract)
      @contract = SemanticContract.compile(contract)
    end

    def decision(status, reason, details = {})
      {'status' => status, 'reason' => reason}.merge(details)
    end

    def temporal_decision(value, outside_scope: false)
      result = value.merge('reason' => value['reason'] || Array(value['reasons']).join('; '))
      result['disposition'] = 'outside_scope' if outside_scope && value['status'] == 'no_match'
      result
    end

    def operand(spec, row, parameters)
      return spec['literal'] if spec.key?('literal')
      return parameters.fetch(spec['param'], MISSING) if spec.key?('param')
      return @collection_id || MISSING if spec['context'] == 'collection_id'
      if spec.key?('evidence_sources')
        record = row[spec['evidence_sources']]
        return MISSING unless record.is_a?(Hash)
        return record.fetch('evidence', []).map { |ref| ref['source_id'] }.uniq.sort
      end
      if spec.key?('calendar_period')
        window = spec['calendar_period']
        date = operand(window['query_date'], row, parameters)
        return MISSING if unknown?(date)
        return SemanticTime.resolve_calendar_period(query_date: date, window_days: window['days']['literal'])
      end
      if spec.key?('selector_identity')
        raw = operand({'ref' => spec['selector_identity']}, row, parameters)
        return MISSING if unknown?(raw)
        normalized = SemanticIdentity.normalize(raw)
        return MISSING unless normalized['status'] == 'ready'
        return normalized.select { |key, _| %w[kind comparison value].include?(key) }
      end
      spec['ref'].split('.').reduce(row) do |value, key|
        break MISSING unless value.is_a?(Hash) && value.key?(key)
        value[key]
      end
    end

    def unknown?(value)
      value.equal?(MISSING) || value.nil?
    end

    def scalar?(value)
      value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
    end

    def source_field?(parent, field)
      parent == field || (parent.is_a?(String) && field.is_a?(String) && parent.start_with?('/') && field.start_with?(parent + '/'))
    end

    def backed_value(spec, value, row, selector: false)
      return decision('match', 'literal or query operand; supplied selector only') unless spec.key?('ref')
      carrier = row[spec['ref'].split('.').first]
      return decision('unresolved', 'comparison carrier record is missing') unless carrier.is_a?(Hash)
      metadata = selector ? value['provenance'] : value
      return decision('unresolved', 'comparison value provenance is missing') unless metadata.is_a?(Hash)
      if selector && metadata['record_id'] != carrier['id']
        return decision('no_match', 'selector provenance identifies a different carrier record')
      end
      refs = carrier['evidence']
      refs = refs.select { |r| r['source_id'] == metadata['source'] } if selector
      return decision('unresolved', 'comparison value has no linked source evidence') if refs.empty?
      known = refs.select { |r| @sources.fetch(r['source_id'])['revision'].is_a?(String) }
      return decision('unresolved', 'comparison source revision is unknown') if known.empty? || unknown?(metadata['source_revision'])
      matched = known.select do |ref|
        @sources.fetch(ref['source_id'])['revision'] == metadata['source_revision'] && source_field?(ref['field'], metadata['field'])
      end
      origins = matched.map { |ref| ref['source_id'] }.uniq
      unknown_origins = refs.any? { |ref| @sources.fetch(ref['source_id'])['revision'].nil? && source_field?(ref['field'], metadata['field']) }
      if origins.size > 1 || unknown_origins
        return decision('unresolved', 'comparison origin is ambiguous across linked source revisions')
      end
      decision(origins.empty? ? 'no_match' : 'match', 'comparison value must use the bound source revision and field', 'source_ids' => origins)
    end

    def conjunction(values)
      %w[no_match unsupported unresolved].each do |status|
        found = values.find { |v| v['status'] == status }
        return found.merge('evaluations' => values) if found
      end
      decision('match', 'all declared predicates supported', 'evaluations' => values)
    end

    def expression(spec, row, parameters)
      op = spec['op']
      if op == 'binding_absent'
        value = row[spec['binding']]
        return decision('match', 'no applicable supported or uncertain candidate in the fully examined supplied optional-binding scope') if value.equal?(OPTIONAL_ABSENT) && !@partial
        return decision('no_match', 'an applicable supported optional-binding candidate is present') if value.is_a?(Hash)
        return decision('unresolved', 'optional-binding absence was not established within the supplied search scope')
      end
      return content_matches(spec, row, parameters) if op == 'content_matches'
      return uri_component_equal(spec, row, parameters) if op == 'uri_component_equal'
      if op == 'certificate_profile_matches'
        cert, profile = %w[certificate profile].map { |key| operand(spec[key], row, parameters) }
        return decision('unresolved', 'certificate/profile record is missing') if unknown?(cert) || unknown?(profile)
        return SemanticCertificateProfiles.profile_matches(certificate: cert, profile: profile, family: spec['family'], evidence: @evidence_index, preserved_source_bytes: @preserved_source_bytes)
      end
      if op == 'ct_name_in_scope'
        name, seed = %w[name seed].map { |key| operand(spec[key], row, parameters) }
        return decision('unresolved', 'certificate name or selected suffix scope is missing') if unknown?(name) || unknown?(seed)
        compared = SemanticCertificateProfiles.name_in_scope(name: name, seed: seed)
        return conjunction([backed_value(spec['name'], name, row, selector: true), backed_value(spec['seed'], seed, row, selector: true), compared])
      end
      if op == 'package_repository_declaration'
        values = %w[declaration package repository sidecar metadata].to_h { |key| [key.to_sym, operand(spec[key], row, parameters)] }
        return decision('unresolved', 'required declaration binding is missing') if values.values.any? { |value| unknown?(value) }
        return SemanticPackageRepository.evaluate(**values, pattern_id: @contract.dig('pattern', 'id'), evidence: @evidence_index, preserved_source_bytes: @preserved_source_bytes)
      end
      if op == 'package_repository_observation'
        id, period = %w[observation period].map { |key| operand(spec[key], row, parameters) }
        return decision('unresolved', 'observation identity or period is missing') if unknown?(id) || unknown?(period)
        key = [id, period]
        return @observation_comparisons[key] ||= SemanticPackageRepository.observation_window(observation: id, period: period, evidence: @evidence_index, consume: -> { budget?(:observation) })
      end
      if op == 'file_set_equal'
        left, right = %w[left right].map { |key| operand(spec[key], row, parameters) }
        return decision('unresolved', 'required file-set manifest binding is missing') if unknown?(left) || unknown?(right)
        return @file_set_comparisons[[left, right, spec['scope_kind']]] ||= SemanticResultPrimitives.file_set_equal(left: left, right: right, scope_kind: spec['scope_kind'], evidence: @evidence_index, preserved_source_bytes: @preserved_source_bytes)
      end
      if op == 'file_set_shared_paths'
        left, right, paths = %w[left right paths].map { |key| operand(spec[key], row, parameters) }
        return decision('unresolved', 'manifest or selected path scope is missing') if [left, right, paths].any? { |value| unknown?(value) }
        return SemanticResultPrimitives.file_set_shared_paths(left: left, right: right, paths: paths, evidence: @evidence_index, preserved_source_bytes: @preserved_source_bytes)
      end
      if op == 'ip_in_prefix'
        address, prefix = %w[address prefix].map { |key| operand(spec[key], row, parameters) }
        return decision('unresolved', 'required address or publisher prefix scope is missing') if unknown?(address) || unknown?(prefix)
        compared = SemanticResultPrimitives.ip_in_prefix(address: address, prefix: prefix, evidence: @evidence_index)
        return conjunction([backed_value(spec['address'], address, row, selector: true), compared])
      end
      if op == 'coexists'
        values = spec['values'].map { |value| operand(value, row, parameters) }
        period = operand(spec['period'], row, parameters)
        return decision('unresolved', 'common applicability operand is missing') if values.any? { |value| unknown?(value) } || unknown?(period)
        return temporal_decision(SemanticTime.coexists(values, period: period), outside_scope: true)
      end
      if %w[all any].include?(op)
        values = spec['args'].map { |v| expression(v, row, parameters) }
        return conjunction(values) if op == 'all'
        return decision('match', 'a declared alternative is supported') if values.any? { |v| v['status'] == 'match' }
        %w[unsupported unresolved].each do |state|
          return values.find { |v| v['status'] == state } if values.any? { |v| v['status'] == state }
        end
        return decision('no_match', 'every declared alternative is contradicted')
      end
      if op == 'not'
        value = expression(spec['arg'], row, parameters)
        return value unless %w[match no_match].include?(value['status'])
        return decision(value['status'] == 'match' ? 'no_match' : 'match', 'negation of an evaluated predicate')
      end
      if %w[present nonblank_text nonblank_text_array nonnegative_integer].include?(op)
        value = operand(spec['value'], row, parameters)
        return decision('unresolved', 'required value is absent or unknown') if unknown?(value)
        return decision(value.is_a?(String) && !value.strip.empty? ? 'match' : 'no_match', 'required nonblank text field') if op == 'nonblank_text'
        if op == 'nonblank_text_array'
          valid = value.is_a?(Array) && !value.empty? && value.all? { |item| item.is_a?(String) && !item.strip.empty? }
          return decision(valid ? 'match' : 'no_match', 'required nonempty array of nonblank text; duplicates confer no additional evidence')
        end
        return decision(JsonSchemaValidator.integer?(value) && value >= 0 ? 'match' : 'no_match', 'required nonnegative mathematical integer') if op == 'nonnegative_integer'
        return decision(value.respond_to?(:empty?) && value.empty? ? 'no_match' : 'match', 'explicit value presence')
      end
      if op == 'within'
        value, period = %w[value period].map { |k| operand(spec[k], row, parameters) }
        return decision('unresolved', 'temporal operand or selected period is missing') if unknown?(value) || unknown?(period)
        at = spec.key?('at') ? operand(spec['at'], row, parameters) : nil
        at = nil if at.equal?(MISSING)
        return temporal_decision(SemanticTime.within(value, period: period, quantifier: spec['quantifier'], at: at), outside_scope: true)
      end
      left, right = %w[left right].map { |k| operand(spec[k], row, parameters) }
      if op == 'time_compare_if_present' && left.equal?(MISSING)
        return decision('match', 'undated occurrence retained; no temporal order asserted')
      end
      return decision('unresolved', 'comparison operand is absent or unknown') if unknown?(left) || unknown?(right)
      case op
      when 'eq', 'ne'
        return decision('unsupported', 'structured values require an explicitly typed comparator') unless scalar?(left) && scalar?(right)
        equal = left == right
        decision((op == 'eq' ? equal : !equal) ? 'match' : 'no_match', 'explicit value comparison')
      when 'in'
        raise InvalidInput, 'in requires an array on the right' unless right.is_a?(Array)
        return decision('unsupported', 'set membership requires scalar values') unless scalar?(left) && right.all? { |v| scalar?(v) }
        decision(right.include?(left) ? 'match' : 'no_match', 'explicit set membership')
      when 'contains'
        raise InvalidInput, 'contains requires an array on the left' unless left.is_a?(Array)
        return decision('unsupported', 'set membership requires scalar values') unless scalar?(right) && left.all? { |v| scalar?(v) }
        decision(left.include?(right) ? 'match' : 'no_match', 'explicit set membership')
      when 'all_in'
        raise InvalidInput, 'all_in requires two scalar arrays' unless left.is_a?(Array) && right.is_a?(Array) && (left + right).all? { |v| scalar?(v) }
        return decision('unresolved', 'empty support set cannot establish scoped evidence') if left.empty?
        decision((left - right).empty? ? 'match' : 'no_match', 'every support source lies in the explicitly selected scope')
      when 'typed_equal'
        # Validate representation first, even if provenance later defeats it.
        compared = SemanticIdentity.compare(left, right)
        conjunction([backed_value(spec['left'], left, row, selector: true), backed_value(spec['right'], right, row, selector: true), compared])
      when 'time_compare', 'time_compare_if_present'
        temporal_decision(SemanticTime.compare(left, spec['operator'], right))
      else
        decision('unsupported', 'unimplemented predicate')
      end
    end

    def content_matches(spec, row, parameters)
      fields = %w[record source sha256 byte_length representation].map { |key| operand(spec[key], row, parameters) }
      return decision('unresolved', 'preserved content metadata is missing') if fields.any? { |value| unknown?(value) }
      id, source_id, expected_hash, length, representation = fields
      unless id.is_a?(String) && !id.strip.empty? && source_id.is_a?(String) && !source_id.strip.empty? && representation.is_a?(String) && !representation.strip.empty?
        raise InvalidInput, 'preserved content record/source identities and representation must be nonblank strings'
      end
      unless expected_hash.is_a?(String) && expected_hash.match?(/\A[0-9a-f]{64}\z/) && JsonSchemaValidator.integer?(length) && length >= 0
        raise InvalidInput, 'content hash must be lowercase SHA-256 and byte_length a nonnegative integer'
      end
      return decision('unsupported', 'content representation requires a separately declared reproduction recipe') unless representation == 'exact_source_bytes'
      record = row[spec['record']['ref'].split('.').first]
      source = @sources[source_id]
      return decision('unresolved', 'preserved content source is not linked to its artifact record') unless record && record['id'] == id && source && record['evidence'].any? { |ref| ref['source_id'] == source_id }
      hash = source['content_hash']
      return decision('unresolved', 'source needs exact_source_bytes SHA-256 identity') unless hash && hash['algorithm'] == 'sha256' && hash['scope'] == 'exact_source_bytes'
      bytes = @preserved_source_bytes[source_id]
      return decision('unresolved', 'exact preserved content bytes were not supplied') if bytes.nil?
      raise InvalidInput, 'preserved source content must be bytes' unless bytes.is_a?(String)
      actual_hash = Digest::SHA256.hexdigest(bytes)
      unless actual_hash == hash['value'] && actual_hash == expected_hash && bytes.bytesize == length
        raise InvalidInput, 'preserved content bytes contradict source or artifact identity'
      end
      decision('match', 'exact preserved bytes reproduce declared content identity; authenticity is not evaluated',
               'source_id' => source_id, 'sha256' => actual_hash, 'byte_length' => bytes.bytesize, 'representation' => representation)
    end

    def uri_component_equal(spec, row, parameters)
      uri, right = %w[uri right].map { |key| operand(spec[key], row, parameters) }
      return decision('unresolved', 'URI component comparison operand is missing') if unknown?(uri) || unknown?(right)
      normalized = SemanticIdentity.normalize(uri)
      return decision(normalized['status'], normalized['reason']) unless normalized['status'] == 'ready'
      return decision('no_match', 'URI operand has a different selector kind') unless normalized['kind'] == 'uri'
      backed = backed_value(spec['uri'], uri, row, selector: true)
      return backed unless backed['status'] == 'match'
      parts = normalized['reference']
      if %w[dns_host host_kind].include?(spec['component'])
        scheme = parts['scheme'].downcase
        if spec['component'] == 'host_kind' && !%w[dns ipv4 ipv6 ipvfuture none reg_name].include?(right)
          return decision('unsupported', 'host_kind requires an admitted string choice')
        end
        known_absent = %w[urn mailto data tel].include?(scheme) && !parts.key?('authority')
        if spec['component'] == 'host_kind' && known_absent
          return decision(right == 'none' ? 'match' : 'no_match', 'scheme has no network DNS-host mapping', 'host_kind' => 'none')
        end
        return decision('no_match', 'URI scheme has no DNS host in this mapping') if known_absent
        return decision('unsupported', 'URI scheme needs an explicit hostname mapping') unless %w[http https ftp ftps ws wss file].include?(scheme)
        authority = parts['authority'] && parts['authority'].split('@', -1).last
        if spec['component'] == 'host_kind'
          kind = if authority.nil? || authority.empty? then 'none'
                 elsif authority.start_with?('[') then authority.match?(/\A\[v[0-9a-f]+\./i) ? 'ipvfuture' : 'ipv6'
                 else
                   host = authority.split(':', -1).first
                   return decision('unsupported', 'percent-encoded reg-name requires an explicit host interpretation') if host.include?('%')
                   if host.match?(/\A[0-9]+(?:\.[0-9]+){3}\z/)
                     octets = host.split('.')
                     valid = octets.all? { |x| x.match?(/\A(?:0|[1-9][0-9]{0,2})\z/) && x.to_i <= 255 }
                     return decision('unsupported', 'ambiguous or malformed numeric authority is not a normalized IPv4 address') unless valid
                     'ipv4'
                   elsif host.empty? then 'none'
                   else
                     probe = {'kind' => 'dns_name', 'representation' => 'ascii', 'normalization' => 'dns_ascii_lower_v1', 'value' => host, 'provenance' => uri['provenance']}
                     begin
                       SemanticIdentity.normalize(probe)
                       'dns'
                     rescue SemanticIdentity::InvalidInput
                       'reg_name'
                     end
                   end
                 end
          return decision(kind == right ? 'match' : 'no_match', 'lexical authority classification only', 'host_kind' => kind)
        end
        return decision('no_match', 'URI has no network authority') unless authority
        return decision('no_match', 'IP literal is not a DNS hostname') if authority.start_with?('[')
        host = authority.split(':', -1).first
        return decision('no_match', 'empty or dotted-address authority is not a DNS hostname') if host.empty? || host.match?(/\A[0-9]+(?:\.[0-9]+){3}\z/)
        return decision('unsupported', 'percent-encoded reg-name needs an explicit DNS normalization mapping') if host.include?('%')
        dns = SemanticIdentity.normalize(right)
        return decision(dns['status'], dns['reason']) unless dns['status'] == 'ready'
        return decision('no_match', 'DNS host comparison requires dns_name selector') unless dns['kind'] == 'dns_name'
        backing = backed_value(spec['right'], right, row, selector: true)
        return backing unless backing['status'] == 'match'
        lexical = right.merge('value' => host)
        begin
          host_value = SemanticIdentity.normalize(lexical)
        rescue SemanticIdentity::InvalidInput
          return decision('no_match', 'valid URI reg-name is outside the concrete DNS hostname profile')
        end
        return decision(host_value['status'], host_value['reason']) unless host_value['status'] == 'ready'
        return decision(host_value['value'] == dns['value'] ? 'match' : 'no_match', 'lexical DNS host only; no resolution, service or ownership inference')
      end
      component = spec['component'] == 'scheme' ? parts['scheme'].downcase : parts['url']
      return decision('no_match', 'URI has no URL mapping in the declared capability') if component.nil?
      return decision('unsupported', 'URI component comparison requires an exact string') unless right.is_a?(String)
      decision(component == right ? 'match' : 'no_match', 'explicit URI component comparison; URL retains exact URI bytes')
    end

    def validate_query(query)
      errors = []
      unsupported = []
      errors.concat(SemanticContract.json_errors(query))
      raise InvalidInput, errors.join('; ') unless errors.empty?
      unless SemanticContract.closed(query, %w[parameters limits], %w[knowledge_cutoff], 'query', errors)
        raise InvalidInput, errors.join('; ')
      end
      params = query['parameters']
      unless params.is_a?(Hash)
        errors << 'query.parameters must be an object'
        params = {}
      end
      (params.keys - @contract['parameters'].keys).each { |k| errors << "unknown query parameter #{k}" }
      @contract['parameters'].each do |name, spec|
        if !params.key?(name)
          rule = spec['requires_when']
          conditional = rule && rule['values'].include?(params[rule['parameter']])
          errors << "required query parameter #{name} missing" if spec['required'] || conditional
          next
        end
        value = params[name]
        permitted = spec['allowed_when']
        if permitted && !permitted['values'].include?(params[permitted['parameter']])
          errors << "query parameter #{name} is inapplicable to the selected inquiry"
        end
        valid = case spec['type']
                when 'string', 'record_id', 'date' then value.is_a?(String) && !value.empty?
                when 'integer' then JsonSchemaValidator.integer?(value)
                when 'boolean' then [true, false].include?(value)
                when 'string_array' then value.is_a?(Array) && value.all? { |v| v.is_a?(String) }
                when 'selector', 'period', 'time' then value.is_a?(Hash)
                else false
                end
        errors << "query parameter #{name} has invalid type" unless valid
        next unless valid
        errors << "query parameter #{name} is outside the declared choices" if spec['enum'] && !spec['enum'].include?(value)
        if spec['type'] == 'string_array'
          errors << "query parameter #{name} contains too few items" if spec['min_items'] && value.size < spec['min_items']
          errors << "query parameter #{name} contains duplicate items" if spec['unique_items'] && value.uniq != value
        end
        case spec['type']
        when 'selector'
          check = SemanticIdentity.normalize(value)
          unsupported << check['reason'] if check['status'] == 'unsupported'
          if spec['selector_kinds'] && !spec['selector_kinds'].include?(value['kind'])
            unsupported << "query parameter #{name} selector kind is outside this contract's declared coverage"
          end
        when 'date'
          SemanticTime.resolve_calendar_period(query_date: value, window_days: 0)
        when 'period'
          SemanticTime.validate_period(value)
        when 'time'
          check = SemanticTime.normalize(value)
          unsupported << Array(check['reasons']).join('; ') if check['status'] == 'unsupported'
        end
      end
      limits = query['limits']
      if SemanticContract.closed(limits, %w[max_bindings max_results], [], 'query.limits', errors)
        %w[max_bindings max_results].each do |name|
          errors << "query.limits.#{name} must be a positive mathematical integer" unless JsonSchemaValidator.integer?(limits[name]) && limits[name].positive?
        end
      end
      errors << 'knowledge_cutoff must be a timestamp envelope' if query.key?('knowledge_cutoff') && !query['knowledge_cutoff'].is_a?(Hash)
      raise InvalidInput, errors.join('; ') unless errors.empty?
      if query.key?('knowledge_cutoff')
        check = SemanticTime.normalize(query['knowledge_cutoff'])
        unsupported << Array(check['reasons']).join('; ') if check['status'] == 'unsupported'
      end
      raise UnsupportedInput, unsupported.join('; ') unless unsupported.empty?
      params
    end

    def trace(row)
      row.each_with_object({}) { |(name, record), h| h[name] = record['id'] if record.is_a?(Hash) }
    end

    def diagnostic(branch, row, status, reason, extra = {})
      @diagnostics << {'branch' => branch['id'], 'bindings' => trace(row), 'status' => status, 'reason' => reason}.merge(extra)
    end

    def budget?(work = :binding)
      if @examined >= @limits['max_bindings']
        @partial = true
        return false
      end
      @examined += 1
      @examined_bindings += 1 if work == :binding
      true
    end

    def source_supported?(record)
      !record['evidence'].empty? && record['evidence'].all? do |ref|
        source = @sources.fetch(ref['source_id'])
        %w[document revision collection].all? { |key| source[key].is_a?(String) && !source[key].empty? }
      end
    end

    def prioritize(branch, binding, candidates, row, parameters)
      return candidates unless binding['priority']
      prepared = []
      candidates.each do |record|
        break unless budget?(:priority)
        next_row = row.merge(binding['name'] => record)
        spec = binding['priority']
        value = operand(spec['time'], next_row, parameters)
        period = operand(spec['period'], next_row, parameters)
        support = binding['where'] ? expression(binding['where'], next_row, parameters) : decision('match', 'typed occurrence')
        backing = time_bindings(branch, next_row, parameters, nil, only_refs: [spec['time']['ref']])
        eligibility = if source_supported?(record) && support['status'] == 'match' && backing['status'] == 'match' && !unknown?(value) && !unknown?(period)
                        temporal_decision(SemanticTime.within(value, period: period, quantifier: 'contained'))
                      else
                        decision('unresolved', 'priority occurrence, source, role or time binding is unresolved')
                      end
        group = {'match' => 'recent', 'no_match' => 'outside_focus'}.fetch(eligibility['status'], 'undated_or_unresolved')
        detail = {'binding' => binding['name'], 'record' => record['id'], 'group' => group, 'period' => unknown?(period) ? nil : period,
                  'evaluation' => eligibility, 'scope' => 'visit priority within supplied evidence; never an activity or finding-eligibility gate'}
        @priority_records[[branch['id'], binding['name'], record['id']]] = detail
        prepared << record
      end
      prepared.sort_by { |r| [priority_rank(@priority_records[[branch['id'], binding['name'], r['id']]]['group']), r['id']] }
    end

    def priority_rank(group)
      {'recent' => 0, 'outside_focus' => 1, 'undated_or_unresolved' => 2}.fetch(group, 2)
    end

    def join(branch, index, row, parameters, &block)
      return if @partial
      return yield(row) if index == branch['bindings'].length
      binding = branch['bindings'][index]
      candidates = @records.select { |r| r['kind'] == binding['kind'] && binding['types'].include?(r['type']) }
      candidates = prioritize(branch, binding, candidates, row, parameters)
      joined = false
      uncertain = false
      candidates.each do |record|
        return unless budget?
        next_row = row.merge(binding['name'] => record)
        result = binding.key?('where') ? expression(binding['where'], next_row, parameters) : decision('match', 'typed record binding')
        if result['status'] == 'match'
          if binding['optional'] && !source_supported?(record)
            uncertain = true
            diagnostic(branch, next_row, 'unresolved', 'optional context lacks source evidence; independent base claim retained', 'scope' => 'optional_context')
            next
          end
          joined = true
          join(branch, index + 1, next_row, parameters, &block)
        elsif %w[unresolved unsupported].include?(result['status'])
          uncertain = true
          diagnostic(branch, next_row, result['status'], result['reason'], binding['optional'] ? {'scope' => 'optional_context'} : {})
        end
      end
      if binding['optional'] && !joined
        absent = uncertain ? OPTIONAL_UNRESOLVED : OPTIONAL_ABSENT
        join(branch, index + 1, row.merge(binding['name'] => absent), parameters, &block)
      elsif !joined
        diagnostic(branch, row, uncertain || candidates.empty? ? 'unresolved' : 'no_match', "no supported binding for #{binding['name']}")
      end
    end

    def knowledge(branch, row, parameters, cutoff)
      return decision('match', 'retrospective inquiry; no as-known cutoff requested') unless cutoff
      return decision('unsupported', 'branch has no complete knowledge binding') unless branch['knowledge']
      timestamps = branch['knowledge'].map do |ref|
        value = operand(ref, row, parameters)
        unknown?(value) ? decision('unresolved', 'knowledge availability missing') : temporal_decision(SemanticTime.compare(value, 'lte', cutoff))
      end
      conjunction(timestamps + branch.fetch('knowledge_checks', []).map { |check| expression(check, row, parameters) })
    end

    def time_bindings(branch, row, parameters, cutoff, only_refs: nil)
      qualification = branch.reject { |key, _| %w[knowledge knowledge_checks time_bindings policies].include?(key) }
      qualification['bindings'] = branch['bindings'].map { |binding| binding.reject { |key, _| key == 'priority' } }
      active_refs = only_refs || SemanticContract.time_refs(qualification)
      active_refs += SemanticContract.time_refs(branch['knowledge']) if cutoff && !only_refs
      active_refs += SemanticContract.time_refs(branch['knowledge_checks']) if cutoff && !only_refs
      conjunction(branch.fetch('time_bindings', []).map do |binding|
        next decision('match', 'unselected historical knowledge operand') unless active_refs.include?(binding.dig('value', 'ref'))
        envelope = operand(binding['value'], row, parameters)
        # Missing unused knowledge is retained for retrospective inquiries; an
        # actual time predicate/cutoff will classify the missing value itself.
        next decision('match', 'absent time carries no substituted binding') if unknown?(envelope)
        unless envelope.is_a?(Hash)
          raise InvalidInput, 'bound time value must be an envelope'
        end
        alternatives = envelope.key?('alternatives') ? envelope['alternatives'] : [envelope]
        conjunction(alternatives.map do |time|
          if binding['value']['ref'].end_with?('.times.collection_available')
            availability = @evidence_index['records'][time.dig('binding', 'occurrence')]
            unless availability && availability['kind'] == 'occurrence' && availability['type'] == 'evidence:availability' && availability.dig('attributes', 'collection_id') == @collection_id && source_supported?(availability)
              next decision('unresolved', 'collection availability requires a source-backed availability occurrence in this input collection')
            end
          end
          decisions = %w[object occurrence].map do |role|
            expected = operand(binding[role], row, parameters)
            actual = time.dig('binding', role)
            if unknown?(expected) || unknown?(actual)
              decision('unresolved', "time #{role} binding is missing")
            else
              decision(expected == actual ? 'match' : 'no_match', "time #{role} binds the declared role")
            end
          end
          conjunction(decisions + [backed_value(binding['value'], time, row)])
        end)
      end)
    end

    def project(branch, row, parameters)
      spec = branch['result']
      keys = spec['identity'].map { |x| operand(x, row, parameters) }
      if keys.any? { |v| !complete_identity?(v) }
        diagnostic(branch, row, 'unresolved', 'emitted identity lacks a required component')
        return
      end
      bound = row[spec['binding']] if spec['mode'] == 'bound'
      if spec['mode'] == 'bound' && (!bound.is_a?(Hash) || bound['type'] != spec['form'])
        diagnostic(branch, row, 'unresolved', 'bound result does not have the declared output type')
        return
      end
      fields = spec['fields'].each_with_object({}) do |(name, ref), out|
        value = operand(ref, row, parameters)
        out[name] = value.equal?(MISSING) ? nil : value
      end
      records = row.values.select { |v| v.is_a?(Hash) }
      unproven = records.reject do |r|
        seed = branch['bindings'].any? { |binding| binding['query_seed'] && row[binding['name']] && row[binding['name']]['id'] == r['id'] }
        source_supported?(r) || seed
      end
      unless unproven.empty?
        diagnostic(branch, row, 'unresolved', 'required supporting records lack source evidence', 'records' => unproven.map { |r| r['id'] })
        return
      end
      evidence = records.flat_map { |r| r['evidence'] }.uniq
      if evidence.empty?
        diagnostic(branch, row, 'unresolved', 'query-selected identities alone supply no supporting evidence')
        return
      end
      priority = branch['bindings'].select { |b| b['priority'] }.map do |b|
        record = row[b['name']]
        record.is_a?(Hash) ? @priority_records[[branch['id'], b['name'], record['id']]] : {'binding' => b['name'], 'group' => 'undated_or_unresolved', 'reason' => 'no supported priority occurrence; result retained'}
      end.compact
      projected = {'id' => spec['mode'] == 'bound' ? bound['id'] : 'ep:evidence:' + SemanticContract.digest([@contract['pattern'], branch['id'], spec['form'], keys]),
       'form' => spec['form'], 'identity' => keys, 'mode' => spec['mode'], 'fields' => fields,
       'evidence_mode' => 'evidence_only', 'assessment_acceptance' => 'not_evaluated',
       'branch' => branch['id'], 'bindings' => trace(row), 'evidence' => evidence,
       'sources' => evidence.map { |e| @sources.fetch(e['source_id']) }.uniq}
      projected['search_priority'] = priority unless priority.empty?
      if branch.dig('finding', 'reference_support')
        projected['reference_support'] = branch['finding']['reference_support'].map { |name| {'binding' => name, 'record_id' => row.fetch(name).fetch('id')} }
      end
      projected
    end

    def complete_identity?(value)
      return false if unknown?(value)
      case value
      when Hash then !value.empty? && value.values.all? { |v| complete_identity?(v) }
      when Array then !value.empty? && value.all? { |v| complete_identity?(v) }
      when String then !value.empty?
      else true
      end
    end

    def policy_decisions(branch, row, parameters)
      branch.fetch('policies', []).map do |policy|
        enabled = policy.key?('enabled_parameter') ? parameters.fetch(policy['enabled_parameter'], policy['default_enabled']) : policy['default_enabled']
        next unless enabled
        subject = operand(policy['subject'], row, parameters)
        temporal = time_bindings(branch, row, parameters, nil, only_refs: SemanticContract.time_refs(policy))
        applies = policy['applies_when'] ? conjunction([temporal, expression(policy['applies_when'], row, parameters)]) : decision('match', 'policy applies to its declared subject')
        if applies['status'] == 'no_match'
          next {'id' => policy['id'], 'revision' => policy['revision'], 'scope' => policy['scope'], 'reason' => policy['reason'],
                'key' => SemanticContract.digest([policy['id'], policy['revision'], 'not_applicable', trace(row)]),
                'required_evaluation' => !!policy['required_evaluation'], 'applicability' => applies,
                'decision' => decision('no_match', 'policy is explicitly not applicable'),
                'allow_evaluation' => decision('match', 'non-applicability is not a clearance claim'), 'conflict_evaluation' => decision('no_match', 'policy not applicable')}
        end
        evaluated = unknown?(subject) ? decision('unresolved', 'filter subject unresolved') : conjunction([temporal, expression(policy['when'], row, parameters)])
        conflict = policy.key?('conflict_when') ? conjunction([temporal, expression(policy['conflict_when'], row, parameters)]) : decision('no_match', 'no contradictory predicate declared')
        allowed = policy['allow_when'] ? conjunction([temporal, expression(policy['allow_when'], row, parameters)]) : decision('unresolved', 'no positive nonexclusion predicate declared')
        evaluated = applies if applies['status'] != 'match'
        allowed = applies if applies['status'] != 'match'
        required_names = branch['bindings'].reject { |binding| binding['optional'] }.map { |binding| binding['name'] }
        path_identity = trace(row).select { |name, _| required_names.include?(name) }
        scope_identity = policy['scope'] == 'path' ? path_identity : subject
        scope_key = SemanticContract.digest([policy['id'], policy['revision'], policy['scope'], unknown?(scope_identity) ? nil : scope_identity])
        if policy.key?('partition_by')
          parts = policy['partition_by'].map { |part| operand(part, row, parameters) }
          if parts.all? { |part| complete_identity?(part) }
            scope_identity = [scope_identity, parts]
          else
            evaluated = allowed = conflict = decision('unresolved', 'policy partition identity is unknown; classification scopes cannot be merged')
            scope_identity = [scope_identity, nil]
          end
        end
        {'key' => SemanticContract.digest([policy['id'], policy['revision'], policy['scope'], unknown?(scope_identity) ? nil : scope_identity]), 'scope_key' => scope_key,
         'id' => policy['id'], 'revision' => policy['revision'], 'scope' => policy['scope'], 'reason' => policy['reason'],
         'required_evaluation' => !!policy['required_evaluation'], 'applicability' => applies,
         'decision' => evaluated, 'conflict_evaluation' => conflict, 'allow_evaluation' => allowed}
      end.compact
    end

    def evaluate(evidence, query, preserved_source_bytes: {})
      parameters = validate_query(query)
      index = SemanticRecords.index(evidence)
      @evidence_index = index
      @file_set_comparisons = {}
      @observation_comparisons = {}
      @contract['parameters'].each do |name, spec|
        next unless spec['item_reference'] && parameters.key?(name)
        identities = index.fetch(spec['item_reference'] == 'source' ? 'sources' : 'records')
        missing = parameters[name].reject { |id| identities.key?(id) }
        raise InvalidInput, "query parameter #{name} references absent #{spec['item_reference']} identities: #{missing.join(', ')}" unless missing.empty?
      end
      @collection_id = evidence['collection_id']
      @records = index['records'].values.sort_by { |r| r['id'] }
      @sources = index['sources']
      raise InvalidInput, 'preserved_source_bytes must map source IDs to byte strings' unless preserved_source_bytes.is_a?(Hash) && preserved_source_bytes.all? { |id, bytes| id.is_a?(String) && bytes.is_a?(String) }
      raise InvalidInput, 'preserved bytes name a source absent from this evidence input' unless (preserved_source_bytes.keys - @sources.keys).empty?
      @preserved_source_bytes = preserved_source_bytes
      @limits = query['limits'].transform_values(&:to_i)
      @examined = 0
      @examined_bindings = 0
      @partial = false
      @diagnostics = []
      @priority_records = {}
      candidates = []
      finding_candidates = []
      @contract['branches'].each do |branch|
        selection = branch['select_when']
        next if selection && !selection['values'].include?(parameters[selection['parameter']])
        join(branch, 0, {}, parameters) do |row|
          # Establish equivalence from every qualified historical path first.
          # A later replay's receipt must not remove an earlier establishment
          # from the history check merely because this is an as-known query.
          cutoff = branch['finding'] ? nil : query['knowledge_cutoff']
          result = conjunction([time_bindings(branch, row, parameters, cutoff), expression(branch['where'], row, parameters), knowledge(branch, row, parameters, cutoff)])
          if result['status'] != 'match'
            diagnostic(branch, row, result.fetch('disposition', result['status']), result['reason'])
            next
          end
          projected = project(branch, row, parameters)
          if projected
            projected['predicate_evaluation'] = result
            unless branch['finding']
              projected = attach_amendments(branch, row, projected, evidence, parameters, query['knowledge_cutoff'])
              next unless projected
            end
            if branch['finding']
              finding_candidates << [branch, row, projected]
            else
              candidates << [projected, policy_decisions(branch, row, parameters)]
            end
          end
        end
      end
      establish_findings(finding_candidates, evidence, query, parameters, preserved_source_bytes).each do |branch, row, projected|
        projected = attach_amendments(branch, row, projected, evidence, parameters, query['knowledge_cutoff'])
        candidates << [projected, policy_decisions(branch, row, parameters)] if projected
      end
      policy_groups = candidates.flat_map { |_, p| p }.group_by { |p| p['key'] }
      contested = policy_groups.select do |_, evaluations|
        evaluations.any? { |p| p.dig('conflict_evaluation', 'status') == 'match' } ||
          (evaluations.any? { |p| p.dig('decision', 'status') == 'match' } && evaluations.any? { |p| p.dig('allow_evaluation', 'status') == 'match' })
      end.keys
      incomplete_policy_groups = @partial ? policy_groups.keys : []
      suppressions = policy_groups.select do |key, evaluations|
        !contested.include?(key) && !incomplete_policy_groups.include?(key) && evaluations.any? { |p| p.dig('decision', 'status') == 'match' }
      end.values.flatten.select { |p| p.dig('decision', 'status') == 'match' }.group_by { |p| p.fetch('scope_key', p['key']) }
      results = []
      candidates.each do |result, policies|
        suppressed = policies.flat_map { |p| suppressions.fetch(p.fetch('scope_key', p['key']), []) }.uniq
        unless suppressed.empty?
          @diagnostics << {'branch' => result['branch'], 'bindings' => result['bindings'], 'status' => 'suppressed', 'reason' => 'explicit scoped exclusion', 'policies' => suppressed, 'projected_result' => result}
          next
        end
        result['policy_evaluations'] = policies
        policies.each do |policy|
          if contested.include?(policy['key'])
            policy['decision'] = decision('unresolved', 'conflicting supported policy assertions retained; no winner selected', 'assertions' => policy_groups[policy['key']].map { |p| p['conflict_evaluation'] })
          elsif incomplete_policy_groups.include?(policy['key'])
            policy['decision'] = decision('unresolved', 'partial search cannot exclude a scoped subject before checking conflicting support', 'observed_evaluation' => policy['decision'])
            policy['coverage'] = 'partial; additional policy evidence may remain unexamined'
          end
        end
        incomplete_controls = policies.select do |policy|
          next false unless policy['required_evaluation']
          policy.dig('decision', 'status') != 'no_match' || policy.dig('allow_evaluation', 'status') != 'match'
        end
        unless incomplete_controls.empty?
          unsupported = incomplete_controls.any? { |policy| [policy.dig('decision', 'status'), policy.dig('allow_evaluation', 'status')].include?('unsupported') }
          @diagnostics << {'branch' => result['branch'], 'bindings' => result['bindings'], 'status' => unsupported ? 'unsupported' : 'unresolved',
            'reason' => 'required control evaluation is unresolved; ordinary output withheld, evidence candidate retained',
            'policies' => incomplete_controls, 'projected_result' => result}
          next
        end
        results << result
      end
      # Deduplicate exact witness records only. Shared target IDs do not merge
      # different provenance, conflicting assertions or source revisions.
      results = results.uniq.sort_by { |r| [r.fetch('search_priority', []).map { |p| priority_rank(p['group']) }.min || 2, r['branch'], r['id'], SemanticContract.digest(r['bindings'])] }
      search_complete = !@partial
      qualified_count = results.length
      output_truncated = results.length > @limits['max_results']
      if results.length > @limits['max_results']
        @partial = true
        results = results.first(@limits['max_results'])
      end
      states = @diagnostics.map { |d| d['status'] }.uniq
      states += results.flat_map { |r| r['policy_evaluations'].map { |p| p.dig('decision', 'status') } }
      required_states = @diagnostics.reject { |d| d['scope'] == 'optional_context' }.map { |d| d['status'] }.uniq
      outcome = if !results.empty?
                  (states & %w[unresolved unsupported]).empty? ? 'qualified_evidence' : 'qualified_evidence_with_gaps'
                elsif required_states.include?('unsupported') then 'unsupported'
                elsif required_states.include?('unresolved') then 'unresolved'
                elsif required_states.include?('suppressed') then 'suppressed'
                elsif required_states.include?('outside_scope') then 'outside_scope'
                else 'no_qualifying_result'
                end
      {'contract' => 'everypivot.semantic_results', 'version' => '1.0', 'pattern' => @contract['pattern'],
       'contract_sha256' => SemanticContract.digest(@contract), 'input_sha256' => SemanticContract.digest(evidence),
       'query_sha256' => SemanticContract.digest(query), 'status' => @partial ? 'partial' : 'complete', 'outcome' => outcome,
       'supplied_content' => preserved_source_bytes.keys.sort.map { |id| {'source_id' => id, 'algorithm' => 'sha256', 'scope' => 'exact_source_bytes', 'value' => Digest::SHA256.hexdigest(preserved_source_bytes[id]), 'byte_length' => preserved_source_bytes[id].bytesize} },
       'results' => results, 'diagnostics' => @diagnostics.uniq,
       'coverage' => {'examined_bindings' => @examined_bindings, 'consumed_work_units' => @examined, 'limits' => @limits, 'exhaustive_for_supplied_input' => !@partial,
                      'search_complete_for_supplied_input' => search_complete,
                      'result_selection' => {'qualified_witnesses_before_limit' => qualified_count, 'returned' => results.length, 'truncated' => output_truncated},
                      'external_completeness' => 'not_evaluated', 'independence' => 'not_evaluated', 'assessment_acceptance' => 'not_evaluated'}}
    end

    def attach_amendments(branch, row, projected, evidence, parameters, cutoff)
      amendments = evaluate_amendments(branch, row, evidence, parameters, cutoff)
      return projected unless amendments
      projected['amendment_evaluation'] = amendments
      if amendments['status'] != 'match'
        diagnostic(branch, row, amendments['status'], amendments['reason'], 'amendment_evaluation' => amendments, 'projected_result' => projected)
        return nil
      end
      spec = branch['amendments']
      if spec['exclusion_parameter']
        enabled = parameters.fetch(spec['exclusion_parameter'], false)
        subject_ids = spec['exclusion_support'].map { |name| row.fetch(name).fetch('id') }
        states = amendments['states'].select { |state| subject_ids.include?(state['assertion_id']) }.map { |state| state['state'] }
        filtered = if !enabled then 'not_selected'
                   elsif (states & %w[unresolved_amendment_context contested]).any? then 'unresolved'
                   elsif (states & spec['excluded_states']).any? then 'suppressed'
                   else 'retained_in_supplied_scope'
                   end
        projected['amendment_filter'] = {'parameter' => spec['exclusion_parameter'], 'enabled' => enabled, 'subject_ids' => subject_ids, 'excluded_states' => spec['excluded_states'], 'disposition' => filtered}
        if %w[suppressed unresolved].include?(filtered)
          diagnostic(branch, row, filtered, 'explicit selected amendment-state filter; original candidate and amendment evidence retained', 'projected_result' => projected)
          return nil
        end
      end
      if amendments['has_gaps']
        diagnostic(branch, row, 'unresolved', 'historical report retained with unresolved amendment context', 'scope' => 'optional_context', 'amendment_evaluation' => amendments)
      end
      projected
    end

    def evaluate_amendments(branch, row, evidence, parameters, cutoff)
      spec = branch['amendments']
      return nil unless spec
      begin
        require_relative 'semantic_amendments'
      rescue LoadError
        raise UnsupportedInput, 'the declared amendment-history evaluator is not packaged'
      end
      SemanticAmendments.evaluate(evidence: evidence,
        assertion_ids: spec['support'].map { |name| row.fetch(name).fetch('id') }.uniq,
        source_ids: operand(spec['sources'], row, parameters), mode: spec['mode'], knowledge_cutoff: cutoff,
        consume: -> { budget?(:amendment) })
    end

    def establish_findings(rows, evidence, query, parameters, preserved_source_bytes)
      grouped = {}
      rows.each do |branch, row, projected|
        finding = branch['finding']
        identity = finding['identity'].map { |v| operand(v, row, parameters) }
        history_id = operand(finding['history'], row, parameters)
        if identity.any? { |v| !complete_identity?(v) } || unknown?(history_id)
          diagnostic(branch, row, 'unresolved', 'finding semantic identity or scoped history is unavailable')
          next
        end
        qualification = {'id' => finding['id'], 'revision' => finding['revision'], 'contract_sha256' => SemanticContract.digest(@contract)}
        claim_key = SemanticContract.digest({'qualification' => finding.values_at('id', 'revision'), 'identity' => identity})
        key = [finding['id'], finding['revision'], claim_key, history_id]
        grouped[key] ||= {'qualification' => qualification, 'claim_key' => claim_key, 'history_id' => history_id, 'rows' => []}
        grouped[key]['rows'] << [branch, row, projected]
      end
      qualified = []
      grouped.each_value do |group|
        branch = group['rows'][0][0]
        if @partial
          group['rows'].each { |b, row, _| diagnostic(b, row, 'unresolved', 'partial qualification search cannot establish earliest equivalent finding') }
          next
        end
        supports = group['rows'].map { |b, row, _| b['finding']['support'].map { |name| row.fetch(name).fetch('id') }.uniq }.uniq
        finding_result = SemanticFinding.evaluate(evidence: evidence, claim_key: group['claim_key'], qualified_support_sets: supports,
                                                 qualification: group['qualification'], history_id: group['history_id'], preserved_source_bytes: preserved_source_bytes)
        group['rows'].each do |b, row, projected|
          unless finding_result['status'] == 'match'
            diagnostic(b, row, finding_result['status'], finding_result['reason'], 'finding_evaluation' => finding_result)
            next
          end
          period = operand(b['finding']['period'], row, parameters)
          if unknown?(period)
            diagnostic(b, row, 'unresolved', 'finding period is missing')
            next
          end
          scoped = temporal_decision(SemanticTime.within(finding_result['first_scoped_time'], period: period, quantifier: 'contained'), outside_scope: true)
          if query['knowledge_cutoff']
            scoped = conjunction([scoped, time_bindings(b, row, parameters, query['knowledge_cutoff']),
                                  knowledge(b, row, parameters, query['knowledge_cutoff']),
                                  temporal_decision(SemanticTime.compare(finding_result['first_scoped_time'], 'lte', query['knowledge_cutoff']))])
          end
          unless scoped['status'] == 'match'
            diagnostic(b, row, scoped.fetch('disposition', scoped['status']), scoped['reason'], 'finding_evaluation' => finding_result)
            next
          end
          projected['finding_evaluation'] = finding_result
          qualified << [b, row, projected]
        end
      end
      qualified
    end
  end
end
