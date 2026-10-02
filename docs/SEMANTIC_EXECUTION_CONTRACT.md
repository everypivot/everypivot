# Explicit semantic execution contract

Implementation status: **focused families implemented; acceptance remains explicitly scoped**.
Pattern-specific interpretations and limits are documented in
[`UNRESOLVED_SEMANTICS.md`](UNRESOLVED_SEMANTICS.md). There are 45 digest-bound
executable definitions: 41 migrated original patterns and four new companions.
The original broad SBL identifier remains an explicitly deprecated,
non-executable compatibility definition. The other 134 original patterns have
not received this focused semantic migration. Neither schema validation nor
synthetic execution establishes analyst, lifecycle or assessment acceptance.

The independently versioned draft contracts are
`everypivot.semantic_pattern` 1.0, `everypivot.semantic_evidence` 1.0 and
`everypivot.semantic_results` 1.0. The implemented authoring capability is 1.6, with
one closed root-level `execution` reference containing contract, version, path
and SHA-256. The reference is also checked against the pattern ID and individual
pattern version. The authoring schema and validator now admit 1.6 with the
explicit reference. Consumers must opt into the capability or report unsupported.
Version 1.5 remains distributable during this focused migration and cannot carry
an execution reference. Registry release v0.6.0, the package-provenance contract
1.0 and SAIL v0.4 DRAFT have separate version identities.

## Encoding and evaluation

`tools/semantic_contract.rb` compiles a finite declarative vocabulary. It never
evaluates Ruby, JavaScript, arbitrary expressions or legacy `temporal.order`
strings. Duplicate JSON members, unknown operators, versions, fields and unbound variables fail closed.
Contract references must stay inside the packaged `contracts/semantics/`
directory, match their exact byte digest, and declare only the pattern's output
forms. Hashes identify content; they do not authenticate a publisher or establish
the truth of a source assertion.

Each branch declares ordered `bindings` with unique names, record kind, explicit
types and predicates. References use a named variable and literal field path;
the compiler disallows forward variable references in binding predicates.
Optional context remains optional: unavailable or unproven optional context must
not discard an independently supported base result. Distinct branch paths and
conflicting source assertions remain separate witnesses.

Diagnostics from optional joins are labelled `optional_context`. They remain
visible, but cannot turn a known failed or outside-period required path into an
unresolved qualifying claim. If the selected inquiry actually requires that
missing context, such as a historical knowledge receipt, its required predicate
still yields unresolved.

Operands are exactly one of `ref`, `param`, `literal`, `context`,
`selector_identity`, `evidence_sources` or `calendar_period`. The only implicit context value is the validated input's
collection ID. `selector_identity` computes the typed comparison identity,
excluding provenance and reprocessing metadata. Predicate operators are
`all`, `any`, `not`, scalar `eq`/`ne`, scalar-set `in`/`contains`, `present`,
`all_in`, `nonblank_text`, `nonblank_text_array`, `nonnegative_integer`,
`binding_absent`, `file_set_equal`, `file_set_shared_paths`, `ip_in_prefix`,
`typed_equal`, `time_compare`, `time_compare_if_present`, `within`, `coexists`,
`content_matches`, `uri_component_equal`, `package_repository_declaration`,
`package_repository_observation`, `certificate_profile_matches` and `ct_name_in_scope`. Structured values cannot acquire
identity through ordinary equality, including two structures containing unknown
identifiers. Missing values remain unresolved; absence does not become a false
statement merely through negation. A known contradiction, an unknown value and
an unsupported operation are different outcomes.

Parameters can declare finite scalar `enum` choices, `selector_kinds` coverage,
and `requires_when`/`allowed_when` for parameters required or permitted by a named
inquiry choice. A period supplied to a purpose that cannot interpret it is
invalid configuration, rather than silently ignored. Unknown
choices are invalid configuration; a well-formed selector outside the selected
contract's coverage is unsupported, even on an empty evidence input. A `date`
parameter is an explicit ISO UTC calendar date. `calendar_period` takes a date
parameter and a nonnegative integer literal duration; it never reads the clock.
`string_array` parameters may require `min_items`, `unique_items` and an
`item_reference` of `source` or `record`. Referenced identities are checked before
search, even if no path qualifies. Unknown IDs are invalid input.
`evidence_sources` names a bound record and reads its actual evidence links.
`all_in` requires every linked source ID to fall within the deliberately selected
scope; an empty support set does not prove qualification. Source IDs resolve to
the exact revisions in this input, rather than arbitrary source-label attributes.

