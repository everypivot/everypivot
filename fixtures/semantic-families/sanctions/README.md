# Sanctions association and source-stated status fixtures

These eight synthetic cases exercise the portable semantic-pattern contract
`everypivot.semantic_pattern` 1.0 and semantic-evidence contract
`everypivot.semantic_evidence` 1.0. Each pattern contract is bound to pattern
version 3.0.0. These versions are separate from the authoring schema, registry
release, adapters and SAIL assessment contracts.

This is a finite, normalized evidence interface. It does not fetch lists,
authenticate documents, resolve arbitrary names, execute bank/ledger adapters,
apply legal tests or accept assessments. The fixtures describe hypothetical
source assertions; their transactions and list entries are not real-world
review evidence. `source.json` files, their hashes and independent expected
cases identify exactly the authored examples. Test mutations receive separate,
reproducible in-memory source snapshots and hashes.

## Query and result contract

Every inquiry requires an explicit source record, purpose, nonempty distinct
`reference_sources` and `entry_revisions`, and execution limits. Source IDs must
exist in the supplied evidence. Entry revision IDs name actual revision-specific
`sanction:entry` records. Every required path record's evidence sources must lie
inside the selected source set. A selected source revision can be older or later
than the activity period; it is not eligible merely because its label resembles
another selected source.

| Purpose | Meaning and time selection |
| --- | --- |
| `retrospective` | Retain source-reported historical association leads with their amendment state. Individual transfers/payments/trades must occur within `period`; ownership, parentage, registration and ASN relationships must have supported applicability overlapping it. Certificate-subject lookup instead uses the explicitly selected fixed certificate reference and forbids an invented activity period. Later designation is allowed, not required. Missing designation chronology remains visible. |
| `historical_at` | Ask source-stated status at the selected event or relationship point. Event families use the actual event occurrence; other families require `at` within `period`. Every time-dependent relationship relevant to that claim and the actual listed subject's status must support the point. |
| `historical_some` | Relationship families require an actual common supported interval within `period`, not separate overlaps at different times. Event families require an in-period individual event and listed status at that occurrence. Fixed certificate references require supported status somewhere in the requested period. |
| `historical_all` | Require relevant relationship states and listed status throughout `period`. For event families, the event remains one in-period occurrence; only listed status is asked to cover the range. This does not assert continuous transactions or commerce. |

An optional top-level `knowledge_cutoff` independently asks whether the actual
supporting assertions and scoped receipts were available by that point. Each
required assertion/occurrence has a `published` time and a linked
`evidence:claim_receipt`. Publication precedes receipt; event occurrence must
also precede its publication. Later publication can support earlier relationship
or list applicability without knowledge being projected backward. A receipt
does not prove global first availability or any individual's awareness.

Results bind the actual revision-specific `sanction:entry`, listed subject,
source, path assertions, status assertion and purpose. They expose amendment
states. The source, person, address, certificate, domain, ASN or related company
does not inherit another subject's listing. Corrected/withdrawn historical
reports remain labelled historical reports; they are not maintained support for
historical-status qualification. Invalid query input, unsupported mapping,
unresolved evidence, known mismatch, outside-period evidence, explicit
suppression and partial evaluation remain distinct.

## Source records and exact joins

All records use the closed evidence envelope: `id`, `kind`, `type`,
`attributes`, `times`, `evidence`, with explicit `subject`/`object` when relevant.
Every consumed assertion is source-qualified through exact `source_id` and
originating `field`; source documents carry revision, collection and publisher
metadata. A label or repeated import is not independent corroboration.

