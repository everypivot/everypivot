# EveryPivot&trade;

EveryPivot&trade; is a public registry of portable graph-pivot patterns for CTI,
fraud, abuse, infrastructure, and supply-chain analysis.

The repository publishes:

- a curated `validated` lane;
- visible `working-set` and `deferred` lanes with caveats;
- a machine-readable `pivot-pattern` schema;
- validator and registry-build tooling;
- generated release artifacts for static sites and downstream consumers.

## Current Release

- Release: `v0.1.1`
- Corpus: 176 patterns
- Lanes: 19 `validated`, 76 `working_set`, 81 `deferred`
- Schema target: `pivot-pattern` v1.4

## Repository Layout

```text
graph-pivots/
  validated/
  working-set/
  deferred/
schemas/
fixtures/
tools/
artifacts/
site/
docs/
```

## Lifecycle Lanes

- `validated`: curated public patterns that are mature enough to feature.
- `working-set`: live candidates under active review.
- `deferred`: useful patterns held back because evidence, fixtures, controls,
  access, or editorial maturity is not yet sufficient.

Validated does not mean a runtime match is an attribution, final assessment, or
confidence score. EveryPivot defines portable pivot relationships. Downstream
systems own execution, corroboration, scoring, and case-specific judgment.

## Validate The Corpus

```bash
ruby tools/validate_pivots.rb --strict-metadata
ruby tools/check_fixture_suite.rb
```

## Build Registry Artifacts

```bash
ruby tools/build_registry_index.rb \
  --repo-root . \
  --release v0.1.1 \
  --published-at 2026-05-22 \
  --output artifacts/registry-index.json \
  --site-data-root site/data
```

This writes:

- `artifacts/registry-index.json`
- `artifacts/release-manifest.json`
- `artifacts/patterns.tar.gz`
- `artifacts/fixtures.tar.gz`
- browser-friendly site data under `site/data/`

## Website

The public registry is deployed at <https://everypivot.io/>.

The lightweight launch UI that powers the site lives under `site/`. It is
static HTML/JS and reads generated registry data. Pattern YAML links point to
the GitHub tag named by the generated registry release metadata.

For local preview:

```bash
python3 -m http.server 4173
```

Then open `http://localhost:4173/site/index.html`.

## Documentation

- [Contributing and promotion](docs/CONTRIBUTING_AND_PROMOTION.md)
- [License FAQ](LICENSE-FAQ.md)
- [Governance](GOVERNANCE.md)
- [Validation semantics](VALIDATION_SEMANTICS.md)
- [Promotion checklist](docs/PROMOTION_CHECKLIST.md)
- [Registry index contract](docs/REGISTRY_INDEX_SPEC.md)

## License And Attribution

EveryPivot uses a dual-license model:

- code, schema, tooling, docs, and site assets: Apache-2.0;
- pattern corpus and fixtures: CC BY 4.0.

Commercial, SaaS, product, internal, and proprietary downstream uses are
allowed under those terms. See [LICENSE-FAQ](LICENSE-FAQ.md),
[LICENSE](LICENSE), [LICENSE-CODE](LICENSE-CODE), [LICENSE-DATA](LICENSE-DATA),
[NOTICE](NOTICE), and
[TRADEMARK.md](TRADEMARK.md).

EveryPivot&trade; is an unregistered trademark associated with the EveryPivot
Project. The open licenses do not grant the right to use the EveryPivot name
for forks, mirrors, or competing products.
