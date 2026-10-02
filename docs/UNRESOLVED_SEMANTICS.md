# Semantic bindings and consumer limits

This document explains the temporal, identity and result meanings of the focused
semantic contracts. The [execution contract](SEMANTIC_EXECUTION_CONTRACT.md)
defines the finite executable vocabulary; each pattern's digest-bound definition
under `contracts/semantics/` supplies its exact parameters, joins and results.
There are 45 executable definitions, one deprecated non-executable SBL definition,
and 134 other original patterns outside this migration. Free-text temporal
expressions in those other patterns do not acquire executable meaning by analogy.

The independently versioned semantic contracts are drafts at version 1.0;
authoring capability 1.6, individual pattern versions, adapter versions, the
registry release and SAIL v0.4 DRAFT are separate. Synthetic verification does not
establish source authenticity, independent corroboration, native interoperability,
analyst acceptance or an accepted assessment. Lifecycle lanes and review dates
retain their own evidence requirements.

## Shared evidence and evaluation rules

Every consumed time binds an object and occurrence, originating source field and
revision, clock, timezone, precision and uncertainty. UTC is the comparison
calendar; preserve source offsets and precision. Missing timezone is unresolved,
not assumed UTC. Date-only or uncertain values retain their supported possible
intervals. A boundary-crossing interval is unresolved; an invalid date is invalid
input. Inclusive calendar ranges include both dates and do not imply an exact
query instant or synchronized source clocks.

Actual activity, contextual observation, extraction, publication, collection
receipt and analyst awareness are different events. A collection-availability
claim needs its actual source-backed availability occurrence in that collection.
A later receipt cannot establish earlier knowledge. Historical knowledge cutoffs
are explicit and do not establish what a particular analyst knew.

A recent-finding window uses a source-backed complete establishment event and
preserved collection history, with the earliest equivalent finding in the declared
scope. Taking the maximum of component dates does not establish a finding.
Equivalent extraction, copying, syndication, replay, changed tool labels and new
record IDs do not refresh it. Unknown earlier history remains unknown. Later
support and amendments remain attached without manufacturing novelty.

Hashes identify an exact representation and check integrity when the bytes are
available. They do not authenticate a publisher, date an occurrence, prove a
source assertion or establish independent origins. Preserve conflicting claims
and source-qualified amendments; a later receipt or revision does not
mechanically win. Missing evidence, malformed input, unsupported capability,
known nonmatch, outside-period evidence, explicit suppression and partial search
are different outcomes. Resource limits do not convert incomplete search into
proof of absence or nonmembership.

## Temporal bindings

### Package/repository relationships

`SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA` and
`CROSS_PACKAGE_REPO_TO_DOMAIN_INFRA` discover a version-specific registry
`declares_source_repository` association. The stored declaration is from the
package version to the named repository. SUPPLY then follows that repository's
infrastructure observation; CROSS follows the exact package version's
infrastructure observation. They are not inverse chronological claims.

Original repository creation, mirror/import creation, package identity creation,
version publication and infrastructure observation are distinct occurrences.
An established 2019 repository can publish a 2026 package version; a metadata
revision can instead declare a mirror created after publication. Preserve each
declaration and its revision without inferring build origin, historical knowledge
or equivalence of the repository identities. Missing or conflicting creation
timestamps do not impose an entity-birth ordering gate.

The 3,650-day window selects the actual infrastructure-relationship observation.
For query date `2026-09-14`, it includes `2016-09-16` through `2026-09-14`:
3,651 calendar dates. Publication dates are context. Late-acquired evidence can
support retrospective discovery; a separately selected knowledge cutoff requires
availability evidence for every required record. Distinct observations retain
source-scoped occurrence identities; replay cannot refresh them.

A repository commit ID or reproducible snapshot digest identifies the exact
linked source snapshot, with evidence binding it to the package version. An
unknown revision remains unresolved. Neither identifier proves a build from
those bytes. See [package provenance](PACKAGE_REPOSITORY_PROVENANCE.md) and the
[portable traversal profile](../fixtures/semantic-families/package-repository/README.md)
for the independent sidecar and execution capabilities.

### Extraction and other temporal operands

The eleven extraction contracts bind derivation from the particular returned
artifact or capture, rather than the first discovery of a selector elsewhere.
Their [evidence profile](../fixtures/semantic-families/extraction/README.md)
defines exact preserved bytes, selector representations, run provenance,
collection history, controls and branch-specific results. It executes no OCR,
decryption, browser, DNS lookup or native extraction operation.

A sample observed in December 2024 may yield a newly established finding in
September 2026. A selector discovered elsewhere before the sample is a different
occurrence. Re-extracting the same finding preserves processing evidence without
creating another contextual sighting or new finding date. No global inequality
between generic `.observed` and `.extracted` names replaces these bindings.

#### Accepted source-path extraction binding

For `CTI_FILE_SOURCE_PATH_CLUSTER`, the extraction occurrence names the exact
file bytes, path output, run, extractor and normalization revisions. Laboratory
inspection does not refresh a contextual file sighting. A mutable filesystem or
embedded creation timestamp does not independently prove the file's production
history, and a recorded sighting is not necessarily its earliest sighting anywhere.

A path extracted on `2026-09-10` from bytes sighted in December 2024 may establish
a new path-to-file finding available to collection C on `2026-09-11`. The 365-day
finding window can select that evidence without a later file sighting; it cannot
backdate derivation or analyst awareness to 2024. Preserve methods and necessary
external inputs, such as decryption material, without implying the earlier
analysis should already have recovered the path.

#### Accepted sample-selector temporal model

The same per-file and 365-day finding-availability rules apply to
`CTI_SAMPLE_UNIQUE_STRING_CLUSTER`, `CTI_SAMPLE_FUNCTION_NAME_CLUSTER` and
`CTI_SAMPLE_RESOURCE_SECTION_HASH_CLUSTER`. String representations retain their
encoding and derivation; function-name evidence distinguishes actual recovered
symbols and supporting debug material from guessed names; resource hashes bind
the selected section bytes and exact hash recipe. Equality across different
representations or normalization revisions is not inferred.

#### Accepted email-cluster temporal model

