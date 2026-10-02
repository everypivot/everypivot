# Certificate expansion semantics and independent fixtures

These eight portable contracts implement distinct selected questions. They use
authoring integration separately from their semantic contract version `1.0`,
proposed pattern versions `3.0.0`, profile-definition revisions, adapter versions,
registry release and SAIL contracts. This directory changes no pattern YAML,
lane, review date, SAIL pin or native acceptance admission.

| Pattern | Selected question and period | Required path |
| --- | --- | --- |
| `CTI_CERT_REUSE_FQDN_CLUSTER` | Candidate presentation period; explicitly selected older seed reference remains a reference | Seed domain → selected certificate-name or actual presentation relationship → exact certificate or explicitly selected SPKI comparison → independently evidenced candidate presentation/name |
| `CTI_C2_CERT_TO_SAMPLE_CLUSTER` | First qualified finding availability in an explicitly named collection and preserved complete declared history | Whole sample artifact → attributable run/contact plus actual certificate presentation → a separately supported encounter, or an explicitly narrower address/service-context association lead |
| `OSINT_RDP_CERT_THUMBPRINT_CLUSTER` | Actual RDP presentation period | Selected whole-certificate SHA256 → actual presentation → RDP service → evidenced IPv4/name correspondence |
| `OSINT_CRT_SH_SUBDOMAINS` | Supported CT-record occurrence period | Actual certificate/precertificate → matching CT record → explicit typed name field; concrete names and literal wildcard clues have different result forms |
| `CTI_TLS_CERT_SUBJECT_PROFILE_TO_INFRA` | Actual presentation period, independently selected from profile criteria | Preserved subject profile → evaluated fields of the same whole certificate → actual presentation/service/endpoint |
| `CTI_CERT_ISSUER_VALIDITY_CLUSTER` | Actual presentation period | Preserved issuer **and** declared-validity-duration criteria → same certificate → actual presentation |
| `CTI_SHORT_LIVED_CERT_INFRA_CLUSTER` | Actual presentation period | Preserved explicit declared-validity-duration range → same certificate → actual presentation |
| `CTI_MARKETPLACE_SOLD_DOMAIN_CERT_CLUSTER` | Candidate presentation period plus separately checked reported-sale chronology | Selected immutable sale report → claimed domain → exact certificate name association → later presentation; pre-existing certificates and historical references remain eligible |

All periods are explicit inclusive UTC calendar dates supplied by the analyst or
case. There is no inherited 825/1095/730/1825/365/120/180-day default here. Missing
scope is invalid query input. Source IDs select exact supplied source revisions;
they do not count independent origins. Selected sources must exist in the input.
The fixtures use reserved example domains and documentation addresses, synthetic
reports and deliberately specified expectations. They access no network.

## Normalized fields and bindings

Every record uses the closed `everypivot.semantic_evidence` envelope. Required
records must link real input source IDs with nonblank document, revision and
collection metadata. Every selector carries source, record ID, source revision,
field and reported/derived provenance. Matching scalar labels cannot replace
typed identity or actual relationship joins.

| Record type | Fields consumed by these contracts |
| --- | --- |
| `x509:cert` | `certificate_selector` must be whole-certificate `certificate_sha256`; optional independently selected `spki_selector` is `spki_sha256`; `artifact_role` is certificate, or explicitly permitted precertificate for CT names |
| `inet:service` | `context_id`, protocol, address record where known; port is retained as reported context, never a substitute for service identity |
| `network:certificate_presentation` | Subject is the actual certificate, object the actual service; typed whole-certificate selector, `service_context_id`, nonblank `occurrence_id` and vantage, actual `certificate_presented` state and leaf/intermediate/chain-member role; typed address selector when supported |
| `network:presentation_name` | Subject is the particular presentation, object the FQDN record; matching service record/context, typed name selector, and requested-SNI/requested-host/source-reported-same-presentation basis. SAN names and later DNS do not supply this join |
| `x509:certificate_name` | Subject actual certificate, object concrete FQDN when applicable; matching whole-certificate selector, typed SAN-DNS/common-name field, actual reported/derived/CT-reported field basis; CT branches also require the exact `ct_record` ID |
| `x509:ct_record` | Subject actual certificate/precertificate; matching certificate selector, nonblank log and record IDs, declared event meaning (`source_reported_record_date` or `log_inclusion_observed`), occurrence time. A reported record date does not claim verified inclusion |
| `file:bytes` | Source-backed `artifact_selector` with kind `artifact_sha256`, algorithm SHA256, representation bytes, normalization `exact_bytes_v1`, scope `whole_artifact`. Reported identity is distinguishable from reproduction; local sample bytes are not universally required |
| `sample:network_contact` | Subject exact sample, actual typed artifact/address selectors, nonblank `occurrence_namespace`, `sample_execution_id` and `connection_id`, reported or locally attributed sample-connection basis; service identity/context required for service-scoped or encounter claims |
| `sample:certificate_encounter` | Subject exact attributable contact, object exact presentation, matching actual sample-execution/connection and actual certificate role/material, reported-attributable or locally checked evidence status. A later scanner observation or report co-mention is insufficient |
| `marketplace:sale_report` | Selected record ID, claimed domain subject and matching DNS selector, actual reported-sale assertion kind, assertion namespace, raw report status and separately bound reported event. Offer, transaction cancellation, report withdrawal and confirmed transfer are distinct |
| `evidence:classification` | Exact subject record, explicit class ID, reported member/not-member/contested state and `selected_source_revision` policy basis. This is a declared supplied-revision policy, not historical applicability or source authenticity |

