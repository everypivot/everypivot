// Synthetic fixture loader for the OSINT_SSH_HOSTKEY_CLUSTER Neo4j demo.
// This deletes and recreates only nodes with the fixture_id below.

:param fixture_id => 'neo4j_osint_ssh_hostkey_cluster_graph_v1';

MATCH (n:EveryPivotNode {fixture_id: $fixture_id})
DETACH DELETE n;

CREATE
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'ssh-hostkey:sha256:example-ed25519-7f3b', form: 'ssh:hostkey', label: 'SHA256:example-ed25519-7f3b'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'ssh-hostkey:sha256:example-rsa-912c', form: 'ssh:hostkey', label: 'SHA256:example-rsa-912c'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'inet:fqdn:jump-01.ops.example.net', form: 'inet:fqdn', label: 'jump-01.ops.example.net'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'inet:ipv4:203.0.113.17', form: 'inet:ipv4', label: '203.0.113.17'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'inet:ipv4:198.51.100.44', form: 'inet:ipv4', label: '198.51.100.44', negative_node_list: 'shared_hosting_ranges'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'inet:ipv4:198.51.100.23', form: 'inet:ipv4', label: '198.51.100.23', stale: true}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'inet:ipv4:203.0.113.88', form: 'inet:ipv4', label: '203.0.113.88'})
WITH $fixture_id AS fixture_id
MATCH (source:EveryPivotNode {fixture_id: fixture_id, id: 'ssh-hostkey:sha256:example-ed25519-7f3b'}),
      (target:EveryPivotNode {fixture_id: fixture_id, id: 'inet:fqdn:jump-01.ops.example.net'})
CREATE (source)-[:PRESENTED_BY {seen: '2026-05-20', source: 'example_scanner_a'}]->(target)
WITH fixture_id
MATCH (source:EveryPivotNode {fixture_id: fixture_id, id: 'ssh-hostkey:sha256:example-ed25519-7f3b'}),
      (target:EveryPivotNode {fixture_id: fixture_id, id: 'inet:ipv4:203.0.113.17'})
CREATE (source)-[:PRESENTED_BY {seen: '2026-05-20', source: 'example_scanner_b'}]->(target)
WITH fixture_id
MATCH (source:EveryPivotNode {fixture_id: fixture_id, id: 'ssh-hostkey:sha256:example-ed25519-7f3b'}),
      (target:EveryPivotNode {fixture_id: fixture_id, id: 'inet:ipv4:198.51.100.44'})
CREATE (source)-[:PRESENTED_BY {seen: '2026-05-20', source: 'example_scanner_a'}]->(target)
WITH fixture_id
MATCH (source:EveryPivotNode {fixture_id: fixture_id, id: 'ssh-hostkey:sha256:example-ed25519-7f3b'}),
      (target:EveryPivotNode {fixture_id: fixture_id, id: 'inet:ipv4:198.51.100.23'})
CREATE (source)-[:PRESENTED_BY {seen: '2023-01-15', source: 'example_scanner_archive'}]->(target)
WITH fixture_id
MATCH (source:EveryPivotNode {fixture_id: fixture_id, id: 'ssh-hostkey:sha256:example-rsa-912c'}),
      (target:EveryPivotNode {fixture_id: fixture_id, id: 'inet:ipv4:203.0.113.88'})
CREATE (source)-[:PRESENTED_BY {seen: '2026-05-20', source: 'example_scanner_a'}]->(target)
RETURN fixture_id AS fixture_id, 7 AS fixture_nodes_loaded, 5 AS fixture_relationships_loaded;