Time references additionally require branch `time_bindings`, each naming the
value and the expected bound object and occurrence. A timestamp from another
valid record is not thereby the timestamp for this role. Operand source revision
and source field must agree with the carrier record's linked evidence. A selected
historical-knowledge cutoff requires explicit `knowledge` operands; an activity
time cannot silently substitute for availability. Unselected historical knowledge
does not impose a new retrospective activity gate.
The reserved normalized `times.collection_available` profile additionally
requires an actual source-backed `evidence:availability` occurrence in the
input collection whenever that time participates in a selected predicate.
Other named activity/publication times do not become collection receipts; their
family contract must supply its own explicit receipt and knowledge checks.

Results explicitly use `bound` projection or `construct`. A bound result must
have the declared form, and may be an earlier binding. A construction uses a
deterministic typed identity over declared identity components and records its
supporting bindings and source evidence. It creates an evidence record, never an
accepted assessment. Exact duplicate witness results can be deduplicated;
different source revisions, paths and conflicts cannot be merged solely because
their endpoint IDs agree.

## Evidence and source identity

The closed evidence schema is
[`semantic_evidence.v1.schema.json`](../schemas/semantic_evidence.v1.schema.json).
`tools/semantic_records.rb` supplies its explicit companion validator rather than
assuming the legacy partial JSON Schema checker implements every schema keyword.

A record has an ID, kind (`entity`, `assertion`, `occurrence` or `finding`), type,
attributes, named time envelopes and evidence references. Subject and object
references, when supplied, identify actual records. Duplicate identities and
dangling references are invalid. Empty evidence permits encoding an unproven
candidate or query seed; it does not qualify an assertion, occurrence or finding.
A selected seed identity alone supplies no qualifying evidence.

Sources keep publisher, document, revision, collection and independent origin
distinct. Explicit null means unknown. A source hash includes its algorithm and
byte/content scope; a declared hash is not automatically reproduced. Source
labels, copied documents, syndication, shared upstream feeds and repeated imports
do not become independent origins. No independence evaluator or numerical
corroboration score is introduced. Raw attributes are data, including any source's
reported status; names such as `match`, `verified` or `complete` are not execution
instructions or proof of qualification.

`content_matches` binds an artifact record to an actually linked source, exact
SHA-256, byte length and `exact_source_bytes` representation. Supplied preserved
bytes must reproduce both the source digest and the artifact digest. Missing
bytes remain unresolved; inconsistent bytes are invalid input; a transform or
decompression recipe is unsupported until explicitly defined. This operation
does not retrieve content, run an extractor or authenticate a source. The result
attestation lists exact hashes and lengths of supplied source bytes separately
from the normalized evidence and contract hashes.

## Time model

`tools/semantic_time.rb` retains original evidence and produces UTC bounds. Each
envelope binds object and occurrence, originating field, source revision, clock
identity/reference/uncertainty, timezone and precision. A displayed `Z` does not
prove a clock's calibration. Missing timezone, uncertainty or other required
metadata remains unresolved; an unsupported clock mapping remains unsupported.
Unknown end dates never become infinite service or validity.

An uncertain occurrence describes possible actual instants. An established
service or validity interval describes a source-supported continuing state.
They have different quantifiers:

| Predicate | Meaning |
| --- | --- |
| `contained` | The entire possible occurrence, or entire stated interval, is inside the selected period. A boundary-crossing uncertain occurrence is unresolved. |
| `some` | An established service/validity interval intersects the selected period. Possible occurrence overlap is insufficient. |
| `all` | An established service/validity interval covers the whole selected period. |
| `at` | A separately bound occurrence falls inside the established state and the selected period. |

`coexists` asks whether all named established service/validity intervals have
common applicability within the selected period. Individual overlap with the
same broad period is insufficient. An ownership interval ending in 2024 and a
listing beginning in 2026 do not establish a contemporaneous chain, even when
both intersect a 2024–2026 inquiry. Possible occurrence overlap, missing ends and
conflicting time alternatives cannot establish coexistence.

Calendar periods use inclusive UTC dates, implemented as a half-open interval
from the first day's start through the day after the last. `calendar_window`
implements `[query_date - window_days, query_date]` without an implicit current
date. This does not widen or change the existing bounded Neo4j pilot.

