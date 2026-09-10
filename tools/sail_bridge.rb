# frozen_string_literal: true

require 'digest'
require 'json'
require 'pathname'

module EveryPivot
  # Checks a documentary candidate shape against the pinned SAIL v0.4 DRAFT
  # contracts. It neither evaluates evidence nor accepts analytical conclusions.
  class SailBridge
    class ContractError < StandardError; end

    MANIFEST_SHA256 = '5416bf429a34afccb4e6657807c26b83491a39bdcbd6c9a313530cadbf032881'
    VERSION = '0.4-draft'
    SCHEMA_VERSIONS = %w[1.1 1.2 1.3 1.4 1.5].freeze
    SCOPES = %w[entity_level campaign_level incident_level].freeze
    BASES = %w[demonstrated assessed suspected theoretical].freeze
    HINT_FIELDS = %w[claim basis scope subject_role object_role object_kind].freeze
    CONTRACT_FILES = %w[predicate_type_matrix.v0.4.json semantic_roles.v0.4.json structural_object_kinds.v0.4.json LICENSE NOTICE].freeze
    STATUSES = %w[evidence_only candidate_compatible incomplete incompatible].freeze

    attr_reader :contract_info

    def initialize(repo_root: Pathname(__dir__).join('..'))
      directory = Pathname(repo_root).join('schemas', 'sail-v0.4-draft')
      manifest_bytes = directory.join('manifest.json').binread
      digest = Digest::SHA256.hexdigest(manifest_bytes)
      raise ContractError, 'Pinned SAIL manifest SHA256 mismatch' unless digest == MANIFEST_SHA256

      manifest = JSON.parse(manifest_bytes)
      files = manifest.fetch('files')
      raise ContractError, 'Incomplete SAIL contract pack' unless files.keys.sort == CONTRACT_FILES.sort

      contracts = {}
      files.each do |filename, entry|
        bytes = directory.join(filename).binread
        unless Digest::SHA256.hexdigest(bytes) == entry.fetch('sha256')
          raise ContractError, "Pinned SAIL SHA256 mismatch: #{filename}"
        end
        contracts[filename] = JSON.parse(bytes) if filename.end_with?('.json')
      end
      matrix = contracts.fetch('predicate_type_matrix.v0.4.json')
      role_contract = contracts.fetch('semantic_roles.v0.4.json')
      kind_contract = contracts.fetch('structural_object_kinds.v0.4.json')
      contracts.each do |filename, contract|
        raise ContractError, "Wrong SAIL version in #{filename}" unless contract['version'] == VERSION
      end
      unless matrix['semantic_role_contract'] == 'semantic_roles.v0.4.json' &&
             matrix['structural_object_kind_contract'] == 'structural_object_kinds.v0.4.json'
        raise ContractError, 'SAIL matrix references unavailable vocabularies'
      end
      @roles = role_contract.fetch('roles').map { |entry| entry.fetch('id') }
      @kinds = kind_contract.fetch('object_kinds').map { |entry| entry.fetch('id') }
      @predicates = matrix.fetch('predicates').to_h { |entry| [entry.fetch('id'), entry] }
      raise ContractError, 'Empty or duplicate SAIL predicates' if @predicates.empty? || @predicates.length != matrix['predicates'].length

      @predicates.each_value do |predicate|
        subjects = predicate.fetch('allowed_subject_roles')
        scopes = predicate.fetch('allowed_scope_by_subject_role')
        unless subjects.any? && (subjects - @roles).empty? && scopes.keys.sort == subjects.sort &&
               (predicate.fetch('allowed_object_roles') - @roles).empty? &&
               (predicate.fetch('allowed_object_kinds') - @kinds).empty? &&
               scopes.values.all? { |values| values.is_a?(Array) && values.any? && (values - SCOPES).empty? }
          raise ContractError, "Incomplete or invalid SAIL predicate contract: #{predicate['id']}"
        end
      end
      @contract_info = {
        'status' => 'verified', 'version' => VERSION, 'manifest_sha256' => digest,
        'source_repository' => manifest.fetch('source_repository'),
        'source_revision' => manifest.fetch('source_revision'),
        'predicate_count' => @predicates.length,
        'sha256' => files.transform_values { |entry| entry.fetch('sha256') }
      }
    rescue ContractError
      raise
    rescue SystemCallError, JSON::ParserError, KeyError, TypeError, NoMethodError => e
      raise ContractError, "SAIL contract pack unavailable or malformed: #{e.message}"
    end

    def check(data, path: nil)
      result = {
        'id' => data.is_a?(Hash) ? data['id'] : nil, 'path' => path.to_s,
        'status' => 'incompatible',
        'assessment_mode' => data.is_a?(Hash) ? data['assessment_mode'] : nil,
        'errors' => [], 'warnings' => [],
        'coverage' => {'complete' => false, 'checks_performed' => [], 'assessment_acceptance_evaluated' => false}
      }
      unless data.is_a?(Hash)
        issue(result, 'errors', 'document_not_mapping', 'top-level pattern must be a mapping')
        return result
      end

      version = data['pattern_schema_version'].to_s
      issue(result, 'errors', 'schema_version_unknown', 'pattern_schema_version is missing or unsupported') unless SCHEMA_VERSIONS.include?(version)
      mode = data['assessment_mode']
      if version == '1.5'
        unless %w[evidence_only candidate_assessment].include?(mode)
          issue(result, 'errors', 'assessment_mode_invalid', 'v1.5 requires assessment_mode evidence_only or candidate_assessment')
        end
        if mode == 'evidence_only'
          issue(result, 'errors', 'evidence_only_has_assessment', 'evidence_only forbids assessment') if data.key?('assessment')
          issue(result, 'errors', 'evidence_only_has_requirements', 'evidence_only forbids assessment_requirements') if data.key?('assessment_requirements')
          result['coverage']['checks_performed'] << 'assessment_mode'
          result['coverage']['complete'] = result['errors'].empty?
          result['status'] = result['errors'].empty? ? 'evidence_only' : 'incompatible'
          return result
        elsif mode == 'candidate_assessment'
          requirements = data['assessment_requirements']
          unless requirements.is_a?(Array) && requirements.any? && requirements.all? { |value| value.is_a?(String) && !value.strip.empty? }
            issue(result, 'errors', 'assessment_requirements_missing', 'candidate_assessment requires nonempty documentary assessment_requirements strings')
          end
        end
      elsif data.key?('assessment_mode') || data.key?('assessment_requirements')
        issue(result, 'errors', 'assessment_mode_requires_v15', 'assessment_mode and assessment_requirements require schema v1.5')
      end

      unless data.key?('assessment')
        if version == '1.1'
          issue(result, 'warnings', 'legacy_assessment_absent', 'Legacy pattern has no assessment hint; compatibility is incomplete')
          result['status'] = result['errors'].empty? ? 'incomplete' : 'incompatible'
        else
          issue(result, 'errors', 'assessment_missing', 'assessment is required unless v1.5 assessment_mode is evidence_only')
        end
        return result
      end

      hint = data['assessment']
      unless hint.is_a?(Hash)
        issue(result, 'errors', 'assessment_not_mapping', 'assessment must be a mapping')
        return result
      end
      (hint.keys - HINT_FIELDS).each do |field|
        issue(result, 'errors', 'assessment_field_unknown', "assessment.#{field} is not part of the documentary bridge contract")
      end
      unless BASES.include?(hint['basis'])
        issue(result, 'errors', 'basis_invalid', 'assessment.basis must use a supported documentary basis; it is not runtime confidence')
      end
      unless SCOPES.include?(hint['scope'])
        issue(result, 'errors', 'scope_invalid', 'assessment.scope must name a SAIL scope')
      end
      predicate = @predicates[hint['claim']]
      unless predicate
        issue(result, 'errors', 'unknown_claim', 'assessment.claim is not in the pinned SAIL predicate matrix')
        return result
      end

      result['coverage']['checks_performed'] = %w[assessment_mode hint_fields predicate subject_role object_role_or_kind scope basis]
      subject = hint['subject_role']
      role = hint['object_role']
      kind = hint['object_kind']
      missing_subject = !hint.key?('subject_role')
      missing_object = !hint.key?('object_role') && !hint.key?('object_kind')
      if missing_subject
        issue(result, 'warnings', 'subject_role_missing', 'assessment.subject_role is absent; subject and scope compatibility remain incomplete')
      elsif !predicate['allowed_subject_roles'].include?(subject)
        issue(result, 'errors', 'subject_role_not_allowed', "assessment.subject_role #{subject.inspect} is not allowed for #{hint['claim']}")
      end
      if missing_object
        issue(result, 'warnings', 'object_role_and_kind_missing', 'assessment requires an object_role or object_kind to establish complete compatibility')
      else
        if hint.key?('object_role') && !(@roles + @kinds).include?(role)
          issue(result, 'errors', 'object_role_unknown', "assessment.object_role #{role.inspect} is not a known SAIL role")
        end
        if hint.key?('object_kind') && !@kinds.include?(kind)
          issue(result, 'errors', 'object_kind_unknown', "assessment.object_kind #{kind.inspect} is not a known SAIL structural kind")
        end
        effective_kinds = [kind]
        if @kinds.include?(role)
          effective_kinds << role
          issue(result, 'warnings', 'deprecated_structural_object_role', "Use assessment.object_kind for legacy structural object_role #{role.inspect}")
        end
        # SAIL §6.11: object-role OR structural-kind eligibility, not both.
        unless predicate['allowed_object_roles'].include?(role) || (effective_kinds & predicate['allowed_object_kinds']).any?
          issue(result, 'errors', 'object_not_allowed', "assessment object role/kind is not allowed for #{hint['claim']}")
        end
      end

      allowed_scopes = predicate['allowed_scope_by_subject_role']
      if missing_subject
        unless allowed_scopes.values.flatten.uniq.include?(hint['scope'])
          issue(result, 'errors', 'scope_not_allowed_for_any_legal_subject', "assessment.scope #{hint['scope'].inspect} is impossible for every legal #{hint['claim']} subject")
        end
      elsif allowed_scopes.key?(subject) && !allowed_scopes[subject].include?(hint['scope'])
        issue(result, 'errors', 'scope_not_allowed_for_subject', "assessment.scope #{hint['scope'].inspect} is not allowed for #{subject} + #{hint['claim']}")
      end

      if %w[1.3 1.4 1.5].include?(version) && (missing_subject || missing_object)
        issue(result, 'errors', 'complete_hint_required', "schema v#{version} requires subject_role and object_role or object_kind")
      end
      result['coverage']['complete'] = result['errors'].empty? && !missing_subject && !missing_object
      result['status'] = if result['errors'].any?
        'incompatible'
      elsif missing_subject || missing_object
        'incomplete'
      else
        'candidate_compatible'
      end
      result
    end

    private

    def issue(result, bucket, code, message)
      result[bucket] << {'code' => code, 'message' => message}
    end
  end
end
