# Pinned SAIL v0.4 DRAFT bridge contracts

The three JSON contracts, `LICENSE`, and `NOTICE` are unmodified copies from
[SAIL commit 3b23012b1ec78cc2a65e093c14d06b6318675c16](https://github.com/sailspec/sail/tree/3b23012b1ec78cc2a65e093c14d06b6318675c16).
The vendored implementable contracts are licensed under Apache 2.0. Upstream
SAIL prose uses CC BY 4.0. The copied upstream `NOTICE` retains references to
SAIL's [licensing documentation](https://github.com/sailspec/sail/blob/3b23012b1ec78cc2a65e093c14d06b6318675c16/LICENSE-AND-GOVERNANCE.md)
and [trademark policy](https://github.com/sailspec/sail/blob/3b23012b1ec78cc2a65e093c14d06b6318675c16/TRADEMARKS.md);
those references concern the upstream repository.

`manifest.json` records the source repository, commit, source paths, license,
and SHA256 for every vendored upstream file. The checker pins the manifest
SHA256 in code and verifies all files before evaluating any pattern. Missing,
corrupt, truncated, or substituted contracts are a blocking error. Refreshing
this pack requires an explicit reviewed contract update; there is no network
fetch or private sibling-repository dependency at runtime.

The pivot JSON Schema checks document shape. Full predicate, role-or-kind,
and subject-specific scope compatibility requires the common bridge checker:

```sh
ruby tools/check_sail_bridge.rb graph-pivots --json --strict-incomplete
ruby tools/validate_pivots.rb graph-pivots --strict-metadata --strict-bridge
ruby tools/test_sail_bridge.rb
```

The JSON command reports `evidence_only`, `candidate_compatible`, `incomplete`,
and `incompatible` separately, plus deprecated structural-role use. Exit code
0 means the selected checks passed, 1 means incompatible hints (or incomplete
coverage in strict mode), and 2 means inputs or pinned contracts could not be
checked. A missing hint on a legacy pattern is not inferred to be an explicit
v1.5 evidence-only disposition.

The Ruby API is `EveryPivot::SailBridge.new(repo_root: root)`,
`checker.check(pattern, path: relative_path)`, and `checker.contract_info`.
The constructor raises `EveryPivot::SailBridge::ContractError` if the pack
cannot be verified. The checker applies SAIL's disjunctive object-role OR
object-kind rule and preserves its deprecated structural-role compatibility.
It never fills in a missing subject role or silently changes a scope.

These checks concern documentary candidate shape only. They do not validate
evidence, interpret a match as proof, assign runtime confidence, or accept an
analytical conclusion. A v1.5 candidate's `assessment_requirements` describe
qualifying evidence; their presence does not establish that evidence exists.
