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

## Pilot Targets

The first profile is Neo4j/Cypher because it gives the smallest executable graph
demo. It currently declares two synthetic targets:

- profile: [`adapters/query-profiles/neo4j_cypher_v0.yml`](../adapters/query-profiles/neo4j_cypher_v0.yml)
- outbound validated target:
  [`OSINT_SSH_HOSTKEY_CLUSTER`](../graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml),
  [`generated query`](../adapters/neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher),
  [`fixture graph`](../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json),
  [`fixture loader`](../fixtures/query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher)
- inbound working-set target:
  [`CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES`](../graph-pivots/working-set/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.yaml),
  [`generated query`](../adapters/neo4j/generated/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.cypher),
  [`fixture graph`](../fixtures/query-profiles/neo4j/cti_email_originating_ip_to_messages.graph.json),
  [`fixture loader`](../fixtures/query-profiles/neo4j/cti_email_originating_ip_to_messages.load.cypher)

The pilot uses only synthetic fixture material based on reserved example values.
It is not live intelligence and it is not an OpenCTI, Neo4j, or vendor-specific
endorsement.

Profiles declare explicit `targets` for each generated demo. A target binds a
pattern ID to its supported pilot shape, generated query, synthetic fixture
graph, and fixture loader. Profiles themselves are discovered from the fixed
top-level path `adapters/query-profiles/*.yml`; `.yaml` files and nested profile
directories are intentionally unsupported and fail the suite.

## Boundary

The query profile may define:

- backend name and query language;
- graph labels and property names;
- relationship type conversion;
- generated output field allowlists;
- target records with supported pilot shape, fixture locations, and
  generated-query locations for demos.

The current targets support exactly one hop, either outbound or inbound, and
require a temporal window. That shape is declared on each target, not inferred
from the pattern ID or filename. The fixtures model `negative_node_list` as one
scalar property; a production graph may need list-valued negative-list
membership. The generated Cypher enforces `temporal.window_days`, but it does
not yet enforce `temporal.order`, `degree_caps`, or `outputs.top_paths`. Those
omissions are declared in each target's `graph_simplifications` and must not be
treated as complete operational semantics.

The SSH host-key fixture behaviourally exercises target-side negative-list
suppression. The email-originating-IP target has source-form negative nodes; its
positive fixture verifies the generated source-side suppression clause but does
not prove the all-results-blocked case yet.

The profile may not redefine:

- source and target forms;
- hop relations or direction;
- temporal windows;
- suppression controls;
- pattern hazards;
- assessment semantics.

Those remain in the pattern YAML and traversal evidence fixtures.

## Generate And Check

Regenerate a committed query:

```bash
ruby tools/generate_query_profile_demo.rb \
  --pattern-id OSINT_SSH_HOSTKEY_CLUSTER \
  --output adapters/neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher

ruby tools/generate_query_profile_demo.rb \
  --pattern-id CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES \
  --output adapters/neo4j/generated/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.cypher
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
