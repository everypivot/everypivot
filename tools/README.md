# Tools

Lightweight registry tooling for the public EveryPivot&trade; repo shape.

> Licensed under [Apache-2.0](../LICENSE-CODE). &copy; 2026 EveryPivot Project.
> See [`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE), and
> [`TRADEMARK.md`](../TRADEMARK.md).

Current tools:
- `validate_pivots.rb` validates schema, lane policy and the pinned SAIL contract; `--strict-bridge` rejects incomplete compatibility
- `check_sail_bridge.rb` reports evidence-only, compatible candidate, incomplete and incompatible results; `--json --strict-incomplete` diagnoses complete semantic mappings; add `--current-distribution` to require current distribution eligibility
- `test_sail_bridge.rb`, `test_registry_assessment.rb` and `test_distribution_eligibility.rb` exercise contract, migration and export boundaries
- `utf8_text.rb` validates and decodes declared text as UTF-8 at read boundaries; `test_utf8_text.rb` tests locale independence and malformed input
- `test_site_assessment.js` checks the shared standalone browser assessment boundary
- `package_repository_provenance.rb` evaluates package/repository declaration records against an explicitly pinned local Git commit; `--check` validates supplied record shape and self-consistency only
- `test_package_repository_provenance.rb` exercises the separate package/repository provenance contract with synthetic Git repositories and sidecars
- `check_fixture_suite.rb` runs the fixture manifest under `fixtures/` and validates traversal evidence examples
- `check_query_profile_suite.rb` validates adapter/query profile sidecars, fixture graphs, and generated query freshness
- `check_cti_promotion_lint.rb` blocks CTI promotion artifacts that encode assessment/review vocabulary, uncataloged tuples, or unsafe fixture content
- `check_release_metadata.rb` verifies that README, release notes, builder defaults, committed artifacts, and site data agree on the current release
- `check_generated_freshness.rb` regenerates and compares stable distribution artifacts; `--preview` checks preview artifacts separately
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
ruby tools/validate_pivots.rb --strict-metadata --strict-bridge
ruby tools/check_sail_bridge.rb --json --strict-incomplete
ruby tools/check_sail_bridge.rb --json --strict-incomplete --current-distribution
ruby tools/test_sail_bridge.rb
ruby tools/test_registry_assessment.rb
ruby tools/test_distribution_eligibility.rb
ruby tools/test_utf8_text.rb
ruby tools/test_build_release_pack.rb
ruby tools/test_validation_boundaries.rb
ruby tools/test_package_repository_provenance.rb
node tools/test_site_assessment.js
ruby tools/check_fixture_suite.rb
ruby tools/check_query_profile_suite.rb
ruby tools/check_cti_promotion_lint.rb
ruby tools/test_cti_promotion_lint.rb
ruby tools/check_relation_catalog.rb
ruby tools/check_relation_catalog.rb /path/to/graph-pivots
ruby tools/smoke_neo4j_query_profiles.rb -- --address bolt://localhost:7687
ruby tools/smoke_neo4j_query_profiles.rb --reset-fixtures -- --address bolt://localhost:7687
ruby tools/generate_stix_mapping_profile_demo.rb --profile adapters/query-profiles/opencti_stix_v0.yml --pattern-id CTI_SAMPLE_IMPHASH_CLUSTER --output adapters/opencti/generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json
ruby tools/check_release_metadata.rb
ruby tools/check_generated_freshness.rb
ruby tools/check_site_links.rb
ruby tools/check_site_snapshot.rb
ruby tools/build_release_pack.rb --release v0.6.0 --published-at 2026-10-02 --artifact-mode stable --authority-status canonical --force
ruby tools/build_release_pack.rb --skip-fixtures --output-dir /tmp/everypivot-release-pack --force
```

Gate split:
- `validate_pivots.rb` enforces schema, lane policy and assessment-contract compatibility; it does not validate case evidence or accept conclusions
- `--current-distribution` on either validation CLI is the blocking distribution gate: schema v1.5 or v1.6, explicit mode and all applicable fields; supported legacy parsing remains available for diagnosis
- `package_repository_provenance.rb` has a separate `everypivot.package_repository_provenance` v1.0 sidecar contract; it does not extend authoring schema v1.5 or execute a native adapter
- `check_cti_promotion_lint.rb` is the promotion-blocking CTI safety gate for public CTI pattern and fixture material
- `check_relation_catalog.rb` remains the warning-only relation/form inventory check used by reviewers and tooling

Default behavior:
- `build_release_pack.rb` checks current distribution eligibility in a temporary copied pack and runs the copied CTI lint, fixture suite, query-profile suite, validation-boundary tests and package/repository provenance tests before emitting artifacts
- the pack manifest records the `package_repository_provenance` quality gate and includes the helper, tests, schema and synthetic sidecars in its hashed source inventory; this gate still runs with `--skip-fixtures`
- stable `build_release_pack.rb` output includes `site/`, regenerates `site/data/`, and reruns release metadata, generated-freshness, site-link, and homepage-snapshot checks inside the copied pack
- `--force` replaces an existing release pack only after all selected checks and generation pass; refused builds preserve the previous pack and remove staging files
- use `--skip-fixtures` only when you explicitly need a pack despite a known fixture issue

`test_site_assessment.js` requires Node and the standalone `site/index.html`. Run
it from the source checkout or a stable release pack; preview packs omit the
site and cannot run that browser test.

## Package/repository provenance

```sh
ruby tools/package_repository_provenance.rb --input RECORD.json --repo /path/to/local/repository --output result.json
ruby tools/package_repository_provenance.rb --check --input RECORD.json
```

Evaluation requires an explicit exact commit and Git object algorithm, or the
source binding remains unresolved. The helper hashes the pinned committed tree,
not the current checkout, `HEAD`, or uncommitted files. Git links and LFS content
remain unresolved until supported. The separate `--check` mode checks only the
supplied record's shape and self-consistency; it does not verify external
provenance or establish that registry declarations are true.

A qualified result is registry-declared source evidence only. Its
`build_provenance` remains `not_verified`: it does not establish which source
produced a released package, ownership, an accepted assessment, or native adapter
acceptance. See the [schema](../schemas/package_repository_provenance.v1.schema.json)
and [synthetic sidecars](../fixtures/package-repository-provenance/).

## Text and binary input boundaries

Declared JSON, YAML, Markdown, HTML and embedded JavaScript inputs are UTF-8,
independent of the caller's locale. The shared reader checks encoding before
parsing or matching text. Invalid or truncated UTF-8 produces a file-specific
encoding error; JSON/YAML syntax errors remain separate parser diagnostics.
UTF-8 BOMs are rejected consistently, including in pinned contracts; no BOM is
stripped. Text is not transcoded, normalized or repaired.

Archives, raw Git/source bytes, pinned-contract digests and freshness comparisons
retain byte semantics. Pinned files are hashed as read, and their JSON is decoded
only after digest verification. A malformed existing release manifest is an
error when used for the pack's default publication date; the missing-manifest
fallback remains available. No locale setting substitutes for these readers.

The release pack ships `utf8_text.rb` with every dependent tool. The locale
regressions use subprocesses with `LANG=C LC_ALL=C` and an available UTF-8 locale,
including multilingual/non-BMP text, malformed bytes and Unicode paths. No Ruby
baseline or external-service requirement changes.


## Finite semantic execution

- `evaluate_semantic_pattern.rb` verifies an authoring 1.6 execution pin and runs
  the finite portable contract against explicitly supplied normalized evidence,
  preserved bytes and query limits. It does not interpret legacy order strings.
- `check_semantic_suite.rb [--json]` runs every packaged `test_semantic_*.rb`
  foundation and family oracle, requiring nonempty tests and zero failures,
  errors or skips. Family tests cover package/repository, extraction, certificate
  presentation/expansion, signing, JA3, sanctions and explicit result bindings.
- `semantic_package_repository.rb`, `semantic_certificate_profiles.rb` and
  `semantic_result_primitives.rb` define bounded named comparison profiles;
  `semantic_identity.rb`, `semantic_time.rb`, `semantic_finding.rb` and
  `semantic_amendments.rb` keep identity, event/knowledge and assertion histories
  distinct. Fields and limits are documented in the execution/family contracts.
- `test_semantic_neo4j_adapter.rb` is a synthetic adapter oracle.
  `accept_semantic_neo4j.rb` is the separately invoked task-owned native round-trip
  runner. Passing synthetic tests is not a native run.

Release packs include these dependencies and all semantic oracles and execute
the copied semantic suite before delivery. The suite reports evidence-only
results and does not authenticate sources, evaluate independence, verify
signatures, renew review dates or accept assessments.


`check_semantic_fixture_hashes.rb` independently reproduces or identifies the
explicit synthetic origins of semantic fixture digest values. The promotion
linter admits only reviewed values at an exact relative fixture path and exact
whole-file SHA-256, using the pinned tool-data manifest. A changed, relocated or
foreign fixture loses that exception; other credential/address/content scans
still run. This supports real computed test vectors without treating plausible
hashes from arbitrary input as reviewed evidence.
