# Result-binding family evidence profile

The seven executable contracts in this fixture family define explicit result
bindings for their supported inquiries. They use the separately versioned portable semantic
contract `1.0`; authoring schema and pattern versions are separate. These inputs
are synthetic evidence, not native adapter execution, field collection, source
authentication, independent corroboration or analyst acceptance. No generated
result has an accepted assessment status.

Run `ruby tools/test_semantic_result_bindings.rb`. The twelve JSON cases include
query, normalized evidence and actual preserved byte strings. `contract_path`
is relative to the repository root. `expected` is an independently specified
oracle. `fixture_factory.rb` creates the same source records for counterexamples;
it never calls the evaluator. `write_fixtures.rb` reproduces the base cases.
`build_contracts.rb` authors the seven JSON contracts and does not edit YAML.

Migrated YAML hop summaries are documentary inquiry projections. In particular,
`yields_evidence_for`, `subject_of_listing_assertion` and
`associated_listed_infrastructure` assert neither stored graph edges nor accepted
assessments. The digest-bound contract defines actual joins, branch alternatives,
temporal predicates and bound/constructed results.

## Shared field and time rules

Records use the semantic evidence envelope. Entity IDs are explicit joins, not
display-name equality. Assertions and occurrences require linked source IDs,
source fields, document/publisher/collection and revisions. A relation is a
source-qualified assertion, even when its endpoints are exact. Its truth is not
proved merely by the existence of a source label or by hashing a report.

Every required record's `times.collection_available` binds that record plus its
`attributes.availability_occurrence`. An explicit as-known cutoff checks those
availability times. Historical inquiry does not substitute activity for receipt
or declare what an analyst actually knew. Time envelopes bind object, occurrence,
originating field, source revision, clock, timezone and precision under
`SemanticTime`. UTC comparison preserves original representations; missing
timezone is unresolved. Missing state endpoints do not mean infinity.

`attributes.content` binds source ID, SHA-256, byte length and representation
`exact_source_bytes`; independent comparison reproduces those values from the
supplied bytes and the linked source's exact-byte hash. A locator is not an
integrity proof. Missing required bytes are unresolved; changed bytes or an
inconsistent hash/length are invalid input. This checks representation identity,
not completeness, authenticity, interpretation or source independence.

Bound results emit the particular named entity/assertion. Constructed results
record the comparison/reference/clue and supporting bindings. Multiple witnesses
for one target are retained with provenance and never imply multiple independent
origins, distinct deployments or repeated mismatches. Result identities and
occurrence identities are separate from receipt/run IDs. No grouping infers
ownership, maliciousness, control or common actors.

## Request-phase comparison

`ADTECH_PIPELINE_PHASE_MISMATCH` binds the query's `http:request` entity to an
actual `http:request_occurrence`. The occurrence supplies `occurrence_key`,
`endpoint_id`, HTTP `method`, `tenant`, `api_version` and `times.occurred`.
`adtech:request_phase.subject` is that actual occurrence, with `phase`,
`input_id`, `method` and `method_version`. Its preserved request trace must name
the same occurrence key. These fields are source claims, not a network parser.

The three explicit phase methods are `request_trace_phase_v1`,
`page_start_phase_v1` and `page_complete_phase_v1`. The latter two require an
actual `web:page_context`, a `http:request_context` association and respectively
`times.started` or `times.completed <= request.times.occurred`. The methods do
not substitute one context boundary for another or manufacture a page for an
API/server request. The one-day inclusive UTC calendar window applies to the
actual request, not comparison time or receipt.

`adtech:endpoint_role_declaration` and `adtech:endpoint_role_inference` bind the
same endpoint and exactly matching method/tenant/API-version scope. Both supply
`basis`, a nonempty finite `phases` array, boolean `exclusive`, preserved
`input_id`, and `times.applicable` containing the actual request. Inference also
requires a preserved `exchange_input_id`, matching endpoint,
`inference_method: integration_and_correlated_exchange_v1`, and revision.
The role source cannot simply reuse the phase input to manufacture independent
corroboration. Distinct inputs still do not prove independent origins.

The query selects a preserved `comparison:phase_rule` with
`profile: exclusive_phase_set_v1`, explicit revision and finite phase vocabulary.
An exclusive role outside the actual phase supports a `risk:observation` only
when no supported or uncertain contrary role remains in the fully examined
supplied scope. A nonexclusive role containing the phase supports compatible
claim context. Supported contrary roles produce contested context, with no
winner. Compatible and contested witnesses can coexist; compatible means with
that selected claim, not globally uncontested compatibility. Context results use
`evidence:phase_comparison`, never additional mismatches.

