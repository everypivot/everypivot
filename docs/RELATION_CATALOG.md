# Relation Catalog

## Scope

This catalog is the v0.2.0 public inventory of EveryPivot relation and form
vocabulary. It is guidance only.

It does not add schema fields, warning lints, sidecar metadata, inheritance, or
runtime portability scoring. Those belong to later work after the vocabulary is
reviewed in public.

Inventory date: 2026-05-24.

Current corpus snapshot:

- 176 patterns.
- 112 distinct `source` values.
- 66 distinct `target` values.
- 204 distinct `hops[].via` values.
- 94 distinct `hops[].form` values.

## Naming Rules

Use forms to name observable node types and relations to name traversable
edges.

- Forms should be nouns or noun phrases, such as `inet:fqdn`, `file:bytes`,
  `x509:cert`, or `email:message`.
- Relations should be short edge phrases, such as `presented_by`,
  `observed_in`, `hosted_by`, or `listed_as`.
- Prefer a specific relation when the edge semantics are materially different.
- Prefer an existing relation when only the data source or collection method is
  different.
- Do not encode confidence, scoring, or final assessment in a relation name.
- Do not encode vendor names in form or relation names unless the underlying
  form is vendor-specific.
- Values joined with `|` are current compatibility vocabulary. They usually
  mean "one of these forms" or "one of these relation shapes"; they are not an
  inheritance model.

## Entity Namespaces

Observed namespace prefixes should stay plain and domain-readable:

| Namespace | Primary use |
| --- | --- |
| `inet` | DNS names, IP addresses, URLs, and web accounts. |
| `x509`, `ssh`, `tls` | Cryptographic and protocol identity material. |
| `file`, `hash`, `pe` | Files, samples, hashes, PE metadata, and extracted features. |
| `email`, `mail` | Messages, sender material, DKIM, DMARC, and mail-routing evidence. |
| `http`, `web`, `javascript`, `url` | Web requests, pages, scripts, DOM/content fingerprints, and URL parts. |
| `cloud`, `auth`, `identity`, `device`, `endpoint` | Cloud, identity, authentication, endpoint, and device handles. |
| `code`, `app`, `it` | Repositories, packages, products, software versions, and development artifacts. |
| `fin`, `crypto`, `ledger`, `sanction`, `lei` | Financial, crypto, transaction, sanctions, and entity-identifier material. |
| `org`, `person`, `geo`, `social`, `telecom`, `travel` | Human, organization, location, social, telecom, and travel linkage observations. |
| `risk`, `malware`, `phish`, `c2`, `reputation`, `abuse` | Security labels, threat/risk objects, malware infrastructure, and abuse records. |
| `adtech`, `osint`, `network` | Domain-specific advertising, OSINT marketplace, and network-service observations. |

New namespaces should be introduced only when an existing namespace would make
the pattern less clear.

## Semantic Families

Semantic families are grouping metadata for browsing and review. They do not
create inheritance, type compatibility, or promotion shortcuts.

| Family | Includes |
| --- | --- |
| `network_infrastructure` | `inet`, `net`, `network`, `x509`, `ssh`, `tls`, DNS, ASN, and service observations. |
| `sample_and_file` | `file`, `hash`, `pe`, malware payloads, code-signing material, and extracted file features. |
| `email_chain` | `email`, `mail`, attachments, sender/recipient material, protected URLs, and first-hop routing. |
| `web_surface` | `http`, `web`, `javascript`, URL components, pages, scripts, redirects, and client identifiers. |
| `endpoint_identity_cloud` | `endpoint`, `device`, `identity`, `auth`, `cloud`, sessions, tenants, subscriptions, and accounts. |
| `software_supply_chain` | `code`, `app`, `it:prod:*`, maintainers, repositories, packages, and release paths. |
| `financial_and_regulatory` | `fin`, `crypto`, `ledger`, `sanction`, `lei`, merchant, payout, refund, and regulatory-list pivots. |
| `human_linkage` | `person`, `org`, `geo`, `social`, `telecom`, `travel`, and other human-linkage observations. |
| `semantic_tokens` | OCR, QR payloads, prompt assets, strings, titles, banners, and derived text tokens. |
| `software_modularity` | Functions, modules, SBOM dependencies, section hashes, resource sections, and compile/build artifacts. |

## Facet Vocabulary

