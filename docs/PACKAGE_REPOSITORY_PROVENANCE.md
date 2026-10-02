# Package Repository Provenance

The independent `everypivot.package_repository_provenance` sidecar is version
1.0. The two pattern versions 3.0.0 also carry authoring-1.6 execution references
for the declaration and infrastructure traversal. The
[portable traversal profile](../fixtures/semantic-families/package-repository/README.md)
defines explicit observation-window, result, control and historical-knowledge
bindings. Sidecar validation, local Git snapshot reproduction and portable
traversal execution are separate capabilities. Native acceptance of this pair
has not been established.

## Scope

This sidecar records the source-repository relationship used by
`SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA` and
`CROSS_PACKAGE_REPO_TO_DOMAIN_INFRA`:

- Preserve a version-specific package-registry declaration naming a source
  repository as an evidence-level association.
- Discover that relationship without a universal package/repository
  entity-creation ordering filter.
- Bind any repository hash to the exact source snapshot associated with that
  package version, preserving the evidence making the association.
- Preserve a declaration with an unresolved snapshot binding when the revision
  is unknown. Do not substitute the repository's current state.
- Treat commit identifiers and snapshot digests as identifiers and integrity
  checks. They do not establish that the package was built from those bytes.

The sidecar is defined by
[`package_repository_provenance.v1.schema.json`](../schemas/package_repository_provenance.v1.schema.json).
It is not a permissive authoring field or a general execution language. The
sidecar, authoring schema, individual pattern versions, semantic execution
contract, registry release, adapters and SAIL v0.4 DRAFT are independently
versioned. Their checks do not promote a lifecycle lane or establish that a
periodic review occurred.

## What the relationship means

`declares_source_repository` has the stored direction:

```text
exact package version --declares_source_repository--> named repository
```

The edge means: a preserved registry metadata revision for this package
version names this repository as its source repository. It does not mean that
the package publisher has proved a build origin, controls the repository, owns
its infrastructure, or has supplied an accepted assessment.

`SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA` follows this edge outward from
`it:prod:softver` to `code:repo`, then follows its existing
`operated_via|distributed_from` infrastructure hop.
`CROSS_PACKAGE_REPO_TO_DOMAIN_INFRA` follows this same edge inward from
`code:repo` to `it:prod:softver`, then follows its existing
`distributed_from|referenced_by` infrastructure hop. The intermediate node is
the exact node reached by the first hop. A common name, project label or
unversioned package identity cannot substitute for it.

Each second hop requires its own evidence. A declared source-repository edge
does not supply a missing repository-to-infrastructure or
package-to-infrastructure relationship. The different second hops mean the
two patterns are not exact inverses. The sidecar alone does not execute
result projection, suppression or the temporal window; those predicates are
defined by the separate portable traversal contract.

Keep original repositories, mirrors, imports and migrations distinct. A later
mirror can be the subject of a later registry declaration; its existence does
not rewrite an earlier declaration. Imported history or shared commit content
does not make two repository identities interchangeable. Preserve conflicting
metadata revisions as separate source records instead of choosing one silently.

## Evidence that must survive collection

Preserve the exact package identity and version, registry identity, named
repository, metadata document identity and revision, original declaration and
field locator, source and acquisition time. A registry's current unversioned
project page cannot establish what an earlier version's metadata declared.
An immutable content digest can identify the preserved document bytes where a
publisher revision identifier is unavailable; identify its algorithm and keep
the source locator as well. In that case, record `revision` as
`sha256:<document digest>`, alongside the required `sha256` value, rather than
inventing a publisher revision.

The sidecar makes these bindings explicit:

| Field | Required meaning |
| --- | --- |
| `package.registry`, `package.name`, `package.version` | Exact registry/package/version identity. |
| `repository_uri` | The repository identifier preserved from the declaration. No automatic mirror, redirect or URL-equivalence inference. |
| `declaration.kind` | `version_source_repository` qualifies the declared-source association; `mirror_reference` preserves a mirror pointer without treating it as a declaration of original source. |
| `declaration.evidence` | `publisher`, `collection`, source `uri`, document `revision`, document `sha256`, original `field` locator and offset-qualified `acquired_at` timestamp. The document must be retained separately; its digest and locator do not authenticate its contents. |
| `revision_binding` | Either `unresolved` with a reason, or `declared` with matching package/repository identity, full `commit` identity and its own evidence anchor. `declared` records a source assertion; it is not verification of build provenance. |
| `snapshot` | Either `unresolved` with a reason, or `hashed` with method, SHA-256 digest, matching commit identity and covered entries. |
| `evidence_mode`, `build_provenance` | Fixed to `evidence_only` and `not_verified`. |

