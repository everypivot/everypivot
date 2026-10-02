# Synthetic fixture hash review

This review covers the 80 retained JSON files under `fixtures/semantic-families`
listed by exact path and complete-file SHA-256 in
`tools/data/reviewed_semantic_fixture_hashes.json`. It supplies narrowly scoped
CTI lint exceptions for 56 files containing 255 distinct otherwise flagged hex
values. The other 24 files need no hash exception. No external feed, native
runtime, real investigation artifact, private signing key, or analyst acceptance
record was used in these fixtures or in this hash reproduction.

The content review inspected the family factories, retained source documents,
source publisher/collection fields, query selectors, certificate vectors and
expected cases. The exception list was accepted only after every value had a
source-defined synthetic derivation or an explicitly artificial vector. Scanner
output alone was not a basis for acceptance.

| Family | JSON files | Synthetic basis and reproduction |
| --- | ---: | --- |
| Extraction | 11 | `fixture_factory.rb` builds literal historical artifacts, extraction reports, selector output, source receipts and finding history. Exact preserved byte strings yield content hashes. Sorted-key `canonical_json_v1` yields record, contract and finding-identity hashes. The resource-section and OCR outputs are literal synthetic strings, not recovered malware data. |
| Result bindings | 12 | `fixture_factory.rb` uses the extraction source helpers for artificial request traces, creative scripts, archives, file-set members/manifests/coverage, appointment reports and reputation assertions. File-set digest values reproduce the exact retained member, manifest and coverage strings; the completeness claims remain synthetic source assertions. |
| Package/repository | 2 | `fixture_factory.rb` embeds the already retained example version-declaration sidecar/source document and artificial repository observations/policy data. Hashes reproduce the exact `source_bytes` strings; the same registry document is shared deliberately. |
| Signing | 10 | `fixture_factory.rb` builds source-reported associations and scoped-check claims. Artifact identities use prose preimages (`historically retained artifact A`, `different historical reference file R`). Signature-material, scheme-content and image-selector values hash explicitly concatenated synthetic kind/role/scheme labels. These label hashes are not a claim that a real signature, PE or APK digest was calculated or verified. Finding hashes use the same explicit canonical recipe. |
| Certificate presentation | 7 | `certificates.json` retains three synthetic public certificate vectors and DER/SPKI encodings, with example names and organization `Synthetic Fixture`. Reproduction parses the PEM, checks DER and public-key bytes, and hashes them independently. Two certificates share a key and differ in serial/certificate bytes; the third uses a different key. No private key is retained or needed. The source JSON is a synthetic normalized report, not a network capture. |
| JA3/JA3S | 5 | `source.json` is an independently authored synthetic normalized TLS report. Its exact file-byte hash is reproduced. The repeated ascending hexadecimal alphabet is a deliberately artificial shared selector vector used to test client/server and occurrence distinctions; it is **not** represented as the computed fingerprint of a retained ClientHello or ServerHello. |
| Sanctions | 33 | Eight `*-source.json` files describe fictional historical/list assertions using example domains, documentation addresses, synthetic organizations/identifiers and the retained synthetic certificate selector. Each source hash reproduces exact source bytes. Queries and expected cases express data interpretation, not legal exposure or liability. |

The 255 distinct reviewed values have these first-listed derivations (shared
values may have more than one reproducing source): 95 preserved-string SHA-256;
90 canonical record SHA-256; 23 finding-identity SHA-256; 23 canonical contract
SHA-256; 10 exact source-file SHA-256; 6 signing-label SHA-256; 5 certificate/SPKI
SHA-256; 2 prose artifact SHA-256; and 1 explicit artificial selector vector.
The manifest records the specific source path/record/preimage for every value.

Run the independent, read-only reproduction and boundary checks with:

```sh
ruby tools/check_semantic_fixture_hashes.rb
ruby tools/test_cti_promotion_lint.rb
ruby tools/check_cti_promotion_lint.rb
```

The reproduction checker implements the canonical JSON recipe without invoking
the semantic evaluator or family factories. It checks all 80 complete-file
pins, all 255 derivations, inventory coverage, and exact allowed-value coverage.
Reproducing a source hash establishes byte identity, not authenticity or the
truth of a source claim.

The lint tool pins the review manifest itself by SHA-256. An exception requires
the exact repository-relative fixture path, its complete reviewed bytes, and
the particular allowed value. An edit, newline change, rename, relocation or
new hex value loses the exception. The hash exception does not bypass domain,
address, credential, command, CVE, review-vocabulary or pattern checks. Portable
release copies preserve the relative paths and therefore the same boundaries.

There is no automatic exception updater. A changed fixture requires inspection
of its synthetic basis, fresh reproduction and an explicit review-data update;
running the scanner or the fixture generator is not that review. This record
does not change pattern review dates, lane, evidence mode or acceptance status.
