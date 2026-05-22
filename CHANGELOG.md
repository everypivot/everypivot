# Changelog

All notable changes to EveryPivot&trade; are documented here.

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
