# JA3 and JA3S semantic cases

These are independently authored **synthetic normalized-source cases** for the
client and server execution contracts. They are not a PCAP parser, internet
scan result, deployed collector, native adapter, source-authenticity check or
analyst acceptance record.

`source.json` is the preserved fixture source; `evidence.json` records its exact
SHA-256, revision, field pointers and normalized object/occurrence identities.
The tests check the source pointers, timestamps and reported selectors against
that content. `expected.json` states expected case results before execution.
The additional adversarial mutations are authored in `test_semantic_ja3.rb`.

```sh
ruby tools/test_semantic_ja3.rb
ruby tools/evaluate_semantic_pattern.rb \
  --pattern graph-pivots/working-set/OSINT_TLS_JA3_TO_FQDNS.yaml \
  --evidence fixtures/semantic-families/ja3/evidence.json \
  --query fixtures/semantic-families/ja3/client-query.json
```

The client message at 30 September 2026 23:59:50 UTC and server response at
1 October 00:00:10 UTC have separate period membership. Tests distinguish an
actual named attempt from a planned scan, wrong exchange/leg, DNS/SAN clue,
missing response, differently typed fingerprint, later derivation/receipt,
replay, independent later message, explicit filtering, conflicting classification
and partial execution. Optional context remains unknown when missing. An
as-known result concerns the named-message assertion support and its actual
derivation/establishment/receipt witnesses, not unrecorded analyst awareness or
automatic historical certification of optional classification context.
