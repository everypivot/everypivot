# frozen_string_literal: true

require_relative 'semantic_records'
require_relative 'semantic_time'

module EveryPivot
  # Explicit revision/amendment relations over supplied source assertions.
  # Source labels are not authentication. Absence of a supplied amendment is
  # never evidence of universal, current or independently verified truth.
  module SemanticAmendments
    TYPE = 'evidence:assertion_amendment'.freeze
    OPERATIONS = %w[withdraw correct reinstate dispute].freeze
    class InvalidInput < ArgumentError; end
    module_function

    def result(status, reason, extra = {})
      {'status' => status, 'reason' => reason}.merge(extra)
    end

    def names!(value, label)
      unless value.is_a?(Array) && !value.empty? && value.all? { |v| v.is_a?(String) && !v.empty? } && value.uniq == value
        raise InvalidInput, "#{label} must be a nonempty array of distinct record/source IDs"
      end
    end

    def scoped?(record, sources, selected)
      refs = record['evidence']
      !refs.empty? && refs.all? do |ref|
        source = sources.fetch(ref['source_id'])
        selected.include?(source['id']) && %w[document revision collection].all? { |key| source[key].is_a?(String) && !source[key].empty? }
      end
    end

    def time_backed(time, record, object, sources)
      return result('unresolved', 'required amendment availability time is missing') unless time.is_a?(Hash)
      alternatives = time.key?('alternatives') ? time['alternatives'] : [time]
      checks = alternatives.map do |part|
        next result('unresolved', 'amendment time has an incorrect or missing object/occurrence binding') unless part['binding'] == {'object' => object, 'occurrence' => record['id']}
        ambiguous = record['evidence'].any? do |ref|
          parent = ref['field']; field = part['field']
          sources.fetch(ref['source_id'])['revision'].nil? && field.is_a?(String) && (field == parent || field.start_with?(parent + '/'))
        end
        next result('unresolved', 'amendment time has an unknown additional source origin') if ambiguous
        matching = record['evidence'].select do |ref|
          field = part['field']; parent = ref['field']
          sources.fetch(ref['source_id'])['revision'] == part['source_revision'] && field.is_a?(String) &&
            (field == parent || (parent.start_with?('/') && field.start_with?(parent + '/')))
        end
        next result('unresolved', 'amendment time origin is missing or ambiguous') unless matching.map { |r| r['source_id'] }.uniq.length == 1
        SemanticTime.normalize(part)
      end
      checks.find { |check| check['status'] != 'match' } || result('match', 'bound source-qualified time')
    end

    def availability(amendment, records, sources, selected, collection, cutoff, consume)
      return result('match', 'supplied revision context; no as-known cutoff selected') unless cutoff
      published = amendment.dig('times', 'published')
      bound = time_backed(published, amendment, amendment['id'], sources)
      return bound unless bound['status'] == 'match'
      receipts = records.values.select do |r|
        throw :amendment_budget unless consume.call
        r['kind'] == 'occurrence' && r['type'] == 'evidence:claim_receipt' && r['subject'] == amendment['id'] &&
          r.dig('attributes', 'collection_id') == collection && scoped?(r, sources, selected)
      end
      return result('unresolved', 'no source-backed receipt in the selected collection') if receipts.empty?
      evaluated = receipts.map do |receipt|
        received = receipt.dig('times', 'received')
        backing = time_backed(received, receipt, amendment['id'], sources)
        next backing unless backing['status'] == 'match'
        order = SemanticTime.compare(published, 'lte', received)
        next result('unresolved', 'amendment publication/receipt chronology is contradictory or unresolved') unless order['status'] == 'match'
        eligible = SemanticTime.compare(received, 'lte', cutoff)
        eligible.merge('receipt' => receipt['id'])
      end
      return result('match', 'an actual scoped receipt supports availability by cutoff', 'receipts' => evaluated.select { |r| r['status'] == 'match' }.map { |r| r['receipt'] }) if evaluated.any? { |r| r['status'] == 'match' }
      return result('unresolved', 'amendment availability at cutoff remains unknown') if evaluated.any? { |r| %w[unresolved unsupported].include?(r['status']) }
      result('no_match', 'amendment received after the scoped cutoff; retained as later context', 'receipts' => evaluated.map { |r| r['receipt'] })
    end

    def amendment_support(amendment, target, records, sources, selected, consume)
      return result('unresolved', 'amendment evidence is outside selected sources or lacks revision support') unless scoped?(amendment, sources, selected)
      attrs = amendment['attributes']
      operation = attrs['operation']
      raise InvalidInput, 'unknown amendment operation' unless OPERATIONS.include?(operation)
      issuer = attrs['issuer_source_id']
      unless issuer.is_a?(String) && amendment['evidence'].any? { |ref| ref['source_id'] == issuer }
        return result('unresolved', 'amendment issuing source is not its linked evidence source')
      end
      namespace = attrs['assertion_namespace']
      unless namespace.is_a?(String) && !namespace.empty? && namespace == target.dig('attributes', 'assertion_namespace')
        return result('unresolved', 'amendment target namespace is missing or different')
      end
      publisher = sources.fetch(issuer)['publisher']
      target_publishers = target['evidence'].map { |ref| sources.fetch(ref['source_id'])['publisher'] }.uniq
      unless operation == 'dispute' || (publisher.is_a?(String) && target_publishers == [publisher])
        return result('unresolved', 'a different or unknown publisher cannot silently correct another source assertion')
      end
      if operation == 'correct'
        replacement = records[amendment['object']]
        unless replacement && %w[assertion occurrence].include?(replacement['kind']) && replacement['id'] != target['id'] &&
               scoped?(replacement, sources, selected) && replacement.dig('attributes', 'assertion_namespace') == namespace &&
               replacement['evidence'].map { |ref| sources.fetch(ref['source_id'])['publisher'] }.uniq == [publisher]
          return result('unresolved', 'correction has no supported distinct replacement assertion in the same source namespace')
        end
      elsif amendment.key?('object')
        raise InvalidInput, 'only correction amendments identify a replacement object'
      end
      supersedes = attrs.fetch('supersedes_amendments', [])
      unless supersedes.is_a?(Array) && supersedes.all? { |v| v.is_a?(String) && !v.empty? } && supersedes.uniq == supersedes
        raise InvalidInput, 'supersedes_amendments must be distinct amendment IDs'
      end
      supersedes.each do |id|
        throw :amendment_budget unless consume.call
        old = records[id]
        unless old && old['kind'] == 'assertion' && old['type'] == TYPE && old['subject'] == target['id'] && old['id'] != amendment['id'] &&
               old.dig('attributes', 'assertion_namespace') == namespace && old['evidence'].map { |r| sources.fetch(r['source_id'])['publisher'] }.uniq == [publisher]
          return result('unresolved', 'supersession must name an actual amendment of this assertion by the same publisher')
        end
        # The explicit revision relation, rather than timestamp recency, is the
        # supersession evidence. Supplied contradictory dates cannot be erased.
        if old.dig('times', 'published') && amendment.dig('times', 'published')
          old_time = time_backed(old['times']['published'], old, old['id'], sources)
          new_time = time_backed(amendment['times']['published'], amendment, amendment['id'], sources)
          order = if old_time['status'] == 'match' && new_time['status'] == 'match'
                    SemanticTime.compare(old['times']['published'], 'lte', amendment['times']['published'])
                  end
          unless order && order['status'] == 'match'
            return result('unresolved', 'explicit supersession has contradictory or unresolved published chronology')
          end
        end
      end
      result('match', 'explicit source-qualified amendment relation; source authenticity is not evaluated')
    end

    def cycles?(amendments, consume)
      edges = amendments.to_h { |r| [r['id'], r.dig('attributes', 'supersedes_amendments') || []] }
      done = {}; active = {}
      edges.keys.each do |root|
        next if done[root]
        stack = [[root, false]]
        until stack.empty?
          throw :amendment_budget unless consume.call
          id, leaving = stack.pop
          if leaving
            active.delete(id); done[id] = true
            next
          end
          return true if active[id]
          next if done[id]
          active[id] = true; stack << [id, true]
          edges.fetch(id, []).reverse_each { |prior| stack << [prior, false] if edges.key?(prior) }
        end
      end
      false
    end

    def evaluate(evidence:, assertion_ids:, source_ids:, mode:, knowledge_cutoff: nil, consume: nil)
      raise InvalidInput, 'unsupported amendment evaluation mode' unless %w[retain_reports require_unwithdrawn_in_scope].include?(mode)
      raise InvalidInput, 'consume must be callable' unless consume.nil? || consume.respond_to?(:call)
      consumed = 0
      external_consume = consume
      consume = lambda do
        allowed = external_consume ? external_consume.call : consumed < 10_000
        consumed += 1 if allowed
        allowed
      end
      names!(assertion_ids, 'assertion_ids'); names!(source_ids, 'source_ids')
      index = SemanticRecords.index(evidence)
      records = index['records']; sources = index['sources']
      raise InvalidInput, 'selected source ID is absent from supplied evidence' unless (source_ids - sources.keys).empty?
      SemanticTime.normalize(knowledge_cutoff) if knowledge_cutoff
      states = []
      encountered = []
      completed = catch(:amendment_budget) do
      assertion_ids.each do |id|
        target = records[id]
        raise InvalidInput, 'support must identify an existing assertion or occurrence' unless target && %w[assertion occurrence].include?(target['kind'])
        amendments = records.values.select do |r|
          throw :amendment_budget unless consume.call
          relevant = r['kind'] == 'assertion' && r['type'] == TYPE && r['subject'] == id
          encountered << r if relevant && !encountered.include?(r)
          relevant
        end
        raise InvalidInput, 'cyclic amendment supersession is invalid' if cycles?(amendments, consume)
        current = amendments.map do |amendment|
          support = amendment_support(amendment, target, records, sources, source_ids, consume)
          available = support['status'] == 'match' ? availability(amendment, records, sources, source_ids, evidence['collection_id'], knowledge_cutoff, consume) : support
          {'record' => amendment, 'support' => support, 'availability' => available}
        end
        active = current.select { |a| a['support']['status'] == 'match' && a['availability']['status'] == 'match' }
        unknown = current.any? { |a| a['support']['status'] != 'match' || %w[unresolved unsupported].include?(a['availability']['status']) }
        unknown ||= !scoped?(target, sources, source_ids)
        superseded = active.flat_map { |a| a['record'].dig('attributes', 'supersedes_amendments') || [] }
        surviving = active.reject { |a| superseded.include?(a['record']['id']) }
        operations = surviving.map { |a| a['record'].dig('attributes', 'operation') }.uniq
        # An explicit supersession is the only way a same-source reinstatement
        # can remove a withdrawal. Newest receipt, repetition and majority do not.
        state = if unknown then 'unresolved_amendment_context'
                elsif operations.include?('dispute') || (operations.include?('reinstate') && (operations & %w[withdraw correct]).any?) then 'contested'
                elsif operations.include?('correct') then 'corrected'
                elsif operations.include?('withdraw') then 'withdrawn'
                else 'reported_in_supplied_scope'
                end
        states << {'assertion_id' => id, 'state' => state, 'amendments' => current,
         'later_context' => current.select { |a| a['availability']['status'] == 'no_match' },
         'active_amendment_ids' => surviving.map { |a| a['record']['id'] },
         'active_operations' => operations,
         'replacement_assertion_ids' => surviving.map { |a| a['record']['object'] }.compact,
         'scope' => 'only supplied explicit amendment relations in selected source revisions; absence is not verified truth'}
      end
      true
      end
      unless completed
        return result('unresolved', 'amendment evaluation budget exhausted; incomplete scan cannot establish unwithdrawn support',
                      'states' => states, 'has_gaps' => true, 'partial' => true, 'consumed' => consumed,
                      'encountered_amendments' => encountered,
                      'selected_source_ids' => source_ids, 'mode' => mode, 'source_authenticity' => 'not_evaluated')
      end
      gaps = states.any? { |s| %w[unresolved_amendment_context contested].include?(s['state']) }
      status = gaps ? 'unresolved' : states.any? { |s| %w[corrected withdrawn].include?(s['state']) } ? 'no_match' : 'match'
      qualification_status = status
      status = 'match' if mode == 'retain_reports'
      reason = if mode == 'retain_reports'
                 'historical source reports retained with explicit amendment states; corrected or withdrawn reports are not maintained support'
               elsif status == 'match'
                 'source reports remain unwithdrawn within supplied scope; truth is not evaluated'
               else
                 'supplied correction, withdrawal or conflicting amendment context affects assertion support'
               end
      result(status, reason,
             'states' => states, 'has_gaps' => gaps, 'selected_source_ids' => source_ids,
             'knowledge_scope' => knowledge_cutoff ? 'as-known in the specified evidence collection, with later context retained' : 'supplied revision context without a historical knowledge cutoff',
             'mode' => mode, 'support_status' => qualification_status,
             'partial' => false, 'consumed' => consumed,
             'source_authenticity' => 'not_evaluated', 'assessment_acceptance' => 'not_evaluated')
    end
  end
end
