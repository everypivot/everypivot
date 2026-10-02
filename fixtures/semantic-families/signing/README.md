# Signing and Authenticode complete-finding fixtures

These synthetic fixtures exercise the finite portable contracts for
`CTI_APK_SIGNING_CERT_CLUSTER`, `CTI_SAMPLE_CODESIGN_CERT_CLUSTER`,
`CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT`,
`SUPPLY_CODESIGN_CERT_TO_PACKAGES` and `CTI_AUTHENTICODE_HASH_CLUSTER`, each
bound to pattern version 3.0.0. Contract version 1.0, pattern version and
authoring schema version are separate. The source of the interpreted decisions
is the accepted signing, certificate validity/discovery, package signing,
Authenticode comparison/reference, case-period and credential-class sections
of `docs/UNRESOLVED_SEMANTICS.md`. This is an executable normalized-evidence
profile; it is not a native format parser, verifier or deployed adapter.

Run `ruby tools/test_semantic_signing.rb` and `ruby tools/test_semantic_identity.rb`
from the repository root. `cases/` contains ten saved input sets with explicit
expected result IDs. `fixture_factory.rb` independently states semantic claim
identities, required support sets and establishment dates. It does not execute
contract predicates to derive those expectations. It loads contract bytes only
to bind a finding-history qualification to their canonical JSON digest. The
tests change evidence, preserve corrected fixture hashes and independently
state the resulting admissibility. They do not establish analyst acceptance.

## Questions and result identities

| Purpose | Required relationship | Result meaning |
| --- | --- | --- |
| `certificate_presence` | Exact artifact → extracted certificate, with actual reported role/location | Certificate presence in those artifact bytes; no signer inference |
| `reported_signer` | Exact artifact → selected signature/material → actual certificate/key in primary or timestamp role | A source-reported signer association; no successful-check prerequisite |
| `scoped_verified_signature` | The reported signer path plus the exactly corresponding, successful scoped check report | Source-reported verification of the selected signature over the declared content; no local reproduction is implied |
| Authenticode `image_content` | Exact artifact → typed source-reported image digest, established input scope | Image-digest comparison; no required signature or certificate result |
| Authenticode `signature_material` | Exact artifact → particular selected signature/blob/container material, representation and role | Equality under that declared material digest recipe; no valid timestamp or artifact signature is inferred |

The first three purposes return the particular `file:bytes` for APK/sample/Strict,
or an `it:prod:softver` package version only with its additional exact distribution
artifact join. Authenticode returns the particular `file:hash`. Certificate
identity is an explicitly retained witness in the certificate-purpose fields;
this profile does not manufacture a separate terminal certificate row. The
package presence purpose is explicitly a package-artifact certificate-presence
finding, not a claim that the package/product was signed. The supporting artifact
and distribution variant remain in every package result.

Finding identity includes purpose, whole-artifact identity, actual certificate
identity where used, selected comparison identity, role, and selected signature/
covered-content/attachment meaning where required. Package identity adds
ecosystem, namespace, name, version and distribution variant. It excludes
processing run, check time, tool version, receipt, display grouping, and query
execution time. A changed normalization or content scope is an explicitly
different comparison question; a tool update by itself is not new evidence.

## Source and selector mapping

Each consumed record has a stable record ID and `evidence` entries naming actual
source IDs and originating fields. Sources retain publisher, document, revision,
collection and unknown or evidenced independent origin. A selector has mandatory
`provenance.source`, `record_id`, `source_revision`, `field` and `basis` (`reported`
or `derived`; derived additionally names method/version). A selector's carrier,
source revision and field must agree with its bound record evidence. Source
presence does not authenticate a report or establish independent corroboration.

| Selector kind | Recipe and scope |
| --- | --- |
| `artifact_sha256` | SHA-256 over exact whole-artifact bytes; `representation: bytes`, `normalization: exact_bytes_v1`, `scope: whole_artifact` |
| `certificate_sha256` | SHA-256 of complete certificate DER, `exact_der_v1`, `whole_certificate` |
| `spki_sha256` | SHA-256 of exact SPKI DER including algorithm identifier/parameters; `subject_public_key_info` |
| `issuer_serial` | Explicit exact issuer namespace/rule and decimal or hexadecimal serial radix; no full-certificate identity claim |
| `scheme_content_digest` | Explicit algorithm, representation, normalization recipe, content scope, recipe version and signature scheme; declared source-computed digest, never an implicit full-file hash |
| `authenticode_image_digest` | Explicit algorithm, representation, normalization, covered scope and recipe version; distinct from all other kinds |
| `signature_material_digest` | Explicit algorithm, representation, normalization, scope, recipe version and actual primary/timestamp/chain/other role |

Digest kinds never fall back to each other. Whole-certificate is the normal
certificate selector; explicit SPKI is a separate question. The Strict companion
accepts only issuer/serial tuples and does not silently acquire SPKI semantics.
Authenticode also allows explicit issuer/serial certificate questions. Query
selector parameters are purpose-specific and reject inadmissible kinds before
joining records. A valid selector in a wrongly named evidence field is defeated
by the field's declared-kind predicate.