A generic mirror pointer is not sufficient for `declares_source_repository`.
If a version-specific metadata revision explicitly names the mirror as its
source repository, preserve that declaration as `version_source_repository`
with the mirror's own identity. This still does not prove the original
publication came from that mirror.

When a source revision is known, preserve the evidence linking this package
version and repository declaration to that revision. A commit copied from an
unrelated release, a mutable tag resolved without recorded evidence or a
currently checked-out branch does not supply the missing link. The local
checker evaluates the supplied record and available local objects; it does
not fetch the registry or independently authenticate the source claim.

Repository identity, Git commit identity and source-snapshot content identity
must stay separate:

| Identity | What it identifies | What it does not establish |
| --- | --- | --- |
| Declared repository | The repository named by the preserved version-specific registry record. | Ownership, control or an original repository inferred from a mirror. |
| Full Git commit ID and `sha1` or `sha256` object-hash algorithm | A particular Git commit object when the object is available and verified locally. | That the package was built from it, or that its author/committer time is trustworthy. |
| Snapshot SHA-256 and hashing-method version | Committed source content covered by the documented method. | Package build origin, completeness beyond the method's supported content or authenticity of registry evidence. |
| Package-version-to-revision evidence | The recorded basis for associating the exact package version with the revision. | Independent verification merely because the record is well formed. |

Do not label an unsigned declaration plus locally computed hash as a verified
build attestation. A separate attestation or reproducible-build investigation
would need its own issuer, subject, method, verification and evidence contract.

## Source-snapshot method

The method identifier is `everypivot.git-tree-content.v1`. Its scope is the
committed Git tree for an explicitly supplied full commit object ID. The
helper must not fall back to `HEAD`, a tag, a branch or another mutable ref.
Git replacement objects are disabled during inspection.
The selected commit, every recursively reached tree, and every covered blob
must also match their Git object IDs, recomputed from object type, byte length
and contents using the repository's declared hash algorithm. A filename or
successful `cat-file` read alone is not an object-integrity check. Missing or
corrupt objects leave the snapshot unresolved without a digest.
Git transports and lazy fetching are disabled; only locally available objects
are used. Repository configuration and availability do not supply missing
package-version binding evidence.

The method reads tracked committed blobs rather than the working tree. It
sorts raw Git paths and records each path as base64, its Git mode, byte size
and blob-content SHA-256. The supported modes are `100644`, `100755` and
`120000`. Mode `120000` hashes the symbolic-link blob bytes; the helper does
not dereference the link. The resulting SHA-256 uses a domain-separated,
framed serialization of these manifest entries.

The exact digest input is constructed as follows; `NUL` is byte `0x00` and
`LF` is byte `0x0a`:

1. Start with the ASCII bytes `EveryPivot source snapshot v1` followed by `LF`.
2. For each entry in ascending raw-path-byte order, append the ASCII mode and
   `NUL`; the raw path's byte length as unsigned decimal ASCII and `NUL`; the
   raw path bytes and `NUL`; the blob's byte length as unsigned decimal ASCII
   and `NUL`; the blob-content SHA-256 as 64 lowercase ASCII hex characters;
   then `LF`.
3. Compute SHA-256 over that entire byte stream and record its 64-character
   lowercase hexadecimal representation.

Decimal lengths have no leading zeroes except the single digit `0`. There is
no entry-count field. An empty tree hashes the initial header bytes alone.
`entries[].path_base64` is standard canonical base64 of the raw path bytes;
the digest input uses the decoded bytes. JSON whitespace and property order
are not part of the digest. Paths must be unique relative Git paths without
NUL bytes, empty components or `.`/`..` components. Every entry includes
`path_base64`, `mode`, nonnegative `size` and lowercase `sha256`.

