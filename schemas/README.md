# Schemas

Public EveryPivot&trade; schemas live here.

> Licensed under [Apache-2.0](../LICENSE-CODE). &copy; 2026 EveryPivot Project.
> See [`LICENSE`](../LICENSE), [`NOTICE`](../NOTICE), and
> [`TRADEMARK.md`](../TRADEMARK.md).

[`pivot_pattern.schema.json`](pivot_pattern.schema.json) defines the current
`pivot-pattern` v1.5 contract and retains parsing support for versions 1.1–1.4.
Current authoring uses v1.5. Its explicit `assessment_mode` is either
`evidence_only` (no hint or requirements) or `candidate_assessment` (complete
hint plus nonempty, nonblank `assessment_requirements`).

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
