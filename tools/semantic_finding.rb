# frozen_string_literal: true

require 'json'
require 'digest'
require_relative 'semantic_contract'
require_relative 'semantic_records'
require_relative 'semantic_time'

module EveryPivot
  # Collection-scoped finding establishment, contract 1.0.
  #
  # evaluate(evidence:, claim_key:, qualified_support_sets:, qualification:,
  #          history_id:, preserved_source_bytes:)
  #
  # The engine computes claim_key from the explicit semantic claim identity and
  # supplies independently qualified required-support sets INCLUDING historical
  # paths. This helper cannot turn raw record presence or completed:true into
  # qualification. A support set is an array of record IDs; qualification is
  # {id, revision, contract_sha256}. contract_sha256 is the semantic digest of
  # the complete compiled contract using SemanticContract canonical_json_v1:
  # SHA-256 of JSON.generate(SemanticContract.canonical(contract)), recursively
  # sorted object keys and preserved array order. It is NOT the execution
  # reference SHA-256 of exact contract-file bytes, nor RFC 8785 serialization.
  # Engine integration must not use a candidate
  # row that has not passed its required identity, type and join predicates.
  #
  # A finding:history assertion identifies one preserved JSON manifest via its
  # attributes {manifest_source_id, manifest_field}; the same pointer must occur
  # in its evidence. The manifest contract is everypivot.finding_history 1.0:
  # {contract,version,history_id,revision,collection_id,scope_id,origin_id,origin_sha256,
  #  through_id,through_sha256,
  #  coverage,qualification,establishments:[{record_id,sha256}]}.
  # coverage is complete_declared_scope or unknown. origin_id names an evidenced
  # collection:origin occurrence, with matching collection_id and an origin time;
  # through_id names a collection:history_snapshot occurrence with a through time.
  # This is source-asserted completeness of a specified collection history, never
  # proof of global novelty, true assertions, source authenticity or independence.
  #
  # Each finding:establishment occurrence has attributes {claim_key,
  # collection_id,history_id,qualification,support:[{record_id,sha256}]} and an
  # established time bound to that occurrence. Every required supporting record
  # must have a collection_available time, bound to that record and an actual
  # evidenced availability occurrence, with its source revision/field preserved.
  # All support must be available no later than the establishment. This is a
  # necessary chronology check, never a max(component times) completion rule.
  # Only a separately evidenced establishment event can date complete findings.
  #
  # Record digests use SemanticContract's canonical JSON serialization. Manifest
  # source bytes are supplied by the caller, never fetched or read implicitly;
  # their exact SHA-256 must match a source content hash explicitly scoped as
  # exact_source_bytes. A normalized/derived representation hash cannot claim
  # reproduction of those bytes. Different
  # output/relationship claim keys remain independent. Later runs, copied
  # reports, receipt, tool labels, native mappings and policy reevaluation are
  # not novelty: earliest qualified equivalent establishment wins. Missing or
  # unverifiable earlier history leaves first availability unresolved. An
  # unresolved equivalent event may remain later context only when its own
  # source-bound time proves every possible instant is strictly later than a
  # fully qualified earliest establishment. Unknown, incomparable or possibly
  # earlier times still block freshness; missing support is never inferred from
  # that ordering. No source identity is inferred when linked source IDs share
  # the same field and revision; temporal origin then remains ambiguous.
  module SemanticFinding
    ID = 'everypivot.finding_history'.freeze
    VERSION = '1.0'.freeze
    SHA256 = /\A[0-9a-f]{64}\z/.freeze
    QUALIFICATION_KEYS = %w[id revision contract_sha256].freeze
    class InvalidInput < ArgumentError; end
    class IntegrityFailure < InvalidInput; end
    class UniqueObject < Hash
      def []=(key, value)
        raise InvalidInput, "duplicate manifest JSON key #{key.inspect}" if key?(key)
        super
      end
    end
    module_function

    def decision(status, reason, details = {})
      { 'status' => status, 'reason' => reason }.merge(details)
    end

    def evaluate(evidence:, claim_key:, qualified_support_sets:, qualification:, history_id:, preserved_source_bytes:)
      validate_digest(claim_key, 'claim_key')
      validate_qualification(qualification)
      validate_support_sets(qualified_support_sets)
      raise InvalidInput, 'history_id must be a nonblank string' unless text?(history_id)
      raise InvalidInput, 'preserved_source_bytes must be an object' unless preserved_source_bytes.is_a?(Hash)
      index = SemanticRecords.index(evidence)
      records, sources = index.values_at('records', 'sources')
      qualified_support_sets.flatten.each do |id|
        raise InvalidInput, "qualified support references unknown record #{id}" unless records.key?(id)
      end
      history = records[history_id]
      return decision('unresolved', 'declared finding history record is unavailable') unless history
      return decision('unsupported', 'history requires a finding:history assertion') unless history['kind'] == 'assertion' && history['type'] == 'finding:history'
      closed(history['attributes'], %w[manifest_source_id manifest_field], 'history attributes')
      source_id, field = history['attributes'].values_at('manifest_source_id', 'manifest_field')
      raise InvalidInput, 'history manifest source and field must be explicit strings' unless text?(source_id) && text?(field)
      unless history['evidence'].include?({ 'source_id' => source_id, 'field' => field })
        return decision('unresolved', 'history manifest is not linked by its exact source and field')
      end
      source = sources[source_id]
      raise InvalidInput, 'history manifest references an unknown source' unless source
      return decision('unresolved', 'history source document, revision or collection is unknown') unless known_source?(source)
      bytes = preserved_source_bytes[source_id]
      return decision('unresolved', 'original history source bytes are unavailable; reproduction is unverified') if bytes.nil?
      raise InvalidInput, 'preserved history source bytes must be a string' unless bytes.is_a?(String)
      content_hash = source['content_hash']
      return decision('unresolved', 'history source lacks a reproducible exact content digest') unless content_hash
      unless content_hash['scope'] == 'exact_source_bytes'
        return decision('unsupported', 'history reproduction requires content_hash.scope exact_source_bytes')
      end
      unless Digest::SHA256.hexdigest(bytes) == content_hash['value']
        raise IntegrityFailure, 'preserved history source SHA-256 mismatch'
      end
      manifest = pointer(parse_json(bytes), field)
      validate_manifest(manifest)
      unless manifest['history_id'] == history_id && manifest['revision'] == source['revision']
        raise IntegrityFailure, 'history manifest identity or revision contradicts its bound source record'
      end
      if manifest['contract'] != ID || manifest['version'] != VERSION
        return decision('unsupported', 'unsupported finding history contract')
      end
      unless manifest['collection_id'] == evidence['collection_id'] && source['collection'] == evidence['collection_id']
        return decision('no_match', 'history belongs to a different collection')
      end
      unless manifest['qualification'] == qualification
        return decision('unsupported', 'history qualification contract differs from the requested qualification')
      end
      manifested_ids = manifest['establishments'].map { |entry| entry['record_id'] }
      unlisted = records.values.select do |record|
        record['type'] == 'finding:establishment' && record.dig('attributes', 'history_id') == history_id && !manifested_ids.include?(record['id'])
      end
      return decision('unresolved', 'supplied establishment is absent from the declared complete history', 'record_ids' => unlisted.map { |record| record['id'] }) unless unlisted.empty?

      candidates = manifest['establishments'].map do |entry|
        record = records[entry['record_id']]
        return decision('unresolved', 'a manifested establishment record is unavailable', 'record_id' => entry['record_id']) unless record
        verify_record_digest(record, entry['sha256'], 'establishment')
        validate_establishment(record)
        record['attributes']['support'].each do |support|
          present = records[support['record_id']]
          verify_record_digest(present, support['sha256'], 'support') if present
        end
        record
      end
      unless manifest['coverage'] == 'complete_declared_scope'
        return decision('unresolved', 'history coverage is unknown; no first-availability claim is justified')
      end
      origin = records[manifest['origin_id']]
      verify_record_digest(origin, manifest['origin_sha256'], 'collection origin') if origin
      origin_status = check_origin(origin, evidence['collection_id'], records, sources)
      return origin_status unless origin_status['status'] == 'match'
      through = records[manifest['through_id']]
      verify_record_digest(through, manifest['through_sha256'], 'history coverage endpoint') if through
      unless through && through['kind'] == 'occurrence' && through['type'] == 'collection:history_snapshot' && through.dig('attributes', 'collection_id') == evidence['collection_id']
        return decision('unresolved', 'history coverage endpoint is not evidenced for this collection')
      end
      through_status = event_time(through, 'through', through['id'], through['id'], evidence['collection_id'], records, sources)
      return through_status unless through_status['status'] == 'match'
      coverage_order = SemanticTime.compare(origin['times']['origin'], 'lte', through['times']['through'])
      if coverage_order['status'] == 'no_match'
        raise InvalidInput, 'history coverage endpoint precedes its collection origin'
      end
      unless coverage_order['status'] == 'match'
        return decision(coverage_order['status'], 'history origin-to-endpoint order is not established', 'coverage_order' => coverage_order)
      end

      equivalent = candidates.select { |record| record.dig('attributes', 'claim_key') == claim_key }
      return decision('unresolved', 'no actual establishment event supports this semantic claim; component timestamps are insufficient') if equivalent.empty?
      checks = equivalent.map do |record|
        check_establishment(record, claim_key, history_id, qualification, qualified_support_sets,
                            evidence['collection_id'], origin, through, records, sources)
      end
      qualified = equivalent.zip(checks).select { |_record, check| check['status'] == 'match' }.map(&:first)
      if qualified.empty?
        blocked = checks.find { |check| %w[unsupported unresolved].include?(check['status']) }
        return unresolved_establishment(blocked, checks, manifest) if blocked
        return decision('no_match', 'no establishment has the independently qualified identity/support correspondence', 'establishment_checks' => checks)
      end

      earliest = qualified.select do |candidate|
        qualified.all? do |other|
          candidate['id'] == other['id'] || SemanticTime.compare(candidate['times']['established'], 'lte', other['times']['established'])['status'] == 'match'
        end
      end
      if earliest.empty?
        return decision('unresolved', 'equivalent establishment times are incomparable; no favorable earliest date selected', 'establishment_checks' => checks)
      end
      chosen = earliest.min_by { |record| record['id'] }
      later_context = []
      equivalent.zip(checks).each do |record, check|
        next unless %w[unsupported unresolved].include?(check['status'])
        event = event_time(record, 'established', record['id'], record['id'], evidence['collection_id'], records, sources)
        ordering = if event['status'] == 'match'
                     SemanticTime.compare(chosen['times']['established'], 'lt', record['times']['established'])
                   else
                     event
                   end
        return unresolved_establishment(check, checks, manifest) unless ordering['status'] == 'match'
        check['freshness_effect'] = 'provably_later_context'
        check['earliest_ordering'] = ordering
        later_context << record['id']
      end
      decision('match', 'earliest qualified establishment in the integrity-checked source-declared collection history',
               'claim_key' => claim_key, 'collection_id' => evidence['collection_id'],
               'first_scoped_time' => chosen['times']['established'],
               'earliest_establishment_ids' => earliest.map { |record| record['id'] }.sort,
               'equivalent_establishment_ids' => qualified.map { |record| record['id'] }.sort,
               'unresolved_later_establishment_ids' => later_context.sort,
               'establishment_checks' => checks,
               'history' => { 'id' => history_id, 'revision' => manifest['revision'], 'scope_id' => manifest['scope_id'],
                              'source_id' => source_id, 'source_sha256' => content_hash['value'], 'origin_id' => origin['id'],
                              'through_id' => through['id'], 'through' => through['times']['through'],
                              'coverage_basis' => 'source_asserted_complete_declared_scope' },
               'limits' => ['source truth and completeness are not independently proven', 'no global first-discovery or analyst-awareness claim',
                            'no refreshed contextual observation, independence, confidence or assessment acceptance'])
    rescue SemanticRecords::InvalidInput => e
      raise InvalidInput, e.message
    end

    def unresolved_establishment(check, checks, manifest)
      decision(check['status'], 'an equivalent establishment remains unresolved; a later event cannot manufacture freshness',
               'establishment_checks' => checks, 'history_scope' => manifest['scope_id'])
    end

    def check_origin(origin, collection, records, sources)
      return decision('unresolved', 'collection-origin evidence is unavailable; prior availability remains unknown') unless origin
      unless origin['kind'] == 'occurrence' && origin['type'] == 'collection:origin' && origin.dig('attributes', 'collection_id') == collection
        return decision('unresolved', 'history does not bind the specified collection origin')
      end
      event_time(origin, 'origin', origin['id'], origin['id'], collection, records, sources)
    end

    def check_establishment(record, claim_key, history_id, qualification, qualified_sets, collection, origin, through, records, sources)
      attrs = record['attributes']
      details = { 'record_id' => record['id'] }
      unless attrs['claim_key'] == claim_key && attrs['collection_id'] == collection && attrs['history_id'] == history_id && attrs['qualification'] == qualification
        return decision('no_match', 'establishment identity, collection, history or qualification does not correspond', details)
      end
      support_ids = attrs['support'].map { |entry| entry['record_id'] }
      unless qualified_sets.any? { |ids| ids.sort == support_ids.sort }
        return decision('unresolved', 'establishment support has not been independently qualified by the engine', details)
      end
      event = event_time(record, 'established', record['id'], record['id'], collection, records, sources)
      return event.merge(details) unless event['status'] == 'match'
      chronology = SemanticTime.compare(origin['times']['origin'], 'lte', record['times']['established'])
      return decision(chronology['status'], 'establishment must not predate its evidenced collection origin', details) unless chronology['status'] == 'match'
      coverage = SemanticTime.compare(record['times']['established'], 'lte', through['times']['through'])
      return decision('unresolved', 'establishment is not covered by the evidenced history endpoint', details) unless coverage['status'] == 'match'
      support_checks = attrs['support'].map do |entry|
        support = records[entry['record_id']]
        return decision('unresolved', 'establishment support record is unavailable', details.merge('support_id' => entry['record_id'])) unless support
        verify_record_digest(support, entry['sha256'], 'support')
        return decision('unresolved', 'establishment cannot use itself or another establishment as its qualification support', details) if support['id'] == record['id'] || support['type'] == 'finding:establishment'
        available = support.dig('times', 'collection_available')
        time_status = event_time(support, 'collection_available', support['id'], available && available.dig('binding', 'occurrence'), collection, records, sources)
        unless time_status['status'] == 'match'
          next time_status.merge('support_id' => support['id'])
        end
        occurrence = records[available.dig('binding', 'occurrence')]
        unless occurrence && occurrence['kind'] == 'occurrence' && occurrence['type'] == 'evidence:availability' && occurrence.dig('attributes', 'collection_id') == collection
          next decision('unresolved', 'support availability is not tied to an evidenced occurrence in this collection', 'support_id' => support['id'])
        end
        unless supported_record?(occurrence, sources)
          next decision('unresolved', 'support availability occurrence lacks source/revision evidence', 'support_id' => support['id'])
        end
        time_compare = SemanticTime.compare(available, 'lte', record['times']['established'])
        decision(time_compare['status'], 'required support availability must precede or equal establishment', 'support_id' => support['id'])
      end
      blocked = support_checks.find { |check| %w[unsupported unresolved].include?(check['status']) }
      return decision(blocked['status'], 'required support availability remains unestablished', details.merge('support_checks' => support_checks)) if blocked
      return decision('no_match', 'known later support cannot backdate a complete finding', details.merge('support_checks' => support_checks)) if support_checks.any? { |check| check['status'] == 'no_match' }
      decision('match', 'actual establishment event and independently qualified support satisfy collection chronology', details.merge('support_checks' => support_checks))
    end

    def event_time(record, field, object_id, occurrence_id, collection, records, sources)
      return decision('unresolved', 'record has no complete source/revision evidence') unless supported_record?(record, sources)
      envelope = record['times'][field]
      return decision('unresolved', "missing #{field} time evidence") unless envelope
      unless envelope.dig('binding', 'object') == object_id && envelope.dig('binding', 'occurrence') == occurrence_id && records.key?(occurrence_id)
        return decision('unresolved', "#{field} time does not bind the actual object and occurrence")
      end
      if envelope['interval_role'] != 'occurrence'
        return decision('unsupported', "#{field} requires an occurrence, not state validity")
      end
      linked = record['evidence'].select do |reference|
        source = sources[reference['source_id']]
        reference['field'] == envelope['field'] && source['revision'] == envelope['source_revision'] && source['collection'] == collection
      end
      if linked.empty?
        return decision('unresolved', "#{field} originating field/revision is not explicitly linked to this collection")
      end
      unless linked.map { |reference| reference['source_id'] }.uniq.length == 1
        return decision('unresolved', "#{field} originating field/revision matches multiple source identities")
      end
      normalized = SemanticTime.normalize(envelope)
      decision(normalized['status'], Array(normalized['reasons']).join('; '))
    end

    def supported_record?(record, sources)
      !record['evidence'].empty? && record['evidence'].all? { |reference| known_source?(sources.fetch(reference['source_id'])) }
    end

    def known_source?(source)
      source && %w[document revision collection].all? { |key| text?(source[key]) }
    end

    def validate_manifest(manifest)
      closed(manifest, %w[contract version history_id revision collection_id scope_id origin_id origin_sha256 through_id through_sha256 coverage qualification establishments], 'history manifest')
      %w[contract version history_id revision collection_id scope_id origin_id through_id].each { |key| raise InvalidInput, "manifest #{key} must be a string" unless text?(manifest[key]) }
      raise InvalidInput, 'history coverage must be explicit' unless %w[complete_declared_scope unknown].include?(manifest['coverage'])
      %w[origin_sha256 through_sha256].each { |key| validate_digest(manifest[key], "manifest #{key}") }
      validate_qualification(manifest['qualification'])
      validate_entries(manifest['establishments'], 'manifest establishments', allow_empty: true)
    end

    def validate_establishment(record)
      unless record['kind'] == 'occurrence' && record['type'] == 'finding:establishment'
        raise InvalidInput, 'manifest entry must identify a finding:establishment occurrence'
      end
      attrs = record['attributes']
      closed(attrs, %w[claim_key collection_id history_id qualification support], 'establishment attributes')
      validate_digest(attrs['claim_key'], 'establishment claim_key')
      %w[collection_id history_id].each { |key| raise InvalidInput, "establishment #{key} must be a string" unless text?(attrs[key]) }
      validate_qualification(attrs['qualification'])
      validate_entries(attrs['support'], 'establishment support')
    end

    def validate_qualification(value)
      closed(value, QUALIFICATION_KEYS, 'qualification')
      %w[id revision].each { |key| raise InvalidInput, "qualification #{key} must be explicit" unless text?(value[key]) }
      validate_digest(value['contract_sha256'], 'qualification contract_sha256')
    end

    def validate_support_sets(sets)
      unless sets.is_a?(Array) && !sets.empty? && sets.all? { |set| set.is_a?(Array) && !set.empty? && set.all? { |id| text?(id) } && set.uniq == set }
        raise InvalidInput, 'qualified_support_sets must contain nonempty unique record-ID arrays independently qualified by the engine'
      end
    end

    def validate_entries(entries, label, allow_empty: false)
      raise InvalidInput, "#{label} must be an array" unless entries.is_a?(Array) && (allow_empty || !entries.empty?)
      ids = []
      entries.each do |entry|
        closed(entry, %w[record_id sha256], label)
        raise InvalidInput, "#{label} record_id is blank or duplicate" unless text?(entry['record_id']) && !ids.include?(entry['record_id'])
        ids << entry['record_id']
        validate_digest(entry['sha256'], "#{label} sha256")
      end
    end

    def verify_record_digest(record, expected, label)
      raise IntegrityFailure, "#{label} canonical record SHA-256 mismatch" unless SemanticContract.digest(record) == expected
    end

    def closed(value, required, label)
      unless value.is_a?(Hash) && value.keys.sort == required.sort
        raise InvalidInput, "#{label} must contain exactly #{required.join(', ')}"
      end
    end

    def validate_digest(value, label)
      raise InvalidInput, "#{label} must be a full lowercase SHA-256" unless value.is_a?(String) && SHA256.match?(value)
    end

    def text?(value)
      value.is_a?(String) && !value.strip.empty?
    end

    def parse_json(bytes)
      text = bytes.dup.force_encoding(Encoding::UTF_8)
      raise InvalidInput, 'history source JSON is not valid UTF-8' unless text.valid_encoding?
      JSON.parse(text, object_class: UniqueObject, max_nesting: 64)
    rescue JSON::ParserError => e
      raise InvalidInput, "invalid preserved history JSON: #{e.message}"
    end

    def pointer(document, path)
      raise InvalidInput, 'manifest field must be an absolute JSON pointer' unless path.start_with?('/')
      path.split('/', -1)[1..-1].reduce(document) do |value, token|
        raise InvalidInput, 'manifest pointer has invalid escape' if token.match?(/~(?![01])/)
        key = token.gsub('~1', '/').gsub('~0', '~')
        if value.is_a?(Hash) && value.key?(key)
          value[key]
        elsif value.is_a?(Array) && key.match?(/\A(?:0|[1-9][0-9]*)\z/) && key.to_i < value.length
          value[key.to_i]
        else
          raise InvalidInput, 'manifest field is absent from preserved source bytes'
        end
      end
    end
    private_class_method :decision, :unresolved_establishment, :check_origin, :check_establishment, :event_time,
                         :supported_record?, :known_source?, :validate_manifest,
                         :validate_establishment, :validate_qualification, :validate_support_sets,
                         :validate_entries, :verify_record_digest, :closed, :validate_digest,
                         :text?, :parse_json, :pointer
  end
end
