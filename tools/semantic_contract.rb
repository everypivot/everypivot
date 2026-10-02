# frozen_string_literal: true

require 'json'
require 'digest'
require 'pathname'
require_relative 'utf8_text'
require_relative 'semantic_identity'

module EveryPivot
  # Compiler for the deliberately finite semantic contract vocabulary. Legacy
  # temporal.order strings are never parsed or evaluated by this module.
  module SemanticContract
    ID = 'everypivot.semantic_pattern'.freeze
    VERSION = '1.0'.freeze
    KINDS = %w[entity assertion occurrence finding].freeze
    PARAMETER_TYPES = %w[string integer boolean record_id selector period time date string_array].freeze
    OPERATORS = %w[all any not eq ne in contains all_in present nonblank_text nonblank_text_array nonnegative_integer binding_absent typed_equal time_compare time_compare_if_present within coexists content_matches uri_component_equal file_set_equal file_set_shared_paths ip_in_prefix package_repository_declaration package_repository_observation certificate_profile_matches ct_name_in_scope].freeze
    FORBIDDEN_RESULT_FIELDS = %w[confidence confidence_score accepted assessment accepted_assessment final_assessment maliciousness attribution authority independence corroboration ownership control].freeze
    NAME = /\A[a-z][a-z0-9_]*\z/.freeze
    REF = /\A[a-z][a-z0-9_]*(?:\.[a-zA-Z0-9_:-]+)*\z/.freeze
    class InvalidContract < StandardError; end
    class UnsupportedContract < StandardError; end
    class UniqueObject < Hash
      def []=(key, value)
        raise InvalidContract, "duplicate JSON member #{key}" if key?(key)
        super
      end
    end
    module_function

    def parse(text)
      JSON.parse(text, object_class: UniqueObject, max_nesting: 64)
    end

    def json_errors(value, path = '$', ancestors = [], depth = 0)
      return ["#{path} exceeds the JSON nesting limit"] if depth > 64
      case value
      when Hash, Array
        return ["#{path} contains cyclic data"] if ancestors.include?(value.object_id)
        seen = ancestors + [value.object_id]
        if value.is_a?(Hash)
          value.flat_map do |key, entry|
            (key.is_a?(String) ? [] : ["#{path} has a non-string key"]) + json_errors(entry, "#{path}.#{key}", seen, depth + 1)
          end
        else
          value.each_with_index.flat_map { |entry, i| json_errors(entry, "#{path}[#{i}]", seen, depth + 1) }
        end
      when String then value.valid_encoding? ? [] : ["#{path} has invalid text encoding"]
      when Float then value.finite? ? [] : ["#{path} has a nonfinite number"]
      when Integer, TrueClass, FalseClass, NilClass then []
      else ["#{path} is not JSON data"]
      end
    end

    def closed(value, required, optional, path, errors)
      unless value.is_a?(Hash)
        errors << "#{path} must be an object"
        return false
      end
      (required - value.keys).each { |k| errors << "#{path}.#{k} is required" }
      (value.keys - required - optional).each { |k| errors << "#{path}.#{k} is unknown" }
      true
    end

    def text(value, path, errors)
      errors << "#{path} must be a nonblank string" unless value.is_a?(String) && !value.strip.empty?
    end

    def names(value, path, errors, allow_empty: false)
      unless value.is_a?(Array) && (allow_empty || !value.empty?) && value.all? { |v| v.is_a?(String) && !v.empty? }
        errors << "#{path} must be #{allow_empty ? 'an' : 'a nonempty'} array of strings"
        return []
      end
      errors << "#{path} contains duplicates" unless value.uniq == value
      value
    end

    def operand(value, variables, parameters, path, errors)
      return unless closed(value, [], %w[ref param literal context selector_identity evidence_sources calendar_period], path, errors)
      if value.keys.size != 1
        errors << "#{path} must select one explicit operand kind"
      elsif value.key?('ref') || value.key?('selector_identity')
        ref = value['ref'] || value['selector_identity']
        if !ref.is_a?(String) || !REF.match?(ref)
          errors << "#{path}.ref is not a field reference"
        elsif !variables.include?(ref.split('.').first)
          errors << "#{path}.ref refers to an unbound variable"
        end
      elsif value.key?('param')
        errors << "#{path}.param is undeclared" unless parameters.include?(value['param'])
      elsif value.key?('context')
        errors << "#{path}.context is unsupported" unless value['context'] == 'collection_id'
      elsif value.key?('evidence_sources')
        errors << "#{path}.evidence_sources must name a bound record" unless variables.include?(value['evidence_sources'])
      elsif value.key?('calendar_period')
        window = value['calendar_period']
        if closed(window, %w[query_date days], [], path + '.calendar_period', errors)
          date = window['query_date']
          valid_date = date.is_a?(Hash) && date.keys == ['param'] && parameters.is_a?(Hash) && parameters.dig(date['param'], 'type') == 'date'
          errors << "#{path}.calendar_period.query_date must name a date parameter" unless valid_date
          days = window['days']
          n = days['literal'] if days.is_a?(Hash)
          valid_days = days.is_a?(Hash) && days.keys == ['literal'] && n.is_a?(Numeric) && n.finite? && n >= 0 && n.to_i == n
          errors << "#{path}.calendar_period.days must be a nonnegative integer literal" unless valid_days
        end
      end
    end

    def time_refs(value)
      case value
      when Hash
        own = value['ref'].is_a?(String) && value['ref'].include?('.times.') ? [value['ref']] : []
        own + value.values.flat_map { |v| time_refs(v) }
      when Array then value.flat_map { |v| time_refs(v) }
      else []
      end
    end

    def temporal_operand(value, variables, parameters, path, errors, record_only: false)
      operand(value, variables, parameters, path, errors)
      return unless value.is_a?(Hash)
      if value.key?('ref')
        unless value['ref'].is_a?(String) && value['ref'].match?(/\A[a-z][a-z0-9_]*\.times\.[a-zA-Z0-9_:-]+\z/)
          errors << "#{path} must name a record.times field with an explicit binding"
        end
      elsif record_only || !value.key?('param')
        errors << "#{path} must bind a record time#{record_only ? '' : ' or declared time parameter'}"
      elsif parameters.is_a?(Hash) && parameters.dig(value['param'], 'type') != 'time'
        errors << "#{path}.param must have declared time type"
      end
    end

    def expression(value, variables, parameters, path, errors, depth = 0)
      if depth > 24
        errors << "#{path} exceeds the expression nesting limit"
        return
      end
      return unless value.is_a?(Hash) || (errors << "#{path} must be an expression"; false)
      op = value['op']
      unless OPERATORS.include?(op)
        errors << "#{path}.op is unsupported: #{op.inspect}"
        return
      end
      case op
      when 'all', 'any'
        closed(value, %w[op args], [], path, errors)
        args = value['args']
        if !args.is_a?(Array) || args.empty?
          errors << "#{path}.args must be nonempty"
        else
          args.each_with_index { |v, i| expression(v, variables, parameters, "#{path}.args[#{i}]", errors, depth + 1) }
        end
      when 'not'
        closed(value, %w[op arg], [], path, errors)
        expression(value['arg'], variables, parameters, "#{path}.arg", errors, depth + 1)
      when 'present', 'nonblank_text', 'nonblank_text_array', 'nonnegative_integer'
        closed(value, %w[op value], [], path, errors)
        operand(value['value'], variables, parameters, "#{path}.value", errors)
      when 'binding_absent'
        closed(value, %w[op binding], [], path, errors)
        errors << "#{path}.binding must name an already declared optional binding" unless variables.include?(value['binding'])
      when 'content_matches'
        keys = %w[record source sha256 byte_length representation]
        closed(value, ['op'] + keys, [], path, errors)
        keys.each { |key| operand(value[key], variables, parameters, "#{path}.#{key}", errors) }
        ref = value.dig('record', 'ref') if value['record'].is_a?(Hash)
        errors << "#{path}.record must name a bound record ID" unless ref.is_a?(String) && ref.match?(/\A[a-z][a-z0-9_]*\.id\z/)
      when 'file_set_equal', 'file_set_shared_paths', 'ip_in_prefix'
        keys = op == 'ip_in_prefix' ? %w[address prefix] : op == 'file_set_shared_paths' ? %w[left right paths] : %w[left right]
        closed(value, ['op'] + keys, op == 'file_set_equal' ? ['scope_kind'] : [], path, errors)
        if value.key?('scope_kind') && !%w[collected_file_set declared_subset].include?(value['scope_kind'])
          errors << "#{path}.scope_kind must be collected_file_set or declared_subset"
        end
        keys.each { |key| operand(value[key], variables, parameters, "#{path}.#{key}", errors) }
        (op == 'ip_in_prefix' ? ['prefix'] : %w[left right]).each do |key|
          ref = value.dig(key, 'ref') if value[key].is_a?(Hash)
          errors << "#{path}.#{key} must name a bound record ID" unless ref.is_a?(String) && ref.match?(/\A[a-z][a-z0-9_]*\.id\z/)
        end
      when 'package_repository_declaration'
        keys = %w[declaration package repository sidecar metadata]
        closed(value, ['op'] + keys, [], path, errors)
        keys.each do |key|
          operand(value[key], variables, parameters, "#{path}.#{key}", errors)
          ref = value.dig(key, 'ref') if value[key].is_a?(Hash)
          errors << "#{path}.#{key} must name a bound record ID" unless ref.is_a?(String) && ref.match?(/\A[a-z][a-z0-9_]*\.id\z/)
        end
      when 'package_repository_observation'
        closed(value, %w[op observation period], [], path, errors)
        %w[observation period].each { |key| operand(value[key], variables, parameters, "#{path}.#{key}", errors) }
        ref = value.dig('observation', 'ref') if value['observation'].is_a?(Hash)
        errors << "#{path}.observation must name a bound record ID" unless ref.is_a?(String) && ref.match?(/\A[a-z][a-z0-9_]*\.id\z/)
        if value['period'].is_a?(Hash) && value['period'].key?('param') && parameters.is_a?(Hash) && parameters.dig(value['period']['param'], 'type') != 'period'
          errors << "#{path}.period.param must have declared period type"
        end
      when 'certificate_profile_matches'
        closed(value, %w[op certificate profile family], [], path, errors)
        %w[certificate profile].each do |key|
          operand(value[key], variables, parameters, "#{path}.#{key}", errors)
          ref = value.dig(key, 'ref') if value[key].is_a?(Hash)
          errors << "#{path}.#{key} must name a bound record ID" unless ref.is_a?(String) && ref.match?(/\A[a-z][a-z0-9_]*\.id\z/)
        end
        errors << "#{path}.family is unsupported" unless %w[subject issuer_validity short_lived].include?(value['family'])
      when 'ct_name_in_scope'
        closed(value, %w[op name seed], [], path, errors)
        %w[name seed].each { |key| operand(value[key], variables, parameters, "#{path}.#{key}", errors) }
      when 'uri_component_equal'
        closed(value, %w[op uri component right], [], path, errors)
        %w[uri right].each { |key| operand(value[key], variables, parameters, "#{path}.#{key}", errors) }
        errors << "#{path}.component must be url, dns_host, host_kind or scheme" unless %w[url dns_host host_kind scheme].include?(value['component'])
      when 'coexists'
        closed(value, %w[op values period], [], path, errors)
        if value['values'].is_a?(Array) && !value['values'].empty?
          value['values'].each_with_index { |v, i| temporal_operand(v, variables, parameters, "#{path}.values[#{i}]", errors) }
        else
          errors << "#{path}.values must contain established time operands"
        end
        operand(value['period'], variables, parameters, "#{path}.period", errors)
        if value['period'].is_a?(Hash) && value['period'].key?('param') && parameters.is_a?(Hash) && parameters.dig(value['period']['param'], 'type') != 'period'
          errors << "#{path}.period.param must have declared period type"
        end
      when 'within'
        closed(value, %w[op value period quantifier], %w[at], path, errors)
        temporal_operand(value['value'], variables, parameters, "#{path}.value", errors)
        operand(value['period'], variables, parameters, "#{path}.period", errors)
        if value['period'].is_a?(Hash) && value['period'].key?('param') && parameters.is_a?(Hash) && parameters.dig(value['period']['param'], 'type') != 'period'
          errors << "#{path}.period.param must have declared period type"
        end
        errors << "#{path}.quantifier must be contained, all, some or at" unless %w[contained all some at].include?(value['quantifier'])
        temporal_operand(value['at'], variables, parameters, "#{path}.at", errors) if value.key?('at')
        errors << "#{path}.at required for at quantifier" if value['quantifier'] == 'at' && !value.key?('at')
      else
        temporal = %w[time_compare time_compare_if_present].include?(op)
        optional = temporal ? ['operator'] : []
        closed(value, %w[op left right] + optional, [], path, errors)
        %w[left right].each do |k|
          temporal ? temporal_operand(value[k], variables, parameters, "#{path}.#{k}", errors) : operand(value[k], variables, parameters, "#{path}.#{k}", errors)
        end
        if temporal && !%w[lt lte eq].include?(value['operator'])
          errors << "#{path}.operator must be lt, lte or eq"
        end
      end
    end

    def validate(document)
      errors = json_errors(document)
      return errors unless errors.empty?
      return ['contract must be an object'] unless document.is_a?(Hash)
      closed(document, %w[contract version pattern parameters branches], %w[description authority], '$', errors)
      errors << 'unsupported contract identity' unless document['contract'] == ID
      errors << 'unsupported contract version' unless document['version'] == VERSION
      if closed(document['pattern'], %w[id version], [], '$.pattern', errors)
        %w[id version].each { |k| text(document['pattern'][k], "$.pattern.#{k}", errors) }
      end
      params = document['parameters']
      unless params.is_a?(Hash)
        errors << '$.parameters must be an object'
        params = {}
      end
      params.each do |name, definition|
        errors << "parameter name #{name.inspect} is invalid" unless name.is_a?(String) && NAME.match?(name)
        next unless closed(definition, %w[type required description], %w[enum selector_kinds requires_when allowed_when min_items unique_items item_reference], "parameter #{name}", errors)
        errors << "parameter #{name} type is unsupported" unless PARAMETER_TYPES.include?(definition['type'])
        errors << "parameter #{name}.required must be boolean" unless [true, false].include?(definition['required'])
        text(definition['description'], "parameter #{name}.description", errors)
        if definition.key?('min_items')
          min = definition['min_items']
          valid = definition['type'] == 'string_array' && min.is_a?(Numeric) && min.finite? && min >= 0 && min.to_i == min
          errors << "parameter #{name}.min_items requires string_array and nonnegative mathematical integer" unless valid
        end
        if definition.key?('unique_items')
          errors << "parameter #{name}.unique_items requires string_array and boolean" unless definition['type'] == 'string_array' && [true, false].include?(definition['unique_items'])
        end
        if definition.key?('item_reference')
          errors << "parameter #{name}.item_reference requires string_array and source or record" unless definition['type'] == 'string_array' && %w[source record].include?(definition['item_reference'])
        end
        if definition.key?('enum')
          choices = definition['enum']
          valid = choices.is_a?(Array) && !choices.empty? && choices.uniq == choices && choices.all? do |v|
            case definition['type']
            when 'string', 'record_id', 'date' then v.is_a?(String) && !v.empty?
            when 'integer' then v.is_a?(Numeric) && v.finite? && v.to_i == v
            when 'boolean' then v == true || v == false
            else false
            end
          end
          errors << "parameter #{name}.enum must contain distinct values of its scalar type" unless valid
        end
        if definition.key?('selector_kinds')
          errors << "parameter #{name}.selector_kinds requires selector type" unless definition['type'] == 'selector'
          kinds = names(definition['selector_kinds'], "parameter #{name}.selector_kinds", errors)
          errors << "parameter #{name}.selector_kinds contains unsupported kinds" unless (kinds - SemanticIdentity::KINDS).empty?
        end
        %w[requires_when allowed_when].each do |condition|
          next unless definition.key?(condition)
          rule = definition[condition]
          if closed(rule, %w[parameter values], [], "parameter #{name}.#{condition}", errors)
            other = params[rule['parameter']]
            choices = rule['values']
            valid = other.is_a?(Hash) && other['enum'].is_a?(Array) && choices.is_a?(Array) && !choices.empty? && (choices - other['enum']).empty?
            errors << "parameter #{name}.#{condition} must select declared choices of another parameter" unless valid && rule['parameter'] != name
          end
        end
      end
      branches = document['branches']
      return errors + ['branches must be a nonempty array'] unless branches.is_a?(Array) && !branches.empty?
      ids = []
      branches.each_with_index do |branch, i|
        path = "$.branches[#{i}]"
        next unless closed(branch, %w[id bindings where result], %w[description policies knowledge knowledge_checks time_bindings finding amendments select_when], path, errors)
        errors << "#{path}.id invalid or duplicate" unless branch['id'].is_a?(String) && NAME.match?(branch['id']) && !ids.include?(branch['id'])
        ids << branch['id']
        if branch.key?('select_when')
          guard = branch['select_when']
          if closed(guard, %w[parameter values], [], "#{path}.select_when", errors)
            selected = params[guard['parameter']]
            values = guard['values']
            valid = selected.is_a?(Hash) && selected['required'] == true && selected['enum'].is_a?(Array) && values.is_a?(Array) && !values.empty? && values.uniq == values && (values - selected['enum']).empty?
            errors << "#{path}.select_when must select distinct choices of a required enum parameter" unless valid
          end
        end
        variables = []
        bindings = branch['bindings']
        unless bindings.is_a?(Array) && !bindings.empty?
          errors << "#{path}.bindings must be nonempty"
          next
        end
        bindings.each_with_index do |binding, j|
          bp = "#{path}.bindings[#{j}]"
          next unless closed(binding, %w[name kind types], %w[where optional query_seed priority], bp, errors)
          name = binding['name']
          errors << "#{bp}.name invalid or reused" unless name.is_a?(String) && NAME.match?(name) && !variables.include?(name)
          variables << name
          errors << "#{bp}.kind unsupported" unless KINDS.include?(binding['kind'])
          names(binding['types'], "#{bp}.types", errors)
          errors << "#{bp}.optional must be boolean" if binding.key?('optional') && ![true, false].include?(binding['optional'])
          if binding.key?('query_seed')
            errors << "#{bp}.query_seed must be boolean" unless [true, false].include?(binding['query_seed'])
            if binding['query_seed']
              where = binding['where']
              valid_seed = binding['kind'] == 'entity' && !binding['optional'] && where.is_a?(Hash) && where['op'] == 'eq' &&
                where['left'] == {'ref' => "#{name}.id"} && where['right'].is_a?(Hash) && params.dig(where['right']['param'], 'type') == 'record_id'
              errors << "#{bp}.query_seed requires a required entity selected by exact record_id parameter" unless valid_seed
            end
          end
          expression(binding['where'], variables, params, "#{bp}.where", errors) if binding.key?('where')
          if binding.key?('priority')
            priority = binding['priority']
            if closed(priority, %w[time period], [], "#{bp}.priority", errors)
              temporal_operand(priority['time'], variables, params, "#{bp}.priority.time", errors, record_only: true)
              ref = priority.dig('time', 'ref') if priority['time'].is_a?(Hash)
              errors << "#{bp}.priority.time must bind this occurrence's own time" unless binding['kind'] == 'occurrence' && ref.is_a?(String) && ref.start_with?(name.to_s + '.times.')
              operand(priority['period'], variables, params, "#{bp}.priority.period", errors)
              if priority['period'].is_a?(Hash) && priority['period'].key?('param')
                errors << "#{bp}.priority.period parameter must have period type" unless params.dig(priority['period']['param'], 'type') == 'period'
              end
            end
          end
        end
        expression(branch['where'], variables, params, "#{path}.where", errors)
        check_absence = lambda do |node|
          if node.is_a?(Hash)
            if node['op'] == 'binding_absent'
              target = bindings.find { |b| b.is_a?(Hash) && b['name'] == node['binding'] }
              errors << "#{path}.binding_absent must reference an optional binding" unless target && target['optional']
            end
            node.each_value { |v| check_absence.call(v) }
          elsif node.is_a?(Array)
            node.each { |v| check_absence.call(v) }
          end
        end
        check_absence.call(branch)
        if branch.key?('amendments')
          spec = branch['amendments']
          ap = "#{path}.amendments"
          if closed(spec, %w[support sources mode], %w[exclusion_parameter excluded_states exclusion_support], ap, errors)
            errors << "#{ap}.mode is unsupported" unless %w[retain_reports require_unwithdrawn_in_scope].include?(spec['mode'])
            supported = names(spec['support'], "#{ap}.support", errors)
            required = bindings.select { |b| b.is_a?(Hash) && !b['optional'] && %w[assertion occurrence].include?(b['kind']) }.map { |b| b['name'] }
            errors << "#{ap}.support must include every required assertion or occurrence, and no other bindings" unless supported.sort == required.sort
            source = spec['sources']
            valid_source = source.is_a?(Hash) && source.keys == ['param'] && params.dig(source['param'], 'type') == 'string_array' && params.dig(source['param'], 'required') == true
            errors << "#{ap}.sources must name a required explicit source-ID array parameter" unless valid_source
            if spec.key?('exclusion_parameter') || spec.key?('excluded_states') || spec.key?('exclusion_support')
              errors << "#{ap}.exclusion_parameter requires retain_reports and a declared boolean parameter" unless spec['mode'] == 'retain_reports' && params.dig(spec['exclusion_parameter'], 'type') == 'boolean'
              states = spec['excluded_states']
              errors << "#{ap}.excluded_states requires distinct withdrawn/corrected choices" unless states.is_a?(Array) && !states.empty? && states.uniq == states && (states - %w[withdrawn corrected]).empty?
              excluded_support = names(spec['exclusion_support'], "#{ap}.exclusion_support", errors)
              errors << "#{ap}.exclusion_support must select explicit supported assertion/occurrence bindings" unless (excluded_support - supported).empty?
            end
          end
          if branch.key?('finding') && (spec['mode'] != 'retain_reports' || spec.key?('exclusion_parameter'))
            errors << "#{ap}: first-finding branches admit retained amendment context only, without amendment-state exclusion"
          end
        end
        if branch.key?('knowledge')
          if branch['knowledge'].is_a?(Array) && !branch['knowledge'].empty?
            branch['knowledge'].each_with_index { |v, j| temporal_operand(v, variables, params, "#{path}.knowledge[#{j}]", errors, record_only: true) }
          else
            errors << "#{path}.knowledge must be a nonempty operand array"
          end
        end
        if branch.key?('knowledge_checks')
          checks = branch['knowledge_checks']
          if checks.is_a?(Array) && !checks.empty? && branch.key?('knowledge')
            checks.each_with_index { |check, j| expression(check, variables, params, "#{path}.knowledge_checks[#{j}]", errors) }
          else
            errors << "#{path}.knowledge_checks requires knowledge and a nonempty predicate array"
          end
        end
        declared_times = []
        time_bindings = branch.fetch('time_bindings', [])
        if time_bindings.is_a?(Array)
          time_bindings.each_with_index do |binding, j|
            tp = "#{path}.time_bindings[#{j}]"
            next unless closed(binding, %w[value object occurrence], [], tp, errors)
            %w[value object occurrence].each { |k| operand(binding[k], variables, params, "#{tp}.#{k}", errors) }
            ref = binding.dig('value', 'ref') if binding['value'].is_a?(Hash)
            errors << "#{tp}.value must name a record time field" unless ref.is_a?(String) && ref.include?('.times.')
            errors << "#{tp}.value is duplicated" if declared_times.include?(ref)
            declared_times << ref
          end
        else
          errors << "#{path}.time_bindings must be an array"
        end
        used_times = time_refs(branch.reject { |k, _| k == 'time_bindings' }).uniq
        (used_times - declared_times).each { |ref| errors << "#{path}: #{ref} lacks explicit object/occurrence binding" }
        if branch.key?('finding')
          finding = branch['finding']
          fp = "#{path}.finding"
          if closed(finding, %w[id revision identity support history period], %w[reference_support], fp, errors)
            %w[id revision].each { |key| text(finding[key], "#{fp}.#{key}", errors) }
            support = names(finding['support'], "#{fp}.support", errors)
            support.each do |name|
              definition = bindings.find { |b| b.is_a?(Hash) && b['name'] == name }
              errors << "#{fp}.support must reference required bindings" unless definition && !definition['optional']
            end
            mandatory = bindings.select { |b| b.is_a?(Hash) && !b['optional'] && !b['query_seed'] }.map { |b| b['name'] }
            reference = finding.key?('reference_support') ? names(finding['reference_support'], "#{fp}.reference_support", errors) : []
            errors << "#{fp}.reference_support must be distinct required non-seed bindings" unless (reference - mandatory).empty? && (reference & support).empty?
            (mandatory - support - reference).each { |name| errors << "#{fp}.support omits required binding #{name}" }
            identities = finding['identity']
            if identities.is_a?(Array) && !identities.empty?
              identities.each_with_index do |v, j|
                operand(v, variables, params, "#{fp}.identity[#{j}]", errors)
                ref = v['ref'] if v.is_a?(Hash)
                if ref.is_a?(String) && (ref.include?('.times.') || ref.match?(/\.(?:tool_version|run_id|received_at|ingested_at)(?:\.|$)/))
                  errors << "#{fp}.identity cannot derive novelty from time, processing or receipt metadata"
                end
              end
            else
              errors << "#{fp}.identity requires explicit stable semantic components"
            end
            %w[history period].each { |key| operand(finding[key], variables, params, "#{fp}.#{key}", errors) }
          end
        end
        result = branch['result']
        if closed(result, %w[mode form identity fields], %w[binding], "#{path}.result", errors)
          errors << "#{path}.result.mode unsupported" unless %w[bound construct].include?(result['mode'])
          text(result['form'], "#{path}.result.form", errors)
          if result['mode'] == 'bound'
            errors << "#{path}.result.binding is unbound" unless variables.include?(result['binding'])
          elsif result.key?('binding')
            errors << "#{path}.result.binding only applies to bound results"
          end
          identity = result['identity']
          if identity.is_a?(Array) && !identity.empty?
            identity.each_with_index { |v, j| operand(v, variables, params, "#{path}.result.identity[#{j}]", errors) }
          else
            errors << "#{path}.result.identity must be a nonempty operand array"
          end
          fields = result['fields']
          if fields.is_a?(Hash)
            fields.each do |k, v|
              errors << "#{path}.result.fields.#{k} cannot manufacture an assessment or inferred authority" if FORBIDDEN_RESULT_FIELDS.include?(k)
              operand(v, variables, params, "#{path}.result.fields.#{k}", errors)
            end
          else
            errors << "#{path}.result.fields must be an object"
          end
        end
        policies = branch.fetch('policies', [])
        if policies.is_a?(Array)
          policy_ids = []
          policies.each_with_index do |policy, j|
            pp = "#{path}.policies[#{j}]"
            next unless closed(policy, %w[id revision scope subject when reason default_enabled], %w[enabled_parameter conflict_when required_evaluation allow_when applies_when partition_by], pp, errors)
            %w[id revision reason].each { |k| text(policy[k], "#{pp}.#{k}", errors) }
            errors << "#{pp}.id duplicate" if policy_ids.include?(policy['id'])
            policy_ids << policy['id']
            errors << "#{pp}.scope unsupported" unless %w[source path occurrence result].include?(policy['scope'])
            if policy.key?('enabled_parameter')
              errors << "#{pp}.enabled_parameter must name a boolean parameter" unless params.dig(policy['enabled_parameter'], 'type') == 'boolean'
            end
            errors << "#{pp}.default_enabled must be explicit boolean" unless [true, false].include?(policy['default_enabled'])
            operand(policy['subject'], variables, params, "#{pp}.subject", errors)
            if policy.key?('partition_by')
              parts = policy['partition_by']
              if parts.is_a?(Array) && !parts.empty? && parts.length <= 16
                parts.each_with_index { |part, k| operand(part, variables, params, "#{pp}.partition_by[#{k}]", errors) }
              else
                errors << "#{pp}.partition_by requires 1 to 16 explicit operands"
              end
            end
            expression(policy['when'], variables, params, "#{pp}.when", errors)
            expression(policy['conflict_when'], variables, params, "#{pp}.conflict_when", errors) if policy.key?('conflict_when')
            %w[allow_when applies_when].each { |key| expression(policy[key], variables, params, "#{pp}.#{key}", errors) if policy.key?(key) }
            errors << "#{pp}.required_evaluation must be boolean" if policy.key?('required_evaluation') && ![true, false].include?(policy['required_evaluation'])
            errors << "#{pp}.required_evaluation needs a positive allow_when predicate" if policy['required_evaluation'] && !policy.key?('allow_when')
          end
        else
          errors << "#{path}.policies must be an array"
        end
      end
      errors
    end

    def compile(document)
      unless document.is_a?(Hash) && document['contract'] == ID && document['version'] == VERSION
        raise UnsupportedContract, 'unknown semantic contract identity or version'
      end
      errors = validate(document)
      raise InvalidContract, errors.join('; ') unless errors.empty?
      Marshal.load(Marshal.dump(document))
    end

    # Digest-check before parsing. Relative references cannot escape the package.
    def load_reference(reference, pattern, root:)
      errors = []
      closed(reference, %w[contract version path sha256], [], 'execution', errors)
      raise InvalidContract, errors.join('; ') unless errors.empty?
      raise UnsupportedContract, 'unsupported execution reference' unless reference['contract'] == ID && reference['version'] == VERSION
      rel = reference['path']
      unless rel.is_a?(String) && rel.match?(/\Acontracts\/semantics\/[A-Z0-9_]+\.json\z/)
        raise InvalidContract, 'execution path must name a packaged semantic contract'
      end
      unless rel == "contracts/semantics/#{pattern['id']}.json"
        raise InvalidContract, 'execution filename must match the bound pattern ID'
      end
      package = File.realpath(root)
      path = File.realpath(File.join(package, rel))
      raise InvalidContract, 'execution reference escapes package' unless path.start_with?(package + File::SEPARATOR)
      bytes = File.binread(path)
      unless reference['sha256'].is_a?(String) && reference['sha256'].match?(/\A[0-9a-f]{64}\z/) && Digest::SHA256.hexdigest(bytes) == reference['sha256']
        raise InvalidContract, 'execution contract digest mismatch'
      end
      document = compile(parse(Utf8Text.decode(bytes, path: path)))
      unless document['pattern'] == {'id' => pattern['id'], 'version' => pattern['version']}
        raise InvalidContract, 'execution contract is bound to a different pattern identity/version'
      end
      forms = pattern['target'].to_s.split('|').map(&:strip)
      unless document['branches'].all? { |b| forms.include?(b.dig('result', 'form')) }
        raise InvalidContract, 'execution result form is outside declared pattern targets'
      end
      document
    rescue SystemCallError, JSON::ParserError, Utf8Text::Error => e
      raise InvalidContract, e.message
    end

    def canonical(value)
      case value
      when Hash then value.keys.sort.each_with_object({}) { |k, h| h[k] = canonical(value[k]) }
      when Array then value.map { |v| canonical(v) }
      else value
      end
    end

    def digest(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
    end
  end
end