`CTI_EMAIL_HEADER_VALUE_CLUSTER` and `CTI_EMAIL_MESSAGE_ID_HOST_CLUSTER` bind the
actual field occurrence in an exact preserved message capture and its original,
gateway or export role. Their 30-day windows select complete findings available
in the named collection. Recipient receipt, capture and extraction are separate.
A Message-ID host does not identify the sender, receiving server or domain owner.
Equivalent later processing does not refresh the finding.

#### Accepted web-content and image capture identity

`CTI_WEB_CONTENT_EMBEDDED_CONFIG_STRING_CLUSTER` and
`CTI_IMAGE_TEXT_REUSE_CLUSTER` require the exact retained extraction input and
output bytes, reproducible SHA-256, byte length and representation. A locator,
ETag or supplied digest does not substitute for preserved bytes. A URL identifies
a resource reference, not an immutable content revision.

Crops, renders, decoded content and normalized outputs are separate artifacts
with their own hashes and evidenced lineage. Do not invent an unretained parent.
Shared OCR text does not establish identical images; an image digest does not
establish placement on a page. The admitted byte comparison checks integrity,
not OCR correctness, complete page capture or reproducibility of the original
rendering operation. Multi-file coverage needs an explicit manifest recipe.

#### Accepted independently supported OCR image results

An independently supported OCR finding can return the actual `file:image` used
as input without a page result. A crop or render is not replaced by its parent.
Returning `inet:url` additionally requires the exact page capture, image
association and URL identifier. Missing page evidence does not invalidate the
independent image finding; it withholds the page claim. Controls apply to the
particular result and required supporting path.

#### Accepted OCR finding-availability window

The 365-day window applies independently to complete image and page findings.
An image finding established on `2026-09-06` cannot lend that date to a page
finding whose association evidence becomes available only on `2026-09-10`.
September 10 is itself only a lower bound until the page finding is established.
An older image can support a new page finding without refreshing either capture.

#### Accepted general URI scope for resource findings

Resource identifiers support a scheme and path, with optional authority, query
and fragment. A URI need not have a domain, IP address or network location.
The exact supported generic URI recipe preserves empty versus absent components
and does not invent scheme-specific equivalence. The result concerns the resource
whose preserved content contains the token; a URI mentioned inside that content
is a separate reference, not evidence that the named resource contains it.

#### Accepted URL mapping preservation and URI coexistence

A supported URL preserves the existing `inet:url` mapping and retains the URI
reference alongside it in one resource finding. This does not require duplicate
storage or a fabricated traversal edge. The hierarchy of generic URI identity
and the more specific URL view does not license a corpus-wide form replacement,
implicit identifier equivalence or an invented DNS host.

#### Accepted fallback for an unmapped non-URL URI

Without a suitable URL mapping, retain the qualified containing-resource finding
as `evidence:resource_content`, with its URI, exact content and evidence. An
unsupported native form is distinct from an invalid URI, unknown content,
nonmatch or explicit suppression. Later adding a mapping changes representation;
it does not establish another capture or refresh the original finding.

#### Accepted resource-content finding window

The web-content pattern's 90-day window selects complete containing-resource
findings newly established in the named collection. Capture time and extraction
time alone do not establish that date. Old captures can supply new findings,
but equivalent extraction, replay or a changed URI mapping cannot reset prior
establishment. Preserve capture, derivation and availability separately.

#### Accepted optional FQDN identifier binding

An optional FQDN result is supported by the actual DNS-host component of the
bound containing-resource URI under the admitted recipe. It is not a domain
found elsewhere in text, reverse-DNS inference, redirect target or ownership
claim. IP literals and non-network URI forms require no fabricated FQDN. The
resource finding can remain independently supported without a domain result.

#### Accepted common-hosting/CDN exclusion scope

A confirmed domain-scoped hosting/CDN exclusion applies to the FQDN projection,
not automatically to the exact containing-resource result. A legitimate domain
can host a compromised path, so domain context does not determine the content
claim. Independent content controls still apply. Missing or conflicting required
control evidence is unresolved; absence of a list entry is not clearance.

#### Accepted common-token exclusion gate

An evidenced common-token exclusion applies to findings that depend on that
selector under the declared representation and normalization profile. It is not
an implicit text-substring test. Unknown membership, scope or equivalence remains
unresolved. Retained excluded evidence can support explicitly scoped later
analysis without being presented as an ordinary qualifying result.

#### Accepted exclusion-list revisions and reproduction

A new evaluation selects identifiable policy/list revisions. Reproduction of an
earlier evaluation uses its original revisions and other inputs. Preserve both
outcomes; a mutable `latest` label must resolve to an exact revision. A policy
change can change qualification without creating a capture, extraction, new
finding or independent source. Required positive nonmembership must have explicit
coverage for the evaluated subject.

#### Accepted optional FQDN finding window and historical context

The optional hostname finding has its own complete claim and establishment date,
with the 90-day purpose. It cannot inherit a resource date before its own required
identifier evidence was available. Reinvestigating an earlier period preserves
actual historical captures; a later capture at the same URL does not prove the
content or domain relationship throughout the intervening period.

#### Accepted explicit historical expansion

An analyst or case may explicitly widen historical inquiry beyond the recent
finding window, recording the selected period, purpose, evidence coverage and
resource limits. This does not modify the original query or initiate unlimited
backfill. Older findings stay historical; newly established findings about older
material retain their actual establishment dates.

#### Accepted email URL extraction evidence binding

`CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS` binds an exact preserved message capture and
the actual body, header, attachment or declared render used for extraction.
Preserve the representation, parser/normalizer revisions, run and lineage. The
message's receipt is a separate event; no universal recipient-receipt-before-
extraction rule follows when evidence comes from a sender copy or another source.

#### Accepted email URL ordinary-output boundary

Ordinary output is the URL actually present in the supplied representation with
its evidence role. A network-fetched redirect, externally loaded page or guessed
absolute URL is not automatically embedded in the message. Relative references
need the appropriate supported base evidence; grouping does not collapse all
roles into one `contains_url` claim or erase distinct occurrences.

#### Accepted email URL finding window and historical expansion

The seven-day window selects complete message-to-URL findings newly established
in the collection. It does not reset message receipt or treat same-result
extraction as novelty. A subsequent explicit historical query can investigate
older findings without relabelling them as recent or retroactively changing what
was available to the earlier query.

