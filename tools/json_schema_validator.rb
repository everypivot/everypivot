module EveryPivot
  class JsonSchemaValidator
    def initialize(schema)
      @schema = schema
    end

    def validate(instance)
      validate_fragment(@schema, instance, [])
    end

    private

    def validate_fragment(schema, instance, path)
      return [] unless schema.is_a?(Hash)

      errors = []

      Array(schema['allOf']).each do |subschema|
        errors.concat(validate_fragment(subschema, instance, path))
      end

      if schema.key?('if')
        if validate_fragment(schema['if'], instance, path).empty?
          errors.concat(validate_fragment(schema['then'], instance, path)) if schema.key?('then')
        elsif schema.key?('else')
          errors.concat(validate_fragment(schema['else'], instance, path))
        end
      end

      if schema.key?('oneOf')
        matches = Array(schema['oneOf']).count do |subschema|
          validate_fragment(subschema, instance, path).empty?
        end

        errors << "#{format_path(path)} must match exactly one allowed schema shape" unless matches == 1
      end

      if schema.key?('anyOf')
        matches = Array(schema['anyOf']).count do |subschema|
          validate_fragment(subschema, instance, path).empty?
        end

        errors << "#{format_path(path)} must match at least one allowed schema shape" if matches.zero?
      end

      if schema.key?('type')
        expected_type = schema['type']
        unless matches_type?(expected_type, instance)
          errors << "#{format_path(path)} must be #{article(expected_type)} #{expected_type}"
          return errors
        end
      end

      if schema.key?('enum') && !Array(schema['enum']).include?(instance)
        allowed = Array(schema['enum']).map { |value| value.inspect }.join(', ')
        errors << "#{format_path(path)} must be one of #{allowed}"
      end

      if schema.key?('const') && instance != schema['const']
        errors << "#{format_path(path)} must equal #{schema['const'].inspect}"
      end

      if instance.is_a?(Hash)
        errors.concat(validate_object(schema, instance, path))
      elsif instance.is_a?(Array)
        errors.concat(validate_array(schema, instance, path))
      end

      errors
    end

    def validate_object(schema, instance, path)
      errors = []
      properties = schema['properties'].is_a?(Hash) ? schema['properties'] : {}

      Array(schema['required']).each do |field|
        errors << "#{format_path(path + [field])} is required" unless instance.key?(field)
      end

      properties.each do |key, subschema|
        next unless instance.key?(key)

        errors.concat(validate_fragment(subschema, instance[key], path + [key]))
      end

      additional_properties = schema.fetch('additionalProperties', true)
      unknown_keys = instance.keys - properties.keys

      if additional_properties == false
        unknown_keys.each do |key|
          errors << "#{format_path(path + [key])} is not allowed"
        end
      elsif additional_properties.is_a?(Hash)
        unknown_keys.each do |key|
          errors.concat(validate_fragment(additional_properties, instance[key], path + [key]))
        end
      end

      errors
    end

    def validate_array(schema, instance, path)
      errors = []

      if schema.key?('minItems') && instance.length < schema['minItems']
        errors << "#{format_path(path)} must contain at least #{schema['minItems']} item(s)"
      end

      items_schema = schema['items']
      return errors unless items_schema

      instance.each_with_index do |value, index|
        errors.concat(validate_fragment(items_schema, value, path + [index]))
      end

      errors
    end

    def matches_type?(expected_type, instance)
      case expected_type
      when 'object'
        instance.is_a?(Hash)
      when 'array'
        instance.is_a?(Array)
      when 'string'
        instance.is_a?(String)
      when 'integer'
        instance.is_a?(Integer)
      when 'number'
        instance.is_a?(Numeric)
      when 'boolean'
        instance == true || instance == false
      when 'null'
        instance.nil?
      else
        true
      end
    end

    def format_path(path)
      return 'document' if path.empty?

      path.each_with_index.map do |segment, index|
        if segment.is_a?(Integer)
          "[#{segment}]"
        elsif index.zero?
          segment.to_s
        else
          ".#{segment}"
        end
      end.join
    end

    def article(word)
      word.start_with?('a', 'e', 'i', 'o', 'u') ? 'an' : 'a'
    end
  end
end
