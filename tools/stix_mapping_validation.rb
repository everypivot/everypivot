# frozen_string_literal: true

require 'date'

module EveryPivot
  # Syntax/calendar validation of mapped fixture values, not traversal eligibility.
  module StixMappingValidation
    module_function

    DATE = /\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/.freeze
    TIMESTAMP = /\A[0-9]{4}-(?:0[1-9]|1[0-2])-(?:0[1-9]|[12][0-9]|3[01])T(?:[01][0-9]|2[0-3]):[0-5][0-9]:[0-5][0-9](?:\.[0-9]+)?Z\z/.freeze

    def timestamp(value, date_allowed: true, milliseconds_required: false)
      unless value.is_a?(String)
        raise ArgumentError, 'expected a calendar date or STIX UTC timestamp string'
      end
      if date_allowed && value.match?(DATE)
        return Date.iso8601(value).strftime('%Y-%m-%dT00:00:00.000Z')
      end
      if value.match?(/:60(?:\.[0-9]+)?Z\z/)
        raise ArgumentError, 'leap-second timestamp inputs are unsupported by this bounded mapper'
      end
      unless value.match?(TIMESTAMP)
        raise ArgumentError, 'expected a complete STIX UTC timestamp (YYYY-MM-DDTHH:mm:ss[.s+]Z)'
      end
      Date.iso8601(value[0, 10]) # Reject impossible calendar dates; do not normalize timestamps.
      if milliseconds_required && !value.match?(/\.[0-9]{3,}Z\z/)
        raise ArgumentError, 'created/modified must include at least millisecond precision'
      end
      value
    end

    def observation_date(value)
      Date.iso8601(timestamp(value)[0, 10])
    end

    def as_of_date(value)
      unless value.is_a?(String) && value.match?(DATE)
        raise ArgumentError, 'as_of must be a YYYY-MM-DD calendar date'
      end
      Date.iso8601(value)
    end

    # Full closure is this transport profile's restriction, not universal STIX.
    def creator_errors(objects, expected_ref)
      errors = []
      objects = Array(objects)
      return ['all bundle objects must be objects'] unless objects.all? { |o| o.is_a?(Hash) }
      ids = objects.map { |o| o['id'] }
      errors << 'duplicate object IDs' unless ids.uniq == ids
      by_id = objects.each_with_object({}) { |o, h| h[o['id']] = o }
      identities = objects.select { |o| o['type'] == 'identity' }
      errors << 'exactly one creator Identity must be included' unless identities.length == 1
      objects.select { |o| o['type'] == 'extension-definition' }.each do |ext|
        ref = ext['created_by_ref']
        if !ref.is_a?(String) || !ref.match?(/\Aidentity--[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/)
          errors << 'extension-definition.created_by_ref must be an Identity identifier'
        elsif by_id[ref].nil?
          errors << 'extension-definition.created_by_ref is dangling'
        elsif by_id[ref]['type'] != 'identity'
          errors << 'extension-definition.created_by_ref targets wrong object type'
        end
        errors << 'extension creator reference differs from declared fixture' unless ref == expected_ref
      end
      identities.each do |identity|
        errors << 'creator Identity differs from declared reference' unless identity['id'] == expected_ref
        errors << 'creator Identity must have spec_version 2.1' unless identity['spec_version'] == '2.1'
        errors << 'creator Identity name must be a nonempty string' unless identity['name'].is_a?(String) && !identity['name'].strip.empty?
        errors << 'creator Identity must describe a group' unless identity['identity_class'] == 'group'
        errors << 'creator Identity must not carry EveryPivot evidence metadata or extensions' if identity.key?('extensions') || identity.keys.any? { |k| k.start_with?('x_everypivot_') }
        begin
          %w[created modified].each { |k| timestamp(identity[k], date_allowed: false, milliseconds_required: true) }
          errors << 'creator modified precedes created' if DateTime.iso8601(identity['modified']) < DateTime.iso8601(identity['created'])
        rescue ArgumentError => e
          errors << "creator timestamp invalid: #{e.message}"
        end
      end
      objects.each do |o|
        refs = o.flat_map { |k, v| k.end_with?('_ref') ? [v] : k.end_with?('_refs') && v.is_a?(Array) ? v : [] }
        refs += (o['extensions'].is_a?(Hash) ? o['extensions'].keys : [])
        refs.each { |ref| errors << "profile reference is unresolved: #{ref.inspect}" unless by_id.key?(ref) }
      end
      errors
    end
  end
end