The two required endpoint controls use the extraction family's exact-subject,
pinned-revision, positively evidenced nonmembership contract. These profiles
evaluate an exact URL endpoint; a legacy host-list label cannot silently supply
that scope. Missing/conflicting control evidence withholds ordinary output and
retains the candidate in diagnostics.

## Creative reference and request

`ADTECH_CREATIVE_SCRIPT_TO_DELIVERY_ENDPOINT` starts with the exact preserved
`web:creative` capture. A script branch requires
`creative:script_correspondence` naming this creative capture, actual script
digest, source location and either preserved embedding or exact capture/resource
correspondence. A shared script does not transfer another creative's request.

Reference evidence is `analysis:creative_reference_extraction` from exact input
to retained `evidence:extracted_value`, using `preserved_extraction_v1`. It records
run/method/normalizer versions, source location and actual extraction time. Basis
is markup attribute, script operation or campaign configuration; the asserted
role must be delivery/impression/click/navigation/campaign identifier. Arbitrary
text occurrences are not automatically qualified references.

Request evidence is `http:creative_request` with the same creative capture,
actual occurrence key, typed URI, trace ID and supported stage: initiated
attempt, proxy-observed, server-received, responded or completed delivery.
`creative:request_correspondence` joins creative, input ID/digest and that request
using an explicit source method/revision. The preserved trace names the same
occurrence. An initiated request never becomes completed delivery by projection.

The URI recipe retains exact generic URI syntax. A supported URL maps to the
existing exact `inet:url` and retains the URI alongside it. DNS controls apply
only through the actual typed DNS-host component; IPv4/IPv6 URL authorities
require no manufactured DNS node. A generic URI lacking an admitted URL mapping
uses `evidence:creative_reference`. It cannot evade a failing DNS control by
being projected again as a generic reference.

Both finding kinds use the extraction family's independently qualified support
sets, explicit establishment events and preserved collection-scoped history.
The thirty-day calendar window applies to earliest equivalent establishment,
not a new run, receipt, control revision or latest component timestamp. Reference
keys bind creative capture/input digest/URI/qualified role; request keys bind
creative capture/actual request key/URI/stage. Separate capability context does
not establish advertiser control.

## Kit correspondence and deployment

`CTI_PHISHKIT_TO_HOSTING_CLUSTER` starts with a `phish:kit`. Two
`kit:representation` assertions bind seed and candidate to exact representations
under `preserved_archive` or `declared_file_set` scope. Exact archive comparison
checks actual bytes. File-set comparison uses the separately specified
`everypivot.file_set_manifest` and `everypivot.file_set_coverage` version `1.0`
representations documented in `tools/semantic_result_primitives.rb`. It checks
declared scope, exact POSIX member paths, complete stated inventory, actual
member bytes, source revisions and finite budgets. Repacking may change archive
identity while preserving file-set identity. Changed configuration bytes defeat
file-set equality. Hosting qualification requires the verified manifest's
`scope.kind: collected_file_set`; a `declared_subset` comparison emits only
`evidence:kit_comparison_clue`, retaining actual comparator scope and both
manifest identities. This is checked against parsed preserved bytes, not an
unverified attribute. Collected-set completeness is not deployment completeness.

`kit:shared_path_interpretation` binds exact left/right manifests and a nonempty
list of selected literal `paths`. The evaluator independently verifies those
paths occur in both complete declared input scopes, without requiring equal
contents. Its `profile: literal_shared_paths_v1`, `interpretation_basis`,
`ordinary_explanations` and `scope` are explicit source-qualified context.
`qualification: supported_specific_shared_feature` permits a candidate branch;
`only_generic_default_paths` yields `evidence:kit_comparison_clue` instead.
This does not compute rarity, entropy or application incongruity. A separate
`kit:component` relation with explicit `component_scope` and exact retained bytes
also returns only a component clue. Neither clue manufactures deployment or
whole-kit equality; neither defeats an independent exact branch.

A qualifying hosting witness requires `kit:deployment.subject` equal to the
same candidate. It records a stable source-scoped `occurrence_key`, actual linked
`origin_source_id`, `source_scope`, `collection_id`, `resource_scope`,
`location_id`, `stage: served|installed_serving_context`, and any evidenced
`times.occurred`. No installation-start date is invented. The source scope and
origin are not a new ingestion ID; copied records preserve them.

