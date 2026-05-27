# Neo4j/Cypher Contract Review

Date: 2026-05-26
Status: accepted for EP-WP15 second-adapter planning

## Scope

This review covers the current Neo4j/Cypher query-profile contract, not live
Neo4j runtime correctness for arbitrary production graph models.

Reviewed surface:

- backend-neutral pattern YAML boundary;
- profile metadata under `adapters/query-profiles/`;
- three declared Neo4j/Cypher targets;
- synthetic query-profile fixtures and loaders;
- generated Cypher freshness;
- generated-output field allowlist and forbidden assessment fields;
- carried-forward hazards, caveats, and blocked assertions;
- source-side full-block suppression coverage.

## Acceptance Basis

The contract is accepted for moving to the EP-WP15 second-adapter decision
because the repository now has:

- one outbound validated target;
- one inbound working-set target;
- one validated source-side full-block suppression target;
- generalized query-profile target discovery;
- explicit graph-simplification limits for scalar negative-list membership,
  temporal-order enforcement, degree caps, and top-path limits;
- documented adapter-versus-fixture license boundaries.

Local verification passed:

```bash
ruby tools/check_query_profile_suite.rb
ruby tools/check_fixture_suite.rb
ruby tools/validate_pivots.rb --strict-metadata
```

## Residual Limits

Accepted residuals:

- the optional live `cypher-shell` smoke helper was not run as part of this
  review;
- generated Cypher remains a demo artifact, not a production correctness
  guarantee;
- scalar negative-list membership is still a pilot simplification;
- `temporal.order`, `degree_caps`, and `outputs.top_paths` remain documented
  downstream responsibilities.

These residuals do not block the second-adapter decision because they are
documented, checked where currently feasible, and outside the stated pilot
contract.

## Second-Adapter Gate

With this review accepted, EP-WP15 may proceed to a second adapter decision.
The next adapter work should be scoped as OpenCTI/STIX-side mapping coverage,
not as a live OpenCTI connector or a new source of pattern semantics.
