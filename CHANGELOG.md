# Changelog

All notable changes to EveryPivot&trade; are documented here.

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
