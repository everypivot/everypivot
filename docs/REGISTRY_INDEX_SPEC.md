# Registry Index Specification

## Purpose

This note sketches the machine-readable `registry-index.json` artifact that should be published with every stable release.

The index should make it easy for:
- the website
- external tools
- alternative self-hosted consumers

to consume the registry without scraping GitHub or walking the repo tree ad hoc.

## Design Goals

- make release pinning explicit
- summarize the corpus without embedding every full pattern inline
- provide stable URLs or paths for pattern retrieval
- expose lane, category, and metadata needed for search and filtering
- stay simple enough to generate in CI

## Top-Level Shape

Suggested file:
- `registry-index.json`

Suggested top-level fields:
- `registry`
- `release`
- `published_at`
- `schema_versions`
- `counts`
- `patterns`
- `artifacts`

## Release Envelope

The release/date fields below identify the prepared v0.5.0 distribution using
schema v1.5. Preparing these files does not publish a release.

## Schema v1.5 Entry Example

```json
{
  "registry": "everypivot",
  "release": "v0.5.0",
  "published_at": "2026-09-10",
  "schema_versions": {
    "pivot_pattern": "1.5"
  },
  "counts": {
    "validated": 21,
    "working_set": 76,
    "deferred": 79
  },
  "patterns": [
    {
      "id": "OSINT_RDP_CERT_THUMBPRINT_CLUSTER",
      "lane": "validated",
      "category": "OSINT",
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "pattern_schema_version": 1.5,
      "assessment_mode": "evidence_only",
      "assessment_compatibility": {
        "status": "evidence_only",
        "contract_version": "0.4-draft",
        "coverage": {"complete": true, "assessment_acceptance_evaluated": false}
      },
      "version": "2.0.0",
      "path": "graph-pivots/validated/OSINT_RDP_CERT_THUMBPRINT_CLUSTER.yaml"
    }
  ],
  "artifacts": {
    "schema": "schemas/pivot_pattern.schema.json",
    "patterns_bundle": "artifacts/patterns.tar.gz",
    "fixtures_bundle": "artifacts/fixtures.tar.gz"
  }
}
```

## Pattern Entry Requirements

Each current v1.5 `patterns[]` entry must include:
- `id`
- `lane`
- `category`
- `version`
- `path`
- `pattern_schema_version`
- `assessment_mode`
- `assessment_compatibility`

For `candidate_assessment`, `assessment` and nonempty
`assessment_requirements` are also required. For `evidence_only`, both fields
must be absent. A distributable entry must have complete compatibility coverage
and must explicitly state that assessment acceptance was not evaluated.

Additional descriptive fields:
- `precision_tier`
- `deferred_reason`
- `robustness_class`
- `name`
- `hazards`
- `capability_requirements`
- `review`
- `controls`
- `presentation`

`deferred_reason` uses the enum in `schemas/pivot_pattern.schema.json`. It is
backlog metadata for deferred patterns, not a confidence score, runtime
capability signal, or release-state override.

`controls` is a compact pass-through summary of existing pattern constraints:
temporal window, degree caps, negative-node suppression lists, and provenance
thresholds. It exists so browser, release-pack, and downstream consumers can show the
same guardrails without scraping raw YAML.

`presentation` is display metadata derived from already-published fields. It
may include hazard/capability counts, review status, and high-cardinality
attention flags. It must not introduce runtime confidence, analyst scoring, or
promotion approval semantics.

## Lane Encoding

Recommended lane values:
- `validated`
- `working_set`
- `deferred`

This should match the registry contract and avoid introducing a second vocabulary.

## Artifact References

The index should reference the release artifacts needed for downstream consumers, such as:
- schema files
- bundle downloads
- optional docs or release notes

This makes the index a lightweight manifest for both humans and machines.

## Stable vs Edge

Recommended behavior:
- publish one index per tagged stable release
- optionally publish an `edge` index for the current `main` snapshot

Consumers should not have to guess whether an index is stable or unreleased.

## Why This Matters

Without a published index:
- clients have to crawl the repo
- URLs and paths become an implicit contract
- release pinning gets messy

With a published index:
- the website can render quickly
- downstream clients can search predictably
- alternative consumers can self-host more easily

## Recommendation

Keep `registry-index.json` intentionally small and boring.

It should be the release manifest for the open corpus, not a second hidden data model.

## Assessment boundary

The generator validates the pinned SAIL contract before writing artifacts and
refuses incomplete or incompatible hints. Top-level `assessment_contract`
records contract provenance and digests; `assessment_coverage` counts the
reported states. Every entry carries `assessment_compatibility`. An
`evidence_only` entry omits `assessment`; a `candidate_assessment` entry carries
a complete hint and qualifying-evidence requirements. Consumers must handle
unknown modes as unavailable for assessment generation. These fields never
certify runtime evidence or an accepted assessment. See
[Evidence and assessment hints](ASSESSMENT_BRIDGE.md).