All required records can carry `times.collection_available`, bound to that record
and its actual `availability_occurrence`, with originating field/revision/clock,
UTC mapping, precision and uncertainty. Knowledge-cutoff queries require all
these availability witnesses. Presentation/contact/CT occurrence must not
postdate its asserted availability. Missing knowledge is unresolved; event time
alone is not knowledge. C2 finding establishment additionally uses the shared
preserved history contract, independently qualified supporting paths and actual
establishment events. Replays and later supplements do not refresh an already
established equivalent finding.

C2 claim equivalence uses the actual source-qualified occurrence namespace,
sample execution/connection identity and presentation occurrence identity, plus
typed material and relationship scope. Normalized record IDs, parser runs and
tool versions are not novelty. `sample_execution_id` identifies the actual
attributable sample execution; it is explicitly different from an extraction or
processing run. The endpoint-scope parameter applies only to indirect leads;
an encounter cannot become a new claim merely by switching that irrelevant view.

## Executable characteristic profiles

`tools/semantic_certificate_profiles.rb` supplies two finite operators;
`certificate_profile_matches` takes bound certificate/profile record IDs and an
explicit family; `ct_name_in_scope` takes a source-bound name and declared DNS
query seed. These are computed comparisons, never an opaque `matched` flag.

A profile is an entity `x509:comparison_profile` with a content descriptor:

```json
{"source_id":"profile-source","source_revision":"r1","field":"/","sha256":"<64 lowercase hexadecimal digits>","byte_length":123,"representation":"exact_source_bytes"}
```

The descriptor must link the record's evidence and source revision. Its digest
must match a source hash scoped as `exact_source_bytes` and the actual supplied
profile bytes. The preserved UTF-8 JSON is a closed object:

```json
{
  "contract": "everypivot.certificate_profile",
  "version": "1.0",
  "id": "case-selected-duration-profile",
  "revision": "definition-r1",
  "family": "short_lived",
  "combination": "all",
  "criteria": [{
    "field": "declared_validity.duration_seconds",
    "comparison": "inclusive_seconds_range_v1",
    "min": 0,
    "max": 604800
  }]
}
```

Seven days is this **fixture's selected criterion**, not a universal threshold.
Profiles allow at most 32 distinct criteria and 1 MiB of preserved definition
bytes. Duplicate JSON members and duplicate fields are invalid. The subject
family requires a subject criterion; issuer-validity requires issuer and duration
criteria; short-lived requires a duration criterion. All declared criteria must
match. Unknown fields/comparison recipes are unsupported, never ignored.

Certificate `attributes.profile_fields` maps each field name to
`{value, representation, provenance}`. Each provenance pointer must be supported
by that exact certificate record/source revision. The helper requires a
source-backed whole-certificate selector before comparing any fields.

