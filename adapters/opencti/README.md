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
`x_everypivot_*` custom properties on non-File STIX objects. File SCO IDs use
only STIX 2.1 ID-contributing properties; the custom `x_imphash` hash key is
preserved as observable data but not used as a UUID input. The bundle does not
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