Ordering compares all possible occurrence instants, without selecting a favorable
instant from coarse or conflicting evidence. Equal known instants can compare
equal; overlapping coarse timestamps need not. Original observation, derivation,
complete-finding establishment and collection knowledge remain separate events.
Complete-finding qualification and equivalent-finding history use
`tools/semantic_finding.rb`; max(component timestamps) is insufficient. A branch
declares stable claim identity components, every required non-seed support,
qualification identity/revision, a history record and the selected finding
period. The engine independently qualifies all corresponding support paths
before passing them to the history checker. A partial search cannot establish
first availability. Exact manifest source bytes, source/revision/collection,
record digests, actual establishment events, support availability and history
origin/endpoint are checked. Earliest equivalent established knowledge remains
earliest after repeated processing. Unknown earlier equivalent history prevents
later processing from manufacturing freshness. History completeness is a
source-asserted, bounded collection claim, not authenticated global completeness.

## Typed identity

`tools/semantic_identity.rb` separates whole-certificate SHA-256 over exact DER,
SPKI SHA-256 over exact DER including its algorithm identifier, explicit
issuer-namespace/serial tuples, Authenticode image digests, signature-material
digests, JA3, JA3S and URI references. A renewed certificate may share SPKI while
remaining a different certificate. Serial radix and issuer matching scope are
explicit. Image-digest comparison does not transfer signature verification.

Every selector retains its originating record/source/revision/field and reported
or derived basis. Record-derived selectors must agree with the carrier's linked
evidence. Where actual certificate/SPKI material is supplied, local reproduction
is reported separately from a source-reported digest. A conflicting reported
digest remains unresolved. These operations neither authenticate the source nor
verify a signature, prove ownership/control or identify an actor.

URI parsing preserves scheme, optional authority, path, query and fragment.
Supported URL locators keep a separate URL mapping alongside the URI. No generic
URI is forced to have a domain or IP. The literal comparison recipe does not
silently equate percent-encoding, case, ports, fragments or path variants.

`uri_component_equal` exposes only finite URL, DNS-host, host-kind and scheme mappings. A `file` authority retains its lexical host; an empty authority supplies no host. Generic URI support does not imply hostname semantics for every scheme.
URL comparisons retain the exact URI bytes; a valid non-URL URI can remain a
resource reference. DNS-host comparison requires a source-backed `dns_name`
selector with the ASCII hostname profile: case and final root dot are normalized,
wildcards and IP text are excluded, and IDNA/percent decoding are not inferred.
An unfamiliar scheme's hostname semantics are unsupported. A lexical host does
not prove DNS resolution, content service, ownership or control. IPv4 comparisons
use strict dotted decimal with no ambiguous leading-zero or alternate forms.

## Policies, resources and outcomes

Explicit policies name their ID/revision, subject, effect scope, predicate,
default and optional analyst-selection parameter. Source, path, occurrence and
result scopes remain distinct. Unknown classification is visible and does not
mean clearance; source/path exclusions must not erase unrelated evidence.
An explicit `conflict_when` predicate preserves opposing or dual-purpose policy
assertions without choosing a winner. A truncated cross-path classification
search cannot silently become a completed exclusion. Family-specific defaults,
including the controlled-deployment exception for
phishkit discovery, must be authored in the actual family contract.

A policy with `required_evaluation: true` requires an explicit `allow_when`
nonexclusion predicate as well as the exclusion predicate. Missing, unsupported
or conflicting eligibility evaluation withholds ordinary output and retains the
projected evidence candidate in diagnostics. This is distinct from suppression.
`applies_when` may establish explicit non-applicability, such as a DNS-only
control on an IP URL; non-applicability is not a clearance claim. Optional
advisory controls retain a base result with visible gaps. Path policy identity
uses required qualification bindings, so contradictory optional classifications
cannot evade conflict handling by having different record IDs.

`binding_absent` names an optional binding. It succeeds only after all supplied
candidates for that binding have been examined without a matching or uncertain
candidate. Missing source support and incomplete execution do not establish
absence. This is a bounded anti-match over supplied evidence, never evidence
that no contrary report exists elsewhere.

The query supplies positive mathematical-integer binding and result budgets.
The `max_bindings` work budget includes candidate checks, priority preparation
amendment-history visits and package observation-equivalence scans. Coverage reports consumed work units separately
from actual examined binding candidates. Exceeding either limit returns partial
output, preserving the requested scope. `search_complete_for_supplied_input`
distinguishes completed search from `result_selection.truncated` display/output
selection; the count before the result cap is explicitly reported. No cap proves
absence in unexamined evidence.

