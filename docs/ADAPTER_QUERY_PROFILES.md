# Adapter And Query Profiles

## Purpose

EP-WP15 starts the execution-adapter track without changing pattern semantics.
The public contract is:

- pattern YAML remains backend-neutral;
- backend-specific query profile metadata lives under `adapters/`;
- generated demo queries preserve pattern hazards and fixture blocked
  assertions;
- generated output must not add confidence, attribution, maliciousness,
  compromise, ownership, or final-assessment semantics.

## First Pilot

The first profile is Neo4j/Cypher because it gives the smallest executable graph
demo:

- profile: [`adapters/query-profiles/neo4j_cypher_v0.yml`](../adapters/query-profiles/neo4j_cypher_v0.yml)
- generated query: [`adapters/neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher`](../adapters/neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher)
- fixture graph: [`fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json`](../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json)
- fixture loader: [`fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher`](../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher)
- pattern: [`graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml`](../graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml)

The pilot uses only synthetic fixture material based on reserved example values.
It is not live intelligence and it is not an OpenCTI, Neo4j, or vendor-specific
endorsement.

## Boundary

The query profile may define:

- backend name and query language;
- graph labels and property names;
- relationship type conversion;
- generated output field allowlists;
- fixture locations for demos.

The current pilot supports exactly one outbound hop and requires a temporal
window. The fixture models `negative_node_list` as one scalar property; a
production graph may need list-valued negative-list membership.

The profile may not redefine:

- source and target forms;
- hop relations or direction;
- temporal windows;
- suppression controls;
- pattern hazards;
- assessment semantics.

Those remain in the pattern YAML and traversal evidence fixtures.

## Generate And Check

Regenerate the committed query:

```bash
ruby tools/generate_query_profile_demo.rb \
  --pattern-id OSINT_SSH_HOSTKEY_CLUSTER \
  --output adapters/neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher
```

Validate the profile, fixture graph, fixture loader, and generated query:

```bash
ruby tools/check_query_profile_suite.rb
```

The check compares the committed query to regenerated output and verifies that
hazards, blocked assertions, temporal controls, negative-node controls, and
allowed result fields are preserved.

## Non-Goals

This pilot does not:

- add schema-facing root fields;
- migrate the public corpus to schema v1.5;
- claim runtime correctness for every Neo4j data model;
- execute against live external data;
- emit scores, final assessments, actor attribution, maliciousness, compromise,
  or ownership claims.
