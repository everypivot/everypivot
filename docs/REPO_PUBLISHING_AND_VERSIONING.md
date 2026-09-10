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

The maintained website is the compact, standalone `site/index.html`. At the
public root `/`, it provides search, filters and expandable pattern details on
one page. Schema access uses `/data/pivot-pattern.schema.json`; downloadable
registry and corpus bundles use `/artifacts/`. Pattern-source links select the
GitHub tag recorded in the loaded registry.

There are no separate pattern-detail or schema-viewer pages, archived-release
routes, or release selector. The earlier larger application has been removed.
Historical releases remain available through tagged source and downloadable
release artifacts.

The preview manifest identifies `/site/index.html` when served from a checkout;
the local preview helper serves a temporary copy at its own `/index.html`.
An edge manifest may identify `/edge/`, but a separate hosting configuration is
required to expose that optional snapshot. A manifest route does not establish
that a deployment exists.

Richer routing or a release selector would require a separately approved future
design. Neither is part of the current UI or the schema v1.5 migration.

### Downloads / API Bundles

Recommended published artifacts:
- `registry-index.json`
- `patterns.tar.gz`
- schema bundle
- fixture bundle
- validator release artifact

Each stable release should publish pinned downloadable assets alongside the human-facing site.

## Current UX and Optional Channels

- The public website reads the generated release bundled with its deployment.
  Local release preparation does not publish that snapshot.
- Search, filters and expandable details share the compact index page.
- Validated and working-set lanes are initially selected; deferred patterns
  remain available through the lane filter, with their caveats.
- Historical versions are selected through GitHub tags and release downloads.
- Any optional edge or preview deployment must identify its unreleased channel.

## CI/CD Expectations

On pull request:
- run validator
- build preview site
- build preview registry bundle

On merge to `main`:
- run validator
- validate the compact browser's evidence/assessment rendering before Pages
  uploads or deploys the site
- deploy the packaged static site only after its Pages gates pass
- refresh an optional `edge` deployment only if separately configured

On tag:
- run validator
- publish release notes and release bundle
- update latest stable on `everypivot.io`
- update release metadata for `mcp.everypivot.io`

## Recommendation

Treat GitHub as the collaborative heart of the project, tagged releases as the public stability contract, and `everypivot.io` as the polished presentation layer generated from that same source.
