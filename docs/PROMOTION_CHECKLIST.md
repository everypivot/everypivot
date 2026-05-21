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
- [ ] Weighted heuristics, temporal scoring, and analyst triage have been kept out of the pattern and left to downstream profile or orchestration layers.
- [ ] Review discussion explains why promotion is warranted.
- [ ] We would be comfortable showing this pattern as part of the public validated story.

## Weak And Composite Selector Addendum

For weak selectors, structural fingerprints, decoded visual payloads,
high-cardinality values, and multi-hop composite pivots, also confirm:

- [ ] Positive, weak-signal, negative, and high-cardinality or suppression examples are present or cited in the promotion discussion.
- [ ] `negative_nodes`, degree caps, temporal windows, and hazards cover the main false-positive modes.
- [ ] Runtime confidence, scoring, and final assessment remain outside the pattern definition.

## Promotion Rule Of Thumb

If a pattern is useful but still awkward, caveat-heavy, or under-tested, it probably belongs in `working-set/`, not `validated/`.
