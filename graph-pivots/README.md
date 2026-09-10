# Graph Pivots

Seeded home for the public EveryPivot&trade; graph-pivot corpus.

> The pattern corpus in this directory (every `*.yaml` file across the
> lifecycle lanes) is licensed under
> [Creative Commons Attribution 4.0 International](../LICENSE-DATA).
> &copy; 2026 EveryPivot Project. See [`NOTICE`](../NOTICE) for the required
> attribution and [`TRADEMARK.md`](../TRADEMARK.md) for the EveryPivot&trade;
> trademark notice. Downstream additions may use other terms, but original
> EveryPivot material remains under CC BY 4.0.

Lifecycle lanes:

- `validated/` for curated patterns mature enough to feature publicly;
- `working-set/` for live candidates under active review;
- `deferred/` for first-class but intentionally non-promoted patterns.

All 176 current patterns use `pivot-pattern` schema v1.5: 175 are
`evidence_only`, and one is a conditional `candidate_assessment` with explicit
qualifying-evidence requirements. A pattern match does not become an accepted
conclusion. Historical releases and deliberate legacy validation fixtures retain
their original schema versions. See [schema migration](../docs/SCHEMA_MIGRATION.md)
and [the assessment boundary](../docs/ASSESSMENT_BRIDGE.md).