The fixed independent vector in
[`snapshot-v1.vector.json`](../fixtures/package-repository-provenance/snapshot-v1.vector.json)
uses a single `hello.txt` file, mode `100644`, containing `hello` followed by
LF. Its blob SHA-256 is
`5891b5b522d5df086d0ff0b110fbd9d21bb4fc7163af34d08286a2e846f6be03`;
the snapshot SHA-256 is
`2b83ba6df9942b489462748a1fb2fe76dc81f4a6c13c8a2f25917233a45775e7`.
The empty-tree digest is
`01518c05d7c12fae3a119160900118fd814ad572d16547a7d3f2f251fc21ebe6`.

Filesystem location, acquisition time, file modification time, archive
container metadata, the `.git` directory and untracked or uncommitted files
are outside this content digest. Commit metadata is identified separately by
the full commit ID. Two commits with the same covered tree content can
therefore have different commit IDs and the same snapshot digest.

Git submodule entries and Git LFS pointer snapshots remain unresolved and
must not receive a complete source-snapshot digest under this method. A
future method may explicitly materialize and bind such content. This method
does not silently fetch it, hash only the pointer and claim the referenced
source was covered, or expand the supported snapshot scope.

The executable implementation and tests are
[`package_repository_provenance.rb`](../tools/package_repository_provenance.rb)
and
[`test_package_repository_provenance.rb`](../tools/test_package_repository_provenance.rb).
The exact serialization is part of the method contract; a change to its
bytes or covered content requires a new method identifier rather than silently
changing existing digest meaning.

Run the helper with a supplied record and local repository to compute a new
snapshot record. It reads only the explicit commit ID in `revision_binding`;
it does not fetch missing objects. Without a local repository it preserves the
declaration and leaves the snapshot unresolved. The `--check` mode checks
record shape, joins and manifest self-consistency only; it does not compare
the manifest against local Git objects or authenticate the evidence payload.
Neither mode records a complete traversal or an accepted build attestation.

```sh
ruby tools/package_repository_provenance.rb --input supplied-record.json --repo /path/to/local/repository --output new-record.json
ruby tools/package_repository_provenance.rb --input new-record.json --check
ruby tools/test_package_repository_provenance.rb
```

Builder input uses this record contract but may omit `snapshot`; any supplied
snapshot is replaced by the newly computed or explicitly unresolved result.
An existing output file is never overwritten. Unknown revisions, missing local
objects and unsupported content produce a valid unresolved record and exit 0;
malformed requests/records exit 2. Consumers must inspect `snapshot.status`;
process success is not a hash, provenance or traversal acceptance result.

The schema checks shape; the helper also checks identity joins, actual calendar
validity, exact hash/commit formatting, unique sorted paths and manifest digest
consistency. `acquired_at` requires a known explicit offset; an offsetless value,
unknown-offset `-00:00` or invalid date does not become a known acquisition time.

## Unresolved and invalid records

A missing revision preserves the declared repository association with an
unresolved source-snapshot binding. A known revision with unavailable local
repository objects also remains unresolved. Neither state means that the
package/repository declaration is false, nor that snapshot verification
passed. Unsupported snapshot content remains unresolved until a supported
method and evidence are supplied.

Malformed contract versions, malformed object IDs or hashes and inconsistent
identity bindings are invalid input to the checker. A mismatched package
version or repository does not become a qualifying relationship. A local
digest mismatch is a failed integrity check against the supplied record, not
a finding of maliciousness or a rejected assessment. These outcomes must be
distinguished from explicit suppression by a separate pattern or case policy.

## Time and availability

Original repository creation, mirror/import creation, package identity
creation and package-version publication are different occurrences. None is
an implicit source for another. Removing the two creation-order strings
avoids making those undocumented substitutions; it does not establish new
bindings for other patterns' temporal operands.

For any time used downstream, a mapping must identify the bound occurrence,
originating document field and revision, source clock, timezone and precision.
Unknown, conflicting or incomparable values remain unresolved. Do not derive
a publication timestamp from a commit's author or committer timestamp.