#### Accepted bundle/map revision correspondence and content identity

`ADTECH_WEBAPP_SOURCEMAP_TO_ADMIN_SURFACE` requires the exact preserved bundle or
map and supported correspondence between revisions when the branch uses both.
Hash the actual input and retained output representations. A familiar filename,
URL or current fetch does not bind a historical map to a bundle. Missing or
conflicting correspondence withholds that relationship, not a separately
supported direct-map extraction.

#### Accepted direct and referenced-asset extraction paths

A directly supplied map can independently support extraction. A path through a
bundle's map reference requires its additional exact correspondence evidence;
no self-reference or placeholder node supplies the missing hop. The branches
retain their input identities and source fields rather than treating direct and
referenced inputs as identical traversal paths.

#### Accepted recovered-route results and separate surface evidence

A supported recovered route is a clue from the exact artifact. It can be a
future pivot or dead end without proving a deployed administration surface.
A separate surface finding requires actual surface evidence and the necessary
joins. Templates and historical captures do not manufacture current deployment,
absolute URLs or control of the application.

#### Accepted source-map family finding windows

The 30-day window applies independently to complete recovered-route and surface
findings. A February artifact can support a September route finding; the surface
finding may be established later. Neither refreshes the artifact's observation.
An explicit historical query may retain older clues, without inferring current
availability or filling missing establishment history.

#### Accepted response-occurrence extraction and probe correlation

`CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_PAYLOADS` binds the exact response occurrence,
retained bytes and extracted payload/configuration. When probe correlation is
required, it must identify the actual request/response exchange, endpoint and
source evidence. A shared address, similar timestamp or replayed response does
not prove correlation. Derived representations retain their input lineage.

#### Accepted independently supported response-derived outputs

A payload, direct configuration and payload-derived configuration are distinct
supported paths. A hash is a view of the particular payload claim, not an extra
independent occurrence. Missing optional probe context does not erase an
independently supported response extraction, and a configuration-only result
does not manufacture payload bytes or another output node.

#### Accepted response-derived finding windows

The 30-day interval selects complete response-derived findings newly established
in the named collection. Actual probe, response, extraction and receipt times
remain separate. Equivalent processing and duplicate ingestion do not refresh
finding history. Decoy, replay, research and other source context must retain
its actual scope rather than imply attacker control.

## Result bindings

The [result-binding profile](../fixtures/semantic-families/result-bindings/README.md)
specifies required fields and branch coverage. A declared target can be a named
bound node or a constructed evidence record; the final hop is not an implicit
return convention. Construction records the supported comparison, reference or
clue and its provenance. It does not create an accepted assessment.

### Accepted request-specific phase comparison finding

`ADTECH_PIPELINE_PHASE_MISMATCH` compares evidence about the same actual request,
endpoint and method/tenant/API-version scope. A supported mismatch emits
`risk:observation` under the explicit comparison rule. The terminal endpoint-role
node is support, not the required returned identity. Duplicate witnesses do not
create additional request occurrences or independent mismatches.

### Accepted declared and inferred endpoint-role evidence

Endpoint roles can come from preserved declarations or independently supported
integration/exchange inference. Each has its own method, source and applicability.
An inferred role does not become an operator declaration. A phase trace cannot
be reused as its own independent corroboration; different input documents still
do not prove independent origins.

### Accepted coexistence and unresolved disagreement without a forced winner

Compatible roles, conflicting claims and dual-purpose behavior can coexist.
A supported or unresolved contrary role prevents a forced exclusive mismatch in
the fully examined scope. Compatible and contested context use
`evidence:phase_comparison`. Preserve source-qualified disagreement instead of
choosing by recency, repetition or a requirement that every case have a winner.

### Accepted request-occurrence window for phase comparisons

The one-day inclusive UTC calendar window selects the actual request occurrence,
not receipt, comparison time or the document's publication. Keep endpoint-role
applicability and phase evidence bound to that request. The interval covers both
boundary dates; it is not an exact 24-hour query-instant window.

### Accepted method-dependent phase context requirements

`request_trace_phase_v1` uses the request trace; `page_start_phase_v1` and
`page_complete_phase_v1` additionally require the actual associated page context
and the respective event. For page start `12:00:00Z`, request `12:00:01Z` and
completion `12:00:03Z`, start and completion predicates differ. Missing required
context stays unresolved; do not invent a page or timing offset. A shared URL
alone does not prove the association.

### Accepted creative URL result selection

`ADTECH_CREATIVE_SCRIPT_TO_DELIVERY_ENDPOINT` returns the actual qualified URL
associated with the exact creative capture and evidence kind. A script is support
when that branch requires it. Its presence alone does not prove a request,
completed delivery, advertiser control or maliciousness.

### Accepted creative reference and request evidence kinds

A preserved extraction supports a reference with its actual delivery, impression,
click, navigation or campaign-identifier role. Correlated request evidence is
separate and retains its stage: initiated attempt, proxy-observed,
server-received, responded or completed delivery. Arbitrary text is not a
qualified role, and an initiated request is not completed delivery.

### Accepted optional advertiser-control context

Advertiser-control evidence is optional context with its own supported identity,
relationship and scope. A shared script, campaign identifier or endpoint does not
establish that control. Missing optional context does not discard an independently
supported reference or request finding.

### Accepted direct creative-markup paths

The exact preserved creative markup can directly support a qualified extraction.
A script-based branch additionally binds the actual script bytes and their
correspondence to that creative capture. A shared library cannot transfer another
creative's request or endpoint association into this result.

### Accepted creative URL hostname binding

A hostname is the actual DNS-host component of the bound URL under the supported
URI recipe. Preserve the complete URL and URI reference, including relevant
path, query and fragment. A domain appearing elsewhere in markup, a redirect or
reverse DNS does not replace this binding.

### Accepted creative IP-URL eligibility and conditional DNS controls

IPv4/IPv6 URL authorities can qualify without a manufactured DNS node. DNS
controls apply only to an actually supported DNS-host component. Absence of a
DNS host is not evidence of failed DNS membership, and all other applicable
creative/request controls still apply.

