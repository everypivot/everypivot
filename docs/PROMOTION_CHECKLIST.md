# Promotion Checklist

## Purpose

Use this checklist when considering whether a pattern should move into `graph-pivots/validated/`.

## Checklist

- [ ] The pivot is materially useful and reusable.
- [ ] The lane change is explicit and intentional.
- [ ] Required metadata for the target lane is present.
- [ ] Hazards and caveats are documented clearly enough for public consumers.
- [ ] The precision claim feels justified.
- [ ] The robustness class feels appropriate.
- [ ] The pattern structure is mature and readable.
- [ ] At least minimal fixtures or examples exist.
- [ ] Fixture roles are explicit where traversal evidence exists.
- [ ] Evidence examples include blocked assertions, not just happy-path edges.
- [ ] Maintainer approval is explicit.
- [ ] There is no unresolved credible challenge against the pattern.
- [ ] Weighted heuristics, temporal scoring, and analyst triage have been kept out of the pattern and left to downstream profile or orchestration layers.
- [ ] Review discussion explains why promotion is warranted.
- [ ] Review discussion states that `validated` is not attribution, maliciousness, runtime confidence, or final assessment.
- [ ] We would be comfortable showing this pattern as part of the public validated story.

## Weak And Composite Selector Addendum

For weak selectors, structural fingerprints, decoded visual payloads,
high-cardinality values, and multi-hop composite pivots, also confirm:

- [ ] Positive, weak-signal, negative, and high-cardinality or suppression examples are present or cited in the promotion discussion.
- [ ] Weak-positive examples explain what corroboration is required before a downstream system treats the match as meaningful.
- [ ] `negative_nodes`, degree caps, temporal windows, and hazards cover the main false-positive modes.
- [ ] Runtime confidence, scoring, and final assessment remain outside the pattern definition.

## Deferred Lane Move Addendum

For any pattern moving out of `deferred/`, also confirm:

- [ ] The old `deferred_reason` has been resolved or replaced with a more accurate live blocker before the lane move.
- [ ] Hazards cover the dominant false-positive modes for this pattern family.
- [ ] Positive, weak-positive, negative, suppression, and high-cardinality examples are present or explicitly not applicable.
- [ ] Blocked claims are documented, including attribution, authorship, ownership, maliciousness, compromise, runtime confidence, and final assessment boundaries.
- [ ] Restricted-data, privacy, consent, or public-safety limits were reviewed where applicable.
- [ ] The assessment note or PR records explicit maintainer approval for the deferred lane move.

## Promotion Rule Of Thumb

If a pattern is useful but still awkward, caveat-heavy, or under-tested, it probably belongs in `working-set/`, not `validated/`.
