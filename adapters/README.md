# Adapter And Query Profiles

Adapter material lives outside the core pattern schema. Pattern YAML stays
backend-neutral; backend names, labels, property mappings, generated query
shape, and demo fixtures live here.

Current pilot:

- [`query-profiles/neo4j_cypher_v0.yml`](query-profiles/neo4j_cypher_v0.yml)
  defines the first Neo4j/Cypher profile.
- [`neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher`](neo4j/generated/OSINT_SSH_HOSTKEY_CLUSTER.cypher)
  is a generated demo query for the validated SSH host-key pattern.

Run the profile checks with:

```bash
ruby tools/check_query_profile_suite.rb
```

The pilot is deliberately narrow. It proves that adapter metadata can translate
one validated pattern into backend-specific query text while carrying hazards
and blocked assertions forward, without adding backend fields to pattern YAML.