### Accepted distinct creative URI-reference findings

A generic URI without an admitted URL mapping can yield
`evidence:creative_reference`, preserving the actual evidence and role. It is
not automatically a retrievable endpoint or completed request. Projection as a
generic reference cannot evade a failing DNS control on the same supported URL.

### Accepted creative finding-availability window

The 30-day window applies to earliest complete establishment of each reference
or request finding in the named collection. Reference identity includes creative
capture, exact input, URI and role; request identity additionally preserves the
actual request occurrence and stage. A policy revision, latest receipt or changed
parser run does not refresh either finding.

### Accepted phish-kit matching-candidate deployment binding

`CTI_PHISHKIT_TO_HOSTING_CLUSTER` joins independently supported kit comparison to
deployment of the same candidate representation at the same resource/location
scope. A kit match alone is not hosting. The result retains the comparison,
deployment correspondence and actual delivery identity; it does not imply
common ownership, actor identity or a malicious deployment.

### Accepted phish-kit archive, file-set and component match scopes

Exact archives compare retained bytes. File-set comparisons use preserved,
versioned manifests with declared inventory, literal member paths and actual
member bytes. Repacking can change archive identity while preserving a file set;
changed member content defeats exact set equality. Only a verified
`collected_file_set` scope can support the whole-set hosting branch. A
`declared_subset` or component match yields a labelled comparison clue, not
whole-kit equality or deployment completeness.

### Accepted phish-kit path-similar candidates and contextual interpretation

Shared-path candidates need explicit source-qualified interpretation and an
independently checked overlap in the declared manifests. Record ordinary
explanations and comparison scope. This branch is weaker than exact archive or
file-set equality and must not silently inherit either identity claim.

### Accepted shared-path distinctiveness and separate application fit

Distinctive shared paths and incongruity with the hosted application are separate
analytical considerations. Generic/default paths alone are clues. The bounded
profile checks literal overlap and the supplied interpretation; it computes no
entropy, global rarity or numerical application-fit score. Common naming,
frameworks, templates and independently reused components remain alternative
explanations.

### Accepted phish-kit deployment boundary and evidence sources

Deployment means evidenced serving or installation in a serving context for the
matched candidate/resource scope. Supported historical reports, content-bearing
PCAP, server resource logs and client network captures can provide correspondence.
A download of the archive, connection, bare request or status code alone is
insufficient. Preserve exact content, source revisions, occurrence, vantage,
collection scope, reliability basis and known gaps; hashes do not supply missing
reliability or prove installation time.

### Accepted client-side deployment evidence with sourced reliability

Reliable source-qualified client evidence can support serving without mandatory
server logs. It must establish an actual network response for the matched
resources. Local overrides, service-worker or cache records do not establish
fresh network serving. The profile consumes normalized source evidence; it does
not parse PCAP or authenticate a log producer.

### Accepted supplied-deployment reference and distinct occurrence handling

Explicitly selected baseline deployments remain references. Matching stable
source-qualified occurrence, candidate, resource and location identifies a
reference even after copying. A candidate outside exact baseline identity needs
supported comparison against every selected baseline before claiming a distinct
occurrence. New row IDs or similar dates cannot settle that distinction. An
empty baseline set supplies no implicit reference.

### Accepted phish-kit initial search focus and incomplete deployment history

The initial 180-day calendar interval prioritizes recent evidence receipt or
supported substantive derivation. It is not an activity cutoff or a claim about
first deployment. Unknown installation date does not reject an otherwise
supported deployment; historical and undated candidates remain eligible and
explicitly dated or undated. Bounded search may stop before the full history is
examined.

### Accepted phish-kit receipt and substantive derivation dates for the first pass

Receipt priority binds the actual collection receipt and original evidence
identity. Derivation priority needs preserved prior/new outputs, exact input,
actual run and revisions, changed correspondence and a stated contribution and
equivalence limit. A changed tool label or arbitrary output bytes is not enough.
Priority is source-reported and does not establish global novelty or refresh
the deployment occurrence.

### Accepted phish-kit qualification independent of discovery order

Search/display order does not determine eligibility. Unranked base-evidence
branches remain available even when arrival records exist, including for an
earlier historical knowledge cutoff. Multiple ranked and unranked witnesses
retain one actual deployment identity. Absent optional time can remain undated;
a malformed or incomplete supplied envelope cannot be treated as absent.

### Accepted phish-kit delivery-IP result with origin unknown

An IP can be returned when the source actually binds it to delivery of the
matched resources or installation in the serving context. Its origin-server
role can remain unknown. A network peer, later DNS lookup or infrastructure
co-occurrence alone does not establish resource delivery, hosting ownership or
origin infrastructure.

### Accepted phish-kit shared-hosting context and scoped exclusion policy

Shared hosting and CDN use are context for the particular deployment, not
automatic exclusions or common-control evidence. Preserve the source-qualified
explanation and any separately selected investigation policy. A shared delivery
provider does not merge tenant deployments or transfer one resource's context
to every hosted URL.

### Accepted phish-kit controlled-occurrence default exclusion

Normal discovery excludes an evidenced controlled research, training, test or
sinkhole occurrence. The control binds the exact candidate, resource, location
and occurrence with rule revision and reason. Positive non-controlled evidence
is required for ordinary output; unknown or contested support stays unresolved.
Explicit `include_controlled` can retain the factual evidence with context. A
later sinkhole cannot classify a different historical deployment.

### Accepted phish-kit generic/default-path overlap as clues only

Overlap supported only by generic or default paths yields
`evidence:kit_comparison_clue`. It does not establish whole-kit identity or an
ordinary hosting result. Retain exact comparator scope, both manifests and the
interpretation; this weak branch does not defeat an independently qualified
exact-match branch.

### Accepted phish-kit public availability as context

Public availability of a kit is an alternative explanation for reuse. It is
not a universal exclusion or proof that a particular deployment is benign,
malicious or controlled by the kit author. Preserve the public-source evidence
without implying exclusivity or transferring identity between deployments.

### Accepted officer/director direct-appointment organisation results

`FIN_ORG_OFFICER_SHARE_CLUSTER` binds the selected person, an actual
`org:appointment`, and the appointed organization with exact identity scopes.
Another appointee at Company A does not automatically lead to that person's
Company C; that is a separately requested expansion. Return organizations with
each appointment's provenance, not an inferred officer group or control claim.

