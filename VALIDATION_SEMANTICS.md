# Validation Semantics

EveryPivot lifecycle states are editorial registry states. They are not
runtime truth labels, attribution judgments, maliciousness findings, or
confidence scores.

## `validated`

`validated` means maintainers consider the pivot mature enough to feature in
the public registry. A validated pattern should have clear semantics, hazards,
constraints, and evidence or fixture support.

`validated` does not mean:

- a runtime match is true;
- the matched entities are malicious;
- the pivot proves attribution, sponsorship, intent, or impact;
- downstream scoring or analyst judgment is complete;
- the pattern is safe without suppression, temporal checks, and corroboration.

## `working_set`

`working_set` means the pattern is live, inspectable, and useful enough for
review, but not yet ready for the validated lane. It may need stronger
fixtures, hazards, constraints, examples, or promotion rationale.

## `deferred`

`deferred` means the pattern is intentionally preserved but not promoted. It
may be waiting on evidence, fixtures, controls, access, vocabulary cleanup, or
editorial maturity.

## `retired`

`retired` means a pattern should no longer be used as a live registry pattern.
Retirement should explain whether the pattern was superseded, unsafe,
duplicative, or semantically wrong.

## Promotion And Demotion

Promotion is a maintainer decision supported by review evidence. Demotion is
not failure; it is how the registry preserves trust when a pattern needs more
work or a credible challenge changes the risk profile.

Downstream systems own execution, scoring, case-specific corroboration, and
final assessment.

