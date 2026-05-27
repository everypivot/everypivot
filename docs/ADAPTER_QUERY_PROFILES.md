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
- source-suppression validated target:
  [`CTI_SAMPLE_IMPHASH_CLUSTER`](../graph-pivots/validated/CTI_SAMPLE_IMPHASH_CLUSTER.yaml),
  [`generated query`](../adapters/neo4j/generated/CTI_SAMPLE_IMPHASH_CLUSTER.cypher),
  [`fixture graph`](../fixtures/query-profiles/neo4j/cti_sample_imphash_cluster_source_suppression.graph.json),
  [`fixture loader`](../fixtures/query-profiles/neo4j/cti_sample_imphash_cluster_source_suppression.load.cypher)

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
not prove the all-results-blocked case. The import-hash target behaviourally
exercises that source-side full-block case: the source node is negative-listed,
expected results are empty, and every connected candidate is listed as
suppressed.

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

ruby tools/generate_query_profile_demo.rb \
  --pattern-id CTI_SAMPLE_IMPHASH_CLUSTER \
  --output adapters/neo4j/generated/CTI_SAMPLE_IMPHASH_CLUSTER.cypher
```

Validate the profile, fixture graph, fixture loader, and generated query:

```bash
ruby tools/check_query_profile_suite.rb
```

The check compares the committed query to regenerated output and verifies that
hazards, blocked assertions, temporal controls, negative-node controls, and
allowed result fields are preserved.

## Optional Neo4j Smoke

The repository does not require Neo4j for normal validation. Maintainers with a
local Neo4j 5.x database and `cypher-shell` can run the synthetic fixtures
against a live database:

```bash
ruby tools/smoke_neo4j_query_profiles.rb -- --address bolt://localhost:7687
ruby tools/smoke_neo4j_query_profiles.rb --reset-fixtures -- --address bolt://localhost:7687
```

Arguments after `--` are passed directly to `cypher-shell`, so local
authentication, database, and address flags can be supplied without EveryPivot
owning those runtime choices. The smoke helper loads each synthetic fixture,
runs the committed generated query, and checks that expected targets appear
while declared suppressed targets do not. It is a maintainer smoke path, not a
CI gate and not proof of runtime correctness for arbitrary production graph
models.

The smoke helper deliberately stays simple. It checks target IDs in plain
`cypher-shell` output, so fixture authors must not repeat suppressed target IDs
inside free-text hazards or blocked assertions; the query-profile suite enforces
that guard. By default, target loaders delete only their own fixture-scoped
nodes. Use `--reset-fixtures` only with a disposable database when all
`EveryPivotNode` nodes should be deleted before the smoke run. Arguments after
`--` must be connection and authentication options, not alternate `--file`
inputs; the helper owns fixture and query file selection.

## Contract Review Status

The Neo4j/Cypher contract is accepted for EP-WP15 second-adapter planning as of
2026-05-26. The acceptance record is
[`docs/assessments/2026-05-26/neo4j_cypher_contract_review.md`](assessments/2026-05-26/neo4j_cypher_contract_review.md).

Acceptance is based on repository-local verification of the query-profile
contract, fixture suite, and strict corpus validation. It is not a claim that
generated Cypher is production-correct for every Neo4j graph model, and it does
not imply that the optional live `cypher-shell` smoke path was run.

## Second Adapter Decision

The second adapter target is OpenCTI/STIX-side mapping coverage.

Initial scope:

- define a mapping/profile shape outside pattern YAML;
- start with a narrow synthetic fixture slice for
  `CTI_SAMPLE_IMPHASH_CLUSTER`;
- map EveryPivot forms and bounded traversal output into STIX/OpenCTI-side
  observable or relationship records without adding attribution, maliciousness,
  compromise, ownership, runtime-confidence, or final-assessment semantics;
- preserve hazards, caveats, blocked assertions, and source fixture boundaries;
- do not build a live OpenCTI connector, importer, or server integration in the
  first slice.

This choice gives the adapter track a CTI object-model pressure test after the
Neo4j graph-query pilot, without making STIX/OpenCTI canonical for the corpus.

## License Boundary

Adapter metadata, adapter docs, generation/checking tools, and generated demo
queries under `adapters/` are Apache-2.0 code/tooling material. Synthetic
fixture graphs and fixture loader files under `fixtures/` are CC BY 4.0 fixture
material. Keeping generated queries and fixture data in separate trees makes the
license boundary visible in both source layout and generated release metadata.

## Non-Goals

This pilot does not:

- add schema-facing root fields;
- migrate the public corpus to schema v1.5;
- claim runtime correctness for every Neo4j data model;
- execute against live external data;
- emit scores, final assessments, actor attribution, maliciousness, compromise,
  or ownership claims.
