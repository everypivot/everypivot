# Schemas

Public EveryPivot&trade; schemas live here.

> Licensed under [Apache-2.0](../LICENSE-CODE). &copy; 2026 EveryPivot Project.
> See [`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE), and
> [`TRADEMARK.md`](../TRADEMARK.md).

[`pivot_pattern.schema.json`](pivot_pattern.schema.json) defines the current
`pivot-pattern` v1.6 contract and retains parsing support for versions 1.1–1.5.
Authoring v1.5 remains distributable during the focused execution migration;
v1.6 additionally requires a closed, digest-bound `execution` reference. Both
versions' explicit `assessment_mode` is either
`evidence_only` (no hint or requirements) or `candidate_assessment` (complete
hint plus nonempty, nonblank `assessment_requirements`).

An execution reference is verified against the packaged contract's bytes and
the exact pattern ID/version/target. It is not supported in v1.5 or earlier.
Contract declaration validity is distinct from executed behavioral or native
acceptance. See [the execution contract](../docs/SEMANTIC_EXECUTION_CONTRACT.md)
for current coverage and remaining integration gates. The new capability does
not adopt the separately proposed families/facets model.

The schema checks document shape. Full predicate, role-or-kind and scope
compatibility requires the shared bridge checker and the pinned SAIL v0.4 DRAFT
contracts under [`sail-v0.4-draft/`](sail-v0.4-draft/README.md). The contract pack
includes source provenance, digests and upstream licensing; validation fails
closed if it is absent or corrupt. No upstream network fetch is needed.

```sh
ruby tools/validate_pivots.rb graph-pivots --strict-metadata --strict-bridge
ruby tools/check_sail_bridge.rb graph-pivots --json --strict-incomplete
```

A compatibility pass concerns the candidate's documented shape. It does not
validate case evidence, assign confidence or accept an analytical conclusion.
See [`ASSESSMENT_BRIDGE.md`](../docs/ASSESSMENT_BRIDGE.md) and
[`SCHEMA_MIGRATION.md`](../docs/SCHEMA_MIGRATION.md) for authoring and migration.
The separately proposed families, facets and case-bound objects are future,
unversioned design work and are not part of v1.5.

[`package_repository_provenance.v1.schema.json`](package_repository_provenance.v1.schema.json)
defines the separate `everypivot.package_repository_provenance` v1.0 sidecar
contract for package/repository declarations and exact source snapshots. Its
version is independent of pattern authoring v1.5, individual pattern versions,
registry releases, adapter profiles and the pinned SAIL assessment contract.

Use `ruby tools/package_repository_provenance.rb --check --input RECORD.json`
to check a supplied record's shape and self-consistency. That check does not
verify external provenance. Evaluation with `--repo LOCAL_GIT_REPOSITORY`
requires an explicit exact commit and Git object algorithm and hashes the pinned
committed tree; unresolved bindings, Git links and LFS content cannot become
qualified source snapshots. Even a qualified result records registry-declared
source evidence only, with `build_provenance: not_verified`. It does not prove
the package was built from that source or establish an accepted assessment.
See [tool usage](../tools/README.md#packagerepository-provenance) and
[synthetic fixtures](../fixtures/package-repository-provenance/).