An occurrence binding may declare `priority` with its own source-backed `time`
and an explicit `period`. It also requires a normal object/occurrence time
binding. This orders visits into recent, outside-focus, then undated/unresolved
groups; record ID breaks ties deterministically. It is not an eligibility gate.
A family must define actual receipt or substantive-derivation evidence in that
occurrence's predicates; deployment time cannot silently substitute. Preparation
is budgeted, older/undated results remain eligible, and partial preparation
cannot claim complete recent-first coverage. Result priority metadata records
the examined focus and reasons. No performance improvement is asserted. No runtime confidence, maliciousness, attribution, authority or accepted
assessment follows from a match or a completed traversal.

Results separate execution status (`complete` or `partial`) from semantic
outcome: qualified evidence (possibly with gaps), unresolved, unsupported,
outside scope, suppressed or no qualifying result. Malformed requests raise a
typed invalid-input error. Every result includes exact contract/input/query
identities, witness bindings, source records and predicate/policy evaluations.
Coverage concerns only the supplied evidence, not external completeness.

## Integration and acceptance gates

An admission requires complete-finding equivalence and history where applicable,
family qualification/comparison profiles, independent behavioral cases,
authoring and consumer migration, and separate backend acceptance where claimed.
The focused portable profiles provide these synthetic cases; any additional
source or runtime must supply its own mapping and acceptance evidence. Preserve the existing bounded profiles rather than silently
upgrading their meaning. Run the full project and extracted-package checks, then
perform an independent requirement-by-requirement re-review. Lane promotion,
review-date renewal, release publication and SAIL changes are not side effects.

## First certificate migration

`OSINT_CERT_SHA_TO_DOMAINS` 3.0.0 requires an explicit purpose:
`certificate_name_association` or `observed_presentation`. The former emits a
concrete DNS name asserted in an identified certificate/precertificate field;
it does not infer network use or borrow a validity/discovery clock. The latter
requires a presentation occurrence and a name association to that same service
context, scoped by analyst-selected UTC dates. Supplying a presentation period
to name-only discovery is rejected rather than ignored.

`OSINT_CERT_TO_SERVERS` 3.0.0 requires actual presentation. Its IPv4 and FQDN
projections have separate address/name correspondence checks and retain the
presentation and service identities. A later DNS observation cannot supply the
missing join. Unknown port, protocol or vantage stays unknown. Source class
and address class filters are explicit and scoped; renewed certificates do not
inherit the selected certificate's class merely by sharing a key.

Both patterns select a source certificate and an explicit whole-certificate or
SPKI selector. Candidate certificate identity and actual presented certificate
identity are checked independently. Matching SPKI does not identify the whole
certificate; a key-only report cannot fabricate a certificate witness. Hashes
reported by a source remain distinguished from hashes reproduced from supplied
DER/PEM. Certificate-name and presentation assertions are source-qualified:
these contracts do not run a CN/SAN extractor, network probe or signature verifier.
Existing lane labels and review dates are preserved historical metadata, not
new analyst or native acceptance of the migrated versions.


## Amendment context and preserved comparisons

A branch may declare `amendments` over every required assertion/occurrence,
with explicit selected source revisions. `retain_reports` preserves historical
reports together with their supplied correction, withdrawal, reinstatement or
dispute evidence. `require_unwithdrawn_in_scope` additionally qualifies support
against those supplied amendments; it does not establish exhaustive publisher
history or current truth. Supersession requires an explicit same-assertion,
same-publisher revision relation; the newest receipt does not win. Cycles are
invalid. Historical knowledge needs actual publication and collection receipt
bindings, while later amendments remain labelled later context. Amendment work
consumes the execution budget. Combined first-finding branches admit retained amendment context only. The
engine establishes candidate history first, then attaches amendments without
changing its earliest finding date. Amendment-state exclusion is not admitted
on a first-finding branch. Elsewhere, an explicit selected amendment exclusion
names its exact support bindings and withdrawn/corrected states; a sale-report
withdrawal cannot silently exclude an unrelated certificate observation.

