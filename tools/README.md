# Tools

Lightweight registry tooling for the public EveryPivot&trade; repo shape.

> Licensed under [Apache-2.0](../LICENSE-CODE). &copy; 2026 EveryPivot Project.
> See [`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE), and
> [`TRADEMARK.md`](../TRADEMARK.md).

Current tools:
- `validate_pivots.rb` validates the `graph-pivots/` corpus against the published schema plus lane-policy rules
- `check_fixture_suite.rb` runs the fixture manifest under `fixtures/` and validates traversal evidence examples
- `check_release_metadata.rb` verifies that README, release notes, builder defaults, committed artifacts, and site data agree on the current release
- `check_generated_freshness.rb` rebuilds registry and site data into a temporary directory and compares the committed public outputs
- `check_site_links.rb` audits local `site/` links against the staged GitHub Pages publish root
- `check_site_snapshot.rb` verifies that homepage pre-rendered counts agree with the registry data
- `build_registry_index.rb` generates release-style registry bundles, manifests, and browser sidecars under `artifacts/`
- `build_release_pack.rb` assembles a portable release pack with copied corpus assets, generated artifacts, and a provenance manifest

Recommended usage:

```bash
ruby tools/check_fixture_suite.rb
ruby tools/check_release_metadata.rb
ruby tools/check_generated_freshness.rb
ruby tools/check_site_links.rb
ruby tools/check_site_snapshot.rb
ruby tools/build_release_pack.rb --release v0.2.0 --published-at 2026-05-24 --artifact-mode stable --authority-status canonical --force
ruby tools/build_release_pack.rb --skip-fixtures --output-dir /tmp/everypivot-release-pack --force
```

Default behavior:
- `build_release_pack.rb` validates the copied corpus and runs the copied fixture suite before emitting artifacts
- use `--skip-fixtures` only when you explicitly need a pack despite a known fixture issue
