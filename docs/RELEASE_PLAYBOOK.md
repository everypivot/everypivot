# Release Playbook

This playbook describes how an EveryPivot release moves from candidate to deployed, and what to verify at each step.

It is organised around release stages. **Name the stage before opening any other section.** The same finding can be a blocker, a procedural step, or a non-issue depending on the stage.

## Release stages

| Stage | What it means | What is expected |
|---|---|---|
| **Candidate** | Work-in-progress on a feature branch or in the working tree | Tree may be dirty; tests may not all pass; intent is being explored |
| **Release-prep branch** | Candidate frozen on `release/vX.Y.Z` | All local gates pass; commit body describes the diff; reachable history is clean of secret-shaped literals |
| **Tagged but not deployed** | `release/vX.Y.Z` merged to `main`, tag `vX.Y.Z` pushed | CI release job has run; release assets are on the GitHub release; site has not yet redeployed |
| **Deployed** | Pages workflow finished and `everypivot.io` serves the new release | Live manifest and registry-index reflect the new tag; source links resolve; counts match |

Each stage has its own checklist below. Findings that belong to a later stage are not defects in an earlier stage — they are reminders of work still to come.

---

## Stage 1 — Candidate

You are here when work is in progress on a feature branch or in the working tree, before the release-prep branch is cut.

### Required
- [ ] The change has a stated purpose that fits within the project's stated scope (see `REPO_SCOPE.md`).
- [ ] Validators pass locally: `ruby tools/validate_pivots.rb --strict-metadata`, `ruby tools/check_fixture_suite.rb`, `ruby tools/check_cti_promotion_lint.rb`, `ruby tools/check_query_profile_suite.rb`, `ruby tools/check_relation_catalog.rb`.
- [ ] If patterns are added or promoted: hazards, blocked assertions, fixtures, and the CTI promotion-boundary rules (`docs/CTI_PROMOTION_BOUNDARIES.md`) are satisfied.
- [ ] If schema, validator, or relation catalog changed: dependent docs and exemplars updated.

### Not required at this stage
- The branch does not need to be pushed.
- The release-prep commit does not need to exist yet.
- `check_release_metadata`, `check_generated_freshness`, `check_site_links`, and `check_site_snapshot` may fail — they only need to pass on a release-prep branch with the right `--release` and `--published-at` values.

### Watch for
- Working-tree state is informational, not signal. A dirty tree at this stage may be intentional work-in-progress.

---

## Stage 2 — Release-prep branch

You are here once `release/vX.Y.Z` exists with the bumped version and all release-prep edits.

### Required
- [ ] All Stage 1 gates pass.
- [ ] `tools/check_release_metadata.rb` passes (version strings, dates, counts, lane totals are consistent across README, CHANGELOG, manifest, registry-index, site data).
- [ ] `tools/check_generated_freshness.rb` passes (regenerated artifacts match what `build_registry_index.rb` would emit from the same source).
- [ ] `tools/check_site_links.rb` and `tools/check_site_snapshot.rb` pass.
- [ ] `tools/check_reachable_history.rb` passes — no secret-shaped literal exists at any commit reachable from the release-prep branch tip. **This is the gate that catches secret-shaped strings introduced earlier in the branch's history**, not just in the current tree.
- [ ] `reuse lint` passes (or the local equivalent — `tools/check_reuse_coverage.rb` if running offline) — every tracked file is covered by a `.reuse/dep5` stanza, and every stanza names files that exist.
- [ ] Release pack builds clean: `ruby tools/build_release_pack.rb --output-dir /tmp/check-pack --force`, then the pack self-validates from inside (`cd /tmp/check-pack && ruby tools/check_release_metadata.rb`).
- [ ] The release commit's message describes the diff if the diff is substantive — new doctrine, new tooling, schema changes, lifecycle promotions. See *Commit-message expectations* below.

### Not required at this stage
- The branch does not need to be merged to `main`.
- The tag does not need to exist.
- The site does not need to reflect the new release.

### Watch for
- A working-tree change after the release-prep commit means the commit is stale. Either fold the change in by amending the release-prep commit (preferred when the branch has not been pushed) or roll it forward in a follow-up commit that documents what changed.
- If `check_reachable_history.rb` finds a literal at an earlier commit on the branch that the working tree has fixed, **amend or squash** to remove it from history rather than adding a forward commit. The working-tree fix does not address the history defect.

---

## Stage 3 — Tagged but not deployed

You are here once the release-prep branch has been merged to `main` and the `vX.Y.Z` tag has been pushed.

### Push order
The tag should be pushed **before or atomically with** main, because the site interpolates the release tag into source-link URLs (`site/index.html:576-654`). If main lands first and the tag is pushed seconds later, source links 404 briefly. Recommended single transaction:

```sh
git push origin vX.Y.Z main
```

Or, if pushing separately:

```sh
git push origin vX.Y.Z
git push origin main
```

