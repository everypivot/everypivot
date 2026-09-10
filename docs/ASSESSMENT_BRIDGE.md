# Evidence and assessment hints

The `pivot-pattern v1.5` contract distinguishes a useful investigative result
from a suggested SAIL assessment. A successful match, the `validated` lane,
or a compatible hint does not establish an accepted analytical conclusion.

## Evidence-only patterns

```yaml
pattern_schema_version: 1.5
assessment_mode: evidence_only
```

An evidence-only pattern has no `assessment` block. Its selectors, hops,
hazards, suppression controls, and provenance still describe a usable lookup.
Its result may support a separately justified assessment later, but the
pattern supplies no default claim. For example, files sharing an import hash
are candidates for examination together; benign software, frameworks,
builders, and packers can explain that overlap.

## Conditional candidate hints

```yaml
pattern_schema_version: 1.5
assessment_mode: candidate_assessment
assessment:
  claim: indicates
  basis: assessed
  scope: incident_level
  subject_role: observation
  object_role: incident
assessment_requirements:
  - Establish the observation and an independently supported incident association.
  - Address alternative explanations and retain corroborating evidence and provenance.
  - Apply runtime assessment review before accepting any conclusion.
```

This example describes a candidate shape. The requirements must be specific
to the pattern and satisfied using case evidence. They are not Boolean claims
that the registry has checked an incident. The subject and object need actual
role mappings, identifiers, and evidence; changing their labels to satisfy a
validator is not a valid repair.

Runtime consumers own corroboration, contradictions, source reliability,
likelihood, confidence, validity, and the applicable review policy. Registry
`basis`, precision tier, or lifecycle state must not supply runtime certainty.

## Validation and exports

The schema checks the mode and required fields. The bridge checker uses the
pinned SAIL v0.4 DRAFT matrix and role/kind vocabularies shipped under
`schemas/sail-v0.4-draft/`. Their source and SHA256 digests are recorded in the
contract manifest. Validation fails if the contract is absent or corrupt.
SAIL model semantics remain authoritative and unchanged.

```sh
ruby tools/validate_pivots.rb --strict-metadata
ruby tools/check_sail_bridge.rb --json --strict-incomplete
```

The bridge checker reports four states:

| State | Meaning |
| --- | --- |
| `evidence_only` | Explicit mode; no default assessment hint. |
| `candidate_compatible` | Hint passes the checked bridge rules; acceptance is not evaluated. |
| `incomplete` | Some required compatibility information is missing or unresolved. |
| `incompatible` | A declared mode, field, role, object, or scope violates the contract. |

Object legality follows SAIL's role-or-structural-kind rule. Missing optional
legacy roles do not by themselves become illegal roles. However, an impossible
scope is still rejected: `indicates` never permits `entity_level` for any of
its legal subject roles. Legacy structural values in `object_role` retain
SAIL v0.4's deprecated compatibility treatment and produce warnings.

Registry generation refuses incomplete or incompatible mappings. The index
carries `assessment_mode`, conditional `assessment` and
`assessment_requirements`, `assessment_compatibility`, and top-level
`assessment_contract` and `assessment_coverage`. Compatibility metadata is
diagnostic; it is not authorization to accept an assessment. The patterns
bundle includes the schema and pinned contracts for offline interpretation.

Consumers must preserve evidence-only status, requirements, hazards, and
provenance. Unknown schema versions, modes, missing compatibility results, or
invalid combinations must not enable assessment generation. The browser shows
those records as unchecked and does not display their claim as an active
candidate. A hosted service must enforce equivalent behavior before adopting
the new contract; this repository does not execute a hosted assessment service.

## Migration from v1.2–v1.4

Older schemas retain their original assessment-block requirements so existing
records can be parsed and diagnosed. Parsing legacy data is not a compatibility
pass. Supplied hints are checked against the pinned PTM, and incomplete hints
cannot be published as active mappings by the registry builder.

Version a pattern when changing its bridge contract. For each pattern, review
what its lookup actually establishes, preserve its operational controls, and
choose evidence-only or a defensible candidate hint. Record why stronger
claims require additional evidence. Do not manufacture a target role or scope,
silently drop optional roles to hide an error, or downgrade the investigative
technique's lifecycle solely because its assessment metadata was wrong.

The v1.5 change is limited to the assessment boundary. It does not adopt the
separate facets, grouping, or case-bound schema proposals.