Acquisition time records when this collection obtained the evidence. It does
not prove when the registry first published it, when another collector
observed it or when an analyst knew it. A record acquired after publication
does not establish that the repository or revision binding was knowable at
publication time. Event-time relationships and knowledge-at-time filtering
need separately stated evidence and bindings.

### Observation-window execution

The authoring-1.6 traversal applies the retained 3,650-day window to evidence-
backed observations of the actual infrastructure relationship. For SUPPLY this
is repository-to-infrastructure; for CROSS it is exact package-version-to-
infrastructure. An unrelated use of the same domain or IP does not date either
relationship. Package identity, version publication and repository, mirror or
import creation are not operands of this lookback.

The [portable traversal profile](../fixtures/semantic-families/package-repository/README.md)
defines `times.observed`, actual source-scoped occurrence identity, linked source
field/revision, clock, timezone, precision and uncertainty. Required declaration,
registry document and second-hop records retain their own explicit bindings.
For example, a query dated `2026-09-14` can consider a relationship observation
on `2026-08-01` even if the repository was created in 2010. The date alone does
not supply missing declaration or infrastructure evidence.

The independent provenance sidecar remains version 1.0 and contains no general
query grammar. Its helper does not execute this window, occurrence validation,
controls or a historical knowledge filter. The separate semantic contract
executes those declared traversal predicates over normalized source evidence;
it does not fetch a registry, authenticate a publisher or accept a native
adapter. The bounded one-hop Neo4j pilot supplies no runtime interpretation for
this pair.

### Accepted retrospective discovery and knowledge filtering

Retrospective discovery permits later-acquired evidence to support observations
within the requested occurrence window. The query date anchors that window; it
does not assert that the evidence was available on that date. An observation on
`2026-08-01` may qualify in a retrospective query anchored to `2026-09-14` even
when the collection first acquires its evidence on `2026-09-20`. This does not
move the observation or prove earlier analyst knowledge.

An explicit `knowledge_cutoff` additionally requires each required record's
`times.collection_available`, bound to the actual availability occurrence in the
named collection. Missing availability leaves that historical inquiry unresolved
while retaining the evidence for retrospective discovery. Publication,
collection availability and an individual's awareness are not interchangeable.
A completed observation cannot be available before it occurred. The sidecar's
acquisition timestamp alone does not supply these separate traversal witnesses.

### Accepted distinct observations and replay

A new observation date requires a distinct evidenced occurrence of the same
bound relationship. Preserve the linked origin source, occurrence namespace,
collector, occurrence key, actual relation and endpoint. The relationship
includes the exact repository or package version; an unrelated use of the same
endpoint cannot refresh it. Earlier occurrences remain separately preserved.

Publication, copying, syndication, replay, ingestion, changed row IDs or a new
source revision do not by themselves create a new observation. A `2015-08-01`
observation reimported on `2026-09-13` stays dated 2015. A distinct source-backed
observation on September 13 may have its own date, without establishing another
independent origin or continuous relationship validity.

The traversal examines supplied reports in the source-qualified occurrence scope
within the query budget. Conflicting endpoints or normalized time bounds remain
unresolved, including conflicts wholly inside the window. A newer revision or
receipt does not automatically override the older assertion. Explicit correction
resolution and global cross-source equivalence are outside this profile.

### Accepted inclusive calendar-date boundaries

The observation window is `[query_date - window_days, query_date]`, inclusive.
For `window_days: 3650` and query date `2026-09-14`, it includes `2016-09-16`
through `2026-09-14`: 3,651 calendar dates. It is not an exact ten-year duration
or an elapsed-time interval from an unstated query instant.

An unambiguous boundary-date observation is inside; `2016-09-15` and
`2026-09-15` are outside. Uncertain boundary placement is unresolved. An invalid
date is malformed input. Outside-period evidence gives no qualifying occurrence
under this predicate, not explicit suppression or proof that the relationship
is false. Passing the date predicate does not establish the complete pivot.

### Accepted UTC comparison and preserved precision