`artifact_sha256.content_base64`, or certificate PEM/DER material where supplied,
allows the identity helper to reproduce the corresponding content hash. Absent
bytes remain source-reported; contradictory reported and reproduced hashes are
unresolved. Signature and scheme-content digest recipes are compared, not locally
computed or verified by this profile. The public certificate vectors come from
`../certificate-presentation/certificates.json`: two distinct certificates share
a key and a third uses a different key. No private key is packaged.

## Record-level bindings

* `file:bytes` / `file:hash`: `attributes.identity` is `artifact_sha256`.
  Optional capture and signature-inspection context remains source-labelled.
  A changed signed derivative cannot reuse another file's attachment or finding.
  Every APK branch also requires that artifact's source-reported `format: apk`;
  certificate presence in an unrelated file format is not an APK finding.
* `x509:cert`: `certificate_selector`, `spki_selector` and/or
  `issuer_serial_selector` retain their distinct typed identities. Actual
  certificate identity is required on all certificate-witness result paths.
* `artifact:certificate_presence` assertion: subject artifact, object certificate;
  exact `artifact_identity` and `certificate_selector`, actual `role`,
  `basis: reported_extraction_from_exact_artifact`, source location and method/
  version. Presence does not need an invented signature object.
* `code:signature:material` entity: `identity` is a role-typed
  `signature_material_digest`; `role` agrees with that digest and the query.
* `signature:signer_binding` assertion: subject selected signature, object actual
  certificate; exact whole-certificate and SPKI selectors, role, source location,
  `basis: reported_selected_signature_signer`. Primary and timestamp are explicit
  supported signer roles; chain/other/unknown cannot qualify as primary signers.
* `signature:artifact_binding` assertion: subject exact artifact, object selected
  signature; exact artifact/signature identities, `covered_content` of kind
  `scheme_content_digest`, matching scheme, format, covered object, source
  location and method/version. `correspondence` explicitly selects embedded,
  detached, catalogue-member or manifest-member evidence. A catalogue member
  claim is not an individual signature on every referenced object. APK requires
  the declared format `apk`; this does not claim an APK parser was run.
* `signature:verification_check` occurrence: subject artifact, object signature;
  exact artifact, selected signature, actual certificate, SPKI and scheme-content
  identities must agree with the entire selected path. Scheme, format and role
  must also agree. Required successful evidence has `check_status: success`,
  `basis: source_reported_scoped_check`, `crypto_check:
  selected_signature_over_declared_content`, verifier/reporting actor, method,
  version, limitations and report location. `times.checked` binds that artifact
  and check occurrence and cannot postdate its collection availability.
  A bare `signed` boolean cannot replace this record. Failed, unsupported,
  unavailable, incomplete and malformed check reports remain distinct optional
  context for a supported reported signer; they do not qualify the successful
  check purpose. No chain trust, platform acceptance or signing time is inferred.
* `analysis:authenticode_image_digest` occurrence: subject artifact; exact artifact
  identity, typed selector, method/version, covered/excluded scope and reported
  `input_status: scope_and_digest_established`. Unknown image input boundaries
  defeat the digest claim even if signature processing is optional. An observed
  absence of embedded signing does not rule out detached or catalogue signing.
* `analysis:signature_material_digest` occurrence: subject artifact, object actual
  selected material; exact artifact identity and material selector, source
  location, method/version and `input_status:
  selected_material_and_digest_established`. The selector role and material role
  agree with the query. Timestamp-certificate reuse and exact timestamp-material
  equality are separate inquiries and do not prove a verified timestamp.
* `package:distribution_artifact` assertion: subject exact artifact, object
  package/version; exact artifact identity, variant, source location and
  `basis: reported_exact_distribution_artifact`. The version entity explicitly
  identifies ecosystem, namespace, name and version. Names or current URLs alone
  cannot supply this join.

These are actual source assertions with explicit content/relationship operands,
not unbound `verified: true`, `signed: true` or maintained-status shortcuts. Their
truth is not independently established merely by satisfying this contract.
Contradictory source records are retained as separate witnesses. A stronger
verification claim has its own purpose/identity/history and does not reset an
older reported association.

## Finding, historical reference and time scope

Every query requires a resolved explicit case `period` and exact `history` ID.
There is no inherited 3650-day default. The saved query and its digest preserve
resolved scope. A client resolving a preset must also preserve its case/preset
origin and relative anchor in its own query provenance; this evaluator accepts
resolved dates and does not invent or resolve hidden presets.

Every candidate support record has `times.collection_available`, bound to that
record and an actual `evidence:availability` occurrence for the named collection.
The envelope names source field/revision, UTC clock and uncertainty, timezone,
precision and occurrence/interval meaning. A preserved `finding:history` manifest
lists exact-hashed support and actual `finding:establishment` occurrences plus
the collection origin and history snapshot. The underlying manifest source bytes
must be supplied and match their SHA-256. The history qualification is bound to
the contract's canonical JSON digest. Complete coverage is explicitly a source
assertion over that declared scope, not independently proven global completeness.

