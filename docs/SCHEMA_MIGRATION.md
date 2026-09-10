# Schema Migration

## Current Contract

`pivot-pattern` v1.5 defines the evidence/assessment boundary. Each pattern
explicitly selects one of two modes:

| Mode | Required behavior |
| --- | --- |
| `evidence_only` | Omit both `assessment` and `assessment_requirements`. The pattern supplies a lookup and its limits, with no default assessment claim. |
| `candidate_assessment` | Include a complete compatible `assessment` and a nonempty list of specific `assessment_requirements`. These describe a possible claim and its qualifying evidence; they never accept a conclusion. |

The JSON schema accepts pattern schema versions `1.1`, `1.2`, `1.3`, `1.4` and
`1.5`. Current pattern authoring uses `1.5`; older versions remain available for
historical and compatibility checks. Parsing an older pattern does not establish
SAIL compatibility or supply a missing evidence-only declaration.

See [`ASSESSMENT_BRIDGE.md`](ASSESSMENT_BRIDGE.md) for examples, compatibility
states and the pinned, unchanged SAIL v0.4 DRAFT contract.

## Scope and Version Boundaries

The older families/facets/case-bound proposal once used the v1.5 name. That work
is now the separately reviewed
[`FUTURE_SEMANTIC_MODEL_PROPOSAL.md`](FUTURE_SEMANTIC_MODEL_PROPOSAL.md), with no
schema version assigned. The implemented v1.5 does not introduce its
`semantic_family`, `implementation_facets`, `parent_pattern`,
`companion_patterns`, `inverse_of`, `applies_blocked_inferences` or
`semantic_boundary` root fields. Unknown root fields remain invalid.

Pattern schema versions, individual pattern versions, registry release versions,
SAIL contract versions, adapter formats and sidecar formats are independently
versioned. Migrating pattern YAML to `1.5` does not rename those other formats.
Historical releases and intentional legacy-compatibility fixtures retain their
original versions.

## Migrate a Pattern

1. Review what the source, target and hops actually establish. Preserve lookup
   behavior, hazards, suppression, provenance, capability requirements and
   lifecycle state unless a separately justified change is needed.
2. Choose `evidence_only` when the lookup supplies a clue without a defensible
   default assessment mapping. Remove the former hint and record the limitation
   in the review trail; do not replace it with an unsupported stronger claim.
3. Use `candidate_assessment` only when the intended subject, object and scope
   follow the SAIL contract. Keep `claim`, `basis`, `scope`, `subject_role` and
   at least one of `object_role` or `object_kind`. Add pattern-specific,
   nonblank `assessment_requirements` describing qualifying case evidence,
   alternatives and acceptance review.
4. Set `pattern_schema_version: 1.5` and increment the individual pattern
   version for the changed contract. Do not relabel entities or omit roles to
   hide a mismatch, and do not treat a match as satisfaction of the requirements.
5. Run document and full bridge validation, then review the resulting candidate
   shape and preserved operational behavior.

```sh
ruby tools/validate_pivots.rb graph-pivots --strict-metadata --strict-bridge
ruby tools/check_sail_bridge.rb graph-pivots --json --strict-incomplete
```

JSON Schema validates document shape. The shared bridge checker additionally
validates predicate, role-or-kind and subject-specific scope compatibility
against the pinned SAIL contracts. Both are required for a distributable
candidate; neither evaluates whether case evidence supports a conclusion.

## Migrate Consumers and Generated Artifacts

Consumers must distinguish evidence-only patterns from conditional candidates.
They must preserve requirements, hazards, provenance and compatibility coverage,
and prevent unknown, incomplete or incompatible records from enabling assessment
generation. A consumer cannot infer an active hint from a missing mode or infer
acceptance from a compatibility pass.

Regenerate the registry index, manifests, archives, browser JSON/JS, schema
copies, embedded YAML sources and release pack from the same reviewed source and
release identifiers. Ship the pinned contracts and checker with portable
artifacts. Validate the exact export, including freshness, package contents,
consumer displays, license coverage and public-safety checks, before publication.
See [`REGISTRY_INDEX_SPEC.md`](REGISTRY_INDEX_SPEC.md) for exported fields and
[`REPO_PUBLISHING_AND_VERSIONING.md`](REPO_PUBLISHING_AND_VERSIONING.md) for
release preparation.

## Existing Doctrine and Promotion

Existing `constraints.semantic_boundary` material is a temporary compatibility
convention, not a standardized v1.5 assessment mechanism. Do not add it to bypass
`assessment_mode`, the bridge checker or runtime review. Consumers need explicit
support before such material can enforce a boundary; grouping metadata does not
belong under `constraints`.

Schema migration does not promote a pattern. Promotion still requires useful
pivot semantics, clear hazards, appropriate lane metadata, fixture or evidence
support, explicit maintainer review and no unresolved credible challenge.
Validated lifecycle state is not attribution, maliciousness, compromise, runtime
confidence or final assessment. CTI promotion additionally follows
[CTI promotion boundaries](CTI_PROMOTION_BOUNDARIES.md).
