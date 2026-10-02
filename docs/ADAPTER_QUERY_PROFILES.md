# Adapter And Query Profiles

## Purpose

Query and mapping profiles describe bounded backend capabilities without changing pattern semantics.
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

The Neo4j pilot uses calendar dates, with an inclusive interval
`[as_of - window_days, as_of]`. Future observations are outside the requested
window; there is no clock-skew allowance. Fixture parameters and relationship
`seen` values must be valid `YYYY-MM-DD` strings. Timestamps, time zones and
sub-day precision are unsupported by this date-only profile and the reference
checker rejects them. Native consumers must validate this input contract before
running generated Cypher; a date window does not establish that a source was
available at an earlier event time. Native Neo4j acceptance remains a separate
smoke procedure below.

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
ruby tools/test_validation_boundaries.rb
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

External STIX validation is optional. Maintainers can run the OASIS
`stix2-validator` against generated bundles. If its installation lacks
`cyber-observable-core.json`, provide the official STIX 2.1 JSON schemas from
[`oasis-open/cti-stix2-json-schemas`](https://github.com/oasis-open/cti-stix2-json-schemas).
Schema-validator success alone does not establish full specification conformance
or native OpenCTI compatibility. The bounded profile also checks creator closure,
File identity, extension fields and timestamp handling.

With the STIX 2.1 schemas available, run:

```bash
uv run --with stix2-validator stix2_validator \
  --version 2.1 \
  --strict \
  adapters/opencti/generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json
```

## Query-profile coverage

The three-target Neo4j/Cypher pilot has a
[historical contract review](assessments/2026-05-26/neo4j_cypher_contract_review.md)
covering repository-local profile checks, synthetic fixtures and strict corpus
validation. That record does not establish live runtime correctness for arbitrary
graph models or execution of the optional `cypher-shell` path.

## OpenCTI/STIX mapping scope

The OpenCTI/STIX profile maps a bounded synthetic `CTI_SAMPLE_IMPHASH_CLUSTER`
fixture. It preserves EveryPivot hazards and blocked assertions, with no live
connector, importer, server integration, workflow state or assessment authority.
STIX/OpenCTI is a backend mapping rather than the corpus's canonical model.

Current status:

- `opencti_stix_v0` maps the bounded `CTI_SAMPLE_IMPHASH_CLUSTER` fixture into
  a STIX 2.1 bundle containing file, observed-data, relationship, and note
  objects plus an extension-definition and its included creator Identity;
- EveryPivot relation semantics are carried in `x_everypivot_relation` while
  the STIX relationship type remains `related-to`;
- generated file SCO IDs are UUIDv5-derived from STIX 2.1 ID-contributing file
  properties; one hash is chosen by MD5/SHA-1/SHA-256/SHA-512 priority,
  then lexical key order including custom `x_imphash`;
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
- introduce future semantic-model fields or migrate independently versioned adapter formats;
- claim runtime correctness for every Neo4j data model;
- execute against live external data;
- emit scores, final assessments, actor attribution, maliciousness, compromise,
  or ownership claims.

### STIX conformance and mapping migration

The historical six-object format omitted the extension-definition creator
required by STIX 2.1 OS section 7.3.1. The 0.2.1 profile includes the EveryPivot
Project group Identity and a distinct replacement extension identifier.
Historical-format and synthetic-creator inputs remain regression fixtures;
neither establishes factual creator provenance. See
[the migration record](../adapters/opencti/MIGRATION.md).

The generator and suite apply the extension-property schema and validate complete
calendar/timestamp values. Fixture checks use both inclusive window endpoints.
Serialization maps selected entries without performing traversal. Mapping profile
0.2.1 and extension schema 0.1.0 are separate version identities. Native OpenCTI
import, persistence, export and replay remain untested.

## Separate semantic evidence adapter

The independently versioned `adapters/semantic-profiles/neo4j_semantic_evidence_v1.json`
profile is hybrid normalized-evidence storage/readback followed by the portable
Ruby evaluator. Its explicit admission manifest currently covers exact client
JA3 and server JA3S contracts only. It checks graph identity/reference round
trips; it does not execute the semantic grammar in Cypher or parse/authenticate
PCAP, client/server logs or external feeds. Native acceptance must be bound to
the exact runtime, adapter, contracts, fixtures and executor hashes; an older
checkpoint is not acceptance of a changed implementation.

This separate profile does not expand the original three-target one-hop pilot,
its calendar-date window, or the OpenCTI/STIX mapping. It makes no statement of
native acceptance for the remaining focused families or other consumers.
