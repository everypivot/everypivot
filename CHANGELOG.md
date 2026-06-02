# Changelog

All notable changes to EveryPivot&trade; are documented here.

## Unreleased

No changes yet.

## v0.4.2 - 2026-06-02

See [release notes](docs/releases/v0.4.2.md).

### Added

- `tools/check_reachable_history.rb`: ref-scoped scanner that iterates
  every commit reachable from a given ref and reports findings against
  a configurable pattern list (default patterns cover AWS access keys,
  GitHub personal access tokens, OpenAI and Anthropic API keys, Slack
  tokens, and PEM/PGP private-key headers). Ships with test suite and
  allow-list.
- `--probe-live BASE_URL` extension to `tools/check_release_metadata.rb`
  that asserts the manifest's declared site paths resolve on the live
  deploy.
- `docs/RELEASE_PLAYBOOK.md` documenting the four release stages and
  the per-stage checklist.
- Release-commit-message convention in `docs/PROMOTION_CHECKLIST.md`.
- REUSE lint CI gate (`pipx install reuse; reuse lint`) plus the
  reachable-history scan as a CI gate in `validate.yml`. The validate
  workflow now checks out with `fetch-depth: 0`.

### Changed

- `tools/build_release_pack.rb` `authority_note` is simplified to two
  canonical values; the longer environment-conditioned strings used by
  non-canonical release modes have been removed from the public copy
  of the tool. The MANIFEST.json `provenance.note` string in any newly-
  built stable release pack now reads "Authoritative public registry
  pack."
- `tools/check_release_metadata.rb`, `tools/check_site_links.rb`, and
  `tools/check_site_snapshot.rb` were simplified: single mode, no
  dual-mode toggle. Previously-relaxed assertions are now applied
  unconditionally.
- `tools/test_build_release_pack.rb` was trimmed to cover only
  canonical-stable behaviour.
- Minor doc sanitization in `docs/releases/v0.3.0.md` and
  `docs/SCHEMA_V1_5_PROPOSAL.md`.

### Notes

- Corpus count remains 176. Lane counts unchanged at 21 / 76 / 79.
- No `pivot-pattern` schema-version change.
- No new public real-case material.
- The new CI gates are additive: they fail the build only on new drift
  introduced after this release.

## v0.4.1 - 2026-06-01

See [release notes](docs/releases/v0.4.1.md).

### Added

- Added public CTI promotion-boundary doctrine for keeping assessment,
  attribution, confidence, operational effect, and private review state out of
  graph relations.
- Added a promotion-blocking CTI lint gate and regression tests for
  public-safe CTI pattern and fixture checks.
- Added synthetic traversal evidence packs for the SBOM dependency and
  cloud-tenant-to-auth-event CTI pilots.

### Changed

- Promoted the SBOM dependency and cloud-tenant-to-auth-event CTI pilots from
  `deferred` to `validated` after synthetic fixture coverage, blocked
  assertions, relation-catalog review, CTI lint, and independent sign-off.
- Trimmed the cloud/SaaS pilot to the accepted single-hop
  `contains_auth_event` relationship; the `associated_session` expansion
  remains deferred pending separate review.

### Notes

- Corpus count remains 176.
- Validated lane increases to 21 patterns; deferred lane decreases to 79.
- No schema-version change.
- No real indicators, commands, exploit details, victim/customer context,
  raw telemetry, or live/current external telemetry claims are introduced.

## v0.4.0 - 2026-05-27

See [release notes](docs/releases/v0.4.0.md).

### Added

- Added bounded EP-WP15 OpenCTI/STIX-side mapping coverage with an
  `opencti_stix_v0` profile, synthetic import-hash fixture slice, generated
  STIX 2.1 bundle, and profile-suite checks that prevent suppressed traversal
  candidates from becoming ordinary STIX relationship objects.
- Documented the incubator `stix2-validator` path for generated STIX bundles
  and hardened the first OpenCTI/STIX bundle with spec-conformant UUIDv5
  file-SCO IDs, a checked top-level `x_everypivot_*` extension definition, and
  a schema document for those mapping properties.
- Added public release-pack coverage for OpenCTI/STIX profile assets,
  generated bundles, mapping fixtures, and schema files.
- Added repository publishing/versioning guidance for public source,
  tagged-release ordering, and stable-release ordering.

### Changed

- Advanced the public promotion-cadence metadata through rounds 3 and 4 while
  preserving current corpus counts.
- Added deferred-lane hazard consistency metadata and reconciled deferred
  reason vocabulary across public patterns.
- Clarified `deferred_reason: insufficient_hazards` schema guidance so repaired
  deferred patterns move to their current live blocker.
- Strengthened validation CI with the relation-catalog check and clarified the
  DCO checkbox/workflow regex sync point.
- Expanded local-clutter ignores for maintainer-only working files.

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