Facets are proposed review vocabulary. They are typed enough to avoid becoming
arbitrary tags, but they are not schema fields in v0.2.0.

| Facet | Use when the pivot is primarily about |
| --- | --- |
| `path_observation` | A path, route, redirect, link, URL component, or traversal path. |
| `web_surface` | Web pages, scripts, DOM/title/body/header fingerprints, web accounts, or client IDs. |
| `email_chain_stage` | First-hop MTA, protected URL, attachment, message ID, sender domain, or final URL stage. |
| `endpoint_handle` | Endpoint UID, device UID, file path on endpoint, DNS cache, process, or egress IP. |
| `identity_handle` | User UID, auth session, web account, phone number, social handle, or account identifier. |
| `cloud_resource` | Cloud tenant, subscription, bucket, app ID, web app, or cloud account. |
| `supply_release_path` | Package, repository, maintainer, signing certificate, product version, or SBOM relationship. |
| `regulatory_list` | Sanctions, LEI, registered address, officer, beneficial owner, or regulated entity linkage. |
| `human_linkage_observation` | Person, organization, travel, telecom, proximity, address, or social linkage. |
| `semantic_token` | OCR text, QR payload, prompt asset, embedded config string, or extracted human-readable token. |
| `software_modularity` | Function name, module, section hash, compile time, resource section, or dependency relationship. |

## Portability Classes

Portability classes are review guidance only in v0.2.0. Do not add them to
pattern YAML, sidecars, registry data, or generated artifacts yet.

| Class | Meaning |
| --- | --- |
| `domain_agnostic` | The relation is broadly portable across CTI, fraud, abuse, or infrastructure analysis without domain-specific assumptions. |
| `domain_portable_with_caveats` | The relation transfers across domains, but caveats, suppression, or interpretation differ materially by domain. |
| `domain_specific` | The relation is useful mainly in one domain vocabulary, such as sanctions, adtech, telecom, or software supply chain. |
| `environment_specific` | The relation depends on local telemetry, deployment conventions, internal identifiers, or enterprise-specific collection. |
| `composite_only` | The relation should not be treated as an atomic positive claim without additional pivots, corroboration, or orchestration. |

## Inverse And Companion Candidates

These candidates are review notes, not schema semantics. They should not be
treated as parent/child relationships.

| Candidate set | Notes |
| --- | --- |
| `presented_by`, `presented_at`, `rdp_presented_at`, `tls_cert` | Certificate/key presentation relations need direction and protocol clarity. |
| `hosted_by`, `hosted_on`, `hosted_at`, `hosts`, `has_host` | Hosting relations mix provider, location, and containment semantics. |
| `registered`, `registered_to`, `registered_address_of` | Registration relations need clearer subject/object direction. |
| `resolves_to`, `resolved_from`, `resolved_or_cached`, `reverse_resolves` | DNS and cache relations should separate current resolution, passive history, and reverse lookup. |
| `contains`, `contains_url`, `embedded_in`, `embedded_in_file`, `embedded_in_page` | Containment and embedding relations are companions, not strict inverses in every data source. |
| `attached_to`, `sent_attachment`, `attachment_named`, `attachment_cluster_hash` | Attachment relations need message-stage clarity. |
| `listed_as`, `listed_by`, `classified_as`, `reputation_of` | List and reputation relations should preserve source-list semantics. |
| `signs`, `signs_or_describes`, `derived_from_certificate` | Signing and certificate-derived relations should distinguish issuer material, signer identity, and derived hashes. |
| `has_mx`, `mx_for`, `receives_reports_for` | Mail infrastructure relations need role-specific naming. |
| `owned_by`, `owns`, `beneficial_owner_of`, `officer_of|director_of` | Organization and ownership relations require caution around legal meaning and jurisdiction. |

## Deprecation Notes

No relation or form value is deprecated in v0.2.0.

Known cleanup pressure:

- Compound values containing `|` are useful compatibility markers today, but
  they should be reviewed before any future lint treats relation or form
  vocabulary as closed.
- Directional pairs such as `hosted_by`/`hosts` and
  `resolves_to`/`resolved_from` need explicit guidance before warning-only
  lints can be fair.
- Domain-specific legal, financial, telecom, and human-linkage forms should
  keep conservative names. Do not make them sound more precise than the
  underlying source evidence.
