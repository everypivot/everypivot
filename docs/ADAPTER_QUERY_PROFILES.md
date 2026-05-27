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
demo. It currently declares three synthetic targets:

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

The second profile is OpenCTI/STIX-side mapping coverage. It currently declares
one synthetic mapping target:

- profile: [`adapters/query-profiles/opencti_stix_v0.yml`](../adapters/query-profiles/opencti_stix_v0.yml)
- validated import-hash target:
  [`CTI_SAMPLE_IMPHASH_CLUSTER`](../graph-pivots/validated/CTI_SAMPLE_IMPHASH_CLUSTER.yaml),
  [`generated STIX bundle`](../adapters/opencti/generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json),
  [`fixture mapping`](../fixtures/query-profiles/opencti/cti_sample_imphash_cluster.stix_mapping.json)

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

The OpenCTI/STIX mapping profile may define:

- STIX object model version and generated artifact type;
- STIX object types used for observable, observation, relationship, and caveat
  records;
- the constrained STIX relationship type used by the demo bundle;
- `x_everypivot_*` custom-property carriage for pattern ID, fixture ID,
  source/target IDs, relation names, hazards, blocked assertions, and
  suppressed targets;
- forbidden OpenCTI/runtime fields that the generated bundle must not emit.

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
  --profile adapters/query-profiles/neo4j_cypher_v0.yml \
  --pattern-id OSINT_SSH_HOSTKEY_CLUSTER \
  --output adapters/neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher

ruby tools/generate_query_profile_demo.rb \
  --profile adapters/query-profiles/neo4j_cypher_v0.yml \
  --pattern-id CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES \
  --output adapters/neo4j/generated/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.cypher

ruby tools/generate_query_profile_demo.rb \
  --profile adapters/query-profiles/neo4j_cypher_v0.yml \
  --pattern-id CTI_SAMPLE_IMPHASH_CLUSTER \
  --output adapters/neo4j/generated/CTI_SAMPLE_IMPHASH_CLUSTER.cypher

ruby tools/generate_stix_mapping_profile_demo.rb \
  --profile adapters/query-profiles/opencti_stix_v0.yml \
  --pattern-id CTI_SAMPLE_IMPHASH_CLUSTER \
  --output adapters/opencti/generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json
```

Validate the profiles, fixtures, fixture loaders where applicable, and
generated artifacts:

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

## Optional STIX Validation

The repository does not require external STIX validation for normal checks. For
incubator review of generated STIX bundles, maintainers can run the OASIS
`stix2-validator` through `uv run`.

The current `uv` wheel for `stix2-validator` may not include the bundled STIX
JSON schemas. If direct validation fails with a missing
`cyber-observable-core.json` schema, use a temporary overlay seeded from the
official OASIS STIX JSON schemas repository:
[`oasis-open/cti-stix2-json-schemas`](https://github.com/oasis-open/cti-stix2-json-schemas).
In the 2026-05-27 incubator check, the generated OpenCTI/STIX bundle validated
as STIX 2.1 when those schemas were available. After the follow-up hardening
pass, file-SCO UUIDv5 inputs exclude custom hash keys, `x_everypivot_*`
properties are kept off File SCOs, and strict validation passed without
disabled best-practice checks.

When the validator package can see the STIX 2.1 schemas, the intended incubator
check is:

```bash
uv run --with stix2-validator stix2_validator \
  --version 2.1 \
  --strict \
  adapters/opencti/generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json
```

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

Current status:

- `opencti_stix_v0` maps the bounded `CTI_SAMPLE_IMPHASH_CLUSTER` fixture into
  a STIX 2.1 bundle containing file, observed-data, relationship, and note
  objects;
- EveryPivot relation semantics are carried in `x_everypivot_relation` while
  the STIX relationship type remains `related-to`;
- generated file SCO IDs are UUIDv5-derived from STIX 2.1 ID-contributing file
  properties; custom `x_imphash` hash keys are not UUID inputs;
- `x_everypivot_*` custom properties are carried on observed-data,
  relationship, and note objects, and are covered by a generated
  `toplevel-property-extension` definition plus local schema document;
- source and target File SCO refs share a single observed-data object in this
  pressure-test fixture; that is a bounded mapping simplification, not a claim
  that the import hash is an independently observed file;
- suppressed fixture targets are documented in EveryPivot metadata and are not
  emitted as STIX relationship objects;
- no OpenCTI connector, importer, server call, workflow state, score, marking,
  runtime confidence, attribution, maliciousness, compromise, ownership, or
  final assessment is modeled.

## License Boundary

Adapter metadata, adapter docs, generation/checking tools, generated demo
queries, and generated mapping artifacts under `adapters/` are Apache-2.0
code/tooling material. Synthetic fixture graphs, fixture loader files, and
mapping fixtures under `fixtures/` are CC BY 4.0 fixture material. Keeping
generated artifacts and fixture data in separate trees makes the license
boundary visible in both source layout and generated release metadata.

## Non-Goals

This pilot does not:

- add schema-facing root fields;
- migrate the public corpus to schema v1.5;
- claim runtime correctness for every Neo4j data model;
- execute against live external data;
- emit scores, final assessments, actor attribution, maliciousness, compromise,
  or ownership claims.