### Required
- [ ] CI tag-validation run for `refs/tags/vX.Y.Z` is `success`.
- [ ] CI release job for the tag is `success`, and the GitHub release at `https://github.com/everypivot/everypivot/releases/tag/vX.Y.Z` exists with the five release assets:
  - `registry-index.json`
  - `release-manifest.json`
  - `patterns.tar.gz`
  - `fixtures.tar.gz`
  - `everypivot-release-pack-vX.Y.Z.tar.gz`
- [ ] `git ls-remote https://github.com/everypivot/everypivot.git refs/tags/vX.Y.Z` returns a tag object that dereferences to the merge commit on `main`.

### Not required at this stage
- The Pages deploy may not have finished. `everypivot.io` may still serve the previous release for a few minutes.

### Watch for
- If the release job fails, do not push a second tag with the same version to retry. Investigate, fix on `main`, and either re-tag with a patch version (`vX.Y.(Z+1)`) or — only after explicit decision — delete and re-create the tag while no consumer has fetched it.

---

## Stage 4 — Deployed

You are here once the Pages workflow for the merge to `main` has finished.

### Required
- [ ] `https://everypivot.io/` returns HTTP 200.
- [ ] `https://everypivot.io/data/registry-index.json` returns the new `release`, `published_at`, and `counts`.
- [ ] `https://everypivot.io/artifacts/release-manifest.json` returns the new `release`, `published_at`, and the `site` paths advertised actually resolve (`tools/check_release_metadata.rb --probe-live https://everypivot.io` exits zero).
- [ ] At least one promoted-or-changed pattern's source link (`https://github.com/everypivot/everypivot/blob/vX.Y.Z/graph-pivots/.../<id>.yaml`) returns 200.
- [ ] Counts match the manifest: README, CHANGELOG, release notes, registry-index, manifest, and the live homepage agree.

### Post-deploy

- [ ] Confirm the release is reproducible from public files alone: download the release pack, unpack it, and run `ruby tools/validate_pivots.rb --strict-metadata`, `ruby tools/check_fixture_suite.rb`, and `ruby tools/check_cti_promotion_lint.rb` from inside the unpacked pack.
- [ ] Monitor public issues and PRs for any credible challenge raised against the new release.

---

## Commit-message expectations

A release commit's message should describe its content. The body is the place the release surface is documented; treat it as a permanent record, not as a chore.

### One-line subject is appropriate when

- The diff is a metadata-only bump: version string, release-date pin, regenerated artifacts, no new public surface.
- The diff is a fast-follow correction to a tag (e.g. `chore: correct release-date pin on vX.Y.Z`).

### A descriptive body is required when the diff includes any of

- New or removed doctrine documents.
- New or significantly changed tooling, validators, or CI gates.
- Pattern promotions, demotions, or schema-version changes.
- Changes to public claims (licensing, governance, validation semantics).
- Public-readiness fixes (REUSE coverage, manifest contract, secret-pattern scope).

### Body structure

Use labelled sections. Each section names the change category and lists the concrete changes:

```
release(vX.Y.Z): short subject describing the headline change

One- or two-sentence overview.

Doctrine and tooling
- ...

Promoted patterns
- ...

Synthetic traversal evidence
- ...

Public-readiness fixes
- ...

Regenerated artifacts and site data
- ...

Counts: A validated / B working_set / C deferred (T total).
Schema unchanged at pivot-pattern vN.M.

Signed-off-by: EveryPivot <github@everypivot.io>
```

The convention of one-line subjects observed in earlier release commits (`release: prepare v0.4.0 public metadata`) is fine for releases whose body is genuinely "we bumped the version and regenerated the artifacts". It is not fine for releases that change what the public can do with the project. Match the convention to the release, not the release to the convention.

---

## What this playbook deliberately does not cover

- **Whether to release at all.** That is a maintainer decision, informed by `REPO_SCOPE.md`, the validated-lane criteria, and any open credible challenges. This playbook assumes the decision has been made.
- **Cross-release strategy.** Roadmap, deprecations, and lifecycle changes across multiple releases belong in `ROADMAP.md` and `GOVERNANCE.md`.
- **Incident response.** If a public release has to be retracted, demoted, or hot-fixed, follow `docs/CONTRIBUTING_AND_PROMOTION.md` and the doctrine sections on demotion and re-review.

## Known limits

- The reachable-history check (`tools/check_reachable_history.rb`) scans for known secret-shaped patterns. It does not detect novel secret formats or natural-language secrets (e.g. an internal codename in prose). Pair with `tools/check_cti_promotion_lint.rb` and manual review.
- The live-probe extension (`tools/check_release_metadata.rb --probe-live`) checks declared paths resolve over HTTP. It does not detect *semantic* drift (e.g. the live manifest pointing to a path that returns 200 but serves the wrong content).
- `reuse lint` covers REUSE/dep5 compliance. It does not check that the *licenses themselves* are appropriate for each file's content — that remains a maintainer judgment.

Each tool's limit is named so reviewers know what the green light does not cover.
