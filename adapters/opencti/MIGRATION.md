# OpenCTI/STIX mapping 0.2.1 migration

This is a bounded experimental mapping for CTI_SAMPLE_IMPHASH_CLUSTER. No
release, pattern maturity, portable pattern semantics, SAIL acceptance, analyst effectiveness
or native OpenCTI compatibility is promoted.

## Creator and historical identity

EveryPivot Project is the creator of the replacement STIX extension. Its
included group Identity records that extension provenance only.

| Role | Stable identifier |
|---|---|
| Historical extension, preserved unchanged | extension-definition--3f6d5a22-c719-4f53-a07b-1e88f44bb5a1 |
| Superseded synthetic test extension, tests only | extension-definition--c97f816d-2ba3-4ff1-b448-54e9f3163011 |
| Superseded synthetic creator, tests only | identity--dc9b0e58-9cda-458d-af63-c40d791437e9 |
| Replacement extension | extension-definition--f88d909d-5287-4f9a-8413-c1bcbc178d29 |
| Real project creator, EveryPivot Project | identity--c0ab47b4-28e6-48b6-bc65-1ad2feee67c6 |

The chosen treatment is **explicit replacement**, not an in-place revision or
retroactive repair of the historical extension. A same-original-creator metadata
revision may be permissible; replacement is selected to preserve the historical
and synthetic identities unambiguously. The new UUIDv4 Identity is a
non-personal project group; it asserts no incorporation, contacts or individual
authorship. Its ID is stored in the fixture and reused on every generation.
The replacement extension is bound to it through created_by_ref. No synthetic
Identity or extension UUID is renamed or reused. The historical object's missing
required creator remains a recorded historical defect; replacement does not make
those old bytes conformant. No revocation is emitted and no native record is
silently merged, deleted or migrated.

STIX 2.1 §§3.6, 3.6.1 and 7.3.1 support distinct object identities and first-version
timestamps: [OASIS specification](https://docs.oasis-open.org/cti/stix/v2.1/os/stix-v2.1-os.html).
The replacement extension and Identity have equal created/modified values of
`2026-09-17T08:28:15.057Z`, the creation time of these new STIX records, not a claim about project
founding or historical authorship time. The bundle has a new UUID. Existing note,
observed-data and relationship preserve IDs and created, with modified advanced
to that time because their extension keys/references changed. Every emitted
extension key now references the replacement. Historical-format and synthetic-creator regression fixtures are retained under
adapters/opencti/tests/historical-fixtures and labelled as test inputs.

The creator reference must resolve to exactly one included group Identity; it
carries no EveryPivot evidence metadata. All forbidden authority properties still
apply recursively, including x_opencti_created_by_ref. Creator provenance is not
source reliability, analyst/reviewer authorization or accepted assessment status.
The observation data remain synthetic, evidence-only mapping examples.

The published schema URL and JSON Schema $id are byte-for-byte unchanged.
Extension property schema version remains 0.1.0: only provenance and identifiers
changed, not its property contract. Profile 0.2.1 supersedes synthetic
0.2.0 and historical 0.1.0. Registry release, authoring schema, pattern version and
pinned SAIL revision remain distinct and unchanged.

## File identifier correction

STIX 2.1 §§2.9 and 6.7 prescribe the shared SCO namespace contributors. The old
custom-only rule omitted a present hash while using that namespace. This is a
contract defect, not merely a preference to match Python. The corrected bounded
mapping uses name (when nonempty) and one hash: MD5, SHA-1, SHA-256, SHA-512
priority, otherwise lexical hash-key order. It includes custom-only x_imphash.
The pinned Python library uses insertion order for fallback hashes, so multiple
nonpreferred hashes may legitimately differ from its chosen value. Ordering is
explicit and stable in this profile. File extensions and parent_directory_ref
are outside the supported fixture mapping, which emits hashes and name only.

Source File migration:
`file--253b8c62-bbe6-56c7-9236-b0cbbc1b29d1` →
`file--9cf9f39c-599e-57ae-b856-9f2c688f61c4`.
The SHA-256 target and suppressed target IDs remain unchanged. Source-dependent
relationship endpoints, observed-data refs and note refs are regenerated. Supplied
fixture IDs must match the new policy; mismatches are refused before output writes.
Native data is not migrated here. Later native evaluation must inspect old and new
IDs side by side; do not silently merge them or delete historical records.

Changing only custom imphash beside a selected standard hash leaves identity
unchanged; changing a selected hash or name changes it. Two standard-hash-distinct
files sharing imphash remain distinct. Equal imphash/name descriptions cannot
prove a unique individual file or occurrence. The source remains a feature proxy;
its inclusion in observed-data is not proof of an independently observed file.
Duplicate emitted identities are refused by this profile rather than silently
merged. Replay and product deduplication remain untested.

## Validation boundaries

Missing/malformed/dangling/wrong-type creators, duplicate IDs, forbidden authority
properties and invalid extension values are refused. Partial bundles can be valid
STIX but violate this profile's closure/shape. Valid future timestamps serialize;
the fixture suite rejects selected observations outside its declared window.
Leap seconds remain explicitly unsupported inputs, including legitimate historical
leap seconds; that limitation is not a claim that those values violate STIX.

Code/docs/schema retain Apache-2.0; fixtures retain CC BY 4.0.
