# Neo4j Adapter Pilot

This directory contains the first public query-profile demo for Neo4j/Cypher.

Files:

- [`../query-profiles/neo4j_cypher_v0.yml`](../query-profiles/neo4j_cypher_v0.yml)
  defines the backend-specific profile metadata.
- [`generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher`](generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher)
  is generated from the validated SSH host-key pattern plus the synthetic query
  profile fixture graph.
- [`../../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json`](../../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json)
  provides the tiny synthetic graph fixture used by the demo.
- [`../../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher`](../../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher)
  loads the same fixture graph into a Neo4j database for local testing.

The generated query returns traversal evidence, caveats, and blocked
assertions. It does not return runtime confidence, attribution, maliciousness,
compromise, ownership, or final assessment fields.

Regenerate the demo query with:

```bash
ruby tools/generate_query_profile_demo.rb \
  --pattern-id OSINT_SSH_HOSTKEY_CLUSTER \
  --output adapters/neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher
```

To run the demo locally, load the fixture Cypher first, then run the generated
query. The loader deletes and recreates only nodes with its fixture id.
