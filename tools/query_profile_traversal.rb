# frozen_string_literal: true

require 'date'
require_relative 'json_schema_validator'

module EveryPivot
  # Bounded one-hop fixture oracle; no temporal order, degree caps or evidence acceptance.
  module QueryProfileTraversal
    module_function

    def profile_date(value)
      unless value.is_a?(String) && value.match?(/\A[0-9]{4}-[0-9]{2}-[0-9]{2}\z/)
        raise ArgumentError, 'expected a YYYY-MM-DD calendar date (timestamps and time zones are unsupported)'
      end
      Date.iso8601(value)
    end

    def form_list(value)
      value.to_s.split('|').map(&:strip).reject(&:empty?)
    end

    def relation_type(relation, strategy)
      case strategy
      when 'uppercase_relation'
        relation.to_s.upcase.gsub(/[^A-Z0-9]+/, '_').gsub(/\A_+|_+\z/, '')
      else
        relation.to_s
      end
    end

    def negative_lists_for_forms(negative_nodes, forms)
      form_set = forms.map(&:to_s)
      Array(negative_nodes).each_with_object([]) do |node, lists|
        next unless node.is_a?(Hash)

        list = node['list']
        lists << list if form_set.include?(node['form'].to_s) && !list.to_s.empty?
      end.uniq
    end

    def fixture_targets(pattern, profile, fixture, errors)
      hop = Array(pattern['hops']).first || {}
      source_id = fixture.dig('parameters', 'source_id')
      as_of = profile_date(fixture.dig('parameters', 'as_of'))
      window_days = pattern.dig('constraints', 'temporal', 'window_days')
      unless EveryPivot::JsonSchemaValidator.integer?(window_days) && window_days.positive?
        errors << 'fixture traversal requires a positive pattern temporal window_days'
        return [[], []]
      end

      earliest_seen = as_of - window_days.to_i
      relationship_type = relation_type(hop['via'], profile.dig('graph_model', 'relationship_type_strategy'))
      nodes_by_id = Array(fixture['nodes']).each_with_object({}) do |node, nodes|
        nodes[node['id']] = node if node.is_a?(Hash)
      end
      source = nodes_by_id[source_id]
      source_forms = form_list(pattern['source'])
      target_forms = form_list(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
      negative_nodes = Array(pattern.dig('constraints', 'negative_nodes'))
      included = []
      suppressed = []

      unless source && source_forms.include?(source['form'])
        errors << 'fixture source node does not match pattern source form'
        return [included, suppressed]
      end

      Array(fixture['relationships']).each do |relationship|
        next unless relationship['type'] == relationship_type

        target_id = if hop['direction'] == 'in'
                      next unless relationship['to'] == source_id

                      relationship['from']
                    else
                      next unless relationship['from'] == source_id

                      relationship['to']
                    end
        target = nodes_by_id[target_id]
        next unless target && target_forms.include?(target['form'])

        seen = profile_date(relationship.dig('properties', 'seen'))
        negative_property = profile.dig('graph_model', 'negative_node_list_property') || 'negative_node_list'
        source_negative_lists = negative_lists_for_forms(negative_nodes, [source['form']])
        target_negative_lists = negative_lists_for_forms(negative_nodes, [target['form']])
        source_negative_list = source[negative_property]
        target_negative_list = target[negative_property]
        outside_window = seen < earliest_seen || seen > as_of
        suppressed_by_list =
          (!source_negative_list.to_s.empty? && source_negative_lists.include?(source_negative_list)) ||
          (!target_negative_list.to_s.empty? && target_negative_lists.include?(target_negative_list))

        if outside_window || suppressed_by_list
          suppressed << target['id']
        else
          included << target['id']
        end
      rescue ArgumentError => e
        errors << "fixture relationship date parse failed: #{e.message}"
      end

      [included.uniq.sort, suppressed.uniq.sort]
    rescue ArgumentError => e
      errors << "fixture parameter date parse failed: #{e.message}"
      [[], []]
    end

  end
end
