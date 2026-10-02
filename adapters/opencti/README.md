# OpenCTI/STIX Mapping Pilot

This directory contains the first bounded OpenCTI/STIX-side mapping artifact.
It is a generated STIX 2.1 bundle pressure test, not a live OpenCTI connector.

Files:

- [`../query-profiles/opencti_stix_v0.yml`](../query-profiles/opencti_stix_v0.yml)
  defines the mapping profile metadata.
- [`generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json`](generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json)
  is generated from the validated import-hash pattern plus the synthetic STIX
  mapping fixture.
- [`../../fixtures/query-profiles/opencti/cti_sample_imphash_cluster.stix_mapping.json`](../../fixtures/query-profiles/opencti/cti_sample_imphash_cluster.stix_mapping.json)
  provides the fixture slice used by the generated bundle.
- [`schemas/x_everypivot_toplevel_extension.schema.json`](schemas/x_everypivot_toplevel_extension.schema.json)
  documents the `x_everypivot_*` properties emitted on observed-data,
  relationship, and note objects.

The generated bundle maps the included import-hash traversal into STIX file,
observed-data, relationship, and note objects. It carries EveryPivot caveats,
blocked assertions, fixture boundaries, and suppressed target metadata through
`x_everypivot_*` custom properties on observed-data, relationship and note.
File SCO IDs select MD5, SHA-1, SHA-256, SHA-512 in that order, then the
lexically first remaining hash (including `x_imphash`), plus nonempty name. The bundle does not
emit confidence, attribution, maliciousness, compromise, ownership, final
assessment, OpenCTI workflow state, or connector metadata.

Regenerate the demo bundle with:

```bash
ruby tools/generate_stix_mapping_profile_demo.rb \
  --profile adapters/query-profiles/opencti_stix_v0.yml \
  --pattern-id CTI_SAMPLE_IMPHASH_CLUSTER \
  --output adapters/opencti/generated/CTI_SAMPLE_IMPHASH_CLUSTER.bundle.json
```

Validate it with:

```bash
ruby tools/check_query_profile_suite.rb
```

## Validation boundaries

The generator validates complete UTC timestamp syntax, calendar dates, and the
local EveryPivot extension-property schema before replacing its output. Date-only
observations become midnight UTC; supported timestamp text is preserved.
Leap-second (`:60`) timestamp inputs are explicitly unsupported and rejected;
ordinary UTC seconds 00–59 are supported. This is an input limitation, not a
claim that real leap seconds are invalid STIX. The fixture
suite checks both inclusive calendar-window endpoints relative to `as_of`. This
checks consistency of an already-selected fixture slice; it does not make the
serializer a traversal engine or enforce temporal ordering, caps, or ranking.

Run the bounded regressions with `ruby tools/test_stix_mapping_validation.rb`.
These checks do not establish full STIX conformance or OpenCTI compatibility.
Profile 0.2.1 includes the EveryPivot Project group Identity and a distinct
replacement extension identifier. The Identity is
provenance for the extension only, carries no EveryPivot evidence metadata, and
remains subject to all forbidden authority-property checks. The closed profile
requires exactly one included creator; generic STIX may use external references.

See [MIGRATION.md](MIGRATION.md) for the explicit File-ID migration, published
extension treatment, separate version axes, and consumer migration requirements.
The candidate has seven objects. Native OpenCTI compatibility remains untested.
