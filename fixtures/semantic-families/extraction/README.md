# Extraction family semantic fixtures

These are synthetic inputs to the portable semantic evaluator. They are not
native adapter runs, real extracted samples, analyst acceptance, independent
corroboration or source-truth verification. The corresponding contracts are
`contracts/semantics/<PATTERN_ID>.json`, semantic contract version `1.0`.

Run `ruby tools/test_semantic_extraction.rb` from the repository root. The eleven
JSON cases contain actual evidence envelopes, query inputs, preserved source
byte strings, explicit establishment/history records and independently selected
expected result IDs. `fixture_factory.rb` authors additional counterexamples;
it does not invoke the evaluator or derive expected results from its predicates.
`write_fixtures.rb` reproduces the eleven base cases after an intentional contract
change. `build_contracts.rb` authors the explicit JSON contracts; it is not a
backend adapter or extractor. Neither script changes pattern YAML.

## Portable evidence profile

The profile name is `preserved_extraction_v1`. Its fields below are explicit
contract requirements. Other attributes are retained context, not executable
semantics. Records remain source-qualified assertions; the evaluator does not
perform OCR, recover encrypted data, execute code, query DNS or fetch URIs.

Each extraction occurrence binds its exact input with `subject` and its exact
preserved output with `object`. It records `run_id`, `method`, `method_version`,
`normalization_method`, `normalization_version`, `source_location`, `profile`,
and the branch-specific `output_semantics`. The method fields describe the
evidenced source operation; their presence does not prove that operation correct.
Content identity is checked independently through actual supplied bytes.

An artifact's `attributes.content` contains `source_id`, `sha256`, `byte_length`,
`representation: exact_source_bytes` and retained `locator` context. Its source
has the same exact-byte content hash, and its evidence links that source. The
evaluator independently reproduces hash and byte length from
`preserved_source_bytes`. A locator does not substitute for bytes, authenticate
a source, prove capture time or prove what the bytes mean. Missing required
bytes are unresolved; altered bytes or inconsistent digest/length are invalid
input. The source itself may preserve original, cropped, rendered or decoded
material; `exact_source_bytes` describes hashing, not a claim that the material
is an unmodified original. Required lineage/association records bind its role.

Simple selectors explicitly bind `namespace`, `representation`,
`profile: literal_exact_v1`, and `value`. Equality is exact across all four
fields. `literal_exact_v1` executes no normalization: decoded/normalized values
are source-reported outputs with their recorded method revisions. The finite
admitted representations are:

| Family | Representation choices |
| --- | --- |
| Source path | `utf8_literal`, `utf8_normalized_path` |
| Sample string / web token | `utf8_literal`, `utf8_decoded` |
| Function name | `utf8_literal` |
| Resource section | `sha256_exact_section_bytes` |
| Header value | `utf8_literal`, `unfolded_utf8` |
| Message-ID host | `utf8_literal`, `ascii_dns_host` |
| OCR | `sha256_exact_ocr_output_bytes` |

Different representations do not compare equal by guesswork. This initial
capability does not implement arbitrary decoder, Unicode normalization, fuzzy
matching or cross-namespace equivalence recipes. Resource-section and OCR
selectors must equal the independently reproduced digest of the actual retained
section/output bytes. Unsupported transformation recipes require a separately
versioned executable capability; a profile label cannot introduce one.

Every required support has `times.collection_available`, bound to its own
record and an actual `evidence:availability` occurrence in the named collection.
Extraction `times.occurred` binds the particular input object and extraction
occurrence, and cannot follow its own evidence availability. Source field,
revision, clock, UTC normalization, original offset/precision, uncertainty and
missing-value behavior follow `SemanticTime`; absent timezone is not assumed
UTC. Other historical observation/receipt/creation fields are context unless
explicitly bound by a branch. No requirement invents a new artifact sighting.

