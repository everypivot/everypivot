# Schema Migration

## Purpose

This note records the public EveryPivot schema migration stance for the v0.3
semantic-doctrine track.

It is planning guidance, not a schema change. The public corpus remains on the
current accepted schema versions until a reviewed migration lands.

## Accepted Schema Versions

The current `pivot-pattern` schema accepts:

- `1.1`
- `1.2`
- `1.3`
- `1.4`

New public pattern work should use the newest accepted schema unless there is a
specific compatibility reason not to.

## Current Boundary

Schema v1.4 has a closed root object: unknown root fields are rejected.

That means v1.5 concepts such as `semantic_family`, `implementation_facets`,
`parent_pattern`, `companion_patterns`, `inverse_of`, and
`applies_blocked_inferences` cannot be added directly to pattern YAML without a
schema version change.

Do not add schema-facing fields early just because the doctrine is being
designed.

## v1.4 Compatibility Bridge

The v1.4 `constraints` object can carry temporary compatibility material
because it allows additional properties.

Acceptable bridge material may include:

```yaml
constraints:
  semantic_boundary:
    allowed_claims:
      - candidate_cluster_member
    blocked_claims:
      - actor_attribution
      - final_assessment
    safe_substitute_relations:
      - artifact_correlation_candidate
```

This is a bridge only. It should not become a second permanent location for
v1.5 semantics.

Do not put `semantic_family` under `constraints`. It is grouping metadata, not
an enforcement constraint.

## v1.5 Design Targets

Schema v1.5 design should cover:

- primitives;
- reusable patterns;
- case-bound pivots;
- worked traversals;
- blocked-inference objects;
- semantic families;
- typed implementation facets;
- companion and inverse relationships;
- source-status and provenance fields;
- semantic boundaries with allowed claims, blocked claims, blocked relations,
  and required output warnings.

## Doctrine Rules

- `semantic_family` is grouping metadata only. It does not imply inheritance,
  substitutability, promotion eligibility, or compatible fixtures.
- Use `parent_pattern` only for true specialization or case-bound attachment.
  Reusable child patterns need an explicit `specialization_reason`.
- Implementation differences should use typed facets.
- Claim differences should use separate patterns or justified children.
- Prefer broad blocked-inference objects plus typed facets over many narrow
  anti-pivot child patterns.
- `safe_substitute_relations` belongs on `blocked_inference` objects in v1.5.
  Any v1.4 use under `constraints.semantic_boundary` is temporary.

## Promotion Expectations

Schema migration does not promote a pattern.

Promotion still requires:

- useful and reusable pivot semantics;
- clear hazards and caveats;
- appropriate metadata for the target lane;
- fixture or evidence support where applicable;
- explicit maintainer review;
- no unresolved credible challenge.

Validated lifecycle state is not attribution, maliciousness, compromise,
runtime confidence, or final assessment.

## No Automatic Corpus Migration

The v0.3 semantic-doctrine work should not migrate the public corpus
automatically.

The safe sequence is:

1. Finish the public-safe doctrine.
2. Review the v1.5 schema proposal in
   [`SCHEMA_V1_5_PROPOSAL.md`](SCHEMA_V1_5_PROPOSAL.md).
3. Add sidecar or fixture pilots where needed.
4. Add schema support.
5. Migrate a small reviewed slice.
6. Expand only after validation, fixtures, and promotion docs agree.