- Future deprecation should follow a public sequence: document the preferred
  value, add warning-only lint, provide migration notes, then consider schema
  enforcement later.

## Current Inventory

Counts below are exact for the v0.2.0-prep corpus on 2026-05-24.

<details>
<summary>Source forms</summary>

- `adtech:dsp:id` (1)
- `adtech:impression:id` (1)
- `app:developer` (1)
- `auth:session` (2)
- `c2:config:key` (1)
- `cloud:account` (1)
- `cloud:application:uid|oauth:application:uid` (1)
- `cloud:bucket` (2)
- `cloud:subscription:uid` (1)
- `cloud:tenant:uid` (2)
- `cloud:webapp|inet:fqdn|inet:url` (1)
- `code:authenticode:hash` (1)
- `code:repo` (3)
- `crypto:address` (2)
- `device:device` (2)
- `domain:registration:profile` (1)
- `email:addr` (1)
- `email:attachment:name` (1)
- `email:final_url` (1)
- `email:header:value` (1)
- `email:message` (2)
- `email:message:id:host` (1)
- `email:protected_url` (1)
- `email:sender:domain` (1)
- `email:url_click` (1)
- `endpoint:process` (1)
- `endpoint:uid` (4)
- `file:av_cluster_hash` (1)
- `file:bytes` (3)
- `file:bytes|message:prompt` (1)
- `file:feature:function_name` (1)
- `file:feature:string` (1)
- `file:hash` (2)
- `file:lshash` (1)
- `file:metadata:compile_time` (1)
- `file:name` (1)
- `file:origin:url` (1)
- `file:path` (1)
- `file:pe:imphash` (1)
- `file:pe:section:hash` (1)
- `file:resource_section:hash` (1)
- `file:source_path` (1)
- `fin:account` (4)
- `fin:merchant:descriptor` (1)
- `geo:address` (2)
- `geo:place` (1)
- `graph:cluster` (1)
- `hash:sha256` (2)
- `http:body:hash` (1)
- `http:headers:fingerprint` (1)
- `http:redirect:fingerprint` (1)
- `http:request` (2)
- `http:server_header` (1)
- `http:status_line` (1)
- `http:uri:path_pattern` (1)
- `identity:user:uid` (2)
- `image:ocr:text_hash` (1)
- `inet:fqdn` (12)
- `inet:fqdn:mx` (1)
- `inet:fqdn:ns` (2)
- `inet:ipv4` (5)
- `inet:ipv4|inet:fqdn` (1)
- `inet:ipv4|inet:fqdn|inet:url` (1)
- `inet:url` (3)
- `inet:url|inet:fqdn` (1)
- `intel:observable` (1)
- `it:dev:pdb:path` (1)
- `it:device:fingerprint` (1)
- `it:exec:mutex` (1)
- `it:prod:soft` (1)
- `it:prod:softver` (2)
- `it:sec:vuln` (1)
- `javascript:hash|web:behavior:fingerprint` (1)
- `mail:dkim:key` (1)
- `mail:dmarc:rua` (1)
- `malware:config:string|web:content:token` (1)
- `net:asn` (2)
- `network:fingerprint:hassh` (1)
- `network:service:probe_response` (2)
- `org:org` (3)
- `osint:marketplace:listing` (1)
- `osint:marketplace:sale` (2)
- `pe:rich:hash` (1)
- `person` (5)
- `phish:kit` (1)
- `rdap:email` (1)
- `rdap:registrant` (1)
- `risk:campaign` (1)
- `risk:threat` (3)
- `social:handle` (3)
- `ssh:hostkey` (1)
- `tel:phone|fin:instrument` (1)
- `telecom:msisdn` (1)
- `tls:ja3` (1)
- `travel:pnr` (1)
- `url:component_hash` (1)
- `visual:qr_payload` (1)
- `web:asset` (1)
- `web:behavior:fingerprint` (1)
- `web:client:uid` (4)
- `web:cookie:name` (1)
- `web:creative` (1)
- `web:dom:structure_hash` (1)
- `web:http:title` (1)
- `web:page` (1)
- `web:search:query` (1)
- `web:site` (1)
- `web:tracking:id` (1)
- `x509:cert` (9)
- `x509:cert:lifetime_profile` (1)
- `x509:cert:profile` (1)
- `x509:subject` (1)