Complete finding establishment is not the maximum component timestamp or a
`complete` flag. A source-backed establishment event must name the independently
qualified support set and computed semantic claim key, and every required
support must have been available by establishment. Exact-byte preserved history
must establish the declared collection origin-through-snapshot scope. Earliest
equivalent establishment controls the window. Unknown earlier history remains
unknown; repeated extraction, copies, ingest receipts, changed method labels,
native mappings or policy revisions do not reset it. A separate as-known cutoff
filters the required support and actual establishment. Neither cutoff proves
actual analyst awareness or worldwide first discovery.

`capture_id` denotes a source-supported, collection-scoped occurrence identity
for the exact capture, not a Message-ID header, locator, content digest or a
new ingestion record ID. Mapping records must preserve that stable identity
when copying/reprocessing the same capture. Conflicting or unestablished capture
identity is unresolved; minting a new ingestion ID is not evidence of a new
capture. Artifact digests and typed URI identity remain separate key components.

## Branch and finding requirements

| Pattern | Independently bound result and key | Window |
| --- | --- | --- |
| `CTI_FILE_SOURCE_PATH_CLUSTER` | Particular file digest + exact path-selector identity | 365 days |
| `CTI_SAMPLE_UNIQUE_STRING_CLUSTER` | Particular sample digest + representation-qualified string | 365 days |
| `CTI_SAMPLE_FUNCTION_NAME_CLUSTER` | Sample digest + actual recovered symbol; external-debug branch additionally requires exact symbol bytes and artifact correspondence | 365 days |
| `CTI_SAMPLE_RESOURCE_SECTION_HASH_CLUSTER` | Sample digest + digest of actual selected section bytes, identified section, selection recipe and SHA-256 algorithm | 365 days |
| `CTI_EMAIL_HEADER_VALUE_CLUSTER` | Exact capture + selector + selected header name; preserve actual field occurrence and original/gateway/export role | 30 days |
| `CTI_EMAIL_MESSAGE_ID_HOST_CLUSTER` | Exact capture + Message-ID host selector from actual Message-ID field occurrence; no sender/server identity claim | 30 days |
| `CTI_IMAGE_TEXT_REUSE_CLUSTER` | Actual original/crop/render image independently; page output additionally binds exact page capture/image association and actual URL identifier | 365 days |
| `CTI_WEB_CONTENT_EMBEDDED_CONFIG_STRING_CLUSTER` | Exact containing-resource capture + content digest + URI + token. URL view retains `inet:url`; generic non-URL URI uses `evidence:resource_content`; parsed DNS-host output has its own claim | 90 days |
| `CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS` | Exact message capture/bytes + URL actually contained in the supplied body/header/attachment/declared-render representation | 7 days |
| `ADTECH_WEBAPP_SOURCEMAP_TO_ADMIN_SURFACE` | Direct or content-corresponded referenced artifact route; separately evidenced administration surface has its own claim | 30 days |
| `CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_PAYLOADS` | Exact response occurrence/bytes + actual payload or direct config; payload-to-config derivation is separate; payload hash is another view of the payload claim | 30 days |

All windows are inclusive UTC calendar intervals
`[query_date - window_days, query_date]`, applied to the first complete finding
in the supported history. Wider historical analysis requires a new explicit
query; it does not rewrite the original result.

For OCR, the returned image is the actual image whose bytes were OCR input.
A crop/render is not silently replaced by its parent. Page association requires
matching image and page capture identities plus actual preserved content/render
or resource-trace evidence. Image qualification does not require page evidence;
page failure does not erase the image finding.

For web content, `capture:resource_identifier` must associate the same capture
with the URI. A URI merely mentioned by the content cannot replace it. URI
comparison uses the explicit generic syntax recipe, retaining query/fragment
and empty/absent components. A supported URL view preserves `inet:url` and URI
reference in one result. No suitable URL mapping permits the evidence-reference
fallback. Only the supported URI recipe's actual DNS-host component can support
an FQDN; no reverse DNS, inferred ownership or arbitrary domain substring is
accepted. An unfamiliar scheme can retain a resource finding while DNS-role
interpretation is unsupported. A different URI claimed to identify the same
resource needs its own association evidence; equal hashes do not prove it.

