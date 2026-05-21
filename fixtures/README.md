# Fixtures

Validation fixtures and golden examples for the public EveryPivot&trade; contract.

> Fixture content in this directory is licensed under
> [CC BY-SA 4.0](../LICENSE-DATA); the surrounding tooling is under
> [Apache-2.0](../LICENSE-CODE). &copy; 2026 EveryPivot Project. See [`LICENSE`](../LICENSE),
> [`NOTICE`](../NOTICE), and [`TRADEMARK.md`](../TRADEMARK.md).

Current contents:
- `validator_suite.yml` manifest for automated fixture checks
- `cases/` library roots with pass/fail scenarios for schema, lane, and metadata validation

Run the suite with:

```bash
ruby tools/check_fixture_suite.rb
```

The suite currently covers:
- minimal valid `v1.4`, `v1.3`, `v1.2`, and `v1.1` patterns
- lane mismatch rejection
- required-field rejection
- enum rejection
- forbidden additional-property rejection
- deferred-reason enforcement
- current assessment-bridge enforcement