### Accepted officer/director historical appointments without concurrency gate

Historical direct officer/director appointments can qualify independently; two
appointments need not overlap. Each needs an evidenced service interval or
source-qualified active-at-time status. Missing end dates do not establish
current service. Co-appointment, nominee status and title alone do not prove
ownership, shell status or common control.

### Accepted officer/director window over evidenced service

The default 3,650-day calendar scope or explicit analyst/case period selects
evidenced service, not record ingestion or initial appointment discovery.
Intervals must overlap; a dated active status must fall in the period. Historical
knowledge cutoff, evidence coverage and execution budgets remain separate.

### Accepted officer/director professional-capacity context and scoped exclusions

Professional-director, nominee and formation-agent context attaches to the
particular appointment. It does not exclude the whole person or every associated
organization. Selected investigation rules require source-qualified applicability,
reason and revision; missing or conflicting required evaluations stay unresolved.
Disabled optional filters do not claim clearance.

### Accepted SBL replacement family as three distinct questions

`CTI_SBL_HOSTING_RISK` is deprecated and has no executable alias. Consumers select
one of three questions explicitly:

| Pattern | Result meaning |
| --- | --- |
| `CTI_IP_TO_LISTING_ASSERTIONS` | Actual publisher assertion about an IP or an explicitly supported covering prefix. |
| `CTI_ASN_TO_EXPLICIT_LISTING_ASSERTIONS` | Actual publisher assertion explicitly about the ASN. |
| `CTI_ASN_TO_LISTED_INFRASTRUCTURE` | Listed infrastructure independently associated with that ASN during the claim. |

A member's listing is not an ASN-wide assertion or a risk score. Prefix expansion
requires source-backed applicability to the entire declared prefix; IPv4
arithmetic alone does not extend an individual-address claim to its neighbors.

### Accepted SBL family historical discovery with later status attached

Historical source assertions remain inspectable with exact entry revisions and
withdrawals, corrections, reinstatements or disputes attached. An expired entry,
withdrawn allegation, reported remediation and absence from one response have
different meanings. Retention does not certify the original claim or establish
current listing status; history outside supplied revisions remains unknown.

### Accepted SBL claim-specific network association periods

An infrastructure-to-ASN join needs its own supported association, role, vantage
and entire-subject coverage. Its interval must contain the claim event or share
an actual intersection with the claim state and selected period. A later
assignment cannot date an earlier join, and BGP origin, allocation, operator and
customer assignment are distinct roles.

### Accepted SBL historical window over source-claim applicability

The query period selects the publisher claim's actual event or established
applicability state. Receipt, publication and first discovery are separate.
Missing endpoints do not create an open-ended state, and separate overlapping
intervals must share the required actual intersection rather than be combined
across incompatible times.

### Accepted SBL analyst-controlled investigation periods

Require an explicit period, analyst/case origin, claim kind and reference source
IDs. Do not silently inherit the former 1,095-day duration or impose a
receipt-date fallback. Reusable case selections may supply recorded dates;
source coverage, historical knowledge and execution limits remain explicit.

### Accepted SBL partial results at an agreed resource limit

Return supported partial results when the explicit work budget ends, with
completion status and coverage limits. Incomplete traversal cannot establish no
listing, no association or nonmembership. A later run may repeat work; the
contract does not promise a resumable cursor or unlimited history retrieval.

### Accepted SBL shared-hosting context and explicit investigation exclusions

Shared-hosting or hyperscaler labels are contextual. A selected exclusion needs
an actual scoped rule evaluation, revision, reason and applicability. For interval
results the bounded rule must cover the whole selected period; partial coverage
stays unresolved rather than silently subtracting intervals. Disabling an
optional rule makes no evaluation or clearance claim.

### Accepted full-certificate identity and separate SPKI reuse

A whole-certificate SHA-256 identifies exact certificate DER; an SPKI SHA-256
identifies the exact encoded public-key information including algorithm
parameters. Renewed certificates can share an SPKI while having different
certificate identities. `OSINT_CERT_SHA_TO_DOMAINS` and `OSINT_CERT_TO_SERVERS`
keep those explicitly selected comparison purposes separate. Different keys do
not match merely because names or issuers coincide. Reuse supplies no ownership,
actor identity or accepted assessment.

### Accepted issuer-and-serial links without automatic certificate merging

Issuer/serial is a distinct selector with an explicit issuer namespace,
normalization rule and serial radix. It does not silently become whole-certificate
or SPKI identity. `CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT` retains its
exact issuer/serial question. Preserve the selector's source, field and revision;
unsupported equivalence or ambiguous issuer identity remains unresolved.

### Accepted certificate-name and observed-presentation associations

SAN/common-name fields and CT name records are claims about certificate material.
An observed presentation is a distinct occurrence at a service/endpoint, with
actual role, vantage and any supported requested-name association. A name in a
certificate does not prove that domain served it. Later DNS, co-mention and
certificate validity do not supply the missing presentation or domain join.

### Accepted certificate presence, reported signer and verified signing distinctions

Certificate presence in an artifact, a source-reported signer association and a
source-reported scoped successful verification are distinct inquiry purposes.
Preserve the particular artifact, selected signature/material, actual certificate,
primary/timestamp/chain role and content scope. Mere presence does not establish
a signature; a verification report is not a local cryptographic verification.
The [signing profile](../fixtures/semantic-families/signing/README.md) defines
these branches and their exact result identities.

### Accepted certificate validity separate from evidenced use

Declared `notBefore`/`notAfter` and an observed use have different meanings.
Evidence of presentation or artifact association can remain historical evidence
outside declared validity. This neither proves successful trust validation nor
repairs an invalid signature. Expiry and revocation context attach to the actual
claim and time; they do not erase an evidenced occurrence.

### Accepted certificate-family links independent of entity discovery order

A certificate discovered after a sample or endpoint may still be independently
linked to an earlier occurrence. First discovery, source observation, extraction
and receipt cannot replace the actual relationship date. Preserve source-backed
joins and chronology; report publication order alone neither proves nor defeats
a sample/certificate or presentation relationship.

