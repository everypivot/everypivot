# frozen_string_literal: true

module EveryPivot
  # A bounded topology oracle for synthetic one-hop evidence packs. This does
  # not execute portable temporal/order, fan-out, suppression or source policy.
  module EvidenceConsistency
    module_function

    def targets(values)
      Array(values).map { |value| value.is_a?(Hash) ? value['id'] : value }
    end

    def forms(value)
      value.to_s.split('|').map(&:strip)
    end

    def check(data, pattern)
      errors = []
      nodes = Array(data['nodes']).select { |item| item.is_a?(Hash) }
      ids = nodes.map { |node| node['id'] }
      errors << 'nodes[] contain duplicate ids' unless ids.uniq == ids
      errors << 'nodes[] require nonempty id and form strings' unless nodes.all? { |node| %w[id form].all? { |key| node[key].is_a?(String) && !node[key].strip.empty? } }
      traversals = Array(data['expected_traversals']).select { |item| item.is_a?(Hash) }
      traversal_ids = traversals.map { |item| item['id'] }
      errors << 'expected_traversals require unique nonempty ids' unless traversal_ids.uniq == traversal_ids && traversal_ids.all? { |id| id.is_a?(String) && !id.strip.empty? }
      hops = Array(pattern['hops'])
      unless hops.length == 1 && %w[in out].include?(hops[0]['direction'])
        return errors + ['bounded evidence consistency supports exactly one in/out hop; a separate reviewed oracle is required for this shape']
      end
      hop = hops.first
      source_forms = forms(pattern['source'])
      target_forms = forms(pattern['target'])
      nodes_by_id = nodes.to_h { |node| [node['id'], node] }
      edges = Array(data['edges']).select { |item| item.is_a?(Hash) }
      edges.each_with_index do |edge, index|
        errors << "edges[#{index}] relation does not match pattern hop" unless edge['relation'] == hop['via']
        errors << "edges[#{index}] requires a nonempty documentary source anchor" unless edge['source'].is_a?(String) && !edge['source'].strip.empty?
        from, to = hop['direction'] == 'out' ? [edge['from'], edge['to']] : [edge['to'], edge['from']]
        hop_forms = forms(hop['form'].to_s.empty? ? pattern['target'] : hop['form'])
        unless source_forms.include?(nodes_by_id.dig(from, 'form')) && hop_forms.include?(nodes_by_id.dig(to, 'form'))
          errors << "edges[#{index}] endpoint forms/direction do not match pattern hop"
        end
      end
      included_by_start = Hash.new { |hash, key| hash[key] = [] }
      suppressed_by_start = Hash.new { |hash, key| hash[key] = [] }
      traversals.each_with_index do |traversal, index|
        prefix = "expected_traversals[#{index}]"
        start = traversal['start']
        errors << "#{prefix} start form does not match pattern source" unless source_forms.include?(nodes_by_id.dig(start, 'form'))
        unless traversal['relation'] == hop['via'] && traversal['direction'] == hop['direction']
          errors << "#{prefix} relation/direction does not match pattern hop"
        end
        included = targets(traversal['included_targets'])
        suppressed = targets(traversal['suppressed_targets'])
        candidates = targets(traversal['candidate_targets'])
        groups = [included, suppressed, candidates]
        errors << "#{prefix} target lists contain duplicate ids" if groups.any? { |group| group.uniq != group }
        errors << "#{prefix} target lists must be disjoint" if groups.combination(2).any? { |left, right| (left & right).any? }
        included_by_start[start].concat(included)
        suppressed_by_start[start].concat(suppressed)
        joined = edges.select { |edge| edge['relation'] == hop['via'] && edge[hop['direction'] == 'out' ? 'from' : 'to'] == start }
                      .map { |edge| edge[hop['direction'] == 'out' ? 'to' : 'from'] }
        (included + suppressed + candidates).each do |target|
          errors << "#{prefix} target #{target.inspect} has the wrong pattern target form" unless target_forms.include?(nodes_by_id.dig(target, 'form'))
        end
        required = included + suppressed
        required += candidates if %w[weak_positive cautionary_positive high_cardinality].include?(traversal['role'])
        (required - joined).each { |target| errors << "#{prefix} target #{target.inspect} has no matching directed hop from start" }
        if traversal['role'] == 'negative' && (candidates & joined).any?
          errors << "#{prefix} negative target unexpectedly has a matching directed hop"
        end
      end
      included_by_start.each do |start, included|
        if (included & suppressed_by_start[start]).any?
          errors << "start #{start.inspect} includes and suppresses the same target across traversals"
        end
      end
      errors
    end
  end
end