For email URLs, a gateway-rewritten URL B in the actual retained message can
qualify independently of a missing original. Decoding B to A or navigating B to
D is a different relation and cannot appear as an ordinary contained URL.

For source maps, matching locators do not prove bundle/map correspondence.
Required correspondence names both actual content digests and an explicit
content-bound manifest/build/pair basis. A direct map route can qualify when
that separate correspondence fails. Comments, examples or ordinary library
strings do not establish application routes. Routes do not establish reachable
or administrative surfaces: additional interface-role/capture association is
required. An asset CDN hostname does not supply the application origin.

For responses, the source profile binds an actual response occurrence key and
vantage; exchange R1 cannot borrow payload bytes downloaded in R3. Qualification
method/revision documents why the source classifies actual extracted bytes as
payload/configuration. Endpoint names and marker strings do not supply that
classification. Response event must precede extraction. Direct config needs no
invented intermediate payload. Payload-derived config needs its actual second
derivation and retained config bytes. Hash enrichment shares the payload claim
and cannot refresh first availability. None of these types or matches establishes
maliciousness, attribution or accepted assessment status.

## Controls and limitations

Each named control uses an explicit pinned revision parameter. Source assertions
use `policy:selector_membership`, `policy:dns_membership` or `policy:membership`
according to the exact compared subject. Assertions name policy/list identity,
revision, `matching_profile: exact_subject_v1`, and `member`, `not_member` or
`contested` state, with preserved exact source bytes. Eligibility requires a
positive `not_member` evaluation with `coverage: complete_for_evaluated_subject`;
absence of a retrieved record does not establish nonmembership. Unknown or
conflicting required evaluation withholds ordinary output and retains the
qualified evidence candidate, bindings and reason in diagnostics. This is
neither policy suppression nor deletion of the finding. Membership is
source-qualified evidence, not independent list ingestion or authenticity
validation. Contradictory supported assertions have no forced winner.

Selector membership compares namespace, representation, profile, value and
extraction context. Equal text under another namespace does not establish list
applicability. The web common-token control also admits an explicit preserved
`selector:equivalence` assertion with left/right selector identities and
contexts, `profile: explicit_selector_equivalence_v1`, method and version.
It qualifies a source-reported mapping; it does not derive arbitrary equivalence
from labels. Unknown mapping retains an unresolved candidate. Record aliases
cannot evade known semantic-selector exclusion. Other controls compare the
actual content digest, exact capture identity, URL, administrative surface
origin or typed DNS selector; a list name is not a selector namespace.

DNS-only controls explicitly test whether the bound URI actually has a DNS host
under the supported mapping. An IP URL records non-applicability, not clearance.
Missing or unsupported hostname interpretation is not treated as an IP or as
passed screening. The supplied positive fixtures carry actual preserved control
evaluations; their ordinary eligibility does not depend on missing membership.

The common-token control applies across that selected selector's dependent
outputs. The web common-hosting/CDN control suppresses only the FQDN result;
the resource URL can remain. Source-map frontend controls cover actual input
and, for the referenced path, its starting bundle. Response payload controls
also cover its dependent configuration path; an independently derived direct
configuration has no invented payload dependency. The other controls retain
their explicit source/result/path scopes in each contract. Changing selected
list revision creates a new evaluation, not a new finding. No source-label
count evaluates independence.

These fixtures establish bounded portable behavior over supplied, normalized,
source-supported records. They do not prove the original extractor was correct,
the source was truthful, history was globally complete, source reports were
independent, the data was operationally representative or any native consumer
acceptance. Missing alternative output support can yield a qualified result
with explicit gaps; no branch failure is silently converted to a global
negative claim.
