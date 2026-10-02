# Package/repository traversal profile

Run `ruby tools/test_semantic_package_repository.rb`. These are synthetic portable
cases, with fixed independently authored expected endpoints. They do not fetch
a registry, authenticate a publisher, execute a native database or verify builds.

`seed` selects an exact package-version or repository entity. The stored
`package:repository_declaration` assertion always has subject = package and
object = repository. Its `sidecar_id` and `metadata_id` name preserved evidence.
SUPPLY follows a `repository:infrastructure_observation` of that repository;
CROSS follows a `package:infrastructure_observation` of that exact version.
The endpoint is the actual observation object. These are distinct second hops.

`evidence:package_repository_provenance` carries actual preserved sidecar JSON;
`attributes.document` must equal those parsed bytes. The existing independent
provenance contract 1.0 checks package/repository correspondence, exact declared
commit identity and snapshot-manifest self-consistency. `version_source_repository`
is required; a bare `mirror_reference` is a known nonmatch. The package's
registry/name/version and source-backed literal repository URI must agree with
the sidecar. No mirror, redirect or imported-history equivalence is inferred.

`evidence:registry_document` preserves the original document. Its reproduced
digest and linked publisher, collection, document URI, revision and field anchor
must agree with the sidecar's declaration evidence. A registry-specific raw
parser is not executed: this remains a source-qualified normalized declaration.
Both documents have `attributes.content` source ID/revision, field, SHA-256,
byte length and `exact_source_bytes` representation, limited to 1 MiB each.
Missing bytes are unresolved; malformed sidecars or mismatched hashes are
invalid; unsupported recipes/sizes stay unsupported. No hash proves truth.

The result retains unresolved or reported revision/snapshot state. The traversal
does not read Git objects. `package_repository_provenance.rb --repo` separately
reproduces local Git content; a supplied manifest is not newly verified source
content and neither capability verifies a package build.

An observation uses `profile: relationship_observation_v1`,
`basis: direct_relationship_observation`, collector-scoped `occurrence_key`,
the actual relation and source-backed endpoint selector. SUPPLY permits
`operated_via` or `distributed_from`; CROSS permits `distributed_from` or
`referenced_by`. These are source-reported relations, not ownership/control.
Copies retain their original occurrence key. Ingestion, publication and revision
changes cannot manufacture another observation.

`times.observed` binds that repository/package and actual observation, its source
field/revision, clock, timezone, precision and uncertainty. Qualification uses
the inclusive UTC interval `[query_date - 3650 days, query_date]`. Uncertain
boundary placement remains unresolved; older/future observations are outside.
Creation, mirror/import and publication dates remain context. An observation
may precede or follow publication without a universal creation-order gate.

Retrospective discovery permits late acquisition. A selected `knowledge_cutoff`
additionally requires every required record's `times.collection_available`,
bound to its actual availability occurrence and specified collection. Missing
availability blocks that historical inquiry. This is collection availability,
not an individual analyst's knowledge or global first discovery.

The inherited repository exclusion uses preserved `policy:repository_membership`
assertions with selected `policy_revision`, policy ID,
`profile: literal_uri_membership_v1` and exact URI. Positive nonmembership also
requires `coverage: complete_for_evaluated_subject`. Missing/conflicting control
evaluation withholds output while retaining the candidate; supported membership
is suppression. A selected policy revision does not claim historical policy
availability at a knowledge cutoff. Source independence and assessment status
remain unevaluated. Lanes and review dates are preserved.


The `package_repository_observation` predicate additionally requires linked
`origin_source_id`, `occurrence_namespace`, `collector`, `occurrence_key` and
`relation`. Publisher/collection/document identify the supplied origin scope;
revision and normalized row ID do not create a new occurrence. All supplied
reports in that scope are examined within the query work budget. Different
endpoints or normalized time bounds retain unresolved competing evidence,
including conflicts entirely inside the window. Unknown counterpart origin or
time cannot clear the conflict. Explicit correction resolution is outside this
profile; newer receipt/revision never wins automatically. Distinct genuinely
source-supported occurrence keys may qualify as new observations. This does
not establish cross-source independence or global equivalence.

The observation requires its originating source revision/field; collection
availability may instead use its own unambiguous linked receipt source and
clock. Both require explicit object/occurrence bindings and an actual
availability occurrence in the input collection. A completed
observation cannot qualify as available before it occurred, with or without a
historical cutoff. Preserved source claims are not authenticated by this check.