| Pattern | Required binding and consumed fields |
| --- | --- |
| `FIN_CRYPTO_TX_TO_SANCTIONED` | `crypto:address` seed and counterparty connected by one `ledger:tx` occurrence. `subject` and `object` are the actual sender/recipient for an identified individual transfer. Require `record_kind=individual_transfer`, `execution_state=completed`, `environment=reported_real_network`, `transaction_id` and `transfer_unit_id`. Either direction is supported. A UTXO co-input cluster, batch aggregate or mere co-participant is not this direct transfer. |
| `FIN_BANK_TXN_TO_SANCTIONED_COUNTERPART` | A `fin:transaction` binds selected account as `subject` and actual party as `object`. Require `individual_payment`, `completed`, `reported_real_event`, identified transaction, and the paired roles sender-account/beneficiary or recipient-account/originator. Correspondents and intermediaries do not become direct counterparties. |
| `FIN_TRADE_PARTNER_SANCTIONS` | A source-reported `trade:transaction` binds the two organizations and its individual occurrence. Require `individual_trade`, `occurred`, `reported_real_event`, `counterparty_role=trade_counterparty` and transaction identity. Planned activity and shared transport context do not supply a trade occurrence. |
| `FIN_BENEFICIAL_OWNER_TO_SANCTIONS` | `org:reported_beneficial_owner` binds person to organization. The bounded mapping requires explicit source category `beneficial_owner`, `category_mapping=exact_source_category_v1`, stated basis and `directness=direct` or `reported_indirect`. It does not promote shareholding, nominee title, employment or control-only categories. Other source category vocabularies need an explicit mapping extension. |
| `FIN_ORG_LEI_PARENT_SANCTIONS` | Source organization-to-child-LEI and parent-organization-to-parent-LEI identity assertions require `identifies_same_legal_entity` with `registry_identifier` or `documented_continuity` basis. `lei:parent_relationship` runs child-to-parent with `direct_accounting_parent` or `ultimate_accounting_parent` role and its own applicability. LEI issuance dates do not substitute for parentage. |
| `CROSS_CERT_SUBJECT_TO_LEI_SANCTIONS` | Exact whole-certificate selector binds the selected material and `x509:subject_organization` assertion (`organizationName`, preserved raw value). An independent `identity:legal_entity_correspondence` assertion must identify the legal entity through registry identifier or documented entity correspondence; same-name text is insufficient. A source-qualified LEI identity assertion supplies the identifier link. Validity/extraction dates are not certificate-use events. |
| `CROSS_FQDN_TO_ORG_LEI_SANCTIONS` | `inet:domain_registration` binds the named domain to the reported registrant of record, with explicit registry-identifier or documented-entity-correspondence basis and actual applicability. A source-qualified LEI identity assertion remains separate. A privacy provider can be the reported registrant without becoming its unknown customer or domain controller. |
| `CROSS_ASN_ORG_TO_SANCTIONS` | `net:asn_organization` binds ASN to the actually reported assigned organization, allocation holder or registered organization, with explicit identity basis and applicability. First observation does not establish this relation's start or customer control. |

All eight then require `sanction:entry_subject` from the actual listed subject
to the selected entry revision, with `role=source_listed_subject` and exact
source-identifier or documented-entity-correspondence basis. A distinct
`sanction:status` assertion binds that entry and subject, `status=listed`, matching
list identity and entry revision. Its `applicable` time supplies source-stated
status, not legal effect. Separate listed periods remain separate assertions;
no gap is filled from a current snapshot or absence of a record.

LEI records in these examples have synthetic, checksum-shaped identifiers.
The evaluator joins explicit identity assertions; it is not an LEI registration
validator or an entity-resolution service. Certificate comparison uses the
separately versioned typed selector profile; reported and locally reproduced
digests retain their distinction and do not verify certificate trust.

Beneficial-owner `amount` is retained source context: value/range/absence,
rights type, denominator, share class and calculation basis. Five percent is an
example, not a threshold. Unknown is not zero; economic and voting percentages
are not interchangeable; multiple reports remain separate. No intermediate
shareholding multiplication or universal control rule is implemented.

## Time envelopes

Every consumed time identifies its object and occurrence, originating field,
source revision, clock, UTC reference, timezone and precision. The occurrence
identifier is the bound assertion/occurrence record. `applicable` on a status
assertion binds its object to the entry; relationship applicability binds the
relationship. Receipt time binds its object to the particular received claim.

An occurrence timestamp is not an established interval. Relationship/status
intervals require explicit start/end and endpoint inclusivity. Missing ends do
not establish perpetual continuation. Conflicting alternatives remain unresolved
when they cannot prove the selected predicate. Inclusive UTC calendar periods
include the whole final date; a state ending at 23:59:59 does not cover that
date's remaining fractional second. Inputs with non-UTC origins require an
explicit supported conversion while retaining original context.

