# Future Semantic Model Proposal

Status: public design proposal; future schema version unassigned.

This proposal explores a broader semantic model: families, facets, case-bound
pivots, worked traversals, relationships, and blocked-inference objects. These
concepts are not part of implemented `pivot-pattern` v1.5. They require a
separate reviewed schema and consumer change before adoption.

The original proposal used the v1.5 name. That name now belongs exclusively to
the assessment-boundary contract described in
[`ASSESSMENT_BRIDGE.md`](ASSESSMENT_BRIDGE.md). No subsequent schema version or
release date is assigned to this broader design.

## Why a Separate Schema Change Is Needed

The implemented pattern schema, including v1.5, has
`additionalProperties: false` at the pattern root. New root
fields such as `semantic_family`, `implementation_facets`, `parent_pattern`,
`companion_patterns`, `inverse_of`, and `applies_blocked_inferences` would be
rejected by the current schema.

The existing `constraints` object can carry temporary bridge material because it
allows additional properties, but that should not become the permanent location
for grouping metadata or semantic-boundary doctrine.

## Design Goals

A future semantic-model schema could model:

- reusable pivot patterns;
- primitives and controlled vocabularies;
- case-bound pivots;
- worked traversals;
- blocked-inference objects;
- semantic families;
- typed implementation facets;
- companion and inverse relationships;
- source status and provenance;
- semantic boundaries with allowed claims, blocked claims, blocked relations,
  and required output warnings.

## Object Types

| Object type | Purpose | Initial location |
| --- | --- | --- |
| `primitive` | Shared vocabulary for node forms, relation names, or facet vocabularies. | Sidecar or schema support file. |
| `pattern` | A reusable pivot pattern. | Main pattern schema. |
| `case_bound_pivot` | A source-bound or historical instance attached to a reusable pattern. | Sidecar first. |
| `worked_traversal` | Concrete graph example with expected allowed and blocked assertions. | Fixture or sidecar first. |
| `blocked_inference` | Guardrail object saying a pivot does not support a stronger claim. | Sidecar first, then schema object. |

Identifiers in examples below are proposal examples unless they name an
existing corpus pattern. Future pattern IDs such as
`CTI_OBSERVER_SELECTOR_TO_SOFTWARE_ARTIFACT_CANDIDATE` are not present in the
current corpus. Synthetic `EXAMPLE_...` identifiers are illustrative stand-ins
for design review; they do not identify approved patterns or real cases.

## Core Fields

Candidate fields for reusable patterns:

```yaml
abstraction_level: pattern
generality: broadly_reusable
semantic_family: sample_and_file
implementation_facets:
  source:
    selector_kind: pe_import_hash
    extraction_method: pe_metadata_parser
  relation:
    evidence_basis: exact_normalized_feature_match
facet_schema_ref: everypivot.facets.sample_and_file.v1
companion_patterns: []
inverse_of: []
applies_blocked_inferences:
  - id: ANTI_SHARED_CAPABILITY_USE_TO_ACTOR_ATTRIBUTION
    applies_when:
      relation_context: shared_artifact_or_capability
      requested_claim_type: actor_attribution
    required_warning: Shared capability use is not actor attribution.
```

`semantic_family` is grouping metadata only. It does not imply inheritance,
substitutability, promotion eligibility, compatible fixtures, or shared
hazards.

## Generality And Portability

`generality` and `portability_class` should not duplicate each other.

`generality` describes the abstraction level:

- `broadly_reusable`
- `domain_portable`
- `domain_specific`
- `case_bound`
- `singleton`

`portability_class` describes how safely the relation transfers across
execution domains:

- `domain_agnostic`
- `domain_portable_with_caveats`
- `domain_specific`
- `environment_specific`
- `composite_only`

A reusable pattern can still be environment-specific if it depends on local
telemetry. A domain-specific pattern can still be reusable inside that domain.

## Parent Pattern Rule

Use `parent_pattern` only for true semantic specialization or case-bound
attachment.

Reusable child patterns require `specialization_reason`:

```yaml
parent_pattern: CTI_SAMPLE_CODESIGN_CERT_CLUSTER
specialization_reason: >
  This pattern narrows the certificate relation to issuer+serial matching and
  adds stricter multi-tenant signing controls that change the allowed claims
  and suppression behavior.
```

Do not use `parent_pattern` for implementation variants that typed facets can
represent.

## Semantic Boundary

The proposed semantic boundary would make allowed and blocked claims explicit:

```yaml
semantic_boundary:
  allowed_claims:
    - candidate_cluster_member
    - artifact_correlation
  blocked_claims:
    - actor_attribution
    - sponsor_claim
    - victim_claim
    - mission_or_intent_claim
    - maliciousness_claim
    - compromise_claim
    - runtime_confidence
    - final_assessment
  blocked_relations:
    - source_relation: shared_capability_use
      blocked_target_relation: same_actor
      reason: Shared capability use does not prove common operator identity.
  required_output_warnings:
    - Validated lifecycle state is not runtime confidence.
```

## Blocked Inference Objects