| Field | Comparison and value | Source representation |
| --- | --- | --- |
| `subject.common_name`, `subject.organization`, `subject.organizational_unit`, `subject.country`, `issuer.common_name`, `issuer.organization` | `literal_utf8_v1`, nonblank exact string; no case fold, similarity, issuer/subject substitution or Unicode normalization | `utf8_string` |
| `subject.distinguished_name_der`, `issuer.distinguished_name_der` | `exact_der_v1`, strict Base64 encoding of one parseable exact DER X.509 Name; ordering is preserved | `der_base64` |
| `issuer.certificate_sha256`, `issuer.spki_sha256` | `typed_identity_v1`, corresponding exact typed selector; reported issuer labels cannot satisfy it | `typed_selector` |
| `declared_validity.duration_seconds` | `inclusive_seconds_range_v1`, explicit nonnegative integer min/max; computed from the two endpoints, never a supplied duration or match flag | Two separately source-bound fields: `declared_validity.not_before` and `.not_after`, each `x509_utc_second` represented as exact `YYYY-MM-DDTHH:MM:SSZ` |

Definition hashes are reproduced locally. Certificate field values are evaluated
as source-qualified reported values; this helper does not claim that those fields
were independently reparsed from retained DER or that an issuer signed the
certificate. Exact certificate/SPKI selector reproduction remains separately
reported by the identity module. A reversed validity interval is unresolved;
malformed exact timestamps are invalid; date-only/coarse or different field
representations need a different explicit profile capability. Duration is neither
issuance time, deployment lifetime, presentation recency nor evidence of ACME.

## CT scope and result identity

Concrete `dns_name` and contextual `dns_wildcard` share explicit ASCII DNS
lowercase/root-dot normalization. A wildcard must be exactly one complete
leftmost `*.` label. The comparator checks literal DNS-label suffix membership;
it does not calculate registrable domains, infer public suffixes, perform IDNA,
resolve DNS, enumerate guessed children or infer service deployment. An explicitly
recorded apex is eligible; the query seed alone never supplies an apex record.
Wildcards emit `evidence:ct_wildcard_scope` constructed clues, which do not count
as concrete FQDN findings. This additional output form requires explicit authoring
and consumer migration before a pattern is bound to the new contract.

## Controls, report revisions and outcomes

Classification defaults retain otherwise supported evidence and context. Filters
must be explicitly selected. Unknown classification is no clearance; conflicting
member/not-member paths remain visible without choosing a winner. Optional context
can create multiple witness rows for one target. A path exclusion leaves an
independently qualifying path intact. IP/FQDN representations of an evidenced
same occurrence cannot evade a selected address filter. The subject-profile
infrastructure control is explicitly a **service-scoped shared-termination role**;
it is not a silent broadening of a historical FQDN-only list. Other profile/RDP/
marketplace infrastructure controls use their evidenced address classification.

Marketplace amendment context is retained for all required assertions and
occurrences. The selected `exclude_withdrawn_reports` filter applies only to the
sale assertion (`exclusion_support: [sale]`), including actual source-linked
withdrawal amendments; it does not silently become an endpoint/name-assertion
filter. The original sale revision is not rewritten. Literal status `withdrawn`
is also an explicit filter condition; `cancelled` is not interpreted as withdrawal.
Correction/dispute/reinstatement relations keep their own source identity and
supersession evidence. As-known views require actual amendment receipt in the
selected collection; earlier publication alone does not establish that knowledge.

Invalid input, unsupported recipe, unresolved binding/history, known non-match,
outside-period evidence, explicit suppression and finite-resource partial results
remain distinct. Suppressed or unresolved required-policy candidates retain their
projected evidence in diagnostics. These contracts do not produce confidence,
independence, maliciousness, C2 function, ownership, control or accepted assessment.

## Reproduction and limits

`contract_factory.rb` explicitly authors the eight static JSON contracts; it does
not derive expected fixture outcomes from evaluator results. `fixture_factory.rb`
constructs independent synthetic relationships and preserved profile/history bytes.
The regression suite specifies expected identities, claim distinctions and defeats
directly, including material/key renewal, scoped filters, old reference/new
presentation, CT wildcard separation, missing joins, source revisions, exact
profile boundaries, withdrawal knowledge, C2 replay and budget truncation.

```sh
ruby tools/test_semantic_result_primitives.rb
ruby tools/test_semantic_certificate_profiles.rb
ruby tools/test_semantic_certificate_expansion.rb
```

No source API mapper, live feed, native CT/RDP collector, certificate trust engine,
full package signature verification or analyst acceptance is exercised. The
existing native JA3/JA3S checkpoint predates subsequent shared-engine changes and
does not admit these families. Static shape validity and passing synthetic
behavioral fixtures do not confer cross-backend or operational approval.
