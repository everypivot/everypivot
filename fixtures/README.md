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
- `package-repository-provenance/` synthetic sidecars for the separately versioned package/repository provenance contract

Run the suite with:

```bash
ruby tools/check_fixture_suite.rb
ruby tools/check_query_profile_suite.rb
ruby tools/test_validation_boundaries.rb
ruby tools/test_package_repository_provenance.rb
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

`check_fixture_suite.rb` checks structure and bounded one-hop consistency for
the current four packs: unique node/traversal IDs, source/target forms,
relation and direction, joins for declared included/suppressed targets,
disconnected negative controls, disjoint result lists, and nonempty documentary
source labels. Unsupported shapes fail with a request for a separate oracle.
These checks do **not** execute temporal/order constraints, suppression policy,
fan-out caps, dependence or assessment acceptance. Source labels are not resolved
anchors and do not prove independent corroboration. Replayed/copied reporting,
future/stale suppression, source-anchor resolution and policy-dependent cases
need explicit downstream execution evidence. Only the separate query-profile
suite executes its documented bounded date-window and negative-list rules.

A structural or topology PASS must not be described as full traversal execution
or sufficient promotion evidence. Promotions must identify the exact executed
oracle and its limits, or retain the outstanding semantic expectations as
unexecuted review requirements.

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

## Package/Repository Provenance Fixtures

[`package-repository-provenance/`](package-repository-provenance/) holds synthetic
sidecars for `everypivot.package_repository_provenance` v1.0, independent of the
pattern authoring v1.5 schema. `test_package_repository_provenance.rb` uses these
records and temporary synthetic Git repositories to exercise declaration and
exact committed-snapshot provenance. This suite runs separately from the
bounded one-hop traversal evidence checker and is a named release-pack gate.

An exact source binding requires a pinned commit and Git object algorithm;
current `HEAD`, checkout contents and uncommitted files cannot substitute for
that snapshot. Unsupported Git links or LFS content remain unresolved. A
qualified result means registry-declared source evidence only, with
`build_provenance: not_verified`; fixtures do not prove that a real package was
built from the source, establish an accepted assessment or supply native adapter
acceptance. The helper's `--check` mode validates supplied shape and
self-consistency only, not external provenance.

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
- [`query-profiles/neo4j/cti_sample_imphash_cluster_source_suppression.graph.json`](query-profiles/neo4j/cti_sample_imphash_cluster_source_suppression.graph.json)
  supports the Neo4j/Cypher adapter pilot for
  [`CTI_SAMPLE_IMPHASH_CLUSTER`](../graph-pivots/validated/CTI_SAMPLE_IMPHASH_CLUSTER.yaml).
- [`query-profiles/neo4j/cti_sample_imphash_cluster_source_suppression.load.cypher`](query-profiles/neo4j/cti_sample_imphash_cluster_source_suppression.load.cypher)
  loads the same synthetic graph into Neo4j for local demo execution.
- [`query-profiles/opencti/cti_sample_imphash_cluster.stix_mapping.json`](query-profiles/opencti/cti_sample_imphash_cluster.stix_mapping.json)
  supports the OpenCTI/STIX mapping pilot for
  [`CTI_SAMPLE_IMPHASH_CLUSTER`](../graph-pivots/validated/CTI_SAMPLE_IMPHASH_CLUSTER.yaml).

Query profile fixtures are synthetic graph and mapping fixtures. They are used
to prove generated adapter output preserves caveats and blocked assertions
without adding backend-specific fields to pattern YAML.


## Focused semantic families

`semantic-families/` contains independent normalized synthetic evidence and
expected outcomes for package/repository, extraction, certificate presentation,
certificate expansion, signing, JA3/JA3S, sanctions and result bindings. Each
family README specifies actual source fields, roles, time/identity profiles,
unknown states and inference limits. Run `ruby tools/check_semantic_suite.rb`;
`--json` preserves commands, runtimes, counts and output hashes. Failures and
skips cannot count as acceptance. Source fixtures are synthetic, including
preserved hashes and collection/history assertions; they do not claim an actual
external source, native parser, source authenticity or analyst review.

The four earlier evidence packs retain their bounded one-hop scope and are not
silently upgraded to semantic family acceptance. Lane/review metadata remains
historical unless an actual separately recorded review changes it.