</details>

<details>
<summary>Target forms</summary>

- `auth:event` (1)
- `auth:event|auth:session` (1)
- `auth:session` (1)
- `cloud:subscription:uid` (1)
- `cloud:tenant:uid` (1)
- `device:device` (2)
- `device:uid` (1)
- `dns:mx|inet:fqdn` (1)
- `email:message` (8)
- `email:message|inet:url` (1)
- `endpoint:uid` (2)
- `file:bytes` (9)
- `file:bytes|endpoint:uid` (1)
- `file:bytes|file:path|endpoint:uid` (1)
- `file:hash` (8)
- `file:hash|endpoint:file` (1)
- `file:hash|x509:cert` (1)
- `file:image|inet:url` (1)
- `file:path` (1)
- `fin:account` (1)
- `fin:account|fin:merchant|org:org` (1)
- `fin:account|person` (1)
- `fin:merchant` (2)
- `fin:merchant|person` (2)
- `http:user_agent` (2)
- `identity:user:uid` (1)
- `identity:user|email:message` (1)
- `inet:fqdn` (30)
- `inet:fqdn|inet:ipv4` (1)
- `inet:fqdn|inet:ipv4|inet:url` (1)
- `inet:fqdn|inet:url` (3)
- `inet:ipv4` (6)
- `inet:ipv4|inet:fqdn` (17)
- `inet:ipv4|inet:fqdn|inet:url` (1)
- `inet:ipv4|inet:fqdn|network:connection` (1)
- `inet:ipv4|inet:fqdn|network:service` (1)
- `inet:ipv4|inet:fqdn|risk:campaign|threat:cluster` (1)
- `inet:url` (3)
- `inet:url|email:message` (2)
- `inet:url|http:request` (1)
- `inet:url|inet:fqdn` (4)
- `inet:url|inet:fqdn|http:response` (2)
- `inet:url|payment:address|identity:account|file:image` (1)
- `inet:web:acct` (6)
- `inet:web:acct|inet:fqdn` (1)
- `inet:web:acct|risk:campaign` (1)
- `it:prod:softver` (4)
- `it:service:rdp` (1)
- `lei:record` (1)
- `malware:payload|file:hash|malware:config` (1)
- `net:asn` (1)
- `net:asn|org:org` (1)
- `org:org` (5)
- `org:org|inet:fqdn` (1)
- `org:org|person` (2)
- `person` (3)
- `person|fin:account` (1)
- `risk:campaign` (3)
- `risk:incident` (1)
- `risk:observation` (1)
- `risk:threat` (1)
- `sanction:entry` (8)
- `telecom:msisdn` (1)
- `telemetry:sighting` (1)
- `web:admin:surface` (1)
- `web:client:uid` (1)

</details>

<details>
<summary>Hop relation values</summary>