## Amendments and historical knowledge

`tools/semantic_amendments.rb` consumes explicit `evidence:assertion_amendment`
assertions. `subject` identifies the exact prior assertion/occurrence.
`operation` is `withdraw`, `correct`, `reinstate` or `dispute`; correction alone
names a distinct replacement assertion as `object`. `assertion_namespace`
must match the target. `issuer_source_id` must be actual linked source evidence.
Corrections/withdrawals/reinstatements require the same reported publisher;
independent disagreement is a dispute, not authority to overwrite another
publisher's assertion. None of these metadata checks authenticates a publisher.

`supersedes_amendments` explicitly names prior amendment records for that same
target/publisher/namespace. Newest receipt, repetition or majority does not
choose a winner. Cycles are invalid. Known contradictory publication chronology
leaves supersession unresolved. Both corrections and their replacements remain
attached; opposing operations and unknown applicability are retained.

As-known evaluation requires amendment `published` and an actual scoped
`evidence:claim_receipt` before the cutoff. Later receipts stay attached as
`later_context` without silently rewriting the earlier view. Missing receipt or
encountered corrections outside selected source scope remain unresolved, not
proof of an unaffected report. No amendment in the supplied scope means only
`reported_in_supplied_scope`, never complete history, authenticated truth or
global current status.

The branch hook covers every required assertion/occurrence. `retain_reports`
returns explicitly labelled historical reports with states and support status;
`require_unwithdrawn_in_scope` prevents known corrected/withdrawn claims from
supplying positive time-qualified support and leaves conflicts unresolved.
Module scans and iterative supersession checks consume the caller's execution
budget. Truncation cannot establish absence of amendments.

## Optional classification policies

Default behavior retains otherwise qualified reports and their context.
`exclude_source_classes`, `exclude_path_classes` and, for event families,
`exclude_event_classes` enable explicit reusable filters. Each enabled flag
requires its nonempty selected class-ID array. `evidence:classification`
identifies its actual subject, class ID, `membership`, source/revision and
`policy_basis=selected_source_revision`. Membership must be supported as
`member`; `not_member` is an explicit bounded nonexclusion assertion, while
`contested` records actual unresolved conflict. A same-class member/nonmember
pair or an explicit contested report prevents a forced decision even if the
other supplied report says nonmember. Policies partition contradiction checks
by actual class ID: membership in one class and nonmembership in a different
class are not contradictory. Any independently supported selected exclusion
still applies across alternate optional classification rows for that same
source, required path or occurrence.

Source scope binds the selected source entity. Path scope binds the actual
listed subject; the LEI-parent contract also preserves explicit child-LEI and
parent-LEI classification subjects. Event scope binds only the identified
occurrence. A narrow path exclusion preserves alternative qualifying paths.
Class policies deliberately evaluate selected report revisions: they do not
assert historical membership or that optional classification context was known
at a knowledge cutoff. Source-policy suppression does not independently
classify all candidate entities. Low value alone does not establish dust,
airdrop, consent or purpose; a batch aggregate cannot qualify as an individual
event merely because its filter is disabled.

These are explicit source-reported class predicates, not implementations of
legal thresholds or clearance. Unknown membership is neither an exclusion nor
clearance. Filters cannot repair missing identity, party roles, list status or
applicability. The global engine's `max_bindings` and `max_results` are explicit
execution budgets; they do not imply implementation of every legacy degree cap,
feature calculation or `outputs.top_paths` declaration.

## Local checks

From canonical EveryPivot:

```sh
ruby tools/test_semantic_amendments.rb
ruby tools/test_semantic_sanctions.rb
```

The tests cover all eight patterns, source/reference scope, distinct purposes,
role and direction failures, before/after designation, missing/open/contradictory
times, genuinely common intervals, later publication/receipt, corrections and
as-known reconstruction, class conflicts, replay and bounded execution. They
establish behavior of these normalized contracts only. They do not establish
native adapter acceptance, list completeness, legal consequences, operational
readiness, independent corroboration or accepted assessment status.
