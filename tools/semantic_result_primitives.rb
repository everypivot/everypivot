# frozen_string_literal: true

require 'digest'
require 'json'
require_relative 'semantic_identity'
require_relative 'semantic_records'

module EveryPivot
  # Finite evidence comparisons. Source assertions are preserved, not
  # authenticated here. A match supplies neither deployment nor an assessment.
  module SemanticResultPrimitives
    class InvalidInput < StandardError; end
    class DuplicateKey < Hash
      def []=(key, value)
        raise InvalidInput, "duplicate JSON member #{key}" if key?(key)
        super
      end
    end
    LIMITS = {'max_manifest_bytes' => 1_048_576, 'max_coverage_bytes' => 1_048_576,
              'max_entries' => 10_000, 'max_total_entry_bytes' => 67_108_864}.freeze
    module_function

    def result(status, reason, details = {})
      {'status' => status, 'reason' => reason, 'assessment_mode' => 'evidence_only'}.merge(details)
    end

    def object!(value, label, keys = nil)
      raise InvalidInput, "#{label} must be an object" unless value.is_a?(Hash)
      raise InvalidInput, "#{label} keys must be strings" unless value.keys.all? { |key| key.is_a?(String) }
      if keys && !(value.keys - keys).empty?
        raise InvalidInput, "#{label} has unknown fields: #{(value.keys - keys).join(', ')}"
      end
      value
    end

    def text!(value, label)
      raise InvalidInput, "#{label} must be a nonblank UTF-8 string" unless value.is_a?(String) && value.dup.force_encoding(Encoding::UTF_8).valid_encoding? && !value.strip.empty?
      value
    end

    def integer!(value, label, positive = false)
      valid = value.is_a?(Numeric) && value.finite? && value == value.to_i && value >= (positive ? 1 : 0)
      raise InvalidInput, "#{label} must be a #{positive ? 'positive' : 'nonnegative'} mathematical integer" unless valid
      value.to_i
    end

    def digest!(value, label)
      raise InvalidInput, "#{label} must be a lowercase SHA-256 digest" unless value.is_a?(String) && /\A[0-9a-f]{64}\z/.match?(value)
      value
    end

    def indexed(evidence)
      object!(evidence, 'evidence')
      return SemanticRecords.index(evidence) if evidence['records'].is_a?(Array)
      object!(evidence['records'], 'indexed records')
      object!(evidence['sources'], 'indexed sources')
      evidence
    rescue SemanticRecords::InvalidInput => error
      raise InvalidInput, error.message
    end

    def record!(index, id, type, kind)
      text!(id, 'record ID')
      record = index['records'][id]
      raise InvalidInput, "unknown record ID #{id}" unless record.is_a?(Hash) && record['id'] == id
      return [record, result('no_match', 'record_kind_or_type_does_not_supply_required_witness')] unless record['kind'] == kind && record['type'] == type
      object!(record['attributes'], "#{id} attributes")
      [record, nil]
    end

    def field_covers?(parent, field)
      parent == field || (parent.is_a?(String) && field.is_a?(String) && parent.start_with?('/') && field.start_with?(parent + '/'))
    end

    def provenance_shape!(provenance)
      return if provenance.nil?
      object!(provenance, 'provenance', %w[source record_id source_revision field basis method method_version])
      %w[source record_id source_revision field basis method method_version].each do |key|
        text!(provenance[key], "provenance.#{key}") unless provenance[key].nil?
      end
      if provenance['basis'] && !%w[reported derived].include?(provenance['basis'])
        raise InvalidInput, 'provenance basis must be reported or derived'
      end
    end

    # A provenance pointer identifies a supplied source assertion. It does not
    # prove publisher authenticity, source independence or the assertion's truth.
    def backed(record, provenance, index)
      provenance_shape!(provenance)
      return result('unresolved', 'source_provenance_unknown') if provenance.nil?
      return result('unresolved', 'source_provenance_unknown') if %w[source record_id source_revision field basis].any? { |key| provenance[key].nil? }
      if provenance['basis'] == 'derived' && %w[method method_version].any? { |key| provenance[key].nil? }
        return result('unresolved', 'derivation_method_unknown')
      end
      return result('no_match', 'provenance_identifies_different_record') unless provenance['record_id'] == record['id']
      source = index['sources'][provenance['source']]
      raise InvalidInput, 'provenance references unknown source' unless source.is_a?(Hash)
      %w[publisher document revision collection].each { |key| text!(source[key], "source.#{key}") unless source[key].nil? }
      return result('unresolved', 'source_identity_or_revision_unknown') if %w[publisher document revision collection].any? { |key| source[key].nil? }
      return result('no_match', 'different_source_revision') unless source['revision'] == provenance['source_revision']
      refs = record['evidence']
      raise InvalidInput, 'record evidence must be an array' unless refs.is_a?(Array)
      refs.each { |ref| object!(ref, 'evidence reference', %w[source_id field]) }
      linked = refs.any? { |ref| ref['source_id'] == provenance['source'] && field_covers?(ref['field'], provenance['field']) }
      result(linked ? 'match' : 'no_match', linked ? 'linked_source_revision_and_field' : 'source_field_is_not_linked',
             'source_id' => provenance['source'], 'source_revision' => source['revision'])
    end

    def ipv4_number(value)
      text!(value, 'IPv4 address')
      valid = value.ascii_only? && /\A(?:0|[1-9][0-9]{0,2})(?:\.(?:0|[1-9][0-9]{0,2})){3}\z/.match?(value)
      valid &&= value.split('.').all? { |part| part.to_i <= 255 }
      raise InvalidInput, 'invalid or ambiguous dotted-decimal IPv4 address' unless valid
      value.split('.').inject(0) { |n, part| (n << 8) | part.to_i }
    end

    # prefix is an assertion record ID with type network:prefix_scope. Its
    # attributes contain prefix {value, representation, normalization, provenance}
    # and applicability {value, provenance}. Both must be the same source revision
    # and carrier; "all_addresses_in_prefix" is the publisher's asserted scope.
    def ip_in_prefix(address:, prefix:, evidence:)
      index = indexed(evidence)
      return result('unresolved', 'address_or_prefix_unknown') if address.nil? || prefix.nil?
      normalized = SemanticIdentity.normalize(address)
      record, error = record!(index, prefix, 'network:prefix_scope', 'assertion')
      return error if error
      attrs = record['attributes']
      network, applicability = attrs['prefix'], attrs['applicability']
      object!(network, 'prefix', %w[value representation normalization provenance]) unless network.nil?
      object!(applicability, 'applicability', %w[value provenance]) unless applicability.nil?
      [network, applicability].compact.each do |item|
        %w[value representation normalization].each { |key| text!(item[key], key) unless item[key].nil? }
        provenance_shape!(item['provenance'])
      end
      # Validate a supplied CIDR even when applicability has not been established.
      if network && network['value'] && network.values_at('representation', 'normalization') == ['ipv4_cidr', 'strict_network_cidr_v1']
        match = /\A(.+)\/(0|[1-9][0-9]?)\z/.match(network['value'])
        raise InvalidInput, 'IPv4 prefix must use canonical CIDR syntax' unless match && match[2].to_i <= 32
        start, bits = ipv4_number(match[1]), match[2].to_i
        mask = bits.zero? ? 0 : ((0xffffffff << (32 - bits)) & 0xffffffff)
        raise InvalidInput, 'IPv4 prefix contains host bits; silent masking is forbidden' unless (start & mask) == start
      end
      return result(normalized['status'], normalized['reason']) unless normalized['status'] == 'ready'
      return result('unsupported', 'address_selector_is_not_ipv4') unless normalized['kind'] == 'ipv4'
      return result('unresolved', 'publisher_prefix_or_applicability_unknown') if network.nil? || applicability.nil? || %w[value representation normalization].any? { |key| network[key].nil? } || applicability['value'].nil?
      return result('unsupported', 'unsupported_prefix_recipe') unless network.values_at('representation', 'normalization') == ['ipv4_cidr', 'strict_network_cidr_v1']
      witnesses = [backed(record, network['provenance'], index), backed(record, applicability['provenance'], index)]
      failure = witnesses.find { |v| v['status'] != 'match' }
      return failure.merge('witnesses' => witnesses) if failure
      if network['provenance'].values_at('source', 'source_revision') != applicability['provenance'].values_at('source', 'source_revision')
        return result('no_match', 'prefix_and_applicability_have_different_source_revisions')
      end
      case applicability['value']
      when 'listed_individual_addresses_only'
        return result('no_match', 'publisher_has_not_asserted_range_member_applicability')
      when 'all_addresses_in_prefix'
        # Supported explicit assertion scope; numerical containment now matters.
      else
        return result('unsupported', 'unsupported_publisher_applicability_scope')
      end
      contained = (ipv4_number(normalized['value']) & mask) == start
      result(contained ? 'match' : 'no_match', contained ? 'address_within_publisher_asserted_prefix' : 'address_outside_publisher_asserted_prefix',
             'address' => normalized['value'], 'prefix' => network['value'], 'scope_record_id' => record['id'],
             'witnesses' => witnesses, 'claim' => 'publisher_range_applicability_only_not_individual_sighting_or_risk')
    rescue SemanticIdentity::InvalidInput => error
      raise InvalidInput, error.message
    end

    def limits!(value)
      object!(value, 'limits', LIMITS.keys)
      LIMITS.merge(value).each_with_object({}) { |(key, amount), out| out[key] = integer!(amount, key, true) }
    end

    # Reproduce source bytes against the descriptor AND source content hash.
    # Missing bytes/metadata are unknown; a known integrity mismatch is invalid.
    def content(record, index, supplied, maximum)
      descriptor = record['attributes']['content']
      return [nil, result('unresolved', 'content_descriptor_unknown')] if descriptor.nil?
      object!(descriptor, 'content descriptor', %w[source_id source_revision field sha256 byte_length representation])
      %w[source_id source_revision field representation].each { |key| text!(descriptor[key], "content.#{key}") unless descriptor[key].nil? }
      digest!(descriptor['sha256'], 'content.sha256') unless descriptor['sha256'].nil?
      integer!(descriptor['byte_length'], 'content.byte_length') unless descriptor['byte_length'].nil?
      return [nil, result('unresolved', 'content_descriptor_unknown')] if %w[source_id source_revision field sha256 byte_length representation].any? { |key| descriptor[key].nil? }
      support = backed(record, {'source' => descriptor['source_id'], 'record_id' => record['id'], 'source_revision' => descriptor['source_revision'], 'field' => descriptor['field'], 'basis' => 'reported'}, index)
      return [nil, support] unless support['status'] == 'match'
      return [nil, result('unsupported', 'unsupported_content_representation')] unless descriptor['representation'] == 'exact_source_bytes'
      source_hash = index['sources'][descriptor['source_id']]['content_hash']
      return [nil, result('unresolved', 'source_content_hash_unknown')] if source_hash.nil?
      object!(source_hash, 'source content hash', %w[algorithm value scope])
      %w[algorithm value scope].each { |key| text!(source_hash[key], "source hash #{key}") unless source_hash[key].nil? }
      return [nil, result('unresolved', 'source_content_hash_unknown')] if %w[algorithm value scope].any? { |key| source_hash[key].nil? }
      return [nil, result('unsupported', 'unsupported_source_content_hash_scope')] unless source_hash.values_at('algorithm', 'scope') == ['sha256', 'exact_source_bytes']
      digest!(source_hash['value'], 'source content hash')
      raise InvalidInput, 'descriptor and source SHA-256 disagree' unless descriptor['sha256'] == source_hash['value']
      bytes = supplied[descriptor['source_id']]
      return [nil, result('unresolved', 'preserved_source_bytes_unavailable')] if bytes.nil?
      raise InvalidInput, 'preserved source bytes must be a String' unless bytes.is_a?(String)
      if bytes.bytesize > maximum || descriptor['byte_length'] > maximum
        return [nil, result('unsupported', 'comparison_byte_budget_exceeded', 'limit' => maximum)]
      end
      raise InvalidInput, 'preserved source byte length differs' unless bytes.bytesize == descriptor['byte_length']
      raise InvalidInput, 'preserved source SHA-256 differs' unless Digest::SHA256.hexdigest(bytes) == descriptor['sha256']
      [bytes, nil]
    end

    def json_document!(bytes, label)
      utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
      raise InvalidInput, "#{label} must be UTF-8 JSON" unless utf8.valid_encoding?
      object!(JSON.parse(utf8, object_class: DuplicateKey, max_nesting: 20), label)
    rescue JSON::ParserError, JSON::NestingError => error
      raise InvalidInput, "invalid #{label}: #{error.class}"
    end

    def path!(value)
      text!(value, 'manifest path')
      parts = value.split('/', -1)
      if value.include?('\\') || /[\x00-\x1f\x7f]/.match?(value) || parts.any? { |part| ['', '.', '..'].include?(part) }
        raise InvalidInput, 'manifest paths must be literal relative POSIX paths without dot segments or controls'
      end
      value
    end

    def scope!(value)
      return result('unresolved', 'comparison_scope_unknown') if value.nil?
      object!(value, 'comparison scope', %w[identity kind description])
      %w[identity kind description].each { |key| text!(value[key], "scope.#{key}") unless value[key].nil? }
      return result('unresolved', 'comparison_scope_unknown') if %w[identity kind description].any? { |key| value[key].nil? }
      return result('unsupported', 'unsupported_comparison_scope') unless %w[collected_file_set declared_subset].include?(value['kind'])
      nil
    end

    # Preserved manifest JSON contract everypivot.file_set_manifest/1.0:
    # profile exact_manifest_v1; scope {identity,kind,description}; path_mapping
    # exact_relative_posix_v1; normalization none; exclusions/transformations [];
    # entries [{path,record_id,sha256,byte_length}]. The referenced member records
    # have type kit:file_set_member and content descriptors as above.
    #
    # A coverage assertion record kit:file_set_coverage has subject=manifest ID,
    # with independently preserved JSON everypivot.file_set_coverage/1.0:
    # manifest_sha256, identical scope, method explicit_path_inventory_v1,
    # method_version 1.0, coverage complete_for_declared_scope, paths [...].
    # Its inventory is locally crosschecked; completeness remains a source claim.
    def file_set(id, index, supplied, budgets)
      record, error = record!(index, id, 'kit:file_set_manifest', 'entity')
      return [nil, error] if error
      bytes, error = content(record, index, supplied, budgets['max_manifest_bytes'])
      return [nil, error] if error
      manifest = json_document!(bytes, 'file-set manifest')
      object!(manifest, 'file-set manifest', %w[contract version profile scope path_mapping normalization exclusions transformations entries])
      %w[contract version profile path_mapping normalization].each { |key| text!(manifest[key], "manifest.#{key}") unless manifest[key].nil? }
      %w[exclusions transformations entries].each do |key|
        raise InvalidInput, "manifest.#{key} must be an array" unless manifest[key].nil? || manifest[key].is_a?(Array)
      end
      return [nil, result('unresolved', 'manifest_recipe_unknown')] if %w[contract version profile path_mapping normalization exclusions transformations entries].any? { |key| manifest[key].nil? }
      error = scope!(manifest['scope'])
      return [nil, error] if error
      recipe = manifest.values_at('contract', 'version', 'profile', 'path_mapping', 'normalization')
      unless recipe == ['everypivot.file_set_manifest', '1.0', 'exact_manifest_v1', 'exact_relative_posix_v1', 'none'] && manifest['exclusions'].empty? && manifest['transformations'].empty?
        return [nil, result('unsupported', 'unsupported_manifest_recipe_or_transformation')]
      end
      entries = manifest['entries']
      return [nil, result('unsupported', 'comparison_entry_budget_exceeded', 'limit' => budgets['max_entries'])] if entries.length > budgets['max_entries']
      members, total_bytes, unknown_entry = {}, 0, false
      entries.each do |entry|
        object!(entry, 'manifest entry', %w[path record_id sha256 byte_length])
        path = path!(entry['path']) unless entry['path'].nil?
        text!(entry['record_id'], 'entry.record_id') unless entry['record_id'].nil?
        digest!(entry['sha256'], 'entry.sha256') unless entry['sha256'].nil?
        length = integer!(entry['byte_length'], 'entry.byte_length') unless entry['byte_length'].nil?
        if %w[path record_id sha256 byte_length].any? { |key| entry[key].nil? }
          unknown_entry = true
          next
        end
        raise InvalidInput, 'duplicate literal manifest path' if members.key?(path)
        members[path] = [entry['sha256'], length]
        total_bytes += length
      end
      return [nil, result('unresolved', 'manifest_entry_identity_or_correspondence_unknown')] if unknown_entry
      return [nil, result('unsupported', 'comparison_total_entry_byte_budget_exceeded', 'limit' => budgets['max_total_entry_bytes'])] if total_bytes > budgets['max_total_entry_bytes']
      member_errors = []
      entries.each do |entry|
        member, member_error = record!(index, entry['record_id'], 'kit:file_set_member', 'entity')
        unless member_error
          member_bytes, member_error = content(member, index, supplied, budgets['max_total_entry_bytes'])
          unless member_error
            unless member_bytes.bytesize == entry['byte_length'] && Digest::SHA256.hexdigest(member_bytes) == entry['sha256']
              raise InvalidInput, 'manifest entry identity disagrees with preserved member bytes'
            end
          end
        end
        member_errors << member_error if member_error
      end
      coverage_id = record['attributes']['coverage_record_id']
      return [nil, result('unresolved', 'coverage_inventory_unknown')] if coverage_id.nil?
      coverage_record, error = record!(index, coverage_id, 'kit:file_set_coverage', 'assertion')
      return [nil, error] if error
      return [nil, result('no_match', 'coverage_applies_to_a_different_manifest')] unless coverage_record['subject'] == id
      coverage_bytes, error = content(coverage_record, index, supplied, budgets['max_coverage_bytes'])
      return [nil, error] if error
      coverage = json_document!(coverage_bytes, 'file-set coverage')
      object!(coverage, 'file-set coverage', %w[contract version manifest_sha256 scope method method_version coverage paths])
      %w[contract version method method_version coverage].each { |key| text!(coverage[key], "coverage.#{key}") unless coverage[key].nil? }
      digest!(coverage['manifest_sha256'], 'coverage.manifest_sha256') unless coverage['manifest_sha256'].nil?
      raise InvalidInput, 'coverage.paths must be an array' unless coverage['paths'].nil? || coverage['paths'].is_a?(Array)
      return [nil, result('unresolved', 'coverage_inventory_unknown')] if %w[contract version manifest_sha256 scope method method_version coverage paths].any? { |key| coverage[key].nil? }
      error = scope!(coverage['scope'])
      return [nil, error] if error
      return [nil, result('unsupported', 'comparison_entry_budget_exceeded', 'limit' => budgets['max_entries'])] if coverage['paths'].length > budgets['max_entries']
      paths = coverage['paths'].map { |path| path!(path) }
      raise InvalidInput, 'duplicate coverage inventory path' unless paths.uniq.length == paths.length
      return [nil, result('unsupported', 'unsupported_coverage_inventory_method')] unless coverage.values_at('contract', 'version', 'method', 'method_version') == ['everypivot.file_set_coverage', '1.0', 'explicit_path_inventory_v1', '1.0']
      return [nil, result('unresolved', 'complete_comparison_scope_not_evidenced')] if coverage['coverage'] == 'unknown'
      return [nil, result('no_match', 'declared_comparison_scope_is_only_partially_covered')] if coverage['coverage'] == 'partial_for_declared_scope'
      return [nil, result('unsupported', 'unsupported_coverage_claim')] unless coverage['coverage'] == 'complete_for_declared_scope'
      return [nil, result('no_match', 'coverage_identifies_different_manifest_or_scope')] unless coverage['manifest_sha256'] == Digest::SHA256.hexdigest(bytes) && coverage['scope'] == manifest['scope']
      return [nil, result('no_match', 'manifest_does_not_cover_declared_inventory')] unless paths.sort == members.keys.sort
      return [nil, member_errors.first] unless member_errors.empty?
      [{'record_id' => id, 'manifest_sha256' => Digest::SHA256.hexdigest(bytes), 'coverage_record_id' => coverage_id,
        'coverage_sha256' => Digest::SHA256.hexdigest(coverage_bytes), 'scope' => manifest['scope'], 'members' => members,
        'entry_count' => members.length, 'entry_bytes' => total_bytes,
        'coverage_basis' => 'source_reported_complete_inventory_locally_crosschecked'}, nil]
    end

    def file_set_equal(left:, right:, evidence:, preserved_source_bytes:, limits: {}, scope_kind: nil)
      raise InvalidInput, 'unsupported selected file-set scope kind' unless scope_kind.nil? || %w[collected_file_set declared_subset].include?(scope_kind)
      budgets = limits!(limits)
      index = indexed(evidence)
      object!(preserved_source_bytes, 'preserved source bytes')
      preserved_source_bytes.each { |id, bytes| raise InvalidInput, "source #{id} bytes must be a String" unless bytes.is_a?(String) }
      [left, right].compact.each { |id| text!(id, 'manifest record ID') }
      return result('unresolved', 'comparison_manifest_unknown') if left.nil? || right.nil?
      a, a_error = file_set(left, index, preserved_source_bytes, budgets)
      b, b_error = file_set(right, index, preserved_source_bytes, budgets)
      errors = [a_error, b_error].compact
      unless errors.empty?
        failure = %w[no_match unsupported unresolved].map { |status| errors.find { |item| item['status'] == status } }.compact.first
        return failure.merge('evaluations' => errors, 'limits' => budgets)
      end
      unless a['scope'] == b['scope']
        return result('unresolved', 'different_declared_comparison_scopes', 'left_scope' => a['scope'], 'right_scope' => b['scope'])
      end
      if scope_kind && a['scope']['kind'] != scope_kind
        return result('no_match', 'preserved_manifest_scope_does_not_support_selected_comparison', 'scope' => a['scope'], 'required_scope_kind' => scope_kind)
      end
      equal = a['members'] == b['members']
      result(equal ? 'match' : 'no_match', equal ? 'exact_preserved_file_set_for_declared_scope' : 'different_literal_paths_or_preserved_member_bytes',
             'scope' => a['scope'], 'left' => a.reject { |key, _| key == 'members' }, 'right' => b.reject { |key, _| key == 'members' },
             'limits' => budgets, 'locally_reproduced' => true,
             'claim' => 'declared_file_set_only_not_archive_identity_deployment_or_complete_deployed_kit')
    end

    # A deliberately selected literal path correspondence is a candidate clue;
    # matching paths do not require matching member contents or prove rarity.
    def file_set_shared_paths(left:, right:, paths:, evidence:, preserved_source_bytes:, limits: {})
      budgets = limits!(limits)
      raise InvalidInput, 'selected paths must be a nonempty array' unless paths.is_a?(Array) && !paths.empty?
      paths.each { |path| path!(path) }
      raise InvalidInput, 'selected paths must be distinct' unless paths.uniq == paths
      return result('unsupported', 'comparison_entry_budget_exceeded', 'limit' => budgets['max_entries']) if paths.size > budgets['max_entries']
      index = indexed(evidence)
      object!(preserved_source_bytes, 'preserved source bytes')
      preserved_source_bytes.each_value { |bytes| raise InvalidInput, 'preserved source bytes must be Strings' unless bytes.is_a?(String) }
      [left, right].compact.each { |id| text!(id, 'manifest record ID') }
      return result('unresolved', 'comparison_manifest_unknown') if left.nil? || right.nil?
      a, a_error = file_set(left, index, preserved_source_bytes, budgets)
      b, b_error = file_set(right, index, preserved_source_bytes, budgets)
      errors = [a_error, b_error].compact
      unless errors.empty?
        failure = %w[no_match unsupported unresolved].map { |status| errors.find { |item| item['status'] == status } }.compact.first
        return failure.merge('evaluations' => errors, 'limits' => budgets)
      end
      shared = paths.select { |path| a['members'].key?(path) && b['members'].key?(path) }
      result(shared.length == paths.length ? 'match' : 'no_match', 'explicit_literal_path_correspondence',
             'selected_paths' => paths, 'shared_paths' => shared, 'left_scope' => a['scope'], 'right_scope' => b['scope'],
             'left_manifest_sha256' => a['manifest_sha256'], 'right_manifest_sha256' => b['manifest_sha256'],
             'limits' => budgets, 'claim' => 'path_candidate_only_not_content_equality_rarity_deployment_or_assessment')
    end
  end
end
