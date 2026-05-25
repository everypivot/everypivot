# Neo4j Adapter Pilot

This directory contains the first public query-profile demo for Neo4j/Cypher.

Files:

- [`../query-profiles/neo4j_cypher_v0.yml`](../query-profiles/neo4j_cypher_v0.yml)
  defines the backend-specific profile metadata.
- [`generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher`](generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher)
  is generated from the validated SSH host-key pattern plus the synthetic
  outbound query-profile fixture graph.
- [`generated/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.cypher`](generated/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.cypher)
  is generated from the working-set email-originating-IP pattern plus the
  synthetic inbound query-profile fixture graph.
- [`../../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json`](../../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json)
  provides the tiny synthetic graph fixture used by the SSH host-key demo.
- [`../../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher`](../../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher)
  loads the same fixture graph into a Neo4j database for local testing.
- [`../../fixtures/query-profiles/neo4j/cti_email_originating_ip_to_messages.graph.json`](../../fixtures/query-profiles/neo4j/cti_email_originating_ip_to_messages.graph.json)
  provides the tiny synthetic graph fixture used by the email-originating-IP
  demo.
- [`../../fixtures/query-profiles/neo4j/cti_email_originating_ip_to_messages.load.cypher`](../../fixtures/query-profiles/neo4j/cti_email_originating_ip_to_messages.load.cypher)
  loads the same fixture graph into a Neo4j database for local testing.

The generated query returns traversal evidence, caveats, and blocked
assertions. It does not return runtime confidence, attribution, maliciousness,
compromise, ownership, or final assessment fields.

Regenerate the demo query with:

```bash
ruby tools/generate_query_profile_demo.rb \
  --pattern-id OSINT_SSH_HOSTKEY_CLUSTER \
  --output adapters/neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher

ruby tools/generate_query_profile_demo.rb \
  --pattern-id CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES \
  --output adapters/neo4j/generated/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.cypher
```

To run the demo locally, load the fixture Cypher first, then run the generated
query. The loader deletes and recreates only nodes with its fixture id.

Maintainers with Neo4j 5.x and `cypher-shell` available can run the optional
live smoke helper:

```bash
ruby tools/smoke_neo4j_query_profiles.rb -- --address bolt://localhost:7687
```

Arguments after `--` are passed directly to `cypher-shell`. The smoke helper is
not part of the default validation gate; it exists to catch obvious fixture/load
or generated-query execution drift in a local disposable Neo4j database.
