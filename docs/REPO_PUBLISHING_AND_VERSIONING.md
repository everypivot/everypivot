# Repository Publishing And Versioning

## Thesis

`everypivot.io` should be published directly from the public GitHub repository.

That repo should be the canonical source of truth for:
- graph-pivot YAML files
- schemas
- fixtures
- validator tooling
- lifecycle and promotion docs

This is what makes the project genuinely community-shaped rather than merely publicly viewable.

## Why GitHub Should Be Canonical

- it invites pull requests for new patterns, fixes, hazards, and fixtures
- it keeps the portable artifacts where contributors expect them
- it makes release provenance inspectable
- it lets the community validate, fork, and reuse the corpus
- it keeps the website honest because it is generated from the same assets everyone can inspect

## Recommended Publication Model

Do not render `everypivot.io` by live-fetching raw files from GitHub on every request.

Recommended flow:
1. GitHub repository is the canonical authoring surface.
2. CI runs validation on commits, pull requests, and tags.
3. CI builds:
   - the website
   - a machine-readable registry bundle
   - release artifacts
4. `everypivot.io` serves the built output.
5. `mcp.everypivot.io` reads the same packaged registry bundle.

This keeps the source open while making the site and MCP surfaces fast, stable, and reproducible.

## Contribution Model

The public repo should welcome community contribution through:
- new pattern PRs
- hazard and caveat improvements
- fixture additions
- validator improvements
- relation catalog additions
- documentation and promotion-policy changes

Recommended governance stance:
- clear contribution guide
- explicit promotion policy
- visible lifecycle states
- maintainers curate promotion, not authors alone

## Branches vs Releases

Branches should exist for maintainers and contributors.

Branches should not be the main public navigation concept.

Public users care about:
- latest stable
- specific tagged releases
- optionally an `edge` or `current` view

They do not need a branch browser as part of the main product experience.

## Recommended Versioning Model

### Git

- `main`
  - active integration branch
- tags such as `v0.1.0`, `v0.2.0`
  - stable released snapshots
- optional preview deployments from pull requests

When two stable releases share the same `published_at` date, semantic version
order is authoritative for release ordering. Do not infer ordering from the
date alone.

### Website

Recommended URL model:
- `/`
  - latest stable homepage
- `/patterns`
  - latest stable pattern browser
- `/patterns/{id}`
  - latest stable pattern detail
- `/releases/v0.1.0/`
  - pinned release homepage
- `/releases/v0.1.0/patterns/{id}`
  - pinned release pattern detail
- `/edge/`
  - optional current snapshot from `main`

### Downloads / API Bundles

Recommended published artifacts:
- `registry-index.json`
- `patterns.tar.gz`
- schema bundle
- fixture bundle
- validator release artifact

Each stable release should publish pinned downloadable assets alongside the human-facing site.

## Recommended UX Defaults

- default website view should be latest stable
- release selector should let users browse older tags
- `edge` should be clearly labeled as unreleased if exposed
- working-set and deferred lanes should remain visible, but clearly caveated

## CI/CD Expectations

On pull request:
- run validator
- build preview site
- build preview registry bundle

On merge to `main`:
- run validator
- refresh optional `edge` deployment

On tag:
- run validator
- publish release notes and release bundle
- update latest stable on `everypivot.io`
- update release metadata for `mcp.everypivot.io`

## Recommendation

Treat GitHub as the collaborative heart of the project, tagged releases as the public stability contract, and `everypivot.io` as the polished presentation layer generated from that same source.