`file_set_equal` invokes a finite preserved-manifest profile. It reproduces exact
manifest, coverage-inventory and member bytes, compares literal relative paths
and hashes, and verifies the source-asserted inventory against the manifest. Optional `scope_kind` selects
`collected_file_set` or `declared_subset` against the actual parsed and verified
manifest scope; a matching subset cannot satisfy the whole collected-file-set
comparison.
It does not establish that the supplied scope contains every deployed file,
parse an archive, authenticate the publisher or prove deployment. Fixed per-side
limits are 1 MiB manifest, 1 MiB inventory, 10,000 entries and 64 MiB member bytes;
oversized comparisons are explicitly unsupported by this profile.
`ip_in_prefix` requires both canonical IPv4 CIDR containment and a source-backed
publisher assertion that the prefix applies to all contained addresses. Mere
arithmetic containment cannot create an individually observed listing.

## Extraction and sanctions migrations

The eleven extraction contracts use `preserved_extraction_v1`, actual content
bytes and explicit first-complete-finding histories. Their former free-text
order strings are removed. Fixed 365/90/30/7-day periods now bind finding
availability, not refreshed artifact observation. See the field-level
[extraction profile](../fixtures/semantic-families/extraction/README.md).

The eight sanctions contracts require an explicit retrospective or historical
status inquiry and selected source/entry revisions. Actual transactions remain
discrete events; relationship paths require their own source-stated applicability.
Beneficial ownership requires the reported category and basis and does not
establish control or a percentage threshold. Corrections remain attached, and
no result supplies legal exposure, violation or liability. See the field-level
[sanctions profile](../fixtures/semantic-families/sanctions/README.md).

These migrations replace legacy feature promises, degree caps and top-path
selection with explicit supported predicates, scoped controls and bounded
query limits. `min_unique_sources` remains documentary metadata. Review dates,
lanes and SAIL assessment boundaries are preserved; portable synthetic tests
are not native or analyst acceptance.


## Explicit branch, reference and policy scope

`select_when` admits a branch only for named values of a required enum parameter.
It avoids treating missing records for an unselected inquiry as failed evidence.
A finding may declare `reference_support` separately from candidate `support`.
Both sets must qualify, but historical comparison material does not establish or
refresh the candidate's novelty. Reference witnesses remain in the output.

`time_compare_if_present` permits a wholly absent left occurrence field, with an
explicit undated limitation. A present incomplete envelope stays unresolved;
a malformed value is invalid. Otherwise it uses the ordinary bound-time
comparison. It cannot replace unknown time with processing time.

A supported `conflict_when` is independently disputed, even without an exclusion
claim. Positive `when` and `allow_when` assertions for the same policy partition
also conflict. Optional advisory policies retain candidates with visible gaps;
required eligibility policies withhold ordinary output. `partition_by` declares
one to sixteen exact operands, for example a source's class identifier. Claims
about different classes are not opposing assertions. An uncontested selected
exclusion still applies to the base subject/path across its alternate class
rows. Unknown partitions never supply suppression or clearance.

## Family profiles and migration limits

- [Package/repository](../fixtures/semantic-families/package-repository/README.md):
  reproduced version declaration plus a particular observed relationship. Stable
  source-scoped occurrences retain competing timestamps across row IDs and
  revisions; no latest-report winner or replay refresh is inferred. Availability
  cannot precede a completed observation. Equivalence is bounded to supplied
  publisher/collection/document plus declared namespace/collector/key/relation;
  cross-source equivalence and source authenticity are not inferred.
- [Certificate expansion](../fixtures/semantic-families/certificate-expansion/README.md):
  preserved finite comparison profiles, exact certificate/key witnesses, concrete
  versus wildcard CT names, presented certificates and direct/indirect C2 evidence.
- [Signing](../fixtures/semantic-families/signing/README.md): whole artifact,
  scheme content, Authenticode image and signature material remain different
  identities. Presence, reported signing and source-reported scoped verification
  are separate inquiries; no local cryptographic verifier is implied.
- [Result bindings](../fixtures/semantic-families/result-bindings/README.md):
  request-phase comparison, creative reference, direct officer expansion,
  phishkit comparison/deployment and three listing inquiries have explicit
  intermediate witnesses and emitted identities. No last-hop convention applies.

The selected repository/classification policies describe separately selected
investigation context. They do not reconstruct policy knowledge at a historical
candidate cutoff. Actual candidate/reference evidence and amendment knowledge
remain cutoff-bound where the selected inquiry requires them.
