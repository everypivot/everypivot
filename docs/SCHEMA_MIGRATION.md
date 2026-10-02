# Schema Migration

## Current Contract

Authoring v1.6 adds the explicit execution-reference capability described in
[`SEMANTIC_EXECUTION_CONTRACT.md`](SEMANTIC_EXECUTION_CONTRACT.md). It preserves
v1.5's assessment modes below. Both 1.5 and 1.6 remain distributable during this
focused migration; only 1.6 can declare an execution reference. The general
families/facets proposal remains separate. Individual migrated patterns and
execution contracts have their own versions.

`pivot-pattern` v1.5 defines the evidence/assessment boundary. Each pattern
explicitly selects one of two modes:

| Mode | Required behavior |
| --- | --- |
| `evidence_only` | Omit both `assessment` and `assessment_requirements`. The pattern supplies a lookup and its limits, with no default assessment claim. |
| `candidate_assessment` | Include a complete compatible `assessment` and a nonempty list of specific `assessment_requirements`. These describe a possible claim and its qualifying evidence; they never accept a conclusion. |

The JSON schema accepts pattern schema versions `1.1`, `1.2`, `1.3`, `1.4` and
`1.5` and `1.6`. Existing documentary patterns use `1.5`; migrated executable
definitions use `1.6`. Versions 1.1–1.4 remain available for
historical and compatibility checks. Parsing an older pattern does not establish
SAIL compatibility or supply a missing evidence-only declaration. Even a complete
compatible legacy hint remains diagnostic material and requires migration before
current registry distribution (stable, preview or edge) or release packaging.
Builders reject the whole publication unit before writing outputs; they do not
upgrade versions, discard retained hints or invent modes or requirements.

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

### Package Repository Provenance

The package/repository pair now uses individual pattern version `3.0.0`, with
authoring schema `1.6` and digest-bound execution references. Its first hop is the explicit
`declares_source_repository` relation, stored from an exact package version to
the repository named by a version-specific registry declaration. The SUPPLY
pattern follows that edge outward; the CROSS pattern follows it inward. Their
infrastructure hops remain distinct. The former entity-creation order strings
are removed; the explicit 3650-day UTC window binds an observation of the particular
infrastructure relationship and the supplied query date. Historical knowledge is
a separate optional cutoff with its own supporting availability bindings.

Consumers of the former `published_from` or package-pair `publishes` edges must
recheck their source records for an exact package version, repository identity
and preserved registry declaration. A legacy edge is not automatically a
qualified declaration. Do not migrate it merely by renaming the relation or
substituting the repository's current revision. Missing source revision leaves
the declaration available with an unresolved snapshot binding.

The separate `everypivot.package_repository_provenance` contract, version
`1.0`, is defined by
[`PACKAGE_REPOSITORY_PROVENANCE.md`](PACKAGE_REPOSITORY_PROVENANCE.md) and
[`package_repository_provenance.v1.schema.json`](../schemas/package_repository_provenance.v1.schema.json).
The sidecar itself introduces no pattern YAML fields and does not change the
registry release, SAIL pin or adapter formats. The separately versioned execution
reference uses the authoring 1.6 capability. Consumers must opt into this
sidecar contract and preserve its unresolved states and evidence-only limits.
Its local checker verifies record shape and bounded snapshot consistency; it
does not accept a complete infrastructure traversal or verify build provenance.

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
4. Set `pattern_schema_version: 1.5` for the documentary assessment capability,
   or `1.6` when adding a verified explicit execution reference, and increment the individual pattern
   version for the changed contract. Do not relabel entities or omit roles to
   hide a mismatch, and do not treat a match as satisfaction of the requirements.
5. Run document and full bridge validation, then review the resulting candidate
   shape and preserved operational behavior.

```sh
ruby tools/validate_pivots.rb graph-pivots --strict-metadata --strict-bridge --current-distribution
ruby tools/check_sail_bridge.rb graph-pivots --json --strict-incomplete --current-distribution
```

