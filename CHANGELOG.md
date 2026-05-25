# Changelog

All notable changes to EveryPivot&trade; are documented here.

## Unreleased

No unreleased changes.

## v0.3.0 - 2026-05-25

See [release notes](docs/releases/v0.3.0.md).

### Added

- Added public schema-migration and v1.5 doctrine proposals for semantic
  families, typed facets, blocked-inference objects, companion/inverse
  relationships, and justified `parent_pattern` use.
- Started EP-WP15 with a public-safe Neo4j/Cypher query-profile pilot for the
  validated SSH host-key pattern.
- Added sidecar adapter metadata, a synthetic query-profile fixture graph, a
  generated demo query, and profile freshness/semantic-boundary checks.
- Added a second synthetic Neo4j/Cypher query-profile target for the
  working-set email-originating-IP pattern to exercise inbound one-hop
  traversal shape.
- Added an optional Neo4j/cypher-shell smoke helper for maintainers who want to
  execute synthetic query-profile fixtures locally.
- Added a third synthetic Neo4j/Cypher query-profile target for the validated
  import-hash pattern to behaviourally prove source-side full-block suppression.

### Changed

- Hardened relation-catalog review by checking default-corpus snapshot-count
  drift and adding warning-only deprecated-vocabulary sections.
- Tightened fixture-manifest coverage so fixture case directories cannot drift
  from `fixtures/validator_suite.yml`.
- Generalized query-profile checking and generation to discover declared
  profile targets instead of relying on hardcoded Neo4j pilot paths.
- Moved pilot shape constraints onto target records so future targets can state
  their supported traversal shape explicitly.
- Clarified that adapter metadata and generated adapter queries are Apache-2.0,
  while synthetic query-profile fixtures and loaders remain CC BY 4.0 fixture
  material.
- Hardened optional Neo4j smoke behaviour by rejecting passthrough `--file`
  arguments and adding an explicit disposable-database reset option.

### Notes

- No corpus expansion.
- No schema-version change.
- No public real-case corpus or validated promotion from case-bound sidecar
  work.

## v0.2.0 - 2026-05-24

See [release notes](docs/releases/v0.2.0.md).

### Added

- Traversal evidence-pack roles and two synthetic evidence examples covering
  positive, weak-positive, suppression, high-cardinality, and negative
  behavior.
- Fixture-suite validation for traversal evidence packs.
- Relation catalog guidance and current relation/form vocabulary inventory.
- Docs-only portability-class guidance for future review.

### Changed

- Updated promotion and contribution docs to require explicit fixture roles and
  blocked assertions when traversal evidence supports a pattern.
- Updated the first-use SSH host-key walkthrough to use the evidence-pack
  format.

### Notes

- No corpus expansion.
- No schema-version change.
- No relation warning lints, sidecars, schema-facing relation fields, or
  committed portability-class records.

## v0.1.2 - 2026-05-24

See [release notes](docs/releases/v0.1.2.md).

### Changed

- Updated the custom GitHub Pages workflow to Node.js 24-compatible official
  action majors.
- Added generated-data freshness, static site link-audit, and homepage
  release-snapshot agreement checks.
- Corrected the committed fixture bundle so it includes the current walkthrough
  fixture example.
- Excluded hidden filesystem metadata from generated corpus and fixture
  bundles.
- Pinned the GitHub release action to an immutable commit.

### Added

- GitHub issue forms for bug/site/tooling reports, new pattern proposals,
  validated-pattern challenges, and schema/docs/governance requests.
- Security-routing guidance for sensitive issue material.

### Notes

- No corpus expansion.
- No schema-version change.
- `v0.1.1` remains immutable; corrected fixture-bundle bytes are published as
  part of `v0.1.2`.

## v0.1.1 - 2026-05-22

See [release notes](docs/releases/v0.1.1.md).

### Changed

- Changed the pattern corpus and fixtures license from CC BY-SA 4.0 to
  CC BY 4.0.
- Clarified commercial, SaaS, product, internal, and proprietary downstream use
  in the license FAQ and public docs.
- Updated license metadata in schema, registry index, release manifest, site
  data, release-pack tooling, and generated release artifacts.
- Repeated the boundary that `validated` is an editorial lifecycle state, not
  attribution, maliciousness, runtime confidence, or final assessment.

### Added

- `LICENSE-FAQ.md`.
- `GOVERNANCE.md`.
- `VALIDATION_SEMANTICS.md`.
- Hybrid DCO workflow, pull request template checks, and relevance-based
  vendor/conflict disclosure guidance.
- `.reuse/dep5` license metadata.

### Notes

- No corpus expansion.
- No schema-version change.
- No alternative commercial license or exception process.

## v0.1.0 - 2026-05-21

### Added

- Initial public graph-pivot corpus: 176 patterns.
- Curated lifecycle lanes: 19 `validated`, 76 `working_set`, 81 `deferred`.
- `pivot-pattern` v1.4 schema.
- Ruby validator, fixture suite, registry-index builder, and release-pack
  builder.
- Generated release artifacts under `artifacts/`.
- Lightweight static pattern-library UI under `site/`.
- Public contribution, promotion, security, licensing, and trademark
  documentation.

### Notes

- The first public release intentionally ships the static registry without
  execution layers.
- Runtime confidence, scoring, final assessment, and attribution remain
  downstream of the pattern definitions.
