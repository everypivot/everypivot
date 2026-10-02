# frozen_string_literal: true

require_relative 'semantic_time'

module EveryPivot
  # Validates supplied evidence encoding and references. This is not provenance
  # verification, corroboration, independence evaluation or assessment acceptance.
  # Attributes are raw source data. A boolean named match/accepted/verified has no
  # special authority here; evaluators must use only their declared predicates.
  module SemanticRecords
    CONTRACT = 'everypivot.semantic_evidence'
    VERSION = '1.0'
    KINDS = %w[entity assertion occurrence finding].freeze
    SOURCE_FIELDS = %w[id publisher document revision collection independent_origin].freeze
    RECORD_FIELDS = %w[id kind type attributes times evidence].freeze
    TIME_FIELDS = %w[binding field source_revision clock timezone precision interval_role value start end start_inclusive end_inclusive original_value alternatives].freeze

    class InvalidInput < StandardError
      attr_reader :errors

      def initialize(errors)
        @errors = errors.freeze
        super(errors.join('; '))
      end
    end

    module_function

    def utf8?(value)
      value.is_a?(String) && value.dup.force_encoding(Encoding::UTF_8).valid_encoding?
    end

    def text?(value)
      utf8?(value) && !value.strip.empty?
    end

    def closed_object(value, required, optional, path, errors)
      unless value.is_a?(Hash)
        errors << "#{path}: expected an object"
        return false
      end
      required.each { |key| errors << "#{path}.#{key}: required" unless value.key?(key) }
      (value.keys - required - optional).each { |key| errors << "#{path}.#{key}: undeclared field" }
      true
    end

    def string(value, path, errors, unknown: false)
      return if unknown && value.nil?
      errors << "#{path}: expected a nonblank string#{unknown ? ' or null for unknown' : ''}" unless text?(value)
    end

    # Values must be JSON data, including finite numbers. A cycle is invalid
    # encoding, rather than a recursive claim or a reason to silently omit data.
    def json_value(value, path, errors, ancestors = [])
      case value
      when Hash, Array
        if ancestors.include?(value.object_id)
          errors << "#{path}: cyclic data is not JSON"
          return
        end
        parents = ancestors + [value.object_id]
        if value.is_a?(Hash)
          value.each do |key, item|
            errors << "#{path}: JSON object keys must be UTF-8 strings" unless utf8?(key)
            json_value(item, "#{path}.#{key}", errors, parents)
          end
        else
          value.each_with_index { |item, i| json_value(item, "#{path}[#{i}]", errors, parents) }
        end
      when String
        errors << "#{path}: invalid UTF-8 string encoding" unless utf8?(value)
      when Float
        errors << "#{path}: nonfinite number is not JSON" unless value.finite?
      when Integer, TrueClass, FalseClass, NilClass
        nil
      else
        errors << "#{path}: value is not JSON data"
      end
    end

    def array(value, path, errors)
      return value if value.is_a?(Array)
      errors << "#{path}: expected an array"
      []
    end

    def unique_index(items, path, errors)
      items.each_with_index.each_with_object({}) do |(row, i), result|
        next unless row.is_a?(Hash) && text?(row['id'])
        if result.key?(row['id'])
          errors << "#{path}[#{i}].id: duplicate identity #{row['id'].inspect}"
        else
          result[row['id']] = row
        end
      end
    end

    def validate_source(source, path, errors)
      return unless closed_object(source, SOURCE_FIELDS, ['content_hash'], path, errors)
      string(source['id'], "#{path}.id", errors)
      (SOURCE_FIELDS - ['id']).each { |key| string(source[key], "#{path}.#{key}", errors, unknown: true) }
      return unless source.key?('content_hash') && !source['content_hash'].nil?
      digest = source['content_hash']
      return unless closed_object(digest, %w[algorithm value scope], [], "#{path}.content_hash", errors)
      errors << "#{path}.content_hash.algorithm: only sha256 is supported in v1.0" unless digest['algorithm'] == 'sha256'
      unless digest['value'].is_a?(String) && digest['value'].match?(/\A[0-9a-f]{64}\z/)
        errors << "#{path}.content_hash.value: expected 64 lowercase hexadecimal characters"
      end
      string(digest['scope'], "#{path}.content_hash.scope", errors)
    end

    def validate_time(time, path, records, source_rows, errors)
      # Missing metadata is retained as unresolved by SemanticTime; supplied
      # malformed metadata and broken references remain invalid input.
      return unless closed_object(time, [], TIME_FIELDS, path, errors)
      %w[field source_revision timezone precision interval_role value start end original_value].each do |key|
        string(time[key], "#{path}.#{key}", errors, unknown: true) if time.key?(key)
      end
      %w[start_inclusive end_inclusive].each do |key|
        next unless time.key?(key) && !time[key].nil?
        errors << "#{path}.#{key}: expected boolean or null" unless time[key] == true || time[key] == false
      end
      if time['precision'] == 'interval' && time.key?('value')
        errors << "#{path}.value: interval cannot also supply a point value"
      elsif %w[instant second minute day month year].include?(time['precision'])
        (time.keys & %w[start end start_inclusive end_inclusive]).each do |key|
          errors << "#{path}.#{key}: point/coarse precision cannot also supply interval fields"
        end
      end
      if time.key?('binding') && !time['binding'].nil?
        if closed_object(time['binding'], [], %w[object occurrence], "#{path}.binding", errors)
          %w[object occurrence].each do |key|
            id = time['binding'][key]
            next if id.nil?
            string(id, "#{path}.binding.#{key}", errors)
            if text?(id) && !records.key?(id)
              errors << "#{path}.binding.#{key}: unknown record #{id.inspect}"
            end
          end
        end
      end
      if time.key?('clock') && !time['clock'].nil?
        if closed_object(time['clock'], [], %w[id reference uncertainty_seconds], "#{path}.clock", errors)
          %w[id reference].each { |key| string(time['clock'][key], "#{path}.clock.#{key}", errors, unknown: true) if time['clock'].key?(key) }
          uncertainty = time['clock']['uncertainty_seconds']
          unless uncertainty.nil? || ((uncertainty.is_a?(Integer) || uncertainty.is_a?(Float)) && uncertainty.finite? && uncertainty >= 0)
            errors << "#{path}.clock.uncertainty_seconds: expected nonnegative finite number or null"
          end
        end
      end
      if time.key?('alternatives')
        (time.keys - %w[alternatives original_value]).each do |key|
          errors << "#{path}.#{key}: alternatives container cannot supply parent time facts"
        end
        array(time['alternatives'], "#{path}.alternatives", errors).each_with_index do |alternative, i|
          validate_time(alternative, "#{path}.alternatives[#{i}]", records, source_rows, errors)
        end
      end
      revision = time['source_revision']
      if text?(revision) && source_rows.any? && source_rows.all? { |source| text?(source['revision']) }
        unless source_rows.any? { |source| source['revision'] == revision }
          errors << "#{path}.source_revision: no linked evidence source has revision #{revision.inspect}"
        end
      end
      begin
        SemanticTime.normalize(time)
      rescue SemanticTime::InvalidInput => e
        errors << "#{path}: #{e.message}"
      end
    end

    def validate_record(record, path, records, sources, errors)
      return unless closed_object(record, RECORD_FIELDS, %w[subject object], path, errors)
      string(record['id'], "#{path}.id", errors)
      string(record['type'], "#{path}.type", errors)
      errors << "#{path}.kind: expected #{KINDS.join(', ')}" unless KINDS.include?(record['kind'])
      errors << "#{path}.attributes: expected an object" unless record['attributes'].is_a?(Hash)
      %w[subject object].each do |key|
        next unless record.key?(key)
        id = record[key]
        string(id, "#{path}.#{key}", errors)
        errors << "#{path}.#{key}: unknown record #{id.inspect}" if text?(id) && !records.key?(id)
      end
      source_rows = []
      array(record['evidence'], "#{path}.evidence", errors).each_with_index do |reference, i|
        reference_path = "#{path}.evidence[#{i}]"
        next unless closed_object(reference, %w[source_id field], [], reference_path, errors)
        string(reference['source_id'], "#{reference_path}.source_id", errors)
        string(reference['field'], "#{reference_path}.field", errors)
        if text?(reference['source_id'])
          source = sources[reference['source_id']]
          source ? source_rows << source : errors << "#{reference_path}.source_id: unknown source #{reference['source_id'].inspect}"
        end
      end
      unless record['times'].is_a?(Hash)
        errors << "#{path}.times: expected an object"
        return
      end
      record['times'].each do |key, time|
        string(key, "#{path}.times key", errors)
        validate_time(time, "#{path}.times.#{key}", records, source_rows, errors)
      end
    end

    def validate(input)
      errors = []
      json_value(input, 'evidence', errors)
      return errors unless errors.empty?
      return errors unless closed_object(input, %w[contract version collection_id sources records], [], 'evidence', errors)
      errors << "evidence.contract: expected #{CONTRACT}" unless input['contract'] == CONTRACT
      errors << "evidence.version: expected #{VERSION.inspect}" unless input['version'] == VERSION
      string(input['collection_id'], 'evidence.collection_id', errors)
      source_rows = array(input['sources'], 'evidence.sources', errors)
      record_rows = array(input['records'], 'evidence.records', errors)
      sources = unique_index(source_rows, 'evidence.sources', errors)
      records = unique_index(record_rows, 'evidence.records', errors)
      source_rows.each_with_index { |source, i| validate_source(source, "evidence.sources[#{i}]", errors) }
      record_rows.each_with_index { |record, i| validate_record(record, "evidence.records[#{i}]", records, sources, errors) }
      errors.uniq
    end

    # The returned lookups preserve supplied records byte-for-value: validation
    # never fills missing provenance, timestamps, independence or match status.
    def index(input)
      errors = validate(input)
      raise InvalidInput, errors unless errors.empty?
      {'records' => input['records'].to_h { |row| [row['id'], row] },
       'sources' => input['sources'].to_h { |row| [row['id'], row] }}
    end
  end
end