`kit:deployment_correspondence` joins that candidate/deployment and explicitly
names the matched representation, resource scope, location and preserved
`evidence:deployment_record`. The latter names the same occurrence key. It also
requires `correspondence_basis`, method/version, `reliability_basis`,
`collection_scope`, and `known_gaps`. The admitted evidence kinds are preserved
historical report, content-bearing PCAP, server resource log and client network
capture. These are source-qualified correspondence recipes, not native PCAP/log
parsers. A source report remains a report; hashes alone do not establish its
reliability. Client evidence additionally requires source-evidenced
`delivery_provenance: actual_network_response` and a served stage. Cache,
service-worker or local-override records do not establish fresh serving. An
archive download, bare request/status code or connection cannot supply this
correspondence.

`kit:delivery_identity` binds the particular deployment to its result entity,
same location and occurrence key, with explicit correspondence basis and
vantage. An application-domain result requires the typed URI's actual DNS host
to equal the typed `inet:fqdn`. An IPv4 result independently requires a typed
matching address and resource-delivery basis, with role delivery endpoint or
installed serving endpoint. `origin_role` may remain unknown. Bare peer/DNS
associations do not establish either role. Public-kit, shared-hosting and CDN
context remain optional `kit:deployment_context` explanations, not exclusions.

The required controlled-purpose policy uses `kit:occurrence_purpose` for the
exact candidate/resource/location/occurrence. `controlled` plus an evidenced
research/training/test/sinkhole purpose suppresses default discovery; positive
`not_controlled` is needed for ordinary output. Both require reason and explicit
rule revision. Unknown or contested support is retained in diagnostics, without
clearance. A later sinkhole record cannot cover a different historical occurrence.
The explicit query boolean `include_controlled` is normally false; true includes
the factual evidence with purpose context and makes no maliciousness claim.

`reference_deployments` is an explicit record-ID array; empty supplies no
baseline. Matching candidate, source-linked origin, source scope, collection,
occurrence key, resource and location classify the selected occurrence as
`evidence:deployment_reference`. Copies of that occurrence do not become new
discoveries merely through record IDs. Different occurrences remain separately
eligible. Cross-origin/source-alias equivalence needs an explicit mapping proof;
this profile does not infer it from similar dates or locators. When selected
baseline IDs are nonempty and exact identity does not prove a reference, ordinary
discovery additionally requires preserved `kit:baseline_comparison` evidence.
It binds the current candidate and exact occurrence/source/collection/resource/
location tuple, covers every requested ID in `compared_baseline_ids`, and records
`profile: source_qualified_occurrence_comparison_v1`, method/version, basis and
`disposition: distinct_occurrences`. Different labels leave the candidate
unresolved. Same-occurrence or contested comparison evidence cannot clear this
gate; cross-origin reference projection remains outside the exact-key recipe.
No comparison is invented for an empty baseline array.

The initial 180-day calendar interval is search priority only. A supported
`evidence:kit_receipt` binds collection, candidate, original evidence identity,
collector and `times.received`. The priority does not claim first-ever receipt.
No receipt leaves a useful candidate unranked and eligible. Actual old or
undated serving stays old or undated, even after recent receipt.

Unranked base-evidence branches remain independently eligible even when arrival
records exist. This prevents a later receipt from excluding an already supported
historical witness at an earlier as-known cutoff. Ranked and unranked paths may
coexist; their shared occurrence identity does not become two deployments.
Provided activity/receipt times must not follow their own recorded availability.
Only a wholly absent optional time field permits an undated result without an
order claim; an incomplete supplied envelope remains unresolved.

An `analysis:kit_context_derivation` priority additionally requires preserved
analysis input and prior/new output records, actual run/time/method revisions,
`profile: source_reported_changed_correspondence_v1`, contribution explanation
and equivalence limit. Candidate/resource/deployment roles require an actual
changed candidate ID, representation ID or location ID respectively, plus
changed output bytes. The new output joins this candidate, matched representation,
location/resource scope, input digest and actual deployment-correspondence record.
It is labelled source-reported substantive derivation: these bounded source
claims do not prove global novelty or worldwide first availability. Mere changed
bytes or tool labels fail. Actual input/prior-output availability must precede
the run, which must precede new-output and run-record availability. The original
unranked witness may coexist with a
derivation witness; both retain the same deployment occurrence identity.

