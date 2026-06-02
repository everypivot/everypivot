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

## Suggested Example

```json
{
  "registry": "everypivot",
  "release": "v0.4.2",
  "published_at": "2026-06-02",
  "schema_versions": {
    "pivot_pattern": "1.4"
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
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "incident_level",
        "subject_role": "observation",
        "object_role": "observation"
      },
      "version": "1.0.0",
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

Each `patterns[]` entry should include:
- `id`
- `lane`
- `category`
- `version`
- `path`

Recommended additional fields:
- `precision_tier`
- `deferred_reason`
- `robustness_class`
- `pattern_schema_version`
- `assessment`
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
