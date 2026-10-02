# Neo4j normalized semantic evidence adapter

`neo4j_semantic_evidence_v1` adapter version **0.1.0** is a separate, explicitly
hybrid profile. Neo4j Community **5.26.0** stores and returns the normalized
evidence graph. `tools/semantic_evaluator.rb` executes the admitted portable
contract after graph identity and relationship checks. The adapter does not
translate that expression language into native Cypher predicates.

The adapter profile contract is `everypivot.semantic_adapter` **1.0**; the
mapping is **1.0**. These versions are independent of the three semantic
contracts **1.0**, authoring schema **1.6**, individual pattern versions,
registry release and SAIL. The original three-target `neo4j_cypher_v0` profile
is unchanged. Its results and this profile's results are different contracts.

## Inputs and execution boundary

Inputs are validated `everypivot.semantic_evidence` 1.0, optional exact preserved
source bytes, an admitted `everypivot.semantic_pattern` 1.0 contract, and its
explicit query. JA3 and JA3S admissions name individual pattern versions and
canonical contract hashes in
[`neo4j_semantic_evidence_v1.json`](../semantic-profiles/neo4j_semantic_evidence_v1.json).
An absent or changed contract admission is unsupported; no legacy fallback is
attempted. Admission declarations are not themselves execution evidence.

The adapter receives already normalized source assertions. It does not parse
PCAP, authenticate log producers, collect network traffic, import OpenCTI/STIX,
or establish that a source assertion is true. The synthetic fixture's source
JSON and hash establish which authored bytes were used. They do not establish
source independence, signature verification, ownership or actor identity.

```text
normalized evidence + preserved bytes
  -> structural validation and explicit native graph mapping
  -> task-owned Neo4j import batch
  -> native records and relationships read back
  -> external receipt hash + payload hash + relationship reconstruction checks
  -> portable evaluator with the exact admitted contract and explicit query
  -> evidence results, diagnostics, policy context and partial/complete coverage
```

No semantic predicate is prefiltered by Neo4j. This avoids quietly discarding
unknown, conflicting, optional or excluded witnesses before the portable
evaluator can account for them. It also means this version reads the entire
supplied batch into memory. It is a bounded acceptance implementation, not a
production query planner or large-corpus performance claim.

An adapter result identifies a verified mapping and portable evaluation. It
cannot prove that a supplied graph snapshot came from a native server. Native
execution therefore requires the separate transaction attestation; the offline
codec/evaluator API never reports native acceptance by itself.

## Native mapping

Each node has exactly the `EveryPivotSemanticItem` label and task owner/import
batch identity. Its role is `envelope`, `record`, `source` or `source_bytes`.
Payloads use canonical JSON and SHA-256. Canonicalization sorts object keys but
preserves arrays, nulls, strings, numbers, booleans and source/record order.
Record nodes also project exact `kind` and `record_type` scalar properties.
Preserved bytes use strict Base64, including binary content. When a source
declares a content hash, supplied bytes must match it before import.

| Native edge | Meaning and retained properties |
| --- | --- |
| `EVIDENCE` | Record to exact source revision record; source field and evidence-reference ordinal retained, including duplicates. |
| `SUBJECT` | Record to its explicitly named subject record. |
| `OBJECT` | Record to its explicitly named object record. |
| `TIME_OBJECT` | Carrier record to the time envelope's bound object; escaped time-field/alternative path retained. |
| `TIME_OCCURRENCE` | Carrier record to the time envelope's bound occurrence, independently of its object; path retained. |

Complete time and selector envelopes remain in the payload, including original
values, precision, clock metadata, revisions, conflicting alternatives and
selector provenance. These are not Neo4j timestamps or implicit host-clock
conversions. A source revision is a property of its retained source record;
source labels or equal revision strings cannot collapse independent records.

The write receipt keeps the input's canonical SHA-256 and an order-independent
graph SHA-256 outside Neo4j. Readback checks that receipt, each payload digest,
every edge/direction/property/multiplicity, and contiguous array ordinals. It
rebuilds the expected graph from returned payloads and compares complete graph
identities. Missing, added, duplicated, reversed, cross-batch or altered edges
are invalid mappings, not semantic negatives. Hashes supply content identity,
not an authentication or hostile-administrator security boundary.

## Isolated native acceptance

The runner accepts only an explicit HTTP port on `127.0.0.1` and the
`/db/neo4j/tx/commit` endpoint. A fresh UUIDv4 ownership marker can be created only
after verifying an empty database. Every read/write checks the exact marker,
runtime version and absence of foreign nodes/edges. It never clears an existing
database. Each case appends a fresh synthetic batch; deliberate corruption
probes affect only those task-owned batches. Do not use a user database.

Provision the exact pinned runtime separately. Neo4j5.26 supports Java21; the
runtime attestation must record the actual Java build and archive hashes.
Use a loopback-only configuration, disable Bolt, HTTPS and usage reporting, and
set a bounded transaction timeout. The HTTP transport is specific to this
version; it is not a claim of compatibility with newer server APIs. Relevant
upstream references are the
[Neo4j runtime requirements](https://neo4j.com/docs/operations-manual/current/installation/requirements/)
and [configuration reference](https://neo4j.com/docs/operations-manual/current/configuration/configuration-settings/).

```sh
ruby tools/test_semantic_neo4j_adapter.rb
ruby tools/accept_semantic_neo4j.rb \
  --endpoint http://127.0.0.1:27474/db/neo4j/tx/commit \
  --owner YOUR_FRESH_UUID_V4 --claim-empty --output /absolute/new/report-directory
```

The offline test performs no native execution. Native acceptance requires the
second command to finish successfully with actual transactions. Omit
`--claim-empty` only when reusing the same task-owned marker; a new output
directory is always required. Unavailable dependencies, refused ownership,
unexpected runtime, failed assertions and connection failures are failures,
never successful skips.

The native runner records all Cypher statements, parameters and responses in a
hashed transaction journal; original case contract/evidence/query/expected
files; preserved source bytes; complete results; input and graph receipts;
actual runtime; relevant implementation and fixture hashes; assertion counts;
and full database-state hashes before and after reads. The separately authored
expectations cover client/server roles, their independent UTC dates, planned
versus actual messages, exchange/leg joins, source revision and clock unknowns,
historical knowledge, selected suppression and partial resource limits.

Full-result parity with direct portable execution is an additional mapping
check. It is **not** an independent semantic oracle. Native edge deletion,
cross-batch relationships, wrong-owner writes and nonempty-database claims have
separate rejection assertions. Reported acceptance is limited to those exact
cases, source mapping, implementation hashes and native runtime. It does not
admit all patterns, raw collectors, other backends, operational deployment,
analyst acceptance or accepted assessments.

## Extending admission

For each new family, first author its portable contract and independent
positive/negative/unknown/suppressed/partial cases. Prove its source/witness
mapping and preserved-byte requirements. Add the exact pattern version and
canonical contract digest to the admission manifest, extend the native runner's
independent assertions, run its real transactions, and retain the resulting
report. A changed contract requires a new explicit digest admission and tests;
updating a pin alone supplies no evidence. Mapping or transport changes require
their own version/migration decision and native regression execution. Leave
uncovered families unsupported rather than treating shared storage as proof of
their semantics.
