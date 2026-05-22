# Governance

EveryPivot is maintainer-led. The project may have one maintainer at launch,
but governance is written around the `EveryPivot maintainers` role so more
maintainers can be added later.

## Maintainer Responsibilities

Maintainers are responsible for:

- preserving the trustworthiness of the validated lane;
- reviewing pattern, fixture, schema, tooling, and documentation changes;
- approving promotions, demotions, and retirements;
- maintaining release and validation discipline;
- resolving credible challenges in public where possible;
- asking for conflict, vendor, or provenance context when review needs it.

## Promotion To `validated`

See `VALIDATION_SEMANTICS.md` for the lifecycle meaning of `validated` and
the claims it must not imply.

Promotion to `validated` requires:

- maintainer approval;
- fixture, example, or evidence support appropriate to the pattern;
- documented hazards and blocked conclusions;
- no unresolved credible challenge against the pattern.

Promotion should happen through a visible pull request or release milestone.

## Challenges, Demotion, And Retirement

Anyone may challenge a pattern's lane, semantics, evidence, hazards, or
runtime-safety framing through an issue or pull request.

- Minor editorial or narrowly scoped technical fixes may remain validated while
  reviewed.
- Credible challenges that affect the safety, semantics, evidence basis, or
  promotion rationale should move a validated pattern back to `working-set` or
  `deferred` while review continues.
- Patterns that are obsolete or unsafe to keep as live candidates may be
  retired with a short explanation.

## Schema Changes

Before v1.0.0, schema evolution may proceed with maintainer approval and clear
  migration notes.

For v1.0.0 and later, substantive schema changes should have an issue or RFC
before merge. Compatibility impact and migration expectations should be stated
before the schema changes land.

## Vendor And Conflict Disclosure

Disclosure is relevance-based. Contributors should disclose affiliations,
financial interests, proprietary-data dependencies, product interests, or
vendor relationships that could affect review, especially for pattern
promotion, validation evidence, or defended conclusions.

Routine neutral fixes do not require broad affiliation disclosure. Maintainers
may ask for more context when it is needed to review a contribution fairly.

## DCO

EveryPivot uses the Developer Certificate of Origin rather than a CLA.
Contributors should sign off their own commits where practical. Maintainers
may squash or clean up good-faith contributions when authorship is clear and
the contributor confirms DCO acceptance in the pull request. Multi-author pull
requests need signoff or clear DCO confirmation from each contributor.
