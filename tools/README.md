# Tools

Lightweight registry tooling for the public EveryPivot&trade; repo shape.

> Licensed under [Apache-2.0](../LICENSE-CODE). &copy; 2026 EveryPivot Project.
> See [`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE), and
> [`TRADEMARK.md`](../TRADEMARK.md).

Current tools:
- `validate_pivots.rb` validates the `graph-pivots/` corpus against the published schema plus lane-policy rules
- `check_fixture_suite.rb` runs the fixture manifest under `fixtures/`
- `build_registry_index.rb` generates release-style registry bundles, manifests, and browser sidecars under `artifacts/`
- `build_release_pack.rb` assembles a portable release pack with copied corpus assets, generated artifacts, and a provenance manifest

Recommended usage:

```bash
ruby tools/check_fixture_suite.rb
ruby tools/build_release_pack.rb --release v0.1.0 --published-at 2026-05-21 --artifact-mode stable --authority-status canonical --force
ruby tools/build_release_pack.rb --skip-fixtures --output-dir /tmp/everypivot-release-pack --force
```

Default behavior:
- `build_release_pack.rb` validates the copied corpus and runs the copied fixture suite before emitting artifacts
- use `--skip-fixtures` only when you explicitly need a pack despite a known fixture issue
