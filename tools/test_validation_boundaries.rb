#!/usr/bin/env ruby

require 'json'
require 'minitest/autorun'
require 'pathname'
require 'yaml'
require_relative 'json_schema_validator'
require_relative 'query_profile_traversal'
require_relative 'evidence_consistency'
require_relative 'utf8_text'

class ValidationBoundariesTest < Minitest::Test
  ROOT = Pathname(EveryPivot::Utf8Text.decode(__dir__, path: __FILE__)).join('..').expand_path

  def json(path)
    JSON.parse(EveryPivot::Utf8Text.read(ROOT.join(path)))
  end

  def yaml(path)
    YAML.safe_load(EveryPivot::Utf8Text.read(ROOT.join(path)), aliases: false)
  end

  def test_mathematical_integer_and_json_number_types
    validator = EveryPivot::JsonSchemaValidator.new('type' => 'integer')
    [90, 90.0, 0, -0.0, -90.0].each { |value| assert_empty validator.validate(value), value.inspect }
    [90.5, nil, true, false, '90', Float::INFINITY, Float::NAN].each { |value| refute_empty validator.validate(value), value.inspect }
    validator = EveryPivot::JsonSchemaValidator.new(json('schemas/pivot_pattern.schema.json'))
    pattern = yaml('graph-pivots/validated/CTI_SAMPLE_IMPHASH_CLUSTER.yaml')
    pattern['review']['review_cadence_days'] = 90.0
    pattern['constraints']['temporal']['window_days'] = 3650.0
    assert_empty validator.validate(pattern)
    pattern['constraints']['temporal']['window_days'] = 3650.5
    assert_includes validator.validate(pattern).join, 'window_days must be an integer'
  end

  def test_calendar_window_includes_both_endpoints_and_excludes_future
    pattern = yaml('graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml')
    profile = yaml('adapters/query-profiles/neo4j_cypher_v0.yml')
    fixture = json('fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json')
    fixture['relationships'] = [fixture['relationships'].first]
    target = fixture['relationships'].first['to']
    # Independently specified 730-day inclusive interval at 2026-05-24.
    {'2024-05-23' => false, '2024-05-24' => true, '2026-05-24' => true,
     '2026-05-25' => false, '2099-01-01' => false}.each do |date, included|
      fixture['relationships'].first['properties']['seen'] = date
      errors = []
      results, suppressed = EveryPivot::QueryProfileTraversal.fixture_targets(pattern, profile, fixture, errors)
      assert_empty errors
      assert_equal included ? [target] : [], results, date
      assert_equal included ? [] : [target], suppressed, date
    end
    ['2026-02-30', '2026-5-24', '2026-05-24T00:00:00Z', '2026-05-24T00:00:00.1+01:00', nil].each do |date|
      fixture['relationships'].first['properties']['seen'] = date
      errors = []
      assert_equal [[], []], EveryPivot::QueryProfileTraversal.fixture_targets(pattern, profile, fixture, errors)
      assert_match(/relationship date parse failed/, errors.join)
    end
    fixture['parameters']['as_of'] = 'not-a-date'
    errors = []
    assert_equal [[], []], EveryPivot::QueryProfileTraversal.fixture_targets(pattern, profile, fixture, errors)
    assert_match(/parameter date parse failed/, errors.join)
  end

  def test_negative_lists_apply_only_to_the_declared_node_form
    pattern = yaml('graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml')
    profile = yaml('adapters/query-profiles/neo4j_cypher_v0.yml')
    fixture = json('fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json')
    fixture['relationships'] = [fixture['relationships'].first]
    target = fixture['nodes'].find { |node| node['id'] == fixture['relationships'].first['to'] }
    %w[known_scanner_asns shared_hosting_ranges].each do |list|
      target['negative_node_list'] = list
      {'inet:fqdn' => [[target['id']], []], 'inet:ipv4' => [[], [target['id']]]}.each do |form, expected|
        target['form'] = form
        errors = []
        assert_equal expected, EveryPivot::QueryProfileTraversal.fixture_targets(pattern, profile, fixture, errors)
        assert_empty errors
      end
    end
  end

  def test_evidence_pack_semantic_counterexamples
    pattern = yaml('graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml')
    base = json('fixtures/examples/osint_ssh_hostkey_cluster.evidence.json')
    assert_empty EveryPivot::EvidenceConsistency.check(base, pattern)
    mutations = {
      'relation does not match' => ->(pack) { pack['edges'].each { |edge| edge['relation'] = 'UNRELATED_REVIEW_COUNTEREXAMPLE' } },
      'wrong pattern target form' => ->(pack) { pack['expected_traversals'][0]['included_targets'] = [pack['source_node']['id']] },
      'no matching directed hop' => ->(pack) { pack['edges'].shift },
      'endpoint forms/direction' => ->(pack) { edge = pack['edges'].first; edge['from'], edge['to'] = edge['to'], edge['from'] },
      'target lists must be disjoint' => ->(pack) { pack['expected_traversals'][0]['suppressed_targets'] = pack['expected_traversals'][0]['included_targets'].dup },
      'includes and suppresses' => ->(pack) { pack['expected_traversals'][1]['suppressed_targets'] = pack['expected_traversals'][0]['included_targets'].dup },
      'duplicate ids' => ->(pack) { pack['nodes'] << pack['nodes'].first.dup },
      'unique nonempty ids' => ->(pack) { pack['expected_traversals'][1]['id'] = pack['expected_traversals'][0]['id'] },
      'source anchor' => ->(pack) { pack['edges'].first.delete('source') },
      'negative target unexpectedly' => ->(pack) { pack['expected_traversals'][2]['candidate_targets'] = pack['expected_traversals'][0]['included_targets'].dup }
    }
    mutations.each do |reason, mutate|
      pack = Marshal.load(Marshal.dump(base))
      mutate.call(pack)
      assert_includes EveryPivot::EvidenceConsistency.check(pack, pattern).join("\n"), reason
    end
  end
end