### Accepted certificate-presentation periods over observed use

Core TLS presentation queries select the actual presentation occurrence, not
certificate issuance, validity, extraction, ingestion or last processing.
A September 2026 report about a December 2024 presentation remains December
activity. Unknown or incomparable occurrence time remains unresolved for dated
eligibility; a point observation does not imply continuous use.

### Accepted historical certificate-cluster seed references

An explicitly selected older seed-domain certificate association can remain a
reference for `CTI_CERT_REUSE_FQDN_CLUSTER` while candidate presentations use the
requested period. It does not automatically enumerate every historical seed
certificate or widen candidate retrieval. Preserve whether the seed association
is a name field or actual presentation, and retain its own date and evidence.

### Accepted analyst or case selection of certificate-presentation periods

`OSINT_CERT_SHA_TO_DOMAINS`, `OSINT_CERT_TO_SERVERS` and applicable certificate-
reuse branches require an analyst/case-selected period; the former 825-day value
is not an implicit override. Reusable selections may resolve dates without
repeated manual entry. Record relative anchors and resolved scope. Missing scope
is invalid query input, while limited source coverage remains a visible evidence
limitation rather than proof of no activity.

### Accepted sample and APK signer finding-availability purpose

`CTI_SAMPLE_CODESIGN_CERT_CLUSTER` and `CTI_APK_SIGNING_CERT_CLUSTER` select the
first complete qualifying artifact/certificate finding in the named collection.
Artifact production, capture, extraction and verification remain distinct events.
A 2026 finding about a 2012 artifact is not a 2012 finding. Same-result processing,
new source labels and repeated receipts cannot establish novelty.

### Accepted complete package-signing findings and availability

`SUPPLY_CODESIGN_CERT_TO_PACKAGES` additionally requires the exact package-version
and distribution-artifact join. A certificate-presence finding about the artifact
alone does not establish a package signing claim. The complete package finding
has its own required support and establishment; it cannot inherit a date before
the package/artifact correspondence was available. Retain the distribution
variant and actual signing-evidence purpose.

### Accepted distinct Authenticode comparison types

`CTI_AUTHENTICODE_HASH_CLUSTER` distinguishes whole-artifact identity, a declared
Authenticode image digest, signature-material digest and certificate/key
selectors. Algorithm, representation, covered scope, recipe/version and role are
part of the typed comparison. Scheme-specific digests are not silently full-file
hashes, and equal signature material does not prove equivalent artifact contents
or valid primary/timestamp signatures.

### Accepted image-digest findings independent of signing status

An adequately evidenced image-digest comparison can qualify without a valid
signature, selected certificate or successful signature-processing report. The
image-content branch must still establish the actual typed digest and scope.
Missing signing evidence does not invalidate that independent comparison or
permit another branch to invent a signer association.

### Accepted Authenticode finding-availability window purpose

Each selected Authenticode question uses its own complete finding and earliest
equivalent establishment in the collection. Image content, signature material
and certificate association do not share one undifferentiated timestamp.
Tool changes, resigning and altered representations must be assessed under the
actual identity recipe; a processing event alone is not novelty.

### Accepted selected historical Authenticode references

A selected older reference can supply the comparison identity without becoming
a recent candidate or widening the candidate period. Preserve its exact artifact,
material scope, signature role and provenance. Reuse of a reference does not
establish another observation, and a new candidate needs its own qualified
comparison and availability history.

### Accepted analyst or case periods for five signing-finding patterns

`CTI_APK_SIGNING_CERT_CLUSTER`, `CTI_SAMPLE_CODESIGN_CERT_CLUSTER`,
`CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT`,
`SUPPLY_CODESIGN_CERT_TO_PACKAGES` and `CTI_AUTHENTICODE_HASH_CLUSTER` require
explicit analyst/case finding periods. They do not automatically inherit 3,650
days. A shared scope-selection policy does not merge claim identities, material
roles or source timestamps. Retention, source coverage, knowledge cutoff and
execution budgets remain separate.

### Accepted shared signing-service context and explicit exclusions

Shared or mass signing-service context is retained with the actual artifact,
credential and role. It does not automatically exclude the finding or identify
an author/operator. A selected investigation filter requires source-qualified
classification and exact effect scope; unknown classification is not membership
or clearance. A service relationship does not prove that customers share control.

### Accepted explicitly selected timestamp-role inquiries

Timestamp-role inquiry is explicit and keeps the timestamp signature/material,
certificate and verification evidence separate from primary signing. A valid
timestamp report does not establish a valid primary artifact signature, and a
primary signer is not inferred from a timestamp certificate. Unsupported role
or recipe combinations are not silently remapped.

### Accepted test/default signing-credential context and explicit exclusions

Test, debug, default and publicly available private-key classifications require
evidence for the actual credential and role. A public certificate does not prove
public access to its private key. Retain context by default; selected scoped
filters are separate. Credential class alone does not determine artifact intent,
maliciousness, trust or accepted assessment.

### Accepted C2 encounters and endpoint-mediated association leads

`CTI_C2_CERT_TO_SAMPLE_CLUSTER` distinguishes an attributable sample connection
that actually encountered the selected presentation from a narrower
endpoint/service-mediated association lead. The encounter binds the actual
sample execution, connection and presentation occurrence. A later scanner
observation, shared endpoint or report co-mention cannot establish an encounter.
Preserve role, endpoint scope and source-qualified correspondence.

### Accepted C2 finding-availability window purpose

The period selects complete sample/certificate findings newly established in the
named collection, with preserved history and exact claim equivalence. An old
network contact can support a later finding; neither contact nor presentation
is redated. Connection/presentation identity, material and relationship scope
control equivalence, not parser run, ingestion ID or an irrelevant view change.

### Accepted analyst or case selection of C2 finding periods

Require explicit analyst/case dates for the C2 finding purpose. No inherited
universal duration supplies missing scope. Older reference evidence can remain
support without becoming a recent finding. Source coverage, actual contact time,
knowledge cutoff and resource limits remain visible and distinct.

### Accepted C2 shared-CDN context and explicit investigation exclusions