## Direct officer appointments

`FIN_ORG_OFFICER_SHARE_CLUSTER` binds `person → org:appointment → org:org`.
Appointment role is officer/director, with explicit appointment key and exact
person/organization identity scopes. Another appointee at Company A does not
lead automatically to that person's Company C. Service is either an evidenced
`org:service_interval.times.held` overlapping the selected period or a
`org:dated_active_status` with `active_at_evidenced_time` inside the period and no
later than that status record's collection availability.
Missing ends do not imply current service. Different nonconcurrent appointments
can independently qualify. Capacity/professional/nominee context attaches to the
particular appointment and does not exclude the whole person.

Query `scope` explicitly selects the default 3650-day calendar service interval
or a required case/analyst `period`. An as-known cutoff is separate. Returned
organization witnesses retain each appointment/service source, without shell,
ownership, control or concurrency inference.

## Three listing inquiries

Legacy `CTI_SBL_HOSTING_RISK` has no executable alias. Its successors ask distinct
questions; native consumers must select deliberately:

| Pattern | Exact question and result |
| --- | --- |
| `CTI_IP_TO_LISTING_ASSERTIONS` | IP-address entry or publisher-supported covering-prefix claim; returns the actual `reputation:assertion` |
| `CTI_ASN_TO_EXPLICIT_LISTING_ASSERTIONS` | Publisher assertion explicitly about this ASN; returns the actual `reputation:assertion` |
| `CTI_ASN_TO_LISTED_INFRASTRUCTURE` | Listed IPv4/prefix independently associated with the ASN during the claim; returns that infrastructure |

Queries require explicit `period`, `period_origin: analyst|case`, claim kind and
reference source IDs. There is no automatic 1095-day history, one-ASN winner or
receipt-date fallback. `reputation:assertion` binds subject and exact
`reputation:entry`, subject kind, claim kind, statement, source scope, assertion
namespace and matching entry revision. Entry fields identify collection, entry
and revision. Actual `times.applies` is explicitly an event or established state;
events must fall in the period and states must overlap it.

An IP covering-prefix claim additionally requires an exact `inet:net4` subject
and `network:prefix_scope` linked to that claim and the same prefix value. The
primitive verifies canonical IPv4 CIDR arithmetic plus source-backed publisher
applicability to all addresses in that prefix. A list of individual addresses
cannot be expanded to every neighbor by arithmetic. IPv6 prefix recipes are
not part of this IPv4 capability.

An ASN-associated result has an independent `network:asn_association` with exact
infrastructure and ASN IDs, role BGP origin/allocation/operator/customer
assignment, vantage and entire-subject-scope coverage. Its established interval
must contain the claim event or share a real intersection with the claim state
and selected period. A later assignment does not establish the earlier join.
An associated member is not an ASN-wide publisher assertion, and a prefix result
does not manufacture individual address observations.

All supplied source amendments are retained through `retain_reports`, including
withdrawals, corrections, reinstatements and disputes. Results explicitly say
historical source assertion / reported in supplied scope. History beyond the
supplied revisions remains unknown; this is neither current status nor a
certified unwithdrawn claim. Complete correction-history lookup is not an
admitted capability. No listing match establishes legal exposure or liability.

## Explicit investigation controls and limits

Officer and listing queries can enable selected investigation rule IDs. Their
source assertions bind the exact appointment or claim and actual applicability
period, with disposition, reason and rule revision. Positive retain evaluations
must explicitly cover every selected rule ID. Labels such as nominee, shared
hosting or hyperscaler alone never exclude. Unknown/conflicting required
evaluations withhold ordinary output and retain evidence in diagnostics.

For interval results this bounded profile requires a selected exclusion or
positive retain evaluation to cover the entire query period. A partial-period
rule cannot suppress the entire broader result; it remains unresolved rather
than silently clipping intervals or manufacturing an unexcluded remainder.
Event/status rules bind the actual event point. Automatic interval subtraction
requires a separately versioned capability. Disabled optional investigation
controls make no evaluation or clearance claim.

Budgets are explicit query inputs. Partial supplied-input search is not proof
of absence or nonmembership; priority preparation consumes work as well.
Missing required support, known nonmatch, explicit suppression, invalid input
and unsupported recipes remain distinct. No native runtime or external feed is
queried by these contracts or fixtures.
