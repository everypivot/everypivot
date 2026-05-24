# Start Here: SSH Host Key Cluster

Use this walkthrough when you want to understand one EveryPivot pattern end to
end before browsing the full corpus.

This example uses only reserved example domains, reserved example IP ranges, and
synthetic keys. It is a mechanics example, not live intelligence.

## Pattern

- Pattern: [`OSINT_SSH_HOSTKEY_CLUSTER`](../graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml)
- Lifecycle lane: `validated`
- Source node form: `ssh:hostkey`
- Target node form: `inet:ipv4|inet:fqdn`
- Hop relation: `presented_by`
- Hop direction: `out`
- Temporal window: 730 days
- Evidence pack: [`fixtures/examples/osint_ssh_hostkey_cluster.evidence.json`](../fixtures/examples/osint_ssh_hostkey_cluster.evidence.json)

## Source Node

Start with one normalized SSH host key fingerprint:

```text
ssh-hostkey:sha256:example-ed25519-7f3b
```

The pattern asks a narrow question: which hosts or names presented this exact
SSH host key inside the permitted window, after suppression controls are
applied?

## Evidence Pack

The fixture contains four candidate edges from the source key and one negative
control edge for a different key:

```text
ssh-hostkey:sha256:example-ed25519-7f3b
  presented_by -> inet:fqdn:jump-01.ops.example.net
  presented_by -> inet:ipv4:203.0.113.17
  presented_by -> inet:ipv4:198.51.100.44
  presented_by -> inet:ipv4:198.51.100.23
ssh-hostkey:sha256:example-rsa-912c
  presented_by -> inet:ipv4:203.0.113.88
```

The first two targets are expected traversal results. The third is suppressed by
a negative-node list. The fourth is stale. The final edge proves the negative
control: a host that presented a different key does not join this cluster.

## Expected Traversal

For this pattern, traverse outbound from the `ssh:hostkey` source over
`presented_by` edges and return targets with form `inet:ipv4` or `inet:fqdn`.

Expected included targets:

- `inet:fqdn:jump-01.ops.example.net`
- `inet:ipv4:203.0.113.17`

The traversal result should carry evidence paths and feature material, not a
final analytic judgment. In the pattern YAML, the configured output includes
`source`, `target`, `features`, `evidence_paths`, and `storm_query`.

## Negative-Node Suppression

The pattern publishes suppression controls:

```yaml
negative_nodes:
  - form: inet:ipv4
    list: known_scanner_asns
  - form: inet:ipv4
    list: shared_hosting_ranges
```

In the fixture, `inet:ipv4:198.51.100.44` is marked as a
`shared_hosting_ranges` member. A downstream graph engine should suppress that
target before showing the result as a meaningful cluster candidate.

Negative-node suppression is not optional decoration. Without it, host-key reuse
from scanners, shared hosting, golden images, or failed key rotation can produce
large and misleading clusters.

## Stale-Edge Caveat

The pattern's temporal control is a 730-day window. In the fixture,
`inet:ipv4:198.51.100.23` has a `presented_by` observation from `2023-01-15`,
which falls outside the example traversal window. Treat that edge as stale for
the first-use result.

Stale SSH host-key observations can remain historically true while no longer
supporting a current pivot. Keep the edge as historical evidence if your system
stores it, but do not present it as a current match without an explicit
historical mode.

## Fixture Roles

This evidence pack includes `positive`, `suppression`, and `negative` roles.
Those roles are part of the public fixture contract:

- `positive` examples show what should be returned.
- `suppression` examples show evidence that may exist but should not be shown
  as an ordinary current match.
- `negative` examples show plausible-looking graph material that must not join
  the source and candidate target.

## Forbidden Conclusions

This pattern is useful because exact SSH host-key reuse is a strong mechanical
link. It still does not prove the following by itself:

- common ownership;
- operator identity;
- malware family, campaign, or actor attribution;
- maliciousness;
- compromise;
- exclusive control of every returned host;
- a final confidence score.

`validated` means the pattern is curated enough to feature in the public
registry. It does not mean every runtime match is true, malicious, attributed,
or finally assessed. Downstream systems must apply suppression, temporal
windows, corroboration, scoring, and case-specific judgment.