- `accessed_from_ip` (2)
- `advertises` (1)
- `announced_by` (1)
- `announces` (1)
- `announces|hosts_many` (1)
- `appears_in` (1)
- `appears_in_message_id` (1)
- `associated_identity` (1)
- `associated_message` (2)
- `associated_session` (1)
- `associated_with` (2)
- `attached_to` (3)
- `attachment_cluster_hash` (1)
- `attachment_named` (1)
- `authenticated_in` (1)
- `authoritative_for` (2)
- `behavior_observed_on_page` (1)
- `belongs_to` (1)
- `belongs_to_subscription` (1)
- `beneficial_owner_of` (1)
- `bgp_origin|asn_of` (2)
- `body_of` (1)
- `bound_to` (1)
- `bt_seen_within` (1)
- `carries` (1)
- `carries_identifier` (1)
- `cashed_out_via` (1)
- `cdr_event` (1)
- `classified_as` (1)
- `clicked_by` (1)
- `co_occurs_with` (1)
- `collects_payments_via` (1)
- `communicates|c2|hosts` (1)
- `communicates|hosts|connects` (1)
- `communicates|hosts|connects|c2` (2)
- `communicates|relays_through` (1)
- `compile_time_of` (1)
- `component_of` (1)
- `configured_in` (1)
- `connected_to` (1)
- `contained_by_tenant` (1)
- `contains` (1)
- `contains_auth_event` (1)
- `contains_payload` (1)
- `contains_url` (2)
- `cookie_name_observed_on` (1)
- `counterparty` (1)
- `ct_subject_alt_name` (1)
- `declares_role` (1)
- `decoded_from_image` (1)
- `decodes_to` (1)
- `depended_on_by` (1)
- `derived_from_certificate` (1)
- `distributed_by|attributed_to` (1)
- `distributed_from|referenced_by` (1)
- `distributes` (1)
- `dom_structure_observed_on` (1)
- `domain_of` (1)
- `downloaded_as` (1)
- `embedded_in` (5)
- `embedded_in_file` (1)
- `embedded_in_page` (1)
- `embedded_in_web_content` (1)
- `embeds` (1)
- `emitted_by` (1)
- `employed_by|owns` (1)
- `enumerated_subdomain` (1)
- `exploited_by|mentioned_with` (1)
- `exposes` (1)
- `exposes_route` (1)
- `final_host` (1)
- `first_hop_mta` (1)
- `first_hop_mta_for` (1)
- `for` (1)
- `function_name_extracted_from` (1)
- `groups` (2)
- `has_host` (6)
- `has_lei` (3)
- `has_mx` (1)
- `has_query_param` (1)
- `has_user_agent` (1)
- `hashes_to` (2)
- `header_fingerprint_observed_on` (1)
- `header_value_present` (1)
- `held_by|used_by` (1)
- `hosted` (1)
- `hosted_at` (3)
- `hosted_by` (6)
- `hosted_on` (2)
- `hosted_on|used_by` (1)
- `hosts` (3)
- `hosts|resolves|pdns_resolves` (1)
- `http_favicon_hash` (2)
- `identified_by` (1)
- `image_observed_on` (1)
- `includes_passenger` (1)
- `links_to` (2)
- `listed_as` (8)
- `listed_by` (1)
- `lists|offers` (1)
- `loads` (1)
- `maintained_by|authored_by` (1)
- `maintains|publishes` (1)
- `maps_to_device_uid` (1)
- `matched_by` (1)
- `matches_profile` (2)
- `mx_for` (1)
- `observed_as` (1)
- `observed_as_name` (1)
- `observed_at` (1)
- `observed_at_path` (1)
- `observed_in` (8)
- `observed_in_auth_event` (1)
- `observed_in_request` (4)
- `observed_on` (7)
- `observed_on_bssid` (2)
- `observed_on_service` (1)
- `observed_path` (1)
- `observed_with` (1)
- `observed_with_client` (1)
- `ocr_text_extracted_from` (1)
- `officer_of|director_of` (2)
- `opened_connection` (1)
- `operated_by` (1)
- `operated_via|distributed_from` (1)
- `originating_ip_for` (1)
- `owned_by` (3)
- `owns` (1)
- `owns_account` (1)
- `parent_of|ultimate_parent` (1)
- `passive_dns_subdomain` (1)
- `path_observed_on_url` (1)
- `payload_resolves_to` (1)
- `points_to_host` (1)
- `posted_by|redirects_to` (1)
- `posted_by|used_by` (1)
- `present_on` (1)
- `presented_at` (6)
- `presented_by` (2)
- `profile_matches_domain` (1)
- `promoted_by|referenced_by` (1)
- `published_from` (1)
- `publishes` (2)
- `rdp_presented_at` (1)
- `reaches` (1)
- `received_payment_from` (1)
- `receives_payout_for` (1)
- `receives_refund_for` (1)
- `receives_reports_for` (1)
- `redirects_to` (2)
- `referenced_by` (2)
- `referenced_by|hosts` (1)
- `references` (1)
- `references|hosts` (1)
- `refs` (1)
- `registered` (2)
- `registered_address_of` (1)
- `registered_to` (2)
- `reputation_of` (1)
- `requested` (1)
- `resolved_from` (1)
- `resolved_or_cached` (1)
- `resolved_to` (1)
- `resolves_to` (1)
- `resolves|connects` (1)
- `resolves|pdns_resolves` (1)
- `resource_section_hash_of` (1)
- `reverse_resolves` (1)
- `routes_to` (1)
- `same_cell_same_time` (1)
- `same_kit_hash|similar_path` (1)
- `same_segment_within_window` (1)
- `sandbox_observed` (2)
- `section_observed_in` (1)
- `seen_in` (1)
- `sent_attachment` (1)
- `served_by` (1)
- `served_by_host` (1)
- `services` (1)
- `shares_officer|shares_address` (1)
- `ships_to|registered_at` (1)
- `signs` (4)
- `signs_or_describes` (1)
- `similar_to` (1)
- `sold_domain|transacted_domain` (2)
- `sourced_from` (2)
- `status_of` (1)
- `string_extracted_from` (1)
- `subject_org` (1)
- `submitted_by|used_by` (1)
- `submitted_for` (1)
- `supported_by` (1)
- `titled_page` (1)
- `tls_cert` (3)
- `touched_domain` (1)
- `to|from` (1)
- `trades_with` (1)
- `transfers_to|transfers_from` (3)
- `used_by` (7)
- `uses` (3)
- `uses_attribute` (1)
- `uses_domain` (1)
- `uses_email` (1)
- `uses|delivers|exploits` (1)

