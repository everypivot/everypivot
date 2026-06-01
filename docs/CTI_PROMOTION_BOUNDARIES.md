# CTI Promotion Boundaries

EveryPivot CTI patterns describe reusable graph-pivot mechanics. They do not
encode analyst assessment, attribution confidence, operational effect, or
private review state as public graph vocabulary.

## Boundary Rule

CTI graph pivots may represent an observable relationship only when the public
pattern names a reviewed source form, target form, relation, direction, and hop
form. Assessment context belongs in hazards, blocked assertions, fixture
evidence, release notes, or other public-safe review text.

Do not encode the following as public relation names, relation suffixes, target
forms, pattern IDs, catalog entries, registry fields, or fixture roles:

- confidence;
- scoring;
- final assessment;
- source method;
- source-scope caveat;
- review state;
- attribution confidence;
- operational effect;
- collection method;
- private gate state;
- private review requirement;
- excluded private data;
- promotion readiness;
- analyst sign-off state.

Generated review strings such as `supports_assessment_context`,
`supports_review_context`, `supports_control_context`,
`supports_detection_context`, `supports_prioritization_context`,
`requires_private_review`, and `excluded_private_data` are not public relation
vocabulary.

## Promotion Gate

Before a CTI candidate is promoted, reviewers must confirm:

- the catalog tuple is accepted for the public observable relationship;
- fixtures are synthetic and role-complete;
- blocked assertions cover attribution, maliciousness, compromise, runtime
  confidence, operational effect, ownership, impact, and final assessment;
- real indicators, commands, exploit details, credentials, C2 infrastructure,
  victim/customer context, raw telemetry, and live/current claims are excluded;
- `tools/check_cti_promotion_lint.rb`, schema validation, relation catalog
  review, and fixture checks pass;
- reviewer sign-off is recorded by someone distinct from the candidate's
  primary drafter;
- the public review trail is durable in release notes, pattern review metadata,
  or another release-packed artifact.

Validated lifecycle status is an editorial promotion state. It is not runtime
confidence, attribution, maliciousness, compromise, ownership, impact, or final
assessment.

## Sidecar-Shaped Context

Source-scope caveats, attribution confidence, vulnerability priority,
defensive-control recommendations, cloud/SaaS trust-boundary caveats, IT/OT
segmentation context, extortion continuity context, fraud/account-control
context, detection coverage, AI/data-lineage context, private C2 review,
malware mechanism review, and indicator-review material remain outside public
graph relations unless a future public schema and tooling proposal explicitly
defines a safe representation.
