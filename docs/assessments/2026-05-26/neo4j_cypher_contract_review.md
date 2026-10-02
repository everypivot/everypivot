# Neo4j/Cypher Contract Review

Date: 2026-05-26
Status: historical repository-local contract review

## Scope

This dated review covers the Neo4j/Cypher query-profile contract as it stood on 2026-05-26, not live
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

The reviewed contract covered:

- one outbound validated target;
- one inbound working-set target;
- one validated source-side full-block suppression target;
- generalized query-profile target discovery;
- explicit graph-simplification limits for scalar negative-list membership,
  temporal-order enforcement, degree caps, and top-path limits;
- documented adapter-versus-fixture license boundaries.

The historical record reports the following local checks passing:

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

These limits bound the scope of this historical review. It is not a fresh
execution record for a later revision.

## Related mapping profile

The separate OpenCTI/STIX profile provides bounded object mapping. It does not
supply live connector acceptance or define new pattern semantics.
