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

The evidence-pack suite checks structure and bounded one-hop consistency, not
complete execution of pattern constraints. Positive/negative/suppression labels
alone are authored expectations. Promotion evidence must name its executed
oracle and separately retain unsupported semantic expectations. See
[fixture scope](fixtures/README.md) and [unresolved bindings](docs/UNRESOLVED_SEMANTICS.md).

## Assessment compatibility

Schema v1.5 requires an explicit `assessment_mode`. Evidence-only patterns
provide useful results without a default assessment. Conditional candidate
hints require a complete SAIL-compatible shape and qualifying-evidence
requirements. Neither state accepts an analytical conclusion.

The native validator checks the pinned SAIL matrix in addition to the local
schema. Registry generation refuses incomplete or incompatible hints.
See [Evidence and assessment hints](docs/ASSESSMENT_BRIDGE.md) for the mode,
compatibility, and consumer requirements.


## Focused executable semantics

Authoring 1.6 binds an independently versioned finite execution contract by exact
bytes, pattern ID/version and result forms. `check_semantic_suite.rb` runs the
packaged synthetic tests over declared normalized evidence. This provides a
separate behavioural check for the 45 admitted definitions, without upgrading
legacy 1.5 patterns, lifecycle labels or assessment status. The broad SBL
compatibility identifier has no execution reference. The 134 other original
patterns remain outside this focused semantic audit.

Source authenticity, upstream parsing, independence, cryptographic verification,
analyst acceptance and native adapters are separate claims. The limited hybrid
Neo4j profile admits only exact JA3/JA3S contract revisions. Its native storage
round trip plus Ruby evaluation does not implement general native Cypher
semantics. See [the execution contract](docs/SEMANTIC_EXECUTION_CONTRACT.md).