Required support must be available by an actual establishment; the maximum of
component dates alone never manufactures that establishment. Equivalent replay,
extra reports and changed tool versions leave the earliest supported complete
finding unchanged. Unknown prior history, missing establishment or partial
qualification cannot prove a recent first finding. The December 2024 sighting
in the fixtures stays a December sighting when a finding is established in
September 2026. Certificate validity and later verification are separate facts.

Authenticode `reference_mode` selects either a sufficiently specified typed
selector with provenance, or `artifact_derived` with an exact
`reference_artifact`. The latter requires the same full purpose-specific
evidence path for that artifact; a candidate cannot repair a missing reference.
Its named bindings appear in `finding.reference_support`, disjoint from candidate
support. They are qualified and source-backed normally, but are excluded from
the candidate's earliest complete finding. Later selection/receipt of a reference
does not renew a candidate's history. A selected historical knowledge cutoff
still requires actual reference availability by that cutoff. Retrospective use
does not invent an earlier knowledge date. No all-history or recursive fetch is
performed. Other signing families use their specifically selected certificate
seed; this reference mode is not silently generalized to them.

An optional query `knowledge_cutoff` gates the actual candidate establishment and
the availability of all required candidate/reference/seed support. Missing or
incomparable knowledge evidence remains unresolved. This states availability to
the selected collection, not individual analyst awareness. Unknown signing time
does not defeat an otherwise supported association. Dates outside certificate
validity are retained as source context; verification time is not signing time.

## Classification, conflicts and limitations

`policy:signing_credential` assertions retain exact certificate or SPKI selector,
actual role, class, membership, source basis, revision and applicable validity
interval. The default preserves this context. An exclusion needs
`exclude_selected_credentials: true`, explicit `classification_records`, pinned
`classification_revision`, an exact `classification_class`, and an independently
selected `classification_period`. A shared-service member and a debug-key
nonmember are different claims, not a conflict that cancels the selected class.
Its `basis_mode: selected_period_context_not_signing_time` prevents treating the
finding date as a signing date. Classification by public key is an explicit
SPKI comparison; it does not merge the certificate identities.

Supported member and opposing/dual-purpose/contested assertions under the same
selected policy retain the result with an unresolved conflict. Missing evidence
or membership means neither clearance nor exclusion. Class labels such as test,
default, debug, publicly available private key and shared signing service remain
distinct source classifications. A public certificate does not prove access to
its private key. Credential class does not establish an artifact's intended
purpose, benignness, operator or common campaign. Role-specific classifications
cannot transfer timestamp membership to the primary signer. Signer-class controls
do not affect independent image-content or signature-material digest branches.

The migrated Strict companion uses the explicit contextual default and selectable
exclusion, so its legacy promised blanket exclusion must be migrated with its
pattern version and consumer documentation. No review-date or lane advancement
is supported by these synthetic tests.

## Correction and withdrawal context

The required `amendment_sources` array explicitly selects actual evidence source
IDs for correction/withdrawal context. Required relationship, analysis and check
assertions carry their source `assertion_namespace`. The amendment hook covers
every required assertion/occurrence, including separately qualified historical
reference assertions, and uses `retain_reports` only. After independently
establishing and dating a complete historical finding, the evaluator attaches
source-qualified amendment states. A correction or withdrawal never renews the
first-finding date or silently replaces its support with corrected material.
The historical report can remain a result labelled corrected/withdrawn; it is
not described as maintained current support.

An `evidence:assertion_amendment` assertion names the exact target assertion as
subject, namespace, operation (`correct`, `withdraw`, `reinstate`, `dispute`) and
issuing evidence source. A correction names the actual distinct replacement
assertion as object. Corrections by a different publisher cannot silently replace
another publisher's report. Explicit `supersedes_amendments` relations, not
recency alone, resolve supported revision chains. Conflicts or ambiguous
amendment scope remain labelled gaps with no forced winner. Under a knowledge
cutoff, actual source-qualified publication and collection receipt are required;
later amendments remain separate later context, and missing receipts do not
establish earlier absence. Absence of a supplied amendment means only
`reported_in_supplied_scope`, never universally current, verified or unwithdrawn.
The bounded scan cannot assert absence or completion if its budget truncates.

Results distinguish invalid/unsupported input, unresolved qualification or dated
eligibility, no qualifying result, explicit suppression and technical partial
results. Work and result budgets are explicit. This profile performs no external
retrieval, native format processing, private-key test, cryptographic signature
check, chain policy, publisher authentication, independent-origin evaluation,
maliciousness, ownership, attribution or accepted assessment. First-finding
evaluation admits retained amendment context, not a current-support exclusion
or an amendment-driven novelty rule. SAIL assessment contracts are unchanged.
