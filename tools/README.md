# Tools

Lightweight registry tooling for the public EveryPivot&trade; repo shape.

> Licensed under [Apache-2.0](../LICENSE-CODE). &copy; 2026 EveryPivot Project.
> See [`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE), and
> [`TRADEMARK.md`](../TRADEMARK.md).

Current tools:
- `validate_pivots.rb` validates the `graph-pivots/` corpus against the published schema plus lane-policy rules
- `check_fixture_suite.rb` runs the fixture manifest under `fixtures/` and validates traversal evidence examples
- `check_query_profile_suite.rb` validates adapter/query profile sidecars, fixture graphs, and generated query freshness
- `check_release_metadata.rb` verifies that README, release notes, builder defaults, committed artifacts, and site data agree on the current release
- `check_generated_freshness.rb` rebuilds registry and site data into a temporary directory and compares the committed public outputs
- `check_relation_catalog.rb` warns when pattern relation/form vocabulary is not yet listed in `docs/RELATION_CATALOG.md`
- `check_site_links.rb` audits local `site/` links against the staged GitHub Pages publish root
- `check_site_snapshot.rb` verifies that homepage pre-rendered counts agree with the registry data
- `smoke_neo4j_query_profiles.rb` optionally runs query-profile fixtures and generated Cypher against a local Neo4j database via `cypher-shell`
- `generate_stix_mapping_profile_demo.rb` renders declared OpenCTI/STIX mapping profile demo bundles
- `build_registry_index.rb` generates release-style registry bundles, manifests, and browser sidecars under `artifacts/`
- `build_release_pack.rb` assembles a portable release pack with copied corpus assets, generated artifacts, and a provenance manifest
- `generate_query_profile_demo.rb` renders declared Neo4j/Cypher query profile demo targets

Recommended usage:

```bash
ruby tools/check_fixture_suite.rb
ruby tools/check_query_profile_suite.rb
ruby tools/check_relation_catalog.rb
ruby tools/check_relation_catalog.rb /path/to/graph-pivots
ruby tools/smoke_neo4j_query_profiles.rb -- --address bolt://localhost:7687
ruby tools/smoke_neo4j_query_profiles.rb --reset-fixtures -- --address bolt://localhost:7687
ruby tools/generate_stix_mapping_profile_demo.rb --profile adapters/query-profiles/opencti_stix_v0.yml --pattern-id CTI_SAMPLE_IMPHASH_CLUSTER --output adapters/opencti/generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json
ruby tools/check_release_metadata.rb
ruby tools/check_generated_freshness.rb
ruby tools/check_site_links.rb
ruby tools/check_site_snapshot.rb
ruby tools/build_release_pack.rb --release v0.4.0 --published-at 2026-05-27 --artifact-mode stable --authority-status canonical --force
ruby tools/build_release_pack.rb --skip-fixtures --output-dir /tmp/everypivot-release-pack --force
```

Default behavior:
- `build_release_pack.rb` validates the copied corpus and runs the copied fixture suite before emitting artifacts
- stable `build_release_pack.rb` output includes `site/`, regenerates `site/data/`, and reruns release metadata, generated-freshness, site-link, and homepage-snapshot checks inside the copied pack
- use `--skip-fixtures` only when you explicitly need a pack despite a known fixture issue
