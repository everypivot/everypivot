# Contributing To EveryPivot&trade;

## Purpose

EveryPivot&trade; is intended to be a community-shaped registry of portable graph-pivot patterns.

We want contribution to be open, while keeping promotion into the validated corpus deliberate and well explained.

## How To Contribute

You can contribute through pull requests that add or improve:
- pivot pattern YAML files
- hazards and caveats
- fixtures and examples
- schema or validator behavior
- relation catalog entries
- documentation and promotion guidance

## Where New Patterns Should Usually Go

Default guidance:
- new patterns usually start in `graph-pivots/working-set/`
- broader or lower-priority patterns may belong in `graph-pivots/deferred/`
- only mature, well-reviewed patterns should land directly in `graph-pivots/validated/`

## What A Good Pattern Contribution Includes

- clear name and description
- correct lane placement
- required metadata for its lane
- hazards or caveats where relevant
- fixture examples if possible
- explanation of why the pivot is useful and what can go wrong

## Review Expectations

Maintainers will review:
- structural correctness
- metadata quality
- hazard handling
- fixture quality
- whether the proposed lane is justified

## Promotion

Promotion from `working-set/` to `validated/` is curated in public.

That means:
- the decision should happen through a visible PR or release milestone
- the reasoning should be documented
- the validated lane should stay trustworthy and earned

## Community Norm

Please optimize for clarity, portability, and honesty about limitations.

We would rather have a clearly caveated working-set pattern than an overclaimed validated one.

## Security

If your contribution relates to service abuse, credential exposure, or operational risk, see `SECURITY.md`.

## Inbound License &amp; DCO

By contributing, you agree that your contributions are submitted under the
project's existing license terms:

- **Code, schema, tooling, validator, docs, site assets** are licensed
  inbound under [Apache License 2.0](LICENSE-CODE).
- **Pattern YAMLs and fixtures** are licensed inbound under
  [CC BY 4.0](LICENSE-DATA).

We use a lightweight **Developer Certificate of Origin (DCO)** rather than a
heavyweight CLA. To certify that you have the right to submit your
contribution under the licenses above, sign your contributor-authored commits
where practical:

```bash
git commit -s -m "your message"
```

The `-s` flag appends a `Signed-off-by:` trailer using your `git config
user.name` and `user.email`. By signing off you are stating you accept the
[DCO v1.1](https://developercertificate.org/) — i.e. that you wrote the
contribution, have the right to submit it, and understand it will be
distributed under the project's open licenses.

Maintainers may squash or clean up good-faith contributions when authorship is
clear and the contributor confirms DCO acceptance in the pull request.
Multi-author pull requests need signoff or clear DCO confirmation from each
contributor.

## Relevant Conflict Or Vendor Disclosure

Disclose affiliations, financial interests, proprietary-data dependencies,
product interests, or vendor relationships that could affect review,
especially for pattern promotion, validation evidence, or defended
conclusions. Routine neutral fixes do not require broad affiliation
disclosure. Maintainers may ask for more context when it is needed to review a
contribution fairly.

## Trademark

**EveryPivot&trade;** is an unregistered trademark associated with the
EveryPivot Project. The inbound licenses cover your contribution's code and
content, but neither grants any right to use the EveryPivot name to identify a
derivative product, fork, or competing registry. See
[`TRADEMARK.md`](TRADEMARK.md).
