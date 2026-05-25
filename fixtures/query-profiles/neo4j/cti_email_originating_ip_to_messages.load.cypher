// Synthetic fixture loader for the CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES Neo4j demo.
// This deletes and recreates only nodes with the fixture_id below.

:param fixture_id => 'neo4j_cti_email_originating_ip_to_messages_graph_v1';

MATCH (n:EveryPivotNode {fixture_id: $fixture_id})
DETACH DELETE n;

CREATE
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'inet:ipv4:203.0.113.45', form: 'inet:ipv4', label: '203.0.113.45'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'inet:ipv4:198.51.100.210', form: 'inet:ipv4', label: '198.51.100.210'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'email:message:example-alpha', form: 'email:message', label: 'example-alpha@example.invalid'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'email:message:example-beta', form: 'email:message', label: 'example-beta@example.invalid'}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'email:message:example-stale', form: 'email:message', label: 'example-stale@example.invalid', stale: true}),
  (:EveryPivotNode {fixture_id: $fixture_id, id: 'email:message:example-other-ip', form: 'email:message', label: 'example-other-ip@example.invalid'})
WITH $fixture_id AS fixture_id
MATCH (message:EveryPivotNode {fixture_id: fixture_id, id: 'email:message:example-alpha'}),
      (ip:EveryPivotNode {fixture_id: fixture_id, id: 'inet:ipv4:203.0.113.45'})
CREATE (message)-[:ORIGINATING_IP_FOR {seen: '2026-05-22', source: 'example_mailflow_parser_a'}]->(ip)
WITH fixture_id
MATCH (message:EveryPivotNode {fixture_id: fixture_id, id: 'email:message:example-beta'}),
      (ip:EveryPivotNode {fixture_id: fixture_id, id: 'inet:ipv4:203.0.113.45'})
CREATE (message)-[:ORIGINATING_IP_FOR {seen: '2026-05-21', source: 'example_mailflow_parser_b'}]->(ip)
WITH fixture_id
MATCH (message:EveryPivotNode {fixture_id: fixture_id, id: 'email:message:example-stale'}),
      (ip:EveryPivotNode {fixture_id: fixture_id, id: 'inet:ipv4:203.0.113.45'})
CREATE (message)-[:ORIGINATING_IP_FOR {seen: '2026-03-10', source: 'example_mailflow_archive'}]->(ip)
WITH fixture_id
MATCH (message:EveryPivotNode {fixture_id: fixture_id, id: 'email:message:example-other-ip'}),
      (ip:EveryPivotNode {fixture_id: fixture_id, id: 'inet:ipv4:198.51.100.210'})
CREATE (message)-[:ORIGINATING_IP_FOR {seen: '2026-05-22', source: 'example_mailflow_parser_a'}]->(ip)
RETURN fixture_id AS fixture_id, 6 AS fixture_nodes_loaded, 4 AS fixture_relationships_loaded;