CDN/shared-endpoint context does not defeat a supported encounter or convert an
indirect lead into a direct one. Retain the explanation and apply only explicitly
selected, source-qualified filters at the actual claim scope. Shared address
reuse does not establish common operator identity or certificate use by a sample.

### Accepted C2 controlled-occurrence context and explicit exclusions

Sinkhole, simulation, test and research context remain attached to the actual
contact or presentation. Their presence does not automatically erase otherwise
supported evidence. Selected exclusions must match that occurrence and role;
a later change of purpose cannot reclassify unrelated historical activity.
Neither inclusion nor filtering supplies maliciousness or analyst acceptance.

### Accepted RDP presentation-occurrence window purpose

`OSINT_RDP_CERT_THUMBPRINT_CLUSTER` selects actual RDP certificate presentations,
with the same service, occurrence, role and evidenced endpoint/name correspondence.
A declared certificate validity period, generic TLS presentation or later DNS
record is not an RDP observation. A newly received old report remains old activity.

### Accepted analyst or case selection of RDP presentation periods

Require an explicit analyst/case presentation period. Reusable selections must
resolve reproducible dates; missing scope is not an unlimited query. Keep source
coverage, retention, knowledge cutoff and resource limits separate. Incomparable
presentation times remain unresolved for dated qualification.

### Accepted RDP CDN-edge context and explicit investigation exclusions

CDN/edge or shared-service classifications remain source-qualified context for
the actual RDP presentation. An explicit investigation filter can exclude the
matching scope with its recorded revision and reason. Classification alone does
not establish ownership, source independence, current exposure or maliciousness.

### Accepted CT-name record-occurrence window purpose

`OSINT_CRT_SH_SUBDOMAINS` selects the supported CT-record occurrence and its
specified meaning, such as a source-reported record date or observed inclusion.
It binds the actual certificate/precertificate and exact typed name field.
Reported record date does not prove verified log inclusion, presentation, DNS
resolution, issuance completion or domain ownership.

### Accepted analyst or case selection of CT-name record periods

Require explicit analyst/case dates for CT-record activity. Certificate validity,
receipt and processing are not substitutes. Preserve source/log/record identity,
uncertain bounds and limited historical coverage. Reusing a relative preset
later may select a different period and must not obscure that scope change.

### Accepted CT wildcard entries as separate contextual clues

A literal wildcard name remains a wildcard clue; it does not enumerate concrete
subdomains or establish that any particular host exists or served a certificate.
Concrete names and wildcard results have distinct forms and query matching
rules. Further DNS or service investigation needs its own evidence.

### Accepted CT-name shared-CDN and hosting context with explicit exclusions

Shared-CDN or hosting context can accompany a CT name without defeating its
existence in the selected record. Any explicit exclusion is source-qualified and
scoped to the query's actual claim. Name inclusion supplies no presentation,
independent origin, customer identity or attribution.

### Accepted explicit reusable certificate-characteristic profiles

`CTI_TLS_CERT_SUBJECT_PROFILE_TO_INFRA`, `CTI_CERT_ISSUER_VALIDITY_CLUSTER` and
`CTI_SHORT_LIVED_CERT_INFRA_CLUSTER` use preserved, digest-checked, explicitly
versioned comparison profiles. Field selection, normalization/comparison recipe,
bounds and combination rule are declared and computed against the same
certificate. An opaque `matched` flag is insufficient. Subject resemblance,
issuer plus validity-duration criteria and short declared validity are different
questions; profile equality does not establish certificate/key identity.

### Accepted presentation-occurrence windows for certificate-profile pivots

The query period selects actual matching-certificate presentations. The profile's
declared validity-duration criterion remains a separate certificate property.
It does not date deployment, uptime or current use. Every result still needs
its actual presentation/service/endpoint path, even when the profile matches.

### Accepted analyst or case periods for certificate-profile presentations

Require explicit analyst/case presentation dates independently of the chosen
characteristic profile. Record both the period and exact profile revision.
A saved profile does not silently carry a universal activity lookback or resource
budget. Missing source coverage and uncertain presentation dates remain visible.

### Accepted common/default certificate-profile context and explicit exclusions

Common/default certificate characteristics are context and an alternative
explanation for similarity. They do not automatically discard a computed match
or establish reuse of one private key. Selected filters require explicit
classification, scope and revision; a descriptive label cannot supply an
unimplemented rarity threshold or numerical score.

### Accepted certificate-profile infrastructure context and explicit exclusions

Shared hosting, CDN, public scanner, controlled service and other infrastructure
context attach to the actual presentation or endpoint relationship. Preserve
otherwise supported profile matches unless the selected scoped policy excludes
them. No infrastructure label establishes common control, a continuous deployment
or the meaning of an unrelated historical occurrence.

### Accepted marketplace-reported sale to certificate-presentation leads

`CTI_MARKETPLACE_SOLD_DOMAIN_CERT_CLUSTER` follows a selected source-reported sale,
its claimed domain, an exact certificate-name association and a supported later
presentation. An offer, cancellation, withdrawal and confirmed transfer differ.
The report does not by itself prove a completed sale, buyer identity or control.
An already-existing certificate can supply the association; no new issuance
requirement is inferred.

### Accepted presentation-occurrence window for marketplace certificate leads

The period selects the actual candidate presentation; reported sale chronology
is checked separately. A sale reported for September 20 does not precede a
September 17 presentation merely because both fall inside the same query period.
Receipt on September 25 does not redate either event. Unknown sale chronology
remains unresolved; certificate validity or CT-only names cannot supply the
missing occurrence.

### Accepted selected historical marketplace sale references

An explicitly selected older sale report can remain the reference for newer
candidate presentations, without an automatic sale-recency gate or expanded
candidate search. Keep reported sale status, chronology and source amendments
visible. Selection does not confirm transfer or enumerate all historical sales
of the domain.

### Accepted analyst or case periods for marketplace certificate presentations

Require analyst/case presentation dates instead of an implicit 180-day duration.
The selected historical sale and its own evidence remain separate. A visible
preset can resolve dates, but cannot invent chronology, conceal source gaps or
supply unlimited retrieval. Event-time and knowledge-at-time inquiries differ.

### Accepted marketplace certificate-class context and explicit exclusions

