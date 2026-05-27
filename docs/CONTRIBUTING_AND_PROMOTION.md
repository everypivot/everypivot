# Contributing And Promotion

## Purpose

This note captures the intended community contribution model for the public EveryPivot&trade; repository.

The goal is to make the project genuinely community-driven while preserving the trustworthiness of the validated corpus.

## Core Principle

Contribution should be open.

Promotion should be curated.

That means:
- anyone should be able to propose a pattern, hazard note, fixture, or documentation change through GitHub
- maintainers should decide promotion state in public using explicit criteria
- weighted adjudication and analyst-ranking logic should stay outside the pivot corpus instead of being hidden inside pattern semantics

## What The Community Should Be Able To Contribute

- new pivot patterns
- revisions to existing patterns
- hazard and caveat improvements
- fixture and golden-test cases
- validator improvements
- relation catalog additions
- documentation and lifecycle-policy updates

## Recommended Contribution Flow

### 1. Propose

A contributor opens a pull request with one or more of:
- a new pattern YAML
- metadata improvements
- hazards
- fixture cases
- relation updates
- documentation

### 2. Validate

CI checks should run automatically:
- schema validation
- corpus policy validation
- fixture checks, including traversal evidence-pack checks where available
- release bundle build preview

### 3. Land In The Right Lane

Default expectations:
- new patterns usually land in `working-set/`
- broad, immature, or low-priority patterns may land in `deferred/`
- only well-reviewed patterns should land directly in `validated/`

### 4. Review Publicly

Maintainers review:
- clarity of the pivot
- hazard handling
- metadata completeness
- fixture quality
- whether the contribution is still an atomic pivot rather than a composite scoring workflow
- whether the proposed lane is justified
- any relevant conflict, vendor, product, or proprietary-data disclosure needed
  to evaluate the contribution fairly

### 5. Promote Intentionally

Promotion from `working-set/` to `validated/` should happen through a visible PR or release milestone, not as an implicit drift.

Promotion requires maintainer approval, fixture or evidence support, and no
unresolved credible challenge against the pattern. Evidence support should name
the fixture role being covered: positive, weak positive, cautionary positive,
cautionary negative, negative, suppression, or high cardinality.

## Lane Expectations

### `validated/`

Represents the curated public story.

Patterns here should:
- carry the required metadata for promoted pivots
- have clear hazards and caveats
- be structurally mature
- feel safe to showcase prominently on the website

### `working-set/`

Represents live candidates under active review.

Patterns here should:
- be visible and inspectable
- be clearly caveated
- have enough metadata to support meaningful review

### `deferred/`

Represents first-class but intentionally non-promoted patterns.

Patterns here should:
- remain visible in the repo
- preserve provenance and future value
- not dilute the editorial promise of the validated lane

## Deferred Lane Move Gate

Do not move a deferred pattern into `working-set/` or `validated/` merely
because its backlog metadata was cleaned up.

Before any deferred pattern moves lanes, maintainers should record a
pattern-specific review covering:

- dominant false-positive modes and hazard adequacy;
- negative controls and suppression behavior;
- positive, weak-positive, negative, suppression, and high-cardinality examples
  where applicable;
- blocked claims, especially attribution, authorship, ownership, maliciousness,
  compromise, runtime confidence, and final assessment;
- restricted-data, privacy, consent, or public-safety limits where applicable;
- the reason the old `deferred_reason` no longer blocks the proposed lane.

`deferred_reason: insufficient_hazards` should be used only when hazards are
missing or materially inadequate. Once hazards are repaired, update the reason
to the live blocker instead of preserving `insufficient_hazards` as a
historical label.

## Promotion Questions Maintainers Should Ask

- Is the pivot materially useful and reusable?
- Is it still an atomic graph pivot, rather than weighted adjudication or analyst triage logic that belongs downstream?
- Are the hazards understandable and documented?
- Is the precision claim justified?
- Is the robustness class appropriate?
- Do we have enough fixtures or examples to trust it?
- Would we be comfortable showing this pattern on the homepage as part of the validated story?

## Weak And Composite Selector Gate

Weak and composite selectors can be useful pivot classes without being
high-confidence runtime conclusions. A pattern may describe a generally useful
relation while still requiring downstream corroboration, suppression, and
analyst judgment before any specific result is trusted.

This gate applies to patterns built around:

- exact weak selectors such as cookie names, tracking IDs, mutexes, PDB paths,
  filenames, user agents, social handles, or BSSIDs;
- structural fingerprints such as DOM, HTML, HTTP-header, title, banner, or
  resource-section hashes;
- decoded visual payloads such as QR or barcode values;
- derived image text, OCR output, or bounded image descriptions;
- high-cardinality values whose main value is noise characterization or
  suppression rather than direct clustering confidence;
- multi-hop or composite joins where the result depends on intermediate state.

Before moving one of these patterns into `working-set/`, reviewers should see:

- concrete hazards for common, shared, generic, stale, spoofed, and
  high-cardinality values;
- a characterized precision tier, not `exploratory`;
- at least one positive fixture or fixture-like example;
- at least one weak-signal example showing why the selector needs
  corroboration;
- at least one negative example that should not cluster;
- at least one high-cardinality or suppression example when the selector can
  fan out broadly.
- blocked assertions that state what the traversal does not prove.

Before moving one of these patterns into `validated/`, reviewers should also
see:

- populated `negative_nodes` or an equivalent suppression story;
- degree caps and a temporal window where the relation can fan out;
- review metadata showing the decision was intentional;
- fixture roles that cover the main positive, negative, suppression, and
  weak-signal behavior expected from the pattern;
- a promotion discussion that explicitly says runtime confidence, scoring, and
  final assessment belong to downstream execution or assessment layers, not to
  the pattern definition.

Maintainer review tooling can mark candidates that trigger this gate. That
signal is advisory: it identifies review pressure, but maintainers still own
the final lane decision.

## Suggested PR Labels

- `new-pattern`
- `metadata`
- `hazards`
- `fixtures`
- `validator`
- `docs`
- `promotion-candidate`
- `validated`
- `working-set`
- `deferred`

## Suggested Public Governance Stance

- discussion happens in the open
- promotion decisions are explained
- maintainers curate the validated lane
- contributors are credited through normal Git history and PR discussion
- `validated` is an editorial lifecycle state, not a runtime confidence score,
  attribution judgment, maliciousness finding, or final assessment
- relevance-based vendor and conflict disclosure is required when affiliations,
  product interests, proprietary-data dependencies, or financial interests
  could affect review
- schema changes before v1.0.0 require maintainer approval and migration notes;
  substantive schema changes after v1.0.0 should have an issue or RFC before
  merge
- DCO enforcement follows the project governance: contributors sign off their
  own commits where practical, maintainers may clean up good-faith
  contributions when DCO acceptance is clear, and multi-author PRs need
  signoff or clear confirmation from each contributor

## Recommendation

Make the repo feel open to contribution, but make the validated lane feel earned.

That balance is what turns an open pattern library into a trusted community project.