</details>

<details>
<summary>Hop forms</summary>

- `abuse:urlhaus:record` (1)
- `adtech:bundle` (1)
- `adtech:campaign:key` (2)
- `adtech:identifier` (1)
- `adtech:pipeline:phase` (1)
- `adtech:platform:role` (1)
- `app:mobile` (1)
- `auth:event` (2)
- `auth:session` (2)
- `c2:endpoint` (2)
- `cloud:bucket|cloud:service` (1)
- `cloud:subscription:uid` (1)
- `cloud:tenant:uid` (1)
- `code:repo` (2)
- `crypto:address` (1)
- `device:device` (2)
- `device:uid` (1)
- `dns:mx` (1)
- `email:addr` (1)
- `email:addr|tel:phone|geo:address` (1)
- `email:attachment` (2)
- `email:message` (12)
- `endpoint:file` (1)
- `endpoint:uid` (3)
- `file:bytes` (11)
- `file:hash` (11)
- `file:image` (2)
- `file:path` (1)
- `file:path|endpoint:uid` (1)
- `fin:account` (3)
- `fin:account|fin:merchant|org:org` (1)
- `fin:account|person` (1)
- `fin:merchant` (2)
- `fin:merchant|person` (2)
- `fin:processor` (1)
- `fin:transaction` (2)
- `forged:document` (1)
- `graph:evidence:path` (1)
- `hash:md5|hash:sha1` (1)
- `http:request` (6)
- `http:response` (2)
- `http:user_agent` (2)
- `identity:user` (1)
- `identity:user:uid` (1)
- `inet:fqdn` (44)
- `inet:fqdn|inet:ipv4` (3)
- `inet:fqdn|inet:ipv4|inet:url` (1)
- `inet:ipv4` (9)
- `inet:ipv4|inet:fqdn` (18)
- `inet:ipv4|inet:fqdn|inet:url` (1)
- `inet:ipv4|inet:fqdn|risk:campaign|threat:cluster` (1)
- `inet:url` (20)
- `inet:url|inet:fqdn` (2)
- `inet:url|payment:address|identity:account` (1)
- `inet:web:acct` (6)
- `inet:web:acct|inet:fqdn` (1)
- `inet:web:acct|risk:campaign` (1)
- `it:prod:soft` (5)
- `it:prod:softver` (5)
- `it:sec:vuln` (1)
- `it:service:rdp` (1)
- `ledger:tx` (2)
- `lei:record` (5)
- `malware:payload` (1)
- `net:asn` (3)
- `net:wifi:bssid` (1)
- `network:connection` (1)
- `network:service` (4)
- `org:org` (13)
- `org:org|person` (3)
- `person` (6)
- `person|fin:account` (1)
- `phish:kit` (1)
- `phish:kit|message:template` (1)
- `reputation:list` (1)
- `risk:campaign` (3)
- `risk:incident` (1)
- `risk:threat` (1)
- `risk:tool:software|file:bytes` (1)
- `sanction:entry` (8)
- `telecom:cdr` (2)
- `telecom:msisdn` (1)
- `telemetry:sighting` (1)
- `url:query:param` (1)
- `web:admin:surface` (1)
- `web:asset` (1)
- `web:client:uid` (1)
- `web:route` (1)
- `web:script` (1)
- `web:site` (2)
- `web:url` (2)
- `web:url|file:bytes` (1)
- `web:url|message:channel` (1)
- `x509:cert` (5)

</details>
