// Synthetic fixture loader for the CTI_SAMPLE_IMPHASH_CLUSTER Neo4j demo.
// This deletes and recreates only nodes with the fixture_id below.

:param fixture_id => 'neo4j_cti_sample_imphash_cluster_source_suppression_graph_v1';

MATCH (n:EveryPivotNode {fixture_id: $fixture_id})
DETACH DELETE n;

CREATE
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'file:pe:imphash:example-common-packer-7b3f', form: 'file:pe:imphash', label: 'example-common-packer-7b3f', negative_node_list: 'common_packer_imphashes'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'file:bytes:sha256:example-alpha', form: 'file:bytes', label: 'sha256:example-alpha'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'file:bytes:sha256:example-beta', form: 'file:bytes', label: 'sha256:example-beta'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'file:bytes:sha256:example-other-imphash', form: 'file:bytes', label: 'sha256:example-other-imphash'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'file:pe:imphash:example-other-91ac', form: 'file:pe:imphash', label: 'example-other-91ac'})
WITH $fixture_id AS fixture_id
MATCH (imphash:EveryPivotNode {fixture_id: fixture_id, id: 'file:pe:imphash:example-common-packer-7b3f'}),
      (sample:EveryPivotNode {fixture_id: fixture_id, id: 'file:bytes:sha256:example-alpha'})
CREATE (imphash)-[:OBSERVED_IN {seen: '2026-05-20', source: 'example_static_parser_a'}]->(sample)
WITH fixture_id
MATCH (imphash:EveryPivotNode {fixture_id: fixture_id, id: 'file:pe:imphash:example-common-packer-7b3f'}),
      (sample:EveryPivotNode {fixture_id: fixture_id, id: 'file:bytes:sha256:example-beta'})
CREATE (imphash)-[:OBSERVED_IN {seen: '2026-05-21', source: 'example_static_parser_b'}]->(sample)
WITH fixture_id
MATCH (imphash:EveryPivotNode {fixture_id: fixture_id, id: 'file:pe:imphash:example-other-91ac'}),
      (sample:EveryPivotNode {fixture_id: fixture_id, id: 'file:bytes:sha256:example-other-imphash'})
CREATE (imphash)-[:OBSERVED_IN {seen: '2026-05-20', source: 'example_static_parser_a'}]->(sample)
RETURN fixture_id AS fixture_id, 5 AS fixture_nodes_loaded, 3 AS fixture_relationships_loaded;