Compare in UTC while preserving the original representation, known offset or
evidenced timezone, source field/revision, clock and precision. Conversion does
not prove clock synchronization. For query date `2026-09-14`,
`2026-09-15T00:30:00+02:00` becomes `2026-09-14T22:30:00Z`, inside the last date;
`2026-09-14T23:30:00-02:00` becomes `2026-09-15T01:30:00Z`, outside it.

Date-only values retain their possible intervals, not invented midnight events.
The local date `2016-09-16` at `+02:00` spans possible UTC times from
`2016-09-15T22:00:00Z` up to but excluding `2016-09-16T22:00:00Z`. It crosses
the lower boundary, so dated eligibility is unresolved. An interval wholly
inside or outside has a determinate age result; crossing a boundary does not.
These are possible-time bounds, not evidence of continuous validity.

Missing timezone or unknown-offset `-00:00` is not assumed UTC or the machine's
local timezone. Conflicting source timestamps cannot be resolved by selecting
whichever conversion qualifies. The portable semantic time envelope supplies
the executable representation; backend source mappings must establish their own
field meanings. The sidecar helper remains separate from this time evaluator.

## Synthetic examples

These are constructed cases, not retrieved registry evidence or records of
analyst acceptance. Dates describe separate occurrences without binding an
adapter clock or implying precise knowledge time.

| Constructed case | Expected declaration/snapshot outcome | Still not established |
| --- | --- | --- |
| Repository R created 2019-03-01; package 1.4.0 published 2026-08-10; that version's preserved metadata declares R. | Preserve the association even though the repository predates publication. Without revision evidence, snapshot binding is unresolved. | Build origin and either infrastructure hop. |
| The same metadata links 1.4.0 to an explicit full commit; supported local objects yield the recorded snapshot digest. | Preserve the declaration, exact commit identity, snapshot digest and linking evidence. | Verification of the registry claim or that the published package was built from those bytes. |
| A mirror M is created 2026-08-12; a preserved 2026-08-13 metadata revision for 1.4.0 declares M. | Preserve the later declaration of M separately from any earlier declaration of R. | Publication from M on 2026-08-10 or knowledge of M at that time. |
| Repository R migrates to N with imported history and shared commit content. | Keep both repository identities and their declarations; preserve explicit migration evidence separately. | Interchangeable repository identity or ownership. |
| R's current commit differs from the revision linked to package 1.4.0. | Use only the explicitly bound revision; unresolved if unavailable. | Historical source provenance from current `HEAD`. |
| A linked revision contains a submodule or LFS pointer. | Preserve the declaration and revision evidence; snapshot digest remains unresolved under this method. | Complete materialized source coverage. |
| Infrastructure is observed 2026-08-01 or 2026-08-11 for the 2026-08-10 publication. | The dates alone neither create nor invalidate the declared repository association. | The second-hop relationship, applicable window or publication-time knowledge. |
| Creation timestamps are missing, conflicting, equal or incomparable. | No universal entity-birth ordering rejects the declaration; keep timestamp uncertainty explicit. | A temporal-window pass or resolved event/knowledge chronology. |

## Migration and consumer limits

Do not convert former package-pair `published_from` or `publishes` edges by
renaming them alone. Recheck the supporting registry record and version/node
joins against this contract. Legacy records with insufficient declaration
evidence need recollection or remain outside this qualified relationship.
Consumers following the repository pattern must also change the first-hop
direction to inward for the package-to-repository stored edge.

The sidecar is optional to existing v1.5 consumers, which must not claim to
support its checks without explicit handling. Consumers using this contract
must preserve its declaration qualification, source/revision metadata and
unresolved states. The pattern YAML does not embed the sidecar into permissive
objects; the JSON schema and helper provide its explicit implementation surface.

The local sidecar checker and its synthetic fixtures cover bounded provenance
validation, not a complete traversal or native backend acceptance. The separate
authoring-1.6 traversal and its independent fixtures cover the declared
observation window, occurrence validation, result binding, selected repository
policy and historical knowledge filter. Its work budgets are explicit; it does
not inherit a general degree-cap or `outputs.top_paths` algorithm. Neither
capability evaluates source independence or accepts an assessment.
`evidence_only` remains in force for both patterns; SAIL contracts remain
separate.
