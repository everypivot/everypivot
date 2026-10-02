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

Pattern IDs are unique across the entire publication unit, including all lanes.
The validator and generator reject duplicate IDs (even identical copies),
filename/ID mismatches and lane/state mismatches. A move removes the old copy.
Rejection occurs before artifact writes, preserving existing snapshots.

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

The following example selects a retained schema v1.5 entry from the v0.6.0
registry, which also distributes authoring 1.6 definitions. Execution declarations
are specified separately below. Release metadata alone does not establish
publication.

## Schema v1.5 Entry Example

```json
{
  "registry": "everypivot",
  "release": "v0.6.0",
  "published_at": "2026-10-02",
  "schema_versions": {
    "pivot_pattern": "1.6"
  },
  "counts": {
    "validated": 21,
    "working_set": 77,
    "deferred": 82
  },
  "patterns": [
    {
      "id": "CTI_SAMPLE_IMPHASH_CLUSTER",
      "lane": "validated",
      "category": "CTI",
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "pattern_schema_version": 1.5,
      "assessment_mode": "evidence_only",
      "assessment_compatibility": {
        "status": "evidence_only",
        "contract_version": "0.4-draft",
        "manifest_sha256": "5416bf429a34afccb4e6657807c26b83491a39bdcbd6c9a313530cadbf032881",
        "checked_input": {
          "pattern_schema_version": 1.5,
          "assessment_mode": "evidence_only"
        },
        "coverage": {
          "complete": true,
          "checks_performed": [
            "assessment_mode"
          ],
          "assessment_acceptance_evaluated": false
        },
        "warnings": []
      },
      "version": "2.0.0",
      "path": "graph-pivots/validated/CTI_SAMPLE_IMPHASH_CLUSTER.yaml"
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

Every distributed `patterns[]` entry must use v1.5 or v1.6 and include:
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

The same assessment eligibility rule applies to stable, preview and edge outputs,
including browser sidecars and archives. A legacy record rejects the whole
publication unit with `migration_required` before any output writes. Supported
v1.1–v1.4 parsing is for diagnostics only; no legacy-publication option exists.

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
requires v1.5 or v1.6, an explicit assessment mode and complete applicable fields. It
refuses all legacy inputs and incomplete or incompatible hints. Top-level `assessment_contract`
records contract provenance and digests; `assessment_coverage` counts the
eligible current states only. Diagnostic CLI semantic counts are separate and
may include compatible legacy hints; their `distribution_counts` identify current
eligibility explicitly. Every entry carries `assessment_compatibility`, including its
exact `checked_input` and pinned `manifest_sha256` for stale-result detection. An
`evidence_only` entry omits `assessment`; a `candidate_assessment` entry carries
a complete hint and qualifying-evidence requirements. Consumers must handle
unknown modes as unavailable for assessment generation. These fields never
certify runtime evidence or an accepted assessment. See
[Evidence and assessment hints](ASSESSMENT_BRIDGE.md).


## Authoring 1.6 execution declarations

Authoring 1.6 adds a closed `execution` reference (contract, version, relative path,
exact-file SHA-256). The builder validates the finite contract and its pattern
ID/version/result forms before exporting it. `semantic_execution` separately
records `checked_input`, declaration status, explicit branch/binding/result
summaries and coverage limits. A checked declaration reports runtime acceptance
as not evaluated. It never inherits assessment compatibility or supplies an
accepted conclusion.

Authoring 1.5 entries have no execution reference and report `not_declared`.
Consumers verify exact checked inputs and reference metadata before displaying
supported declarations. The browser rejects altered versions, targets, pins or
unchecked summaries; support for a declaration is not execution. Consumers
without authoring 1.6/semantic contract 1.0 support must return unsupported and
must not fall back to free-text temporal strings or a last-hop return rule.
Contracts are included in pattern bundles and portable release packs. The
registry release is v0.6.0; each version identifies its own contract surface.
