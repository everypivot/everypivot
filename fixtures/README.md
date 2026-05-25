# Fixtures

Validation fixtures and golden examples for the public EveryPivot&trade; contract.

> Fixture content in this directory is licensed under
> [CC BY 4.0](../LICENSE-DATA); the surrounding tooling is under
> [Apache-2.0](../LICENSE-CODE). &copy; 2026 EveryPivot Project. See [`LICENSE`](../LICENSE),
> [`NOTICE`](../NOTICE), and [`TRADEMARK.md`](../TRADEMARK.md).

Current contents:
- `validator_suite.yml` manifest for automated fixture checks
- `cases/` library roots with pass/fail scenarios for schema, lane, and metadata validation
- `examples/` traversal evidence packs for first-use and promotion examples
- `query-profiles/` synthetic fixture graphs for adapter/query profile demos

Run the suite with:

```bash
ruby tools/check_fixture_suite.rb
ruby tools/check_query_profile_suite.rb
```

The suite currently covers:
- minimal valid `v1.4`, `v1.3`, `v1.2`, and `v1.1` patterns
- lane mismatch rejection
- required-field rejection
- enum rejection
- forbidden additional-property rejection
- deferred-reason enforcement
- current assessment-bridge enforcement
- traversal evidence examples with expected included, suppressed, and blocked
  assertions

## Fixture Roles

Traversal evidence packs use `fixture_roles` to make the purpose of each
example explicit:

- `positive`: a traversal that should return the documented target.
- `weak_positive`: a candidate relation that is mechanically true but still
  needs corroboration before a downstream system treats it as meaningful.
- `cautionary_positive`: a true relation that is likely to be overread unless
  caveats are shown near the result.
- `cautionary_negative`: a near miss that looks plausible but should be blocked
  by a documented caveat.
- `negative`: a relation that should not join the source and candidate target.
- `suppression`: a relation that may exist as evidence but should be withheld
  from ordinary results because of negative-node, temporal, or local policy
  controls.
- `high_cardinality`: a noisy value whose main value is explaining fan-out,
  suppression, or rarity behavior rather than making a positive cluster claim.

Evidence packs must include blocked assertions. Those statements are part of
the fixture contract: they say what a consumer must not infer from the
traversal, even when the raw edge exists.

## Traversal Evidence Examples

- [`examples/osint_ssh_hostkey_cluster.evidence.json`](examples/osint_ssh_hostkey_cluster.evidence.json)
  supports the [`START_HERE`](../docs/START_HERE.md) walkthrough. It covers
  exact host-key reuse, stale-edge suppression, shared-hosting suppression, and
  a different-key negative control.
- [`examples/cti_sample_imphash_cluster.evidence.json`](examples/cti_sample_imphash_cluster.evidence.json)
  covers import-hash clustering, weak-positive corroboration, common-packer
  suppression, and high-cardinality handling.

All examples are synthetic. They use reserved example domains or documentation
IP ranges and are not live observation data.

## Query Profile Fixtures

- [`query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json`](query-profiles/neo4j/osint_ssh_hostkey_cluster.graph.json)
  supports the Neo4j/Cypher adapter pilot for
  [`OSINT_SSH_HOSTKEY_CLUSTER`](../graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml).
- [`query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher`](query-profiles/neo4j/osint_ssh_hostkey_cluster.load.cypher)
  loads the same synthetic graph into Neo4j for local demo execution.
- [`query-profiles/neo4j/cti_email_originating_ip_to_messages.graph.json`](query-profiles/neo4j/cti_email_originating_ip_to_messages.graph.json)
  supports the Neo4j/Cypher adapter pilot for
  [`CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES`](../graph-pivots/working-set/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.yaml).
- [`query-profiles/neo4j/cti_email_originating_ip_to_messages.load.cypher`](query-profiles/neo4j/cti_email_originating_ip_to_messages.load.cypher)
  loads the same synthetic graph into Neo4j for local demo execution.

Query profile fixtures are synthetic graph fixtures. They are used to prove
generated adapter output preserves caveats and blocked assertions without adding
backend-specific fields to pattern YAML.