JSON Schema validates document shape. The shared bridge checker additionally
validates predicate, role-or-kind and subject-specific scope compatibility
against the pinned SAIL contracts. Both are required for a distributable
candidate; neither evaluates whether case evidence supports a conclusion. The
explicit `--current-distribution` flag additionally enforces the v1.5 distribution
assessment distribution policy for 1.5/1.6. Omitting it preserves legacy diagnostics; strict bridge completeness
alone does not forbid complete legacy hints. Diagnostic output reports legacy
records as non-distributable and separates semantic counts from current coverage.

## Migrate Consumers and Generated Artifacts

For authoring 1.6, verify `execution.contract`, `version`, package-relative
`path` and exact-file `sha256`, then validate the closed contract grammar and its
pattern ID/version/result forms. The registry and browser separately bind the
checked execution declaration to those exact inputs. A checked declaration is
not proof of runtime behavior. Consumers that lack this capability must report
unsupported execution; they must not fall back to the old free-text order or
last-hop projection convention.

### JA3 and JA3S migration

`OSINT_TLS_JA3_TO_FQDNS` 2.0.0's mixed purpose is replaced by client-only 3.0.0
and companion `OSINT_TLS_JA3S_TO_FQDNS` 1.0.0. Both use authoring 1.6; the
original working-set lane is retained, and the companion starts in working-set,
without claiming validated maturity or updating any existing review date.
The registry release and pinned SAIL contract are unchanged.

Legacy untyped fingerprint rows require their actual kind, message role,
exchange/leg, source revision, and domain-association evidence. Do not infer a
response, transfer a JA3 classification to JA3S, or convert DNS/SAN/scan-plan
co-occurrence into an observed exchange. Source-reported values keep that basis.
Client and server messages use their own occurrence dates. A case period is
required; the former 365-day window is no longer an automatic default.
The former 5,000-degree and three-path values may be deliberately chosen as
resource/display presets but are not hidden qualification predicates. Actual
binding/result budgets are required by the execution request. Common-profile
and scanner filters are explicit selections with recorded scope and reasons,
not mandatory inherited negative-node exclusions. No lane promotion follows
from the normalized synthetic tests. Native/source adapters remain a separate
acceptance gate.

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


## Focused executable migrations

The focused migration contains 45 executable definitions: the package pair,
eleven extraction patterns, fifteen certificate/signing patterns, client JA3
and its new server JA3S companion, eight sanctions patterns, four existing
result-binding patterns and three new listing patterns. Ordinary 2.0.0
interpretation changes become 3.0.0; the source-map, phase and creative 0.2.0
patterns become 0.3.0. New companions start at 1.0.0. These are unreleased
working-tree changes, not a new registry release or renewed maturity review.

`CTI_SBL_HOSTING_RISK` 3.0.0 remains authoring 1.5 as a deprecated compatibility
identifier with no execution reference. Consumers must explicitly choose
`CTI_IP_TO_LISTING_ASSERTIONS`, `CTI_ASN_TO_EXPLICIT_LISTING_ASSERTIONS` or
`CTI_ASN_TO_LISTED_INFRASTRUCTURE`. Old risk scores and ASN-wide implications
cannot be converted into publisher assertions by renaming edges.

Consumers must resolve the exact execution reference, verify its byte hash and
pattern/version/output-form correspondence, and implement the required finite
capability or return unsupported. Legacy free-text order expressions cannot
serve as a fallback. Named bindings, branch-specific outputs, constructed
context records, scoped exclusion states and explicit query limits replace
assumptions about terminal nodes, date aliases, feature calculation and fixed
path caps. A missing control is distinct from an explicit suppression.

Extraction consumers need preserved content, exact representation-qualified
selectors, run and capture correspondence, complete finding history and the
selected control revisions. URL output remains distinct from generic resource
references; a DNS host is not invented for every URI. Sanctions consumers need
explicit source/entry revisions, source-stated applicability, amendment context
and the chosen inquiry. A beneficial-owner relationship cannot be relabelled as
control. Historical reports are not legal conclusions.

Existing review dates and lanes retain their prior evidential scope. Neither
schema validation nor synthetic execution claims native adapter or analyst
acceptance. Generated indexes, browser data and release packs must be rebuilt
and checked from the same working-tree inputs. Stale generated files are not
acceptance evidence. The 134 other original patterns remain outside this audit.