Common/default or shared certificate classes remain context for the actual
marketplace-to-presentation lead. A selected source-qualified filter can exclude
that scope; class alone does not establish a false sale, shared owner or a
malicious endpoint. Certificate and SPKI comparison meanings remain distinct.

### Accepted CDN context and explicit exclusions for marketplace and certificate-to-servers leads

Both marketplace leads and `OSINT_CERT_TO_SERVERS` retain supported CDN/shared-
service presentations with their actual context. An optional investigation
exclusion must be explicit and evidence-backed. Shared delivery infrastructure
does not invalidate the presentation or establish common ownership across its
tenants; unknown origin role remains unknown.

### Accepted certificate-class context and scoped exclusions for the three core TLS pivots

`OSINT_CERT_SHA_TO_DOMAINS`, `OSINT_CERT_TO_SERVERS` and
`CTI_CERT_REUSE_FQDN_CLUSTER` retain supported certificate relationships with
source-qualified class context. Selected filters act on the actual claim and
role, not every use of a certificate/key or every hosted domain. Conflicting
classifications remain visible; an unresolved required filter is not clearance.

### Accepted historical marketplace sale-report leads with visible revisions and status filters

Preserve historical reports with their exact source/revision and explicit
corrections, withdrawal, reinstatement or dispute context. A corrected report
remains a labelled historical claim rather than silently becoming maintained
support. Latest receipt does not automatically win. Optional investigation
status filters must state their scope; retaining a report does not confirm a
transaction, current ownership or legally effective transfer.

### Accepted separate client-JA3 and server-JA3S companion pivots

`OSINT_TLS_JA3_TO_FQDNS` concerns the client message;
`OSINT_TLS_JA3S_TO_FQDNS` concerns the server response. Fingerprint kinds and
message roles are non-interchangeable. A domain association needs source-qualified
evidence from the actual named exchange/leg, not merely a SAN, later DNS answer
or shared endpoint. A named client attempt does not require inventing a server
response; a planned scan is not an actual attempt. Shared fingerprints are
not unique endpoint, application, owner or actor identities.

### Accepted analyst or case activity periods for JA3 and JA3S

Require explicit analyst/case dates for the actual selected message occurrence.
A client message at `2026-09-30T23:59:50Z` and server response at
`2026-10-01T00:00:10Z` have different date membership. Extraction, receipt and
reprocessing do not move those events. The [JA3 fixture profile](../fixtures/semantic-families/ja3/README.md)
and separately bounded adapter define their admitted evidence and execution
scope; no raw PCAP parser or general native capability is implied.

### Accepted common-profile and scanning context with explicit JA3-family filters

Common fingerprints, scanners and controlled activity remain scoped contextual
explanations. Retain an otherwise supported observation unless an explicitly
selected and evidenced filter excludes it. Missing optional classification stays
unknown; conflicting required policy evidence does not clear the candidate.
A shared fingerprint supplies no unique device identity or assessment status.

### Accepted separate retrospective and historical-status sanctions inquiries

All eight sanctions patterns distinguish retrospective association discovery
from source-stated historical status. Later designation can be relevant to a
retrospective inquiry without being required. Historical status needs the actual
listed subject, selected entry/list revisions and supported applicability at the
requested point or interval. Publication, source-stated effective/applicable
dates and receipt are distinct; none alone constitutes a legal determination.
The [sanctions profile](../fixtures/semantic-families/sanctions/README.md) defines
`retrospective`, `historical_at`, `historical_some` and `historical_all` purposes.

### Accepted dated historical sanctions chains and time-qualified relationship claims

Transactions and trades use actual individual occurrences and counterparties;
co-inputs, batch aggregates, correspondents or shared transport are not silently
direct counterparties. Ownership, LEI parentage, registration and ASN association
require their own time-qualified identity and relationship evidence. Historical
`some` requires a real common supported interval, not unrelated overlaps.
`all` does not imply continuous transactions. Fixed certificate references do
not create a certificate-use event. A linked subject does not inherit another
subject's listing.

### Accepted analyst-selected sanctions inquiry periods and separate reference history

Require explicit inquiry purpose, selected source and entry revisions, and the
period/point appropriate to that purpose. Fixed certificate-reference lookup
forbids an invented activity period in retrospective mode. Historical reference
selection, source coverage and the actual activity period remain separate.
A knowledge cutoff additionally checks actual publication and collection receipt
of required support; later evidence does not establish earlier analyst awareness.

### Accepted sanctions context with explicit reusable investigation filters

Preserve source-qualified historical assertions and amendments, including
contradictory reports, without choosing by repetition or latest receipt.
Selected reusable investigation filters act on explicit scoped evidence and
retain reasons and revisions. Unknown independence stays unknown. Matches,
retained reports and source-stated status supply no legal exposure, sanctions
violation, liability, maliciousness or accepted assessment.

### Accepted reported beneficial-owner leads with separately supported control

`FIN_BENEFICIAL_OWNER_TO_SANCTIONS` follows an explicit source-reported beneficial-
owner category and its stated basis, directness and applicability. Shareholding,
nominee title, employment or control-only categories are not relabelled as that
category. Preserve quantities, ranges, absent amounts, denominator, rights type
and share class; unknown is not zero and economic/voting percentages differ.
There is no universal percentage-to-control rule or multiplication of indirect
chains. A control claim requires separate evidence and an explicit supported
capability; reported beneficial ownership alone does not supply it.

## Other unresolved consumer assumptions

- The 134 original definitions outside this migration still need their own
  semantic binding analysis before general executable interpretation. No
  last-hop result convention or global temporal ordering is implicit.
- Backend mappings must implement the exact admitted contract or report
  unsupported. The bounded one-hop Neo4j pilot does not enforce general
  `temporal.order`, degree caps or `outputs.top_paths`; the hybrid semantic
  adapter and OpenCTI mapping retain their separately documented limits.
- Documentary `min_unique_sources` is not an independence evaluator. Documents,
  publishers, collections, source labels and independent origins are distinct.
  Copies, syndication and duplicate ingestion do not establish corroboration.
- Source authentication, globally complete history, arbitrary entity resolution,
  legal interpretation and accepted assessments are outside these contracts.
- Overdue `next_review` metadata requires actual maintainer review evidence.
  Tooling or documentation updates do not establish that review.
