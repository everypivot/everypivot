# Bounded native acceptance of neo4j_cypher_v0 0.1.0

This opt-in acceptance harness covers only the three declared Neo4j targets.
It uses synthetic data and the generated query bodies. It does not evaluate
real cases, promote patterns, accept assessments, or enforce `temporal.order`,
`degree_caps`, `outputs.top_paths`, historical source availability or independent
source provenance. Calendar dates are inclusive `[as_of - window_days, as_of]`.

## Requirements and isolation

Use Python 3.10+ (standard library only), Ruby for local checks/smoke, and a
**new task-owned Neo4j Community 5.x instance**. The tested configuration was
Community 5.26.0, Java 21, heap 256–512 MiB, page cache 128 MiB, transaction timeout
10 seconds, HTTP `127.0.0.1:17474`, Bolt `127.0.0.1:17687`. The runner uses the
transactional HTTP API supported (but deprecated) in 5.26, not a third-party
driver. The smoke helper uses the bundled cypher-shell. There are no live data
feeds or external queries. Use the official Neo4j distribution and Java
requirements, verify archives, and record their exact versions and hashes.

Never reuse a user database. Before first loading, prove the fresh instance is
empty with `MATCH (n) RETURN count(n)`. In that empty database create exactly one
`EveryPivotAcceptanceOwner` node with a newly generated UUID string in `token`.
Write a task-local ownership JSON file:

```json
{"endpoint":"http://127.0.0.1:17474/db/neo4j/tx/commit","token":"the-same-task-uuid"}
```

The ownership marker is an accident-prevention check, not an authentication
mechanism. The supported harness endpoint is loopback-only. The tested disposable
instance disables authentication and binds only loopback; use only synthetic data
and shut it down after the test. Provisioning, archive checksums, process ownership,
configuration and cleanup evidence must accompany any claim of native acceptance.
The runner never creates an ownership marker in an arbitrary existing database.

The runner deletes **all EveryPivotNode nodes** in the verified task database,
creates an index on their IDs and loads synthetic fixtures. A finite streaming
computation exercises the required server-configured 10-second transaction
timeout; it does not change server settings.
Only run on the instance provisioned for this task. Stop that process and remove
its disposable data after preserving the evidence; do not stop unrelated services.

## Run

From the source checkout or a freshly extracted release pack:

```sh
ruby tools/check_query_profile_suite.rb
ruby tools/test_validation_boundaries.rb
ruby tools/check_fixture_suite.rb
python3 tools/test_accept_neo4j_query_profiles.py
ruby tools/smoke_neo4j_query_profiles.rb --reset-fixtures -- --address bolt://127.0.0.1:17687
python3 tools/accept_neo4j_query_profiles.py \
  --ownership-file /absolute/task/ownership.json \
  --output /absolute/task/new-evidence-directory --high-cardinality
```

The output directory must be new. `--pattern-id` selects one or more known targets;
unknown targets fail. A missing database or dependency is failure, not a skip.
Omitting `--high-cardinality` records skips and returns nonzero; it is not complete
native acceptance. The largest fixture has 50,002 nodes / 50,001 relationships.
Allow several minutes and space for the compressed request/record evidence.

## Oracle and evidence

The authored JSON contracts in `fixtures/query-profiles/neo4j/acceptance` explicitly
state the reviewed direction, forms, relation, window and applicable suppression
side/lists. Caveats are copied from pattern hazards and blocked assertions from
the authored fixture; neither is inferred from Cypher results. Scenario expected
inclusions are specified individually, independently of the Ruby reference
traversal evaluator. That evaluator remains an additional local comparison in
the existing suites, and its unique target list is not a native row-count oracle.

The harness removes only complete `:param` shell lines, decodes their string
values, verifies the authored defaults, and saves the remaining query body plus
parameters. It does not insert DISTINCT, LIMIT, date guards, new predicates or
result transformations. Loader statements are split outside strings/comments.
Structured records are compared as complete JSON multisets: order is immaterial,
row multiplicity is preserved, and extra/missing fields, rows and wrong values fail.
Duplicate-relationship cardinality is an observation of this query, not a new
portable deduplication policy. Source-suppressed zero results pass only after
node/edge/property/direction inspection proves the fixture loaded correctly.

Each scenario runs twice and compares full graph state before/after, including
node labels, properties, internal identities, all relationship types/endpoints
and properties. This demonstrates persisted graph preservation for these runs;
it does not prove every database metadata or filesystem byte remains unchanged.
Every native request, response, timing and database error is recorded in
`native-requests.jsonl.gz`. Per-scenario JSON gzip files contain inputs, complete
expected and actual records, cardinalities and persisted fixture evidence.
`summary.json` records runtime, source hashes, outcomes and skips.

Invalid or unsupported dates are rejected by preflight. Separate deliberate raw
native probes bypass that preflight and record the actual database response;
those observations do not become supported-date acceptance. Null and omitted
parameters/properties are separate cases. Native query errors, failed fixture
load rollback and transaction timeout are expected-failure checks.

The harness tests reject identifiers appearing only in caveats, extra targets,
malformed/wrong records, wrong evidence direction, extra columns, lost or invented
multiplicity and an accidentally empty graph. Whole-database state inspection
and null/omission regressions protect findings raised by independent review.
