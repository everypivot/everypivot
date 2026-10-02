# frozen_string_literal: true
require_relative 'semantic_result_primitives'
require_relative 'package_repository_provenance'

module EveryPivot
  # Bounded normalized declaration profile. Reproducing preserved bytes does
  # not authenticate a registry, verify a package build or read a Git checkout.
  module SemanticPackageRepository
    class InvalidInput < StandardError; end
    module_function
    def result(status, reason, extra = {})
      {'status' => status, 'reason' => reason}.merge(extra)
    end

    # Compare all supplied reports of the same source-scoped actual occurrence.
    # Record IDs, revisions and receipts cannot refresh that occurrence. This
    # intentionally does not infer equivalence between independent source scopes.
    def observation_scope(record, index)
      attrs = record['attributes']
      return nil unless %w[origin_source_id occurrence_namespace collector occurrence_key relation].all? { |key| SemanticRecords.text?(attrs[key]) }
      source = index['sources'][attrs['origin_source_id']]
      return nil unless source && %w[publisher collection document revision].all? { |key| SemanticRecords.text?(source[key]) }
      return nil unless record['evidence'].any? { |ref| ref['source_id'] == source['id'] }
      source.values_at('publisher', 'collection', 'document') + attrs.values_at('occurrence_namespace', 'collector', 'occurrence_key', 'relation')
    end

    def observation_time(record, key, object, occurrence, index)
      time = record.dig('times', key)
      return result('unresolved', 'actual observation time or collection availability is missing') if time.nil?
      normalized = SemanticTime.normalize(time)
      return normalized.merge('reason' => Array(normalized['reasons']).join('; ')) unless normalized['status'] == 'match'
      return result('no_match', 'observation time is bound to a different object or occurrence') unless time['binding'] == {'object' => object, 'occurrence' => occurrence}
      sources = record['evidence'].select do |ref|
        SemanticResultPrimitives.field_covers?(ref['field'], time['field']) &&
          (key != 'observed' || ref['source_id'] == record.dig('attributes', 'origin_source_id'))
      end
      origins = sources.select { |ref| index['sources'][ref['source_id']]['revision'] == time['source_revision'] }.map { |ref| ref['source_id'] }.uniq
      unknown_origin = sources.any? { |ref| index['sources'][ref['source_id']]['revision'].nil? }
      return result('unresolved', 'observation or receipt time needs one unambiguous linked source revision and field') unless origins.size == 1 && !unknown_origin
      result('match', 'bound source-qualified time', 'normalized' => normalized)
    end

    def observation_window(observation:, period:, evidence:, consume: nil)
      index = SemanticResultPrimitives.indexed(evidence)
      current = index['records'][observation]
      raise InvalidInput, 'unknown observation record' unless current
      return result('no_match', 'record is not a package/repository relationship occurrence') unless current['kind'] == 'occurrence' && %w[repository:infrastructure_observation package:infrastructure_observation].include?(current['type'])
      scope = observation_scope(current, index)
      return result('unresolved', 'observation needs a linked origin, stable source namespace, collector and occurrence key') unless scope
      reports = []
      index['records'].each_value do |record|
        return result('unresolved', 'bounded occurrence-equivalence scan is incomplete', 'report_ids' => reports.map { |r| r['id'] }) if consume && !consume.call
        next unless record['kind'] == 'occurrence' && record['type'] == current['type']
        candidate_scope = observation_scope(record, index)
        # An unscoped copy with the same supplied stable key is uncertain, never
        # evidence that the current timestamp is uncontested.
        if candidate_scope.nil? && record['attributes'].values_at('occurrence_namespace', 'collector', 'occurrence_key', 'relation') == current['attributes'].values_at('occurrence_namespace', 'collector', 'occurrence_key', 'relation')
          return result('unresolved', 'possible equivalent occurrence has unresolved source scope', 'report_id' => record['id'])
        end
        reports << record if candidate_scope == scope
      end
      intervals = []
      reports.each do |record|
        return result('unresolved', 'same source-scoped occurrence has competing relationship endpoints', 'report_ids' => reports.map { |r| r['id'] }) unless record['subject'] == current['subject'] && record['object'] == current['object']
        # Differently normalized endpoint record IDs are conservatively retained
        # as unresolved correspondence, never used to manufacture a new sighting.
        observed = observation_time(record, 'observed', record['subject'], record['id'], index)
        available = observation_time(record, 'collection_available', record['id'], record.dig('attributes', 'availability_occurrence'), index)
        failure = [observed, available].find { |value| value['status'] != 'match' }
        return result('unresolved', 'equivalent occurrence contains unsupported or conflicting temporal evidence', 'report_ids' => reports.map { |r| r['id'] }, 'evaluation' => failure) if failure
        sequence = SemanticTime.compare(record['times']['observed'], 'lte', record['times']['collection_available'])
        return result('unresolved', 'completed observation cannot be established as available before it occurred', 'report_id' => record['id'], 'evaluation' => sequence) unless sequence['status'] == 'match'
        intervals << observed['normalized']['normalized']
      end
      # No latest-revision-wins rule exists. Even conflicting dates both inside
      # the window need explicit source correction before they become one time.
      return result('unresolved', 'same source-scoped occurrence has competing reported times; no winner selected', 'report_ids' => reports.map { |r| r['id'] }) unless intervals.uniq.size == 1
      evaluation = SemanticTime.within(current['times']['observed'], period: period, quantifier: 'contained')
      evaluation.merge('reason' => 'source-scoped actual relationship observation within the selected UTC period', 'equivalent_report_ids' => reports.map { |r| r['id'] }, 'equivalence_scope' => scope)
    end

    def evaluate(declaration:, package:, repository:, sidecar:, metadata:, pattern_id:, evidence:, preserved_source_bytes:)
      index = SemanticResultPrimitives.indexed(evidence)
      ids = [declaration, package, repository, sidecar, metadata]
      return result('unresolved', 'required declaration binding is absent') if ids.any?(&:nil?)
      records = ids.map { |id| index['records'][id] }
      raise InvalidInput, 'declaration refers to an unknown record' if records.any?(&:nil?)
      d, pkg, repo, sc, md = records
      return result('no_match', 'records do not have the declared package/repository roles') unless
        d.values_at('kind', 'type') == ['assertion', 'package:repository_declaration'] &&
        pkg.values_at('kind', 'type') == ['entity', 'it:prod:softver'] &&
        repo.values_at('kind', 'type') == ['entity', 'code:repo'] &&
        sc.values_at('kind', 'type') == ['entity', 'evidence:package_repository_provenance'] &&
        md.values_at('kind', 'type') == ['entity', 'evidence:registry_document']
      return result('no_match', 'declaration endpoints or preserved evidence bindings differ') unless
        d['subject'] == package && d['object'] == repository && d.dig('attributes', 'sidecar_id') == sidecar && d.dig('attributes', 'metadata_id') == metadata
      bytes, failure = SemanticResultPrimitives.content(sc, index, preserved_source_bytes, 1_048_576)
      return failure if failure
      original, failure = SemanticResultPrimitives.content(md, index, preserved_source_bytes, 1_048_576)
      return failure if failure
      document = SemanticResultPrimitives.json_document!(bytes, 'package provenance sidecar')
      errors = PackageRepositoryProvenance.validate(document)
      raise InvalidInput, errors.join('; ') unless errors.empty?
      return result('unresolved', 'normalized sidecar fields are absent') if sc.dig('attributes', 'document').nil?
      return result('no_match', 'normalized sidecar fields do not reproduce its preserved document') unless document == sc.dig('attributes', 'document')
      return result('no_match', 'sidecar belongs to a different versioned pattern') unless document['pattern_id'] == pattern_id && document['pattern_version'] == '3.0.0'
      return result('no_match', 'mirror pointer is not a version-specific source-repository declaration') unless document.dig('declaration', 'kind') == 'version_source_repository'
      package_identity = pkg.dig('attributes', 'package')
      return result('unresolved', 'package identity is absent') if package_identity.nil?
      raise InvalidInput, 'package identity must be a registry/name/version object' unless package_identity.is_a?(Hash)
      return result('unresolved', 'package identity has an unknown component') if %w[registry name version].any? { |key| package_identity[key].nil? }
      raise InvalidInput, 'package identity components must be nonblank text' unless %w[registry name version].all? { |key| package_identity[key].is_a?(String) && !package_identity[key].strip.empty? }
      return result('no_match', 'sidecar identifies a different package version') unless document['package'] == package_identity
      uri = repo.dig('attributes', 'uri')
      return result('unresolved', 'repository URI identity is unknown') if uri.nil?
      normalized = SemanticIdentity.normalize(uri)
      return result(normalized['status'], normalized['reason']) unless normalized['status'] == 'ready'
      return result('unsupported', 'repository identity requires a literal URI selector') unless normalized['kind'] == 'uri'
      backing = SemanticResultPrimitives.backed(repo, uri['provenance'], index)
      return backing unless backing['status'] == 'match'
      return result('no_match', 'declared repository URI differs; no mirror or redirect equivalence inferred') unless uri['value'] == document['repository_uri']
      anchor = document.dig('declaration', 'evidence')
      descriptor = md.dig('attributes', 'content')
      source = index['sources'][descriptor['source_id']]
      return result('unresolved', 'registry source identity has an unknown origin component') if %w[revision publisher collection document].any? { |key| source[key].nil? }
      return result('no_match', 'registry document identity or revision differs from the preserved declaration anchor') unless
        anchor['sha256'] == Digest::SHA256.hexdigest(original) && anchor['revision'] == source['revision'] &&
        anchor['publisher'] == source['publisher'] && anchor['collection'] == source['collection'] && anchor['uri'] == source['document'] &&
        d['evidence'].any? { |ref| ref['source_id'] == source['id'] && SemanticResultPrimitives.field_covers?(ref['field'], anchor['field']) }
      result('match', 'preserved version-specific declaration and exact package/repository correspondence',
        'sidecar_record_id' => sidecar, 'metadata_record_id' => metadata, 'revision_binding' => document['revision_binding'],
        'snapshot' => document['snapshot'], 'snapshot_validation' => 'supplied manifest self-consistency only; local Git reproduction is a separate helper',
        'build_provenance' => 'not_verified', 'source_authenticity' => 'not_evaluated')
    rescue SemanticResultPrimitives::InvalidInput, PackageRepositoryProvenance::InvalidRecord => e
      raise InvalidInput, e.message
    end
  end
end