Prefer broad blocked-inference objects plus typed facets over many narrow
anti-pivot child patterns.

```yaml
id: ANTI_SEMANTIC_TOKEN_TO_ATTRIBUTION
abstraction_level: blocked_inference
blocked_relation:
  - token_overlap_to_actor_attribution
blocked_claim_types:
  - actor_attribution
  - authorship
  - ownership
target_kinds:
  - actor
  - person
  - organization
facets:
  token_type:
    - public_handle
    - language_string
    - cultural_reference
    - tool_label
    - human_reference
  source_context:
    - artifact_string
    - report_label
    - UI_text
    - public_profile
  hazard_flags:
    - spoofable
    - borrowed
    - reputational_harm
safe_substitute_relations:
  - external_reference_candidate
  - naming_hypothesis
  - artifact_correlation_candidate
reason: >
  A semantic token can support a bounded reference or correlation candidate,
  but it does not establish actor identity, authorship, ownership,
  sponsorship, victim selection, mission, or intent.
```

`safe_substitute_relations` is a proposed field on `blocked_inference` objects.
It is not a current pattern-schema field or approved graph vocabulary. Any
existing bridge under `constraints.semantic_boundary` remains temporary and
needs explicit consumer support; it does not enable assessment acceptance.

## Case-Bound Pivot Example

Case-bound pivots attach to reusable patterns without becoming reusable child
patterns:

```yaml
id: CASE_BOUND_SELECTOR_TO_ARTIFACT_SET_EXAMPLE
abstraction_level: case_bound_pivot
# Proposed parent pattern ID; not present in the current corpus.
parent_pattern: CTI_OBSERVER_SELECTOR_TO_SOFTWARE_ARTIFACT_CANDIDATE
attachment_reason: case_bound_instance
source_status: pending_source
implementation_facets:
  token_type: public_handle
  source_context: artifact_string
  extraction_method: source_review_pending
allowed_assertions:
  - Artifact correlation candidate only.
blocked_assertions:
  - Do not infer actor attribution, sponsor, victim, mission, authorship,
    ownership, maliciousness, compromise, runtime confidence, or final
    assessment.
applies_blocked_inferences:
  - id: ANTI_SEMANTIC_TOKEN_TO_ATTRIBUTION
  - id: ANTI_OBSERVER_SELECTOR_TO_AUTHORSHIP_OR_OWNERSHIP
```

This example is intentionally generic. Public case material should not be
promoted until source status, wording, fixtures, and blocked assertions are
reviewed.

## Companion And Inverse Example

Companion and inverse relationships describe graph-direction or workflow
adjacency. They are not inheritance.

```yaml
id: CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS
companion_patterns:
  - CTI_EMAIL_EMBEDDED_URL_TO_MESSAGES
  - CTI_EMAIL_PROTECTED_URL_TO_ORIGINAL_URL
inverse_of:
  - pattern_id: CTI_EMAIL_EMBEDDED_URL_TO_MESSAGES
    inverse_scope: relation_direction
    caveat: Provider URL rewriting and final URL resolution are companion stages, not exact inverses.
```

## Worked Traversal Example

Worked traversals preserve expected results and forbidden conclusions:

```yaml
id: sample_imphash_weak_positive_traversal
abstraction_level: worked_traversal
pattern_id: CTI_SAMPLE_IMPHASH_CLUSTER
source_node: file:pe:imphash:example
expected_traversals:
  - role: weak_positive
    included_targets: []
    candidate_targets:
      - file:bytes:sha256:example
    allowed_assertions:
      - The sample shares the same normalized import hash and can remain a weak candidate edge.
    blocked_assertions:
      - Do not promote this weak import-hash match without corroboration from configuration, behavior, code signing, infrastructure, or additional sample features.
blocked_assertions:
  - Import-hash reuse is not attribution, maliciousness, compromise, or final assessment.
```

## Source Status

Source status should control review and promotion handling, not confidence:

- `public`: public and citeable;
- `leaked`: public but ethically or legally sensitive;
- `analyst_supplied`: contributor or maintainer supplied;
- `pending_source`: source review incomplete;
- `unverifiable`: cannot support promotion.

## Migration Path

Safe migration order:

1. Keep the implemented v1.5 assessment-boundary contract intact.
2. Pilot future object definitions and relationships outside current pattern YAML.
3. Review the proposed shape, vocabulary, compatibility and consumer behavior.
4. Assign a separate schema version only when that design is accepted.
5. Add schema, relationship validation, fixtures and export support.
6. Migrate a small, reviewed corpus slice without changing evidence meaning.
7. Expand only after validators, consumers and promotion documentation agree.

The v1.5 assessment-boundary migration neither depends on nor approves this
design. Approval of this proposal alone would not migrate any corpus files.

## Doctrine Summary

- Implementation differences should use facets.
- Claim differences should use separate patterns or justified children.
- `semantic_family` is grouping only, not inheritance.
- `parent_pattern` is reserved for true specialization or case-bound
  attachment.
- Broad blocked-inference objects plus typed facets are preferred over many
  narrow anti-pivot child patterns.
