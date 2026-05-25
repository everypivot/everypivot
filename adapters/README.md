# Adapter And Query Profiles

Adapter material lives outside the core pattern schema. Pattern YAML stays
backend-neutral; backend names, labels, property mappings, generated query
shape, and demo fixtures live here.

Current pilot:

- [`query-profiles/neo4j_cypher_v0.yml`](query-profiles/neo4j_cypher_v0.yml)
  defines the first Neo4j/Cypher profile and its declared demo targets.
- [`neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher`](neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher)
  is a generated outbound demo query for the validated SSH host-key pattern.
- [`neo4j/generated/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.cypher`](neo4j/generated/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.cypher)
  is a generated inbound demo query for a working-set email-originating-IP
  pattern.

Run the profile checks with:

```bash
ruby tools/check_query_profile_suite.rb
```

The pilot is deliberately narrow. It proves that adapter metadata can translate
declared pattern targets into backend-specific query text while carrying hazards
and blocked assertions forward, without adding backend fields to pattern YAML.

License boundary:

- adapter metadata, docs, tools, and generated queries under `adapters/` are
  Apache-2.0 code/tooling material;
- synthetic graph fixtures and fixture loaders under `fixtures/` are CC BY 4.0
  fixture material.
