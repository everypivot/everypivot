# Package/repository provenance fixtures

All inputs here are synthetic, use reserved example domains, and are licensed
under CC BY 4.0 like other fixture material. They do not record real package
provenance, an attestation, a maintainer review or native adapter acceptance.

- `version-declaration.record.json` preserves a version-specific source
  declaration with no known source revision. It must remain evidence-only with
  an unresolved snapshot even when a local repository is supplied.
- `mirror-reference.record.json` preserves a mirror pointer as `mirror_reference`;
  it must not be relabeled as a qualifying `declares_source_repository` edge.
- The matching `.source.json` files contain the synthetic source documents.
  Their exact byte digests appear in each record's evidence anchor.
- `snapshot-v1.vector.json` is a fixed independent digest vector for one
  committed `hello.txt` file, mode `100644`, containing the six bytes `hello` +
  LF. It also gives the digest for the empty tree. It is a digest vector, not
  a provenance record. JSON formatting itself is not the hashed representation.

Run `ruby tools/test_package_repository_provenance.rb` from the repository root.
The suite creates disposable local Git repositories to test exact commits,
dirty/current-tree isolation, changed contents/modes, symbolic links, repeated
content across commits, unsupported LFS/submodule content, identity mismatches,
and CLI output safety. The fixed vector checks the documented method against
an expectation calculated independently of the Ruby implementation.

The helper does not fetch or authenticate source documents. Its `--check` mode
validates supplied structure and manifest self-consistency, not repository
content or build provenance. These fixtures have their own narrow oracle and
are separate from the four one-hop traversal evidence packs. They do not test
the two patterns' infrastructure hops, temporal windows, suppression, degree
caps, source independence or assessment acceptance. See
[`PACKAGE_REPOSITORY_PROVENANCE.md`](../../docs/PACKAGE_REPOSITORY_PROVENANCE.md).
