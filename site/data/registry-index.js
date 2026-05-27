window.__EVERYPIVOT_REGISTRY__ = {
  "registry": "everypivot",
  "release": "v0.3.0",
  "published_at": "2026-05-25",
  "channel": "stable",
  "license": {
    "copyright": "© 2026 EveryPivot Project",
    "copyright_holder_notice": "The named copyright holder and trademark owner is identified in LICENSE, NOTICE, and TRADEMARK.md. \"EveryPivot Project\" is the designated attribution party for redistribution under CC BY 4.0 §3(a)(1)(A)(i).",
    "code": {
      "spdx": "Apache-2.0",
      "url": "LICENSE-CODE",
      "applies_to": [
        "schemas/",
        "tools/",
        "site/",
        "docs/",
        "adapters/"
      ]
    },
    "corpus": {
      "spdx": "CC-BY-4.0",
      "url": "LICENSE-DATA",
      "applies_to": [
        "graph-pivots/",
        "fixtures/"
      ]
    },
    "attribution_required": "Pattern definitions and tooling from EveryPivot (EveryPivot Project), used under Apache-2.0 (code) and CC BY 4.0 (patterns).",
    "notice_url": "NOTICE",
    "license_summary_url": "LICENSE",
    "trademark": {
      "mark": "EveryPivot",
      "symbol": "™",
      "policy_url": "TRADEMARK.md",
      "owner_notice": "See TRADEMARK.md for the named trademark owner.",
      "note": "EveryPivot is a trademark. The license grants above do not include any right to use the EveryPivot name, logo, or other trademarks to identify your own products, services, forks, or competing registries."
    }
  },
  "schema_versions": {
    "pivot_pattern": "1.4"
  },
  "counts": {
    "validated": 19,
    "working_set": 76,
    "deferred": 81
  },
  "patterns": [
    {
      "id": "CROSS_CLOUD_BUCKET_TO_DOMAINS",
      "lane": "validated",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CROSS_CLOUD_BUCKET_TO_DOMAINS.yaml",
      "summary": "Cluster domains/CNAMEs pointing to the same object storage bucket (S3/GCS/Azure).",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "ownership_signal",
      "name": "Cloud Object Bucket → Domains",
      "description": "Cluster domains/CNAMEs pointing to the same object storage bucket (S3/GCS/Azure).",
      "source": "cloud:bucket",
      "target": "inet:fqdn",
      "datasets": [
        "pdns",
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Shared agency, reseller, or CDN-managed buckets can legitimately host unrelated domains.",
        "Stale CNAME or bucket references can persist after ownership or hosting changes."
      ],
      "capability_requirements": {
        "required": [
          "passive_dns",
          "cloud_bucket_resolution"
        ],
        "optional": [
          "web_fingerprinting"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "cloud:bucket": 20000
        },
        "negative_nodes": [
          {
            "form": "cloud:bucket",
            "list": "public_cdn_buckets"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_APK_SIGNING_CERT_CLUSTER",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_APK_SIGNING_CERT_CLUSTER.yaml",
      "summary": "Cluster APKs signed with the same Android signing certificate (issuer+serial or SPKI).",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "Android APK Signing Certificate → Apps/Samples",
      "description": "Cluster APKs signed with the same Android signing certificate (issuer+serial or SPKI).",
      "source": "x509:cert",
      "target": "file:bytes",
      "datasets": [
        "sandbox",
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Shared OEM, test, or repackaging certificates can cluster APKs that do not belong to the same malware family.",
        "Certificate reuse shows signer overlap, not necessarily identical developer intent or campaign ownership."
      ],
      "capability_requirements": {
        "required": [
          "apk_signature_extraction",
          "sample_collection"
        ],
        "optional": [
          "sandbox_analysis"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "x509:cert": 10000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "known_mass_dev_apk_certs"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CERT_REUSE_FQDN_CLUSTER",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_CERT_REUSE_FQDN_CLUSTER.yaml",
      "summary": "Cluster domains by identical certificate (SPKI or cert SHA256) observed in CT logs or scanners.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "Cert Reuse → FQDN Cluster",
      "description": "Cluster domains by identical certificate (SPKI or cert SHA256) observed in CT logs or scanners.",
      "source": "inet:fqdn",
      "target": "inet:fqdn",
      "datasets": [
        "ct",
        "tls",
        "pdns"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Managed certificates, CDNs, and shared hosts can create benign domain clusters.",
        "Certificate history can lag rotation events and leave stale associations in passive datasets."
      ],
      "capability_requirements": {
        "required": [
          "tls_scanning",
          "certificate_normalization"
        ],
        "optional": [
          "ct_history",
          "passive_dns"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-14",
        "review_cadence_days": 90,
        "next_review": "2026-08-12"
      },
      "controls": {
        "temporal_window_days": 825,
        "degree_caps": {
          "x509:cert": 2000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "letsencrypt_mass_certificates"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CLOUD_SUBSCRIPTION_TO_TENANT",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_CLOUD_SUBSCRIPTION_TO_TENANT.yaml",
      "summary": "Pivot from a normalized cloud subscription identifier to the tenant observed as owning or administering that subscription.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "ownership_signal",
      "name": "Cloud Subscription -> Tenant",
      "description": "Pivot from a normalized cloud subscription identifier to the tenant observed as owning or administering that subscription.",
      "source": "cloud:subscription:uid",
      "target": "cloud:tenant:uid",
      "datasets": [
        "cloud_inventory",
        "cloud_audit_logs"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Subscriptions can move between tenants, be delegated, or be managed by service providers, so observation time must be preserved.",
        "Subscription-to-tenant containment is an administrative relationship and must not imply compromise or actor control.",
        "Multi-tenant service principals and delegated administration can create legitimate cross-tenant edges.",
        "Shared or default provider delegation patterns require corroboration with tenant-specific administrative evidence before clustering."
      ],
      "capability_requirements": {
        "required": [
          "cloud_subscription_identifier_normalization",
          "cloud_tenant_identifier_normalization"
        ],
        "optional": [
          "delegated_admin_relationships",
          "cloud_audit_log_access"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-14",
        "review_cadence_days": 90,
        "next_review": "2026-08-12"
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "cloud:subscription:uid": 100000,
          "cloud:tenant:uid": 100000
        },
        "negative_nodes": [
          {
            "form": "cloud:tenant:uid",
            "list": "provider_service_or_support_tenants"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CLOUD_WEBAPP_TO_SUBSCRIPTION",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_CLOUD_WEBAPP_TO_SUBSCRIPTION.yaml",
      "summary": "Pivot from a normalized cloud web app hostname or resource identifier to the cloud subscription that contains it.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "ownership_signal",
      "name": "Cloud Web App -> Subscription",
      "description": "Pivot from a normalized cloud web app hostname or resource identifier to the cloud subscription that contains it.",
      "source": "cloud:webapp|inet:fqdn|inet:url",
      "target": "cloud:subscription:uid",
      "datasets": [
        "cloud_inventory",
        "cloud_audit_logs",
        "dns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Cloud web app hostnames can be reassigned, disabled, recycled, or fronted by shared platform infrastructure.",
        "A web app to subscription join describes administrative containment, not proof of malicious use or actor ownership.",
        "Provider-specific IDs and product names must remain adapter metadata."
      ],
      "capability_requirements": {
        "required": [
          "cloud_webapp_inventory",
          "cloud_subscription_identifier_normalization"
        ],
        "optional": [
          "cloud_audit_log_access",
          "hostname_to_resource_mapping"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-14",
        "review_cadence_days": 90,
        "next_review": "2026-08-12"
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "cloud:webapp": 1000,
          "cloud:subscription:uid": 100000
        },
        "negative_nodes": [
          {
            "form": "cloud:webapp",
            "list": "provider_default_or_recycled_webapps"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_CODESIGN_CERT_SERIAL_ISSUER_CLUSTER_STRICT.yaml",
      "summary": "Cluster samples by exact code-signing certificate issuer+serial; strict filters exclude multi-tenant/signing services.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "Code-sign Cert (Issuer+Serial) → Samples (Strict)",
      "description": "Cluster samples by exact code-signing certificate issuer+serial; strict filters exclude multi-tenant/signing services.",
      "source": "x509:cert",
      "target": "file:bytes",
      "datasets": [
        "sandbox",
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Stolen or enterprise signing certificates can span multiple unrelated tool families or distribution channels.",
        "Strict filtering reduces, but does not eliminate, benign software-signing and build-pipeline noise.",
        "Common enterprise signing services and default build certificates can create false clustering; corroborate with sample lineage and signer context."
      ],
      "capability_requirements": {
        "required": [
          "codesign_certificate_parsing",
          "sample_collection"
        ],
        "optional": [
          "publisher_allowlists"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "x509:cert": 10000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "multi_tenant_signing_services"
          },
          {
            "form": "x509:cert",
            "list": "known_mass_developer_certs"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_PROTECTED_URL_TO_ORIGINAL_URL",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_EMAIL_PROTECTED_URL_TO_ORIGINAL_URL.yaml",
      "summary": "Decode a protected or rewritten email URL into the original embedded destination URL while preserving provider and adapter provenance.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "domain_expansion",
      "name": "Email Protected URL -> Original URL",
      "description": "Decode a protected or rewritten email URL into the original embedded destination URL while preserving provider and adapter provenance.",
      "source": "email:protected_url",
      "target": "inet:url",
      "datasets": [
        "mail_telemetry",
        "url_corpus"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "demonstrated",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Protected URL decoders can fail or produce partial output when providers change encodings, nest wrappers, or omit destination parameters.",
        "Decoded destinations can still be benign intermediary links that redirect again at click time.",
        "Common redirectors and shared security wrappers can create false joins; corroborate decoded destinations with message context."
      ],
      "capability_requirements": {
        "required": [
          "protected_url_decoding",
          "url_normalization"
        ],
        "optional": [
          "redirect_resolution",
          "provider_adapter_metadata"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-14",
        "review_cadence_days": 90,
        "next_review": "2026-08-12"
      },
      "controls": {
        "temporal_window_days": 1,
        "degree_caps": {
          "email:protected_url": 100
        },
        "negative_nodes": [
          {
            "form": "email:protected_url",
            "list": "malformed_or_unsupported_protected_urls"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_CODESIGN_CERT_CLUSTER",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_SAMPLE_CODESIGN_CERT_CLUSTER.yaml",
      "summary": "Cluster samples signed with the same code-signing certificate (issuer+serial or SPKI).",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "Code-signing Certificate → Signed Samples",
      "description": "Cluster samples signed with the same code-signing certificate (issuer+serial or SPKI).",
      "source": "x509:cert",
      "target": "file:bytes",
      "datasets": [
        "sandbox",
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Shared signing infrastructure can reflect outsourced build or release services rather than common operator ownership.",
        "Signer reuse alone should not be treated as final campaign attribution without supporting code, infra, or behavioural overlap."
      ],
      "capability_requirements": {
        "required": [
          "codesign_certificate_parsing",
          "sample_collection"
        ],
        "optional": [
          "publisher_allowlists"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "x509:cert": 10000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "known_mass_developer_certs"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_CONFIG_KEY_CLUSTER",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_SAMPLE_CONFIG_KEY_CLUSTER.yaml",
      "summary": "Cluster malware sharing exact C2 crypto keys, campaign IDs, or license/public keys from config.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "Malware Config Key/ID → Sample Cluster",
      "description": "Cluster malware sharing exact C2 crypto keys, campaign IDs, or license/public keys from config.",
      "source": "c2:config:key",
      "target": "file:bytes",
      "datasets": [
        "sandbox"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Default builder keys, campaign IDs, or templated config material can overcluster adjacent operations.",
        "Common builder defaults and shared malware frameworks can reuse config key material across unrelated samples.",
        "Parser or extraction errors can create false exact matches if config fields are not normalized carefully."
      ],
      "capability_requirements": {
        "required": [
          "config_extraction",
          "sample_collection"
        ],
        "optional": [
          "sandbox_analysis"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "c2:config:key": 20000
        },
        "negative_nodes": [
          {
            "form": "c2:config:key",
            "list": "default_builder_keys"
          },
          {
            "form": "c2:config:key",
            "list": "templated_campaign_ids"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_IMPHASH_CLUSTER",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_SAMPLE_IMPHASH_CLUSTER.yaml",
      "summary": "Cluster Windows PE samples that share the same import hash, preserving file hashes and collection provenance.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "PE ImpHash -> Sample Cluster",
      "description": "Cluster Windows PE samples that share the same import hash, preserving file hashes and collection provenance.",
      "source": "file:pe:imphash",
      "target": "file:bytes",
      "datasets": [
        "malware_corpus",
        "sandbox",
        "edr"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Common packers, frameworks, malware builders, and benign software families can share import hashes without shared operation.",
        "Import hashes can change with minor build changes and can be distorted by packing, import reconstruction, or damaged PE metadata."
      ],
      "capability_requirements": {
        "required": [
          "pe_metadata_extraction",
          "sample_hash_normalization"
        ],
        "optional": [
          "sandbox",
          "malware_family_labels"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-14",
        "review_cadence_days": 90,
        "next_review": "2026-08-12"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "file:pe:imphash": 10000
        },
        "negative_nodes": [
          {
            "form": "file:pe:imphash",
            "list": "common_benign_imphashes"
          },
          {
            "form": "file:pe:imphash",
            "list": "common_packer_imphashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_PDB_PATH_CLUSTER",
      "lane": "validated",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/validated/CTI_SAMPLE_PDB_PATH_CLUSTER.yaml",
      "summary": "Cluster malware samples reusing the same embedded PDB path or canonicalized build-path string.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "PDB Path -> Sample Cluster",
      "description": "Cluster malware samples reusing the same embedded PDB path or canonicalized build-path string.",
      "source": "it:dev:pdb:path",
      "target": "file:bytes",
      "datasets": [
        "sandbox",
        "malware_corpus"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Leaked builders, copied projects, and generic folder names can produce weak build-path overlaps.",
        "Canonicalization mistakes can merge distinct paths or split true matches if normalization is inconsistent."
      ],
      "capability_requirements": {
        "required": [
          "pe_metadata_extraction",
          "pdb_path_extraction"
        ],
        "optional": [
          "path_normalization",
          "common_build_path_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-21",
        "review_cadence_days": 90,
        "next_review": "2026-08-19"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "it:dev:pdb:path": 5000
        },
        "negative_nodes": [
          {
            "form": "it:dev:pdb:path",
            "list": "common_benign_pdb_paths"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_CERT_SHA_TO_DOMAINS",
      "lane": "validated",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/validated/OSINT_CERT_SHA_TO_DOMAINS.yaml",
      "summary": "Pivot by identical certificate hash/SPKI to enumerate domains presenting the same cert.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "Cert SHA/SPKI → Domains",
      "description": "Pivot by identical certificate hash/SPKI to enumerate domains presenting the same cert.",
      "source": "x509:cert",
      "target": "inet:fqdn",
      "datasets": [
        "ct",
        "tls"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Managed certificates and shared web hosts can create benign overlap between unrelated domains.",
        "Scanner lag and historical cert retention can preserve stale domain relationships after rotation."
      ],
      "capability_requirements": {
        "required": [
          "tls_scanning",
          "certificate_normalization"
        ],
        "optional": [
          "ct_history"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-14",
        "review_cadence_days": 90,
        "next_review": "2026-08-12"
      },
      "controls": {
        "temporal_window_days": 825,
        "degree_caps": {
          "x509:cert": 10000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "letsencrypt_mass_certificates"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_CERT_TO_SERVERS",
      "lane": "validated",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/validated/OSINT_CERT_TO_SERVERS.yaml",
      "summary": "Enumerate servers that present an identical certificate or SPKI (public key).",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "X.509 SPKI/Cert → Servers (IP/FQDN)",
      "description": "Enumerate servers that present an identical certificate or SPKI (public key).",
      "source": "x509:cert",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "ct",
        "tls"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Managed certificates and shared load balancers can join unrelated hosts behind the same delivery surface.",
        "CT and scanner coverage can be incomplete or stale, so absence should not be interpreted as disproof."
      ],
      "capability_requirements": {
        "required": [
          "tls_scanning",
          "certificate_normalization"
        ],
        "optional": [
          "ct_history"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 825,
        "degree_caps": {
          "x509:cert": 10000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "letsencrypt_mass_certificates"
          },
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_DKIM_KEY_CLUSTER",
      "lane": "validated",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/validated/OSINT_DKIM_KEY_CLUSTER.yaml",
      "summary": "Cluster sending domains sharing the exact same DKIM public key (selector/keypair).",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "DKIM Public Key → Domain Cluster",
      "description": "Cluster sending domains sharing the exact same DKIM public key (selector/keypair).",
      "source": "mail:dkim:key",
      "target": "inet:fqdn",
      "datasets": [
        "pdns",
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Bulk mail providers can legitimately host many customer domains behind the same DKIM selector or key material.",
        "Delegated mail operations can obscure whether the link reflects direct ownership or outsourced sending.",
        "Common selectors and shared provider defaults require corroboration with domain control and mail configuration context."
      ],
      "capability_requirements": {
        "required": [
          "dns_mail_enrichment",
          "dkim_key_extraction"
        ],
        "optional": [
          "mail_flow_analysis"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 1095,
        "degree_caps": {
          "mail:dkim:key": 10000
        },
        "negative_nodes": [
          {
            "form": "mail:dkim:key",
            "list": "provider_managed_dkim_keys"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_DMARC_RUA_TO_DOMAINS",
      "lane": "validated",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/validated/OSINT_DMARC_RUA_TO_DOMAINS.yaml",
      "summary": "Cluster domains that send aggregate DMARC reports to the same reporting mailbox, filtering provider-managed collection endpoints.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "DMARC RUA Mailbox -> Domains",
      "description": "Cluster domains that send aggregate DMARC reports to the same reporting mailbox, filtering provider-managed collection endpoints.",
      "source": "mail:dmarc:rua",
      "target": "inet:fqdn",
      "datasets": [
        "dns",
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Managed reporting providers legitimately aggregate DMARC traffic for many unrelated domains.",
        "Mailbox reuse can reflect outsourced email operations rather than direct affiliation between the senders.",
        "Common reporting mailboxes and shared provider defaults require corroboration with domain ownership and current DNS."
      ],
      "capability_requirements": {
        "required": [
          "dns_public_lookup",
          "dns_mail_enrichment"
        ],
        "optional": [
          "dmarc_record_parsing",
          "managed_mail_provider_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-21",
        "review_cadence_days": 90,
        "next_review": "2026-08-19"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "mail:dmarc:rua": 5000
        },
        "negative_nodes": [
          {
            "form": "mail:dmarc:rua",
            "list": "provider_managed_dmarc_mailboxes"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_PRIVATE_NS_TO_DOMAINS",
      "lane": "validated",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/validated/OSINT_PRIVATE_NS_TO_DOMAINS.yaml",
      "summary": "Enumerate domains delegated to a non‑provider (private) authoritative nameserver.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "ownership_signal",
      "name": "Private Authoritative NS → Domains",
      "description": "Enumerate domains delegated to a non‑provider (private) authoritative nameserver.",
      "source": "inet:fqdn:ns",
      "target": "inet:fqdn",
      "datasets": [
        "pdns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "White-label DNS resellers and managed hosting can create shared private nameservers for unrelated customers.",
        "Delegation records can remain stale after migrations, parking, or account turnover."
      ],
      "capability_requirements": {
        "required": [
          "passive_dns",
          "delegation_resolution"
        ],
        "optional": [
          "whois_rdap"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "inet:fqdn:ns": 10000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn:ns",
            "list": "public_ns_providers"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_RDP_CERT_THUMBPRINT_CLUSTER",
      "lane": "validated",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/validated/OSINT_RDP_CERT_THUMBPRINT_CLUSTER.yaml",
      "summary": "Cluster RDP endpoints presenting the same TLS certificate thumbprint.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "RDP TLS Certificate → Host Cluster",
      "description": "Cluster RDP endpoints presenting the same TLS certificate thumbprint.",
      "source": "x509:cert",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "shodan_censys",
        "tls"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Default appliance images or cloned deployments can reuse RDP certificates across otherwise unrelated systems.",
        "Scanner bias, NAT, or protocol gateways can distort the apparent size of a cluster."
      ],
      "capability_requirements": {
        "required": [
          "rdp_scanning",
          "certificate_normalization"
        ],
        "optional": [
          "asset_allowlists"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 730,
        "degree_caps": {
          "x509:cert": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_SSH_HOSTKEY_CLUSTER",
      "lane": "validated",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/validated/OSINT_SSH_HOSTKEY_CLUSTER.yaml",
      "summary": "Cluster servers that present the exact same SSH host key (e.g., ed25519/rsa SHA256).",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "SSH Host Key Fingerprint → Host Cluster",
      "description": "Cluster servers that present the exact same SSH host key (e.g., ed25519/rsa SHA256).",
      "source": "ssh:hostkey",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "shodan_censys"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Golden images and failed key rotation can legitimately duplicate SSH host keys across unrelated environments.",
        "Shared bastions or fronted services can hide the true endpoint population behind one observed key."
      ],
      "capability_requirements": {
        "required": [
          "ssh_scanning",
          "hostkey_normalization"
        ],
        "optional": [
          "asset_allowlists"
        ]
      },
      "review": {
        "last_reviewed": "2026-04-04",
        "review_cadence_days": 90,
        "next_review": "2026-07-03"
      },
      "controls": {
        "temporal_window_days": 730,
        "degree_caps": {
          "ssh:hostkey": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "known_scanner_asns"
          },
          {
            "form": "inet:ipv4",
            "list": "shared_hosting_ranges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "SUPPLY_CODESIGN_CERT_TO_PACKAGES",
      "lane": "validated",
      "category": "SUPPLY",
      "version": "1.0.0",
      "path": "graph-pivots/validated/SUPPLY_CODESIGN_CERT_TO_PACKAGES.yaml",
      "summary": "Cluster packages or update artifacts signed by the same code-signing certificate or signer material.",
      "pattern_schema_version": 1.4,
      "precision_tier": "high",
      "robustness_class": "exact_cryptographic",
      "name": "Code-Signing Certificate -> Packages",
      "description": "Cluster packages or update artifacts signed by the same code-signing certificate or signer material.",
      "source": "x509:cert",
      "target": "it:prod:softver",
      "datasets": [
        "package_registry",
        "binary_metadata"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Enterprise signing services and shared release pipelines can sign multiple unrelated products.",
        "Certificate reuse indicates signing control, not necessarily shared source provenance or maintainer identity."
      ],
      "capability_requirements": {
        "required": [
          "code_signing_certificate_extraction",
          "package_metadata_collection"
        ],
        "optional": [
          "signer_certificate_chain_resolution",
          "package_registry_history"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-14",
        "review_cadence_days": 90,
        "next_review": "2026-08-12"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "x509:cert": 20000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "enterprise_mass_signing_services"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "ADTECH_AD_REQUEST_TO_INFECTION_HIT",
      "lane": "working_set",
      "category": "ADTECH",
      "version": "0.1.0",
      "path": "graph-pivots/working-set/ADTECH_AD_REQUEST_TO_INFECTION_HIT.yaml",
      "summary": "Link an ad-tech delivery or qualification request to a suspicious downstream endpoint when the two events share a device/session identifier and occur within a short time window.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "multi_hop_inference",
      "name": "Ad Request -> Suspicious Infection Hit",
      "description": "Link an ad-tech delivery or qualification request to a suspicious downstream endpoint when the two events share a device/session identifier and occur within a short time window.",
      "source": "http:request",
      "target": "risk:incident",
      "datasets": [
        "proxy_logs",
        "browser_telemetry",
        "cti_reports",
        "adtech_logs"
      ],
      "hop_count": 4,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "incident_level",
        "subject_role": "observation",
        "object_role": "incident"
      },
      "hazards": [
        "Short temporal proximity between an ad request and a suspicious endpoint can reflect normal redirect, verification, or analytics flows unless the downstream endpoint is independently suspicious.",
        "Device or session identifiers may be redacted, hashed, or rotated, so identity continuity must be handled conservatively.",
        "Shared vendor redirects, tracking tags, and common verification pixels are false-positive sources; corroborate with endpoint risk and campaign context."
      ],
      "capability_requirements": {
        "required": [
          "web_request_telemetry",
          "browser_client_uid_normalization"
        ],
        "optional": [
          "web_fingerprinting",
          "endpoint_risk_context"
        ]
      },
      "controls": {
        "temporal_window_days": 1,
        "degree_caps": {
          "adtech:identifier": 500,
          "inet:url": 1000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "commodity_ad_verification_pixels"
          },
          {
            "form": "inet:fqdn",
            "list": "high_volume_ad_exchange_endpoints"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "ADTECH_IMPRESSION_ID_REUSE_CLUSTER",
      "lane": "working_set",
      "category": "ADTECH",
      "version": "0.1.0",
      "path": "graph-pivots/working-set/ADTECH_IMPRESSION_ID_REUSE_CLUSTER.yaml",
      "summary": "Cluster domains, analytics endpoints, and campaign surfaces that carry the same ad impression or auction identifier.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "ownership_signal",
      "name": "Impression ID Reuse -> Ad-Tech Domain Cluster",
      "description": "Cluster domains, analytics endpoints, and campaign surfaces that carry the same ad impression or auction identifier.",
      "source": "adtech:impression:id",
      "target": "inet:fqdn",
      "datasets": [
        "proxy_logs",
        "url_corpus",
        "adtech_logs",
        "cti_reports"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "campaign_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Impression IDs can be propagated through legitimate verification, billing, or analytics partners without implying operator control.",
        "Malformed URL parsing can overcluster unrelated impressions if parameter boundaries are not normalized.",
        "Shared tracking vendors, redirects, and common verification pixels can create false reuse; corroborate with additional campaign evidence."
      ],
      "capability_requirements": {
        "required": [
          "web_request_telemetry",
          "adtech_identifier_normalization"
        ],
        "optional": [
          "browser_client_uid_normalization",
          "campaign_context_enrichment"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "adtech:impression:id": 200,
          "inet:fqdn": 1000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "known_measurement_vendors"
          },
          {
            "form": "inet:fqdn",
            "list": "high_volume_ad_exchange_endpoints"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "ADTECH_PIPELINE_PHASE_MISMATCH",
      "lane": "working_set",
      "category": "ADTECH",
      "version": "0.1.0",
      "path": "graph-pivots/working-set/ADTECH_PIPELINE_PHASE_MISMATCH.yaml",
      "summary": "Flag ad-tech URLs whose observed request phase conflicts with the domain, path, or declared role suggested by the endpoint.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "multi_hop_inference",
      "name": "Ad Pipeline Phase Mismatch",
      "description": "Flag ad-tech URLs whose observed request phase conflicts with the domain, path, or declared role suggested by the endpoint.",
      "source": "http:request",
      "target": "risk:observation",
      "datasets": [
        "browser_telemetry",
        "proxy_logs",
        "adtech_logs",
        "url_corpus"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "incident_level",
        "subject_role": "observation",
        "object_role": "observation"
      },
      "hazards": [
        "Domain names often reflect legacy product names rather than current ad-pipeline function.",
        "Some exchanges intentionally reuse event, prebid, or creative endpoints across multiple phases.",
        "Shared vendors, CDNs, redirects, and common tracking endpoints can create false phase mismatches; corroborate with observed request flow."
      ],
      "capability_requirements": {
        "required": [
          "web_request_telemetry",
          "endpoint_role_classification"
        ],
        "optional": [
          "web_fingerprinting",
          "phase_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 1,
        "degree_caps": {
          "inet:fqdn": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "known_multi_phase_ad_endpoints"
          },
          {
            "form": "inet:fqdn",
            "list": "major_ad_exchange_canonical_hosts"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "ADTECH_RTB_URL_PARAMS_TO_CAMPAIGN_CLUSTER",
      "lane": "working_set",
      "category": "ADTECH",
      "version": "0.1.0",
      "path": "graph-pivots/working-set/ADTECH_RTB_URL_PARAMS_TO_CAMPAIGN_CLUSTER.yaml",
      "summary": "Cluster ad-tech requests into candidate campaigns using recurring RTB query parameters such as campaign IDs, DSP IDs, impression IDs, device IDs, location, OS, browser, and auction fields.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "multi_hop_inference",
      "name": "RTB URL Parameters -> Campaign Cluster",
      "description": "Cluster ad-tech requests into candidate campaigns using recurring RTB query parameters such as campaign IDs, DSP IDs, impression IDs, device IDs, location, OS, browser, and auction fields.",
      "source": "inet:url",
      "target": "risk:campaign",
      "datasets": [
        "proxy_logs",
        "browser_telemetry",
        "adtech_logs",
        "url_corpus"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "campaign_level",
        "subject_role": "behavioural_cluster",
        "object_role": "campaign"
      },
      "hazards": [
        "Campaign, DSP, auction, and device parameters can be opaque vendor-local IDs that collide across platforms.",
        "Precise geolocation parameters may be estimated, rounded, or inherited from upstream bid streams rather than directly selected by the advertiser.",
        "Shared vendor namespaces, redirects, and tracking macros can create false parameter clusters; corroborate with advertiser and campaign evidence."
      ],
      "capability_requirements": {
        "required": [
          "web_request_telemetry",
          "query_parameter_normalization"
        ],
        "optional": [
          "browser_client_uid_normalization",
          "campaign_context_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "url:query:param": 5000,
          "adtech:campaign:key": 1000
        },
        "negative_nodes": [
          {
            "form": "url:query:param",
            "list": "generic_cachebuster_params"
          },
          {
            "form": "inet:fqdn",
            "list": "high_volume_ad_exchange_endpoints"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "ADTECH_WEBAPP_SOURCEMAP_TO_ADMIN_SURFACE",
      "lane": "working_set",
      "category": "ADTECH",
      "version": "0.1.0",
      "path": "graph-pivots/working-set/ADTECH_WEBAPP_SOURCEMAP_TO_ADMIN_SURFACE.yaml",
      "summary": "Pivot from exposed JavaScript bundles or source maps to recovered application routes, panel strings, and administration surfaces.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "Webapp Source Map -> Admin Surface",
      "description": "Pivot from exposed JavaScript bundles or source maps to recovered application routes, panel strings, and administration surfaces.",
      "source": "web:asset",
      "target": "web:admin:surface",
      "datasets": [
        "osint_web",
        "url_corpus",
        "web_crawl",
        "cti_reports"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_kind": "concept"
      },
      "hazards": [
        "Exposed JavaScript bundles and source maps can identify benign SaaS administration surfaces.",
        "Recovered route names are evidence of application capability, not proof that the surface is used in a specific operation.",
        "Shared SaaS vendors, CDNs, and common admin-route names can create false matches; corroborate with tenant-specific artifacts."
      ],
      "capability_requirements": {
        "required": [
          "web_fingerprinting",
          "web_script_extraction"
        ],
        "optional": [
          "dynamic_rendering",
          "route_recovery"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 96,
        "next_review": "2026-08-30"
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "web:asset": 1000,
          "web:route": 5000
        },
        "negative_nodes": [
          {
            "form": "web:asset",
            "list": "common_frontend_framework_assets"
          },
          {
            "form": "web:admin:surface",
            "list": "known_benign_saas_panels"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_CLOUD_ACCOUNT_TO_DOMAIN_INFRA",
      "lane": "working_set",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CROSS_CLOUD_ACCOUNT_TO_DOMAIN_INFRA.yaml",
      "summary": "Expand from a parent cloud account or project to the domains and infrastructure it operates through owned services and assets.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "Cloud Account -> Domain or Infra",
      "description": "Expand from a parent cloud account or project to the domains and infrastructure it operates through owned services and assets.",
      "source": "cloud:account",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "cloud_asset_inventory",
        "pdns",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Shared reseller, MSP, or umbrella cloud accounts can host assets for unrelated tenants.",
        "Infrastructure expansion from parent-account data should be corroborated with billing, admin, or deployment evidence."
      ],
      "capability_requirements": {
        "required": [
          "cloud_control_telemetry",
          "cloud_asset_inventory"
        ],
        "optional": [
          "dns_public_lookup",
          "passive_dns",
          "cloud_audit_log_access"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 90,
        "next_review": "2026-08-24"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "cloud:account": 5000
        },
        "negative_nodes": [
          {
            "form": "cloud:account",
            "list": "shared_platform_cloud_accounts"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_FQDN_TO_ORG_LEI",
      "lane": "working_set",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CROSS_FQDN_TO_ORG_LEI.yaml",
      "summary": "Resolve a domain to an identified legal entity record without requiring a sanctions overlay.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "FQDN -> Org -> LEI",
      "description": "Resolve a domain to an identified legal entity record without requiring a sanctions overlay.",
      "source": "inet:fqdn",
      "target": "lei:record",
      "datasets": [
        "rdap",
        "lei"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "RDAP and corporate registry data can be stale, privacy-filtered, or registrar-noisy.",
        "Legal-entity resolution may identify an intermediary, hoster, or service provider rather than the operational controller.",
        "Common registrant strings and shared service-provider records require corroboration with current RDAP and LEI evidence before clustering."
      ],
      "capability_requirements": {
        "required": [
          "rdap_enrichment",
          "lei_resolution"
        ],
        "optional": [
          "registrar_reseller_context",
          "privacy_service_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 97,
        "next_review": "2026-08-31"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "inet:fqdn": 10000
        },
        "negative_nodes": [
          {
            "form": "org:org",
            "list": "privacy_redacted_registrants"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_CONTROLLERS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_CONTROLLERS.yaml",
      "summary": "Pivot from a normalized active protocol probe response to controller endpoints that emitted the same distinctive response or handshake.",
      "pattern_schema_version": 1.3,
      "precision_tier": "medium",
      "robustness_class": "multi_hop_inference",
      "name": "Active C2 Protocol Response -> Controllers",
      "description": "Pivot from a normalized active protocol probe response to controller endpoints that emitted the same distinctive response or handshake.",
      "source": "network:service:probe_response",
      "target": "inet:ipv4|inet:fqdn|inet:url",
      "datasets": [
        "active_discovery_results",
        "internet_scan_archives",
        "malware_analysis"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Active protocol probes require authorization, scope control, and careful rate limiting; the pattern only models the observed relationship.",
        "Protocol emulation can trigger decoys, sinkholes, honeypots, middleboxes, or replayed responses that do not represent an operator-controlled controller.",
        "A matching response is infrastructure evidence, not actor attribution.",
        "Common or default protocol banners and shared test infrastructure can produce false matches; corroborate with independent malware or network evidence."
      ],
      "capability_requirements": {
        "required": [
          "active_protocol_probe_result_normalization",
          "controller_endpoint_extraction"
        ],
        "optional": [
          "payload_decoding",
          "sinkhole_honeypot_suppression",
          "internet_scan_archive_lookup"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "network:service:probe_response": 10000,
          "inet:ipv4": 10000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "known_sinkholes_honeypots"
          },
          {
            "form": "inet:fqdn",
            "list": "benign_protocol_testbeds"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_PAYLOADS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_ACTIVE_C2_PROTOCOL_RESPONSE_TO_PAYLOADS.yaml",
      "summary": "Pivot from a normalized active protocol response to decoded payloads, loaders, or configuration blobs recovered from that response.",
      "pattern_schema_version": 1.3,
      "precision_tier": "medium",
      "robustness_class": "multi_hop_inference",
      "name": "Active C2 Protocol Response -> Payloads",
      "description": "Pivot from a normalized active protocol response to decoded payloads, loaders, or configuration blobs recovered from that response.",
      "source": "network:service:probe_response",
      "target": "malware:payload|file:hash|malware:config",
      "datasets": [
        "active_discovery_results",
        "malware_analysis",
        "file_reputation"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Decoded payloads can be generated by sandboxes, decoys, replay services, or defensive research infrastructure.",
        "A payload returned by a controller can be ephemeral and may not remain available for later verification.",
        "Protocol response reuse links observations, but it does not prove common operator control."
      ],
      "capability_requirements": {
        "required": [
          "active_protocol_probe_result_normalization",
          "payload_decoding"
        ],
        "optional": [
          "sample_hashing",
          "payload_family_classification",
          "decoy_response_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "network:service:probe_response": 1000,
          "malware:payload": 5000
        },
        "negative_nodes": [
          {
            "form": "malware:payload",
            "list": "known_test_or_decoy_payloads"
          },
          {
            "form": "file:hash",
            "list": "common_benign_payload_hashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_AUTH_SESSION_TO_DOMAINS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_AUTH_SESSION_TO_DOMAINS.yaml",
      "summary": "Pivot from a bounded authentication session to domains observed during that session.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Auth Session -> Domains",
      "description": "Pivot from a bounded authentication session to domains observed during that session.",
      "source": "auth:session",
      "target": "inet:fqdn",
      "datasets": [
        "auth_logs",
        "proxy_logs",
        "dns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Authentication-session pivots must stay time-bounded; a domain touched during auth is not proof of account ownership or actor control.",
        "Auth-session domains can include common or shared identity providers, redirects, CDNs, captive portals, telemetry beacons, and security-product probes, so corroborating request role is required.",
        "Session-to-domain expansion should retain request role and timing so benign login infrastructure is not clustered as adversary infrastructure."
      ],
      "capability_requirements": {
        "required": [
          "auth_session_telemetry",
          "domain_normalization"
        ],
        "optional": [
          "redirect_chain_extraction",
          "identity_provider_domain_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 98,
        "next_review": "2026-09-01"
      },
      "controls": {
        "temporal_window_days": 1,
        "degree_caps": {
          "auth:session": 1000000,
          "inet:fqdn": 1000000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "identity_provider_or_sso_domains"
          },
          {
            "form": "inet:fqdn",
            "list": "common_cdn_domains"
          },
          {
            "form": "inet:fqdn",
            "list": "captive_portal_or_probe_domains"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_AUTH_SESSION_TO_IDENTITIES",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_AUTH_SESSION_TO_IDENTITIES.yaml",
      "summary": "Pivot from a bounded authentication session to normalized user or principal identities associated with that session.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "Auth Session -> Identities",
      "description": "Pivot from a bounded authentication session to normalized user or principal identities associated with that session.",
      "source": "auth:session",
      "target": "identity:user:uid",
      "datasets": [
        "auth_logs",
        "identity"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Authentication sessions can be reused, merged, replayed, or associated with multiple identities through shared accounts, delegated access, and service principals.",
        "A session-to-identity join is account telemetry context, not proof that a human user controlled every event in the session.",
        "Session identifiers must remain time-bounded and source-scoped to avoid joining unrelated authentication records."
      ],
      "capability_requirements": {
        "required": [
          "auth_session_telemetry",
          "identity_uid_normalization"
        ],
        "optional": [
          "service_principal_classification",
          "delegated_access_context"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 90,
        "next_review": "2026-08-24"
      },
      "controls": {
        "temporal_window_days": 1,
        "degree_caps": {
          "auth:session": 1000000,
          "identity:user:uid": 100000
        },
        "negative_nodes": [
          {
            "form": "identity:user:uid",
            "list": "shared_or_service_accounts"
          },
          {
            "form": "auth:session",
            "list": "stale_or_merged_session_records"
          },
          {
            "form": "auth:session",
            "list": "synthetic_or_healthcheck_sessions"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_C2_CERT_TO_SAMPLE_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_C2_CERT_TO_SAMPLE_CLUSTER.yaml",
      "summary": "Link malware samples whose detonated C2 endpoints present the same TLS certificate or SPKI material.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "multi_hop_inference",
      "name": "C2 TLS Certificate -> Sample Cluster",
      "description": "Link malware samples whose detonated C2 endpoints present the same TLS certificate or SPKI material.",
      "source": "x509:cert",
      "target": "file:bytes",
      "datasets": [
        "sandbox",
        "tls_scans",
        "pdns"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Multi-tenant TLS termination, sinkholes, or shared redirectors can reuse certificates across unrelated malware.",
        "Sandbox-only visibility may miss the variability of live infrastructure and overstate cluster confidence."
      ],
      "capability_requirements": {
        "required": [
          "malware_sandbox_summary",
          "tls_scanning",
          "certificate_normalization"
        ],
        "optional": [
          "sample_hash_normalization",
          "ct_history"
        ]
      },
      "controls": {
        "temporal_window_days": 1095,
        "degree_caps": {
          "x509:cert": 2000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "shared_cdn_certificates"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CLOUD_APP_ID_TO_AUTH_EVENTS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_CLOUD_APP_ID_TO_AUTH_EVENTS.yaml",
      "summary": "Pivot from a normalized cloud or OAuth application identifier to authentication, consent, or token-use events involving that application.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "Cloud App ID -> Auth Events",
      "description": "Pivot from a normalized cloud or OAuth application identifier to authentication, consent, or token-use events involving that application.",
      "source": "cloud:application:uid|oauth:application:uid",
      "target": "auth:event",
      "datasets": [
        "auth_logs",
        "cloud_audit_logs",
        "cloud_inventory"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Application identifiers can represent legitimate multi-tenant applications, first-party services, delegated apps, or attacker-created resources.",
        "Auth events can reflect testing, consent, token replay, service activity, or benign automation rather than direct user action.",
        "An app ID to auth-event join is not proof of application ownership or compromise.",
        "Common first-party or shared SaaS application IDs can produce false joins; corroborate with tenant-specific consent and timing."
      ],
      "capability_requirements": {
        "required": [
          "cloud_application_identifier_normalization",
          "auth_event_telemetry"
        ],
        "optional": [
          "consent_event_telemetry",
          "service_principal_inventory",
          "first_party_app_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 90,
        "next_review": "2026-08-24"
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "cloud:application:uid": 100000,
          "auth:event": 1000000
        },
        "negative_nodes": [
          {
            "form": "cloud:application:uid",
            "list": "common_first_party_or_managed_apps"
          },
          {
            "form": "auth:event",
            "list": "expected_service_automation_events"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_ATTACHMENT_HASH_TO_MESSAGES",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_ATTACHMENT_HASH_TO_MESSAGES.yaml",
      "summary": "Pivot from a normalized attachment file hash to email messages where that attachment was observed.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "Email Attachment Hash -> Messages",
      "description": "Pivot from a normalized attachment file hash to email messages where that attachment was observed.",
      "source": "file:hash",
      "target": "email:message",
      "datasets": [
        "mail_telemetry",
        "malware_corpus",
        "sandbox"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Mail attachment pivots can be inflated by forwarding, detonation, bulk mail, shared mailboxes, and rewritten attachment metadata.",
        "Common documents, logos, signatures, invoices, and benign software attachments can connect unrelated messages.",
        "Attachment reuse is message evidence, not actor attribution; corroborate with sender, recipient, timing, and file context."
      ],
      "capability_requirements": {
        "required": [
          "mail_attachment_telemetry",
          "file_hash_normalization"
        ],
        "optional": [
          "message_trace_join",
          "detonation_artifact_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 90,
        "next_review": "2026-08-24"
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "file:hash": 1000000,
          "email:message": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:hash",
            "list": "common_benign_attachment_hashes"
          },
          {
            "form": "email:message",
            "list": "bulk_or_newsletter_messages"
          },
          {
            "form": "email:message",
            "list": "detonation_generated_messages"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_EMBEDDED_URL_TO_MESSAGES",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_EMBEDDED_URL_TO_MESSAGES.yaml",
      "summary": "Pivot from an embedded URL to email messages that contained it, retaining normalized and raw URL forms.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Embedded URL -> Email Messages",
      "description": "Pivot from an embedded URL to email messages that contained it, retaining normalized and raw URL forms.",
      "source": "inet:url",
      "target": "email:message",
      "datasets": [
        "mail_telemetry",
        "url_corpus"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Common embedded URLs such as unsubscribe endpoints, social links, image CDNs, and sender infrastructure can appear in unrelated messages.",
        "URL normalization choices can overjoin messages when query parameters, fragments, or protection wrappers are stripped too aggressively."
      ],
      "capability_requirements": {
        "required": [
          "email_url_extraction",
          "url_normalization"
        ],
        "optional": [
          "campaign_message_clustering",
          "protected_url_decoding"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "inet:url": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:url",
            "list": "high_volume_email_service_urls"
          },
          {
            "form": "inet:fqdn",
            "list": "common_marketing_domains"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_FINAL_URL_TO_MESSAGES",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_FINAL_URL_TO_MESSAGES.yaml",
      "summary": "Pivot from a click-time or detonation-resolved final URL to email messages and original embedded URLs that reached it.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Email Final URL -> Messages",
      "description": "Pivot from a click-time or detonation-resolved final URL to email messages and original embedded URLs that reached it.",
      "source": "email:final_url",
      "target": "email:message|inet:url",
      "datasets": [
        "mail_telemetry",
        "mail_click_telemetry",
        "url_corpus"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Final URLs can vary by time, geography, user agent, authentication state, or security-sandbox handling.",
        "Final destinations may be benign shared services or interstitials rather than adversary-controlled infrastructure."
      ],
      "capability_requirements": {
        "required": [
          "redirect_resolution",
          "message_trace_join"
        ],
        "optional": [
          "protected_url_decoding",
          "browser_sandbox_resolution"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "email:final_url": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "common_url_redirectors"
          },
          {
            "form": "inet:fqdn",
            "list": "benign_shared_landing_services"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_FIRST_HOP_MTA_TO_MESSAGES",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_FIRST_HOP_MTA_TO_MESSAGES.yaml",
      "summary": "Pivot from a first-hop mail transfer agent IP or host to email messages observed using that relay within a bounded window.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "First-Hop MTA -> Email Messages",
      "description": "Pivot from a first-hop mail transfer agent IP or host to email messages observed using that relay within a bounded window.",
      "source": "inet:ipv4|inet:fqdn",
      "target": "email:message",
      "datasets": [
        "mail_telemetry",
        "dns",
        "asn_registry"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Shared mail relays, cloud mail platforms, mailing lists, and security gateways can connect many unrelated messages.",
        "First-hop MTA observations can be rewritten or normalized differently across mail telemetry sources.",
        "Message expansion from an MTA must use time windows and degree caps to avoid overjoining campaigns."
      ],
      "capability_requirements": {
        "required": [
          "mailflow_header_normalization",
          "message_identifier_normalization"
        ],
        "optional": [
          "bulk_sender_suppression",
          "tenant_or_recipient_domain_filtering",
          "relay_chain_parsing"
        ]
      },
      "controls": {
        "temporal_window_days": 14,
        "degree_caps": {
          "inet:ipv4": 100000,
          "email:message": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "common_bulk_mail_relays"
          },
          {
            "form": "inet:fqdn",
            "list": "managed_mail_gateway_hosts"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_MESSAGE_TO_EMBEDDED_URLS.yaml",
      "summary": "Pivot from a normalized email message identifier to URLs embedded in its body, headers, attachments, or rendered content.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "Email Message -> Embedded URLs",
      "description": "Pivot from a normalized email message identifier to URLs embedded in its body, headers, attachments, or rendered content.",
      "source": "email:message",
      "target": "inet:url",
      "datasets": [
        "mail_telemetry",
        "url_corpus"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Marketing, notification, and newsletter emails can contain many benign tracking, unsubscribe, image, and CDN URLs.",
        "Security gateways may rewrite or enrich URLs, so extraction must distinguish original message content from protected or detonation-added links.",
        "Common tracking and CDN links should be suppressed or corroborated before treating URL overlap as meaningful."
      ],
      "capability_requirements": {
        "required": [
          "email_url_extraction",
          "url_normalization"
        ],
        "optional": [
          "message_body_parsing",
          "protected_url_decoding"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 90,
        "next_review": "2026-08-24"
      },
      "controls": {
        "temporal_window_days": 7,
        "degree_caps": {
          "email:message": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:url",
            "list": "common_email_service_links"
          },
          {
            "form": "inet:fqdn",
            "list": "common_cdn_domains"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_MESSAGE_TO_FIRST_HOP_MTA",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_MESSAGE_TO_FIRST_HOP_MTA.yaml",
      "summary": "Pivot from a normalized email message to the first-hop mail transfer agent IP or host observed for that message.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "Email Message -> First-Hop MTA",
      "description": "Pivot from a normalized email message to the first-hop mail transfer agent IP or host observed for that message.",
      "source": "email:message",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "mail_telemetry",
        "dns",
        "asn_registry"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "First-hop MTA fields can be absent, rewritten, spoofed, relayed, or hidden by mail gateways and privacy controls.",
        "Bulk senders, mailing lists, and shared relays can produce high-degree benign joins.",
        "An MTA IP observed in mailflow is not proof of sender identity or actor control."
      ],
      "capability_requirements": {
        "required": [
          "mailflow_header_normalization",
          "ip_normalization"
        ],
        "optional": [
          "relay_chain_parsing",
          "bulk_sender_suppression",
          "asn_enrichment"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 90,
        "next_review": "2026-08-24"
      },
      "controls": {
        "temporal_window_days": 7,
        "degree_caps": {
          "email:message": 5000,
          "inet:ipv4": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "common_bulk_mail_relays"
          },
          {
            "form": "inet:fqdn",
            "list": "managed_mail_gateway_hosts"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_ORIGINATING_IP_TO_MESSAGES.yaml",
      "summary": "Pivot from an email-originating IP address to messages that expose the same originating IP in normalized mailflow telemetry.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Email Originating IP -> Messages",
      "description": "Pivot from an email-originating IP address to messages that expose the same originating IP in normalized mailflow telemetry.",
      "source": "inet:ipv4",
      "target": "email:message",
      "datasets": [
        "mail_telemetry",
        "asn_registry",
        "proxy_reputation"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Originating IP headers can be spoofed, stripped, rewritten, or unavailable depending on the mail path and privacy controls.",
        "VPNs, proxies, NAT, compromised hosts, and shared senders can connect unrelated messages to one IP.",
        "An originating IP match is delivery-path evidence, not proof of sender identity."
      ],
      "capability_requirements": {
        "required": [
          "mailflow_header_normalization",
          "originating_ip_extraction"
        ],
        "optional": [
          "proxy_vpn_suppression",
          "sender_domain_filtering",
          "asn_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "inet:ipv4": 50000,
          "email:message": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "common_vpn_proxy_egress"
          },
          {
            "form": "inet:ipv4",
            "list": "common_bulk_mail_relays"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_PROTECTED_URL_CLICK_TO_USERS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_PROTECTED_URL_CLICK_TO_USERS.yaml",
      "summary": "Pivot from a protected email URL click event to the user identity and message context associated with the click.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "Protected URL Click -> Users",
      "description": "Pivot from a protected email URL click event to the user identity and message context associated with the click.",
      "source": "email:url_click",
      "target": "identity:user|email:message",
      "datasets": [
        "mail_click_telemetry",
        "identity",
        "mail_telemetry"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Security scanners, link detonation systems, prefetchers, and mailbox protection services can generate click telemetry that does not represent user action.",
        "Shared mailboxes, aliases, forwarding, and delegated access can obscure which human actually clicked a URL."
      ],
      "capability_requirements": {
        "required": [
          "protected_url_click_telemetry",
          "identity_normalization"
        ],
        "optional": [
          "security_scanner_filtering",
          "message_trace_join"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "email:url_click": 1000,
          "identity:user": 100000
        },
        "negative_nodes": [
          {
            "form": "identity:user",
            "list": "automated_security_mailboxes"
          },
          {
            "form": "email:url_click",
            "list": "security_scanner_clicks"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_URL_COMPONENT_HASH_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_EMAIL_URL_COMPONENT_HASH_CLUSTER.yaml",
      "summary": "Cluster embedded or final email URLs by normalized component hashes such as canonical URL, host, path, query, or final URL hash.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "Email URL Component Hash -> URL Cluster",
      "description": "Cluster embedded or final email URLs by normalized component hashes such as canonical URL, host, path, query, or final URL hash.",
      "source": "url:component_hash",
      "target": "inet:url|email:message",
      "datasets": [
        "mail_telemetry",
        "url_corpus"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "URL component hashes can overcluster benign services when generic paths, empty queries, tracking parameters, or CDN paths dominate.",
        "Canonicalization differences across products can make equivalent URLs fail to match or unrelated URLs collide after aggressive normalization."
      ],
      "capability_requirements": {
        "required": [
          "url_canonicalization",
          "email_url_extraction"
        ],
        "optional": [
          "redirect_resolution",
          "campaign_message_clustering"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "url:component_hash": 100000
        },
        "negative_nodes": [
          {
            "form": "url:component_hash",
            "list": "generic_url_component_hashes"
          },
          {
            "form": "inet:fqdn",
            "list": "common_marketing_domains"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_ENDPOINT_FILE_ORIGIN_URL_TO_FILES",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_ENDPOINT_FILE_ORIGIN_URL_TO_FILES.yaml",
      "summary": "Pivot from endpoint file-origin URL metadata to downloaded files, file paths, and endpoint identities.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "Endpoint File Origin URL -> Files",
      "description": "Pivot from endpoint file-origin URL metadata to downloaded files, file paths, and endpoint identities.",
      "source": "file:origin:url",
      "target": "file:bytes|file:path|endpoint:uid",
      "datasets": [
        "edr",
        "endpoint",
        "proxy_logs"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "File origin metadata can be missing, copied, spoofed, inherited from referrers, or rewritten by browsers and download managers.",
        "Common software CDNs and update endpoints can connect unrelated files and endpoints unless provider controls are applied."
      ],
      "capability_requirements": {
        "required": [
          "endpoint_file_origin_telemetry",
          "file_hash_normalization"
        ],
        "optional": [
          "mark_of_the_web_parsing",
          "download_referrer_extraction"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "file:origin:url": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "common_software_cdn_domains"
          },
          {
            "form": "file:origin:url",
            "list": "browser_internal_urls"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_ENDPOINT_UID_TO_DEVICE_UID_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_ENDPOINT_UID_TO_DEVICE_UID_CLUSTER.yaml",
      "summary": "Pivot from a normalized endpoint identifier to device-level identifiers that may group endpoint telemetry across identity namespaces.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "ownership_signal",
      "name": "Endpoint UID -> Device UID Cluster",
      "description": "Pivot from a normalized endpoint identifier to device-level identifiers that may group endpoint telemetry across identity namespaces.",
      "source": "endpoint:uid",
      "target": "device:uid",
      "datasets": [
        "edr",
        "endpoint",
        "asset_inventory"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Endpoint and device identifiers can reset, collide, be scrubbed, be cloned across images, or represent different identity layers in different sources.",
        "Device UID clustering is many-to-many and needs degree caps, noisy-ID suppression, and cross-source provenance before promotion.",
        "A shared endpoint or device UID cluster is not actor attribution and should be corroborated with independent endpoint or identity evidence."
      ],
      "capability_requirements": {
        "required": [
          "endpoint_identity_normalization",
          "device_identity_mapping"
        ],
        "optional": [
          "asset_inventory_join",
          "edr_device_identity_resolution",
          "image_clone_detection"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 90,
        "next_review": "2026-08-24"
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "endpoint:uid": 100000,
          "device:uid": 100000
        },
        "negative_nodes": [
          {
            "form": "device:uid",
            "list": "default_or_null_device_identifiers"
          },
          {
            "form": "device:uid",
            "list": "cloned_image_device_identifiers"
          },
          {
            "form": "endpoint:uid",
            "list": "shared_kiosk_or_lab_endpoints"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_ENDPOINT_UID_TO_DNS_CACHE_NAMES",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_ENDPOINT_UID_TO_DNS_CACHE_NAMES.yaml",
      "summary": "Pivot from a normalized endpoint identifier to DNS names observed in endpoint DNS cache or recent-resolution telemetry.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Endpoint UID -> DNS Cache Names",
      "description": "Pivot from a normalized endpoint identifier to DNS names observed in endpoint DNS cache or recent-resolution telemetry.",
      "source": "endpoint:uid",
      "target": "inet:fqdn",
      "datasets": [
        "edr",
        "endpoint",
        "dns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Endpoint DNS cache and recent-resolution data can include prefetches, retries, stale cache entries, captive portals, sinkholes, and benign shared services.",
        "Endpoint identifiers can reset, collide, be scrubbed, or represent different identity layers across telemetry sources.",
        "A DNS cache name observed on an endpoint is context for further investigation, not proof of actor control or intent."
      ],
      "capability_requirements": {
        "required": [
          "endpoint_dns_cache_telemetry",
          "endpoint_identity_normalization"
        ],
        "optional": [
          "dns_query_deduplication",
          "sinkhole_or_captive_portal_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "endpoint:uid": 100000,
          "inet:fqdn": 1000000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "captive_portal_or_probe_domains"
          },
          {
            "form": "inet:fqdn",
            "list": "dns_sinkhole_or_blockpage_domains"
          },
          {
            "form": "inet:fqdn",
            "list": "common_os_update_or_telemetry_domains"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_ENDPOINT_UID_TO_EGRESS_IPS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_ENDPOINT_UID_TO_EGRESS_IPS.yaml",
      "summary": "Pivot from a normalized endpoint identifier to public IP addresses observed as endpoint egress or source IP context.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Endpoint UID -> Egress IPs",
      "description": "Pivot from a normalized endpoint identifier to public IP addresses observed as endpoint egress or source IP context.",
      "source": "endpoint:uid",
      "target": "inet:ipv4",
      "datasets": [
        "edr",
        "endpoint",
        "proxy_logs",
        "netflow"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Endpoint egress IPs are weak ownership evidence because NAT, VPN, proxy, corporate or shared egress, DHCP churn, and cloud-hosted workloads can overjoin unrelated endpoints without corroboration.",
        "Endpoint identifiers can reset, collide, be scrubbed, or represent different identity layers across telemetry sources.",
        "An endpoint-to-egress-IP observation is network context, not actor attribution or proof of endpoint ownership."
      ],
      "capability_requirements": {
        "required": [
          "endpoint_network_telemetry",
          "endpoint_identity_normalization"
        ],
        "optional": [
          "proxy_chain_parsing",
          "vpn_or_proxy_enrichment",
          "egress_ip_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "endpoint:uid": 100000,
          "inet:ipv4": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "private_or_reserved_ranges"
          },
          {
            "form": "inet:ipv4",
            "list": "high_volume_corporate_egress_ips"
          },
          {
            "form": "inet:ipv4",
            "list": "known_vpn_proxy_or_tor_egress"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_ENDPOINT_UID_TO_FILE_PATHS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_ENDPOINT_UID_TO_FILE_PATHS.yaml",
      "summary": "Pivot from a normalized endpoint identifier to file paths observed on that endpoint.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Endpoint UID -> File Paths",
      "description": "Pivot from a normalized endpoint identifier to file paths observed on that endpoint.",
      "source": "endpoint:uid",
      "target": "file:path",
      "datasets": [
        "edr",
        "endpoint"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "File paths, directories, process names, and command-line fragments can be generic, localized, user-specific, copied, or privacy-sensitive.",
        "Endpoint file-path observations can reflect benign software layout, user profile naming, installer defaults, or temporary extraction paths.",
        "A shared path on an endpoint is context for follow-on file or process evidence, not actor attribution."
      ],
      "capability_requirements": {
        "required": [
          "endpoint_file_inventory",
          "file_path_normalization"
        ],
        "optional": [
          "user_profile_path_minimization",
          "process_context_join"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "endpoint:uid": 100000,
          "file:path": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:path",
            "list": "default_os_or_program_paths"
          },
          {
            "form": "file:path",
            "list": "temporary_extraction_or_cache_paths"
          },
          {
            "form": "file:path",
            "list": "privacy_sensitive_user_profile_paths"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_FAVICON_HASH_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_FAVICON_HASH_CLUSTER.yaml",
      "summary": "Pivot by identical HTTP favicon hash to discover co-hosted panels or cloned kits.",
      "pattern_schema_version": 1.2,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "HTTP Favicon Hash → FQDN Cluster",
      "description": "Pivot by identical HTTP favicon hash to discover co-hosted panels or cloned kits.",
      "source": "web:site",
      "target": "inet:fqdn",
      "datasets": [
        "tls",
        "osint_web",
        "pdns",
        "shodan_censys"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Common frameworks, panel kits, and copied web templates reuse favicons widely across unrelated sites.",
        "Favicon hashes are exploratory and should be paired with infra, certificate, or content corroboration."
      ],
      "capability_requirements": {
        "required": [
          "web_fingerprinting",
          "http_probe"
        ],
        "optional": [
          "passive_dns",
          "tls_scanning"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "hash:md5": 5000
        },
        "negative_nodes": [
          {
            "form": "web:site",
            "list": "popular_cms_default_icons"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_FILE_HASH_TO_ENDPOINT_UIDS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_FILE_HASH_TO_ENDPOINT_UIDS.yaml",
      "summary": "Pivot from a normalized file hash to endpoint identifiers where the file was observed.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "File Hash -> Endpoint UIDs",
      "description": "Pivot from a normalized file hash to endpoint identifiers where the file was observed.",
      "source": "file:hash",
      "target": "endpoint:uid",
      "datasets": [
        "edr",
        "endpoint",
        "malware_corpus"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "File-hash-to-endpoint pivots can reflect common benign software, shared installers, test files, or malware-sandbox artifacts.",
        "Prevalence and endpoint spread are context, not attribution; common files need suppression before clustering.",
        "Endpoint observations can be stale, deduplicated, or copied between telemetry products, so timing and source provenance must be retained."
      ],
      "capability_requirements": {
        "required": [
          "endpoint_file_inventory",
          "file_hash_normalization"
        ],
        "optional": [
          "software_prevalence_enrichment",
          "sandbox_artifact_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 90,
        "next_review": "2026-08-24"
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "file:hash": 1000000,
          "endpoint:uid": 100000
        },
        "negative_nodes": [
          {
            "form": "file:hash",
            "list": "common_benign_software_hashes"
          },
          {
            "form": "file:hash",
            "list": "shared_installer_or_update_hashes"
          },
          {
            "form": "endpoint:uid",
            "list": "malware_sandbox_or_lab_endpoints"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_FILE_REALPATH_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_FILE_REALPATH_CLUSTER.yaml",
      "summary": "Cluster file hashes or endpoint file observations that share the same normalized runtime or real filesystem path.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "multi_hop_inference",
      "name": "File Real Path Cluster",
      "description": "Cluster file hashes or endpoint file observations that share the same normalized runtime or real filesystem path.",
      "source": "file:path",
      "target": "file:hash|endpoint:file",
      "datasets": [
        "endpoint_telemetry",
        "malware_analysis",
        "file_reputation"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Runtime paths can be generic, installer-created, user-specific, localized, or inherited from shared tooling.",
        "Real paths can expose sensitive host or user details and should be normalized and minimized before publication.",
        "A shared path supports clustering only when paired with prevalence, temporal, and host-context controls."
      ],
      "capability_requirements": {
        "required": [
          "endpoint_file_path_telemetry",
          "path_normalization"
        ],
        "optional": [
          "common_path_suppression",
          "file_hash_enrichment",
          "endpoint_context"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "file:path": 10000,
          "file:hash": 100000,
          "endpoint:file": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:path",
            "list": "common_system_or_application_paths"
          },
          {
            "form": "file:hash",
            "list": "common_benign_file_hashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_FILE_SOURCE_PATH_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_FILE_SOURCE_PATH_CLUSTER.yaml",
      "summary": "Cluster files that expose the same normalized source, build, or project path in metadata, debug records, strings, or extracted configuration.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "File Source Path Cluster",
      "description": "Cluster files that expose the same normalized source, build, or project path in metadata, debug records, strings, or extracted configuration.",
      "source": "file:source_path",
      "target": "file:hash",
      "datasets": [
        "malware_analysis",
        "file_reputation",
        "endpoint_telemetry"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Source paths can be copied, templated, localized, redacted, or produced by common build systems.",
        "Paths can contain user names, project names, or sensitive local filesystem details and require minimization before publication.",
        "A shared source path is build-context evidence, not actor attribution."
      ],
      "capability_requirements": {
        "required": [
          "file_metadata_extraction",
          "path_normalization"
        ],
        "optional": [
          "common_build_path_suppression",
          "pdb_path_extraction",
          "sample_prevalence_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "file:source_path": 5000,
          "file:hash": 100000
        },
        "negative_nodes": [
          {
            "form": "file:source_path",
            "list": "common_build_system_paths"
          },
          {
            "form": "file:hash",
            "list": "common_benign_file_hashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HASSH_FINGERPRINT_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HASSH_FINGERPRINT_CLUSTER.yaml",
      "summary": "Cluster hosts or services observed with the same SSH HASSH client/server fingerprint while filtering common tools and scanners.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "HASSH Fingerprint -> Host Cluster",
      "description": "Cluster hosts or services observed with the same SSH HASSH client/server fingerprint while filtering common tools and scanners.",
      "source": "network:fingerprint:hassh",
      "target": "inet:ipv4|inet:fqdn|network:service",
      "datasets": [
        "honeypot",
        "netflow",
        "shodan_censys"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Common SSH clients, libraries, automation frameworks, and scanning tools can reuse HASSH fingerprints across unrelated activity.",
        "HASSH is sensitive to protocol implementation and capture quality, and should be corroborated with service, timing, or infrastructure context."
      ],
      "capability_requirements": {
        "required": [
          "ssh_fingerprint_telemetry",
          "network_session_normalization"
        ],
        "optional": [
          "honeypot_telemetry",
          "ssh_banner_collection"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "network:fingerprint:hassh": 5000
        },
        "negative_nodes": [
          {
            "form": "network:fingerprint:hassh",
            "list": "common_ssh_client_fingerprints"
          },
          {
            "form": "inet:ipv4",
            "list": "known_scanner_asns"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_BODY_HASH_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HTTP_BODY_HASH_CLUSTER.yaml",
      "summary": "Cluster URLs, hosts, or HTTP observations by a normalized hash of the HTTP response body.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "HTTP Body Hash Cluster",
      "description": "Cluster URLs, hosts, or HTTP observations by a normalized hash of the HTTP response body.",
      "source": "http:body:hash",
      "target": "inet:url|inet:fqdn|http:response",
      "datasets": [
        "http_scans",
        "proxy_logs",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "HTTP body hashes are weak fingerprints when default pages, parked domains, error pages, CDN responses, WAF blocks, and scanner artifacts dominate.",
        "Body hashing can vary with compression, localization, A/B tests, timestamps, personalization, and fetch context.",
        "A shared HTTP body hash is clustering evidence only; corroborate with infrastructure, timing, or content context before drawing conclusions."
      ],
      "capability_requirements": {
        "required": [
          "http_body_capture",
          "http_body_hashing"
        ],
        "optional": [
          "dynamic_content_normalization",
          "scanner_artifact_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "http:body:hash": 100000,
          "inet:fqdn": 1000000
        },
        "negative_nodes": [
          {
            "form": "http:body:hash",
            "list": "default_or_error_page_body_hashes"
          },
          {
            "form": "http:body:hash",
            "list": "parked_domain_or_cdn_body_hashes"
          },
          {
            "form": "http:response",
            "list": "scanner_or_security_product_responses"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_HREF_TO_LINKED_DOMAIN",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HTTP_HREF_TO_LINKED_DOMAIN.yaml",
      "summary": "Pivot from a crawled web page to external FQDNs referenced in href, script, image, form, or embedded resource links.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "HTTP Href -> Linked Domain",
      "description": "Pivot from a crawled web page to external FQDNs referenced in href, script, image, form, or embedded resource links.",
      "source": "web:page",
      "target": "inet:fqdn",
      "datasets": [
        "osint_web",
        "proxy_logs",
        "url_corpus"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "suspected",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Most web pages link to common benign services such as analytics, social media, CDNs, payment processors, and consent platforms.",
        "A linked domain is weak evidence of shared operation unless supported by link context, repeated co-occurrence, or additional infrastructure pivots."
      ],
      "capability_requirements": {
        "required": [
          "web_crawling",
          "url_normalization"
        ],
        "optional": [
          "content_extraction",
          "link_context_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "web:page": 10000,
          "inet:fqdn": 50000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "social_media_platforms"
          },
          {
            "form": "inet:fqdn",
            "list": "analytics_platforms"
          },
          {
            "form": "inet:fqdn",
            "list": "common_cdn_domains"
          },
          {
            "form": "inet:fqdn",
            "list": "payment_and_consent_platforms"
          }
        ],
        "negative_node_count": 4,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_REDIRECT_FINGERPRINT_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HTTP_REDIRECT_FINGERPRINT_CLUSTER.yaml",
      "summary": "Cluster infrastructure exposing the same HTTP redirect fingerprint, including status, redirect headers, and adjacent banner traits.",
      "pattern_schema_version": 1.2,
      "precision_tier": "low",
      "robustness_class": "multi_hop_inference",
      "name": "HTTP Redirect Fingerprint -> Infra Cluster",
      "description": "Cluster infrastructure exposing the same HTTP redirect fingerprint, including status, redirect headers, and adjacent banner traits.",
      "source": "http:redirect:fingerprint",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "shodan_censys",
        "osint_web",
        "tls"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Generic redirect frameworks, WAFs, captive portals, and SaaS front doors can share the same HTTP redirect fingerprint across unrelated infrastructure.",
        "Scanner coverage and banner parsing can miss conditional redirects, JavaScript redirects, or host-specific routing behaviour."
      ],
      "capability_requirements": {
        "required": [
          "http_header_collection",
          "http_redirect_extraction"
        ],
        "optional": [
          "tls_scanning",
          "web_fingerprinting"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "http:redirect:fingerprint": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "common_saas_redirectors"
          },
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_REDIRECT_TARGET_TO_FQDN",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HTTP_REDIRECT_TARGET_TO_FQDN.yaml",
      "summary": "Pivot from a URL or host to FQDNs observed as redirect targets in HTTP, meta-refresh, or JavaScript redirect chains.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "multi_hop_inference",
      "name": "HTTP Redirect Target -> FQDN",
      "description": "Pivot from a URL or host to FQDNs observed as redirect targets in HTTP, meta-refresh, or JavaScript redirect chains.",
      "source": "inet:url|inet:fqdn",
      "target": "inet:fqdn",
      "datasets": [
        "osint_web",
        "shodan_censys",
        "proxy_logs"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Redirect chains often traverse benign SaaS, WAF, link-shortener, tracking, payment, consent, and CDN infrastructure.",
        "Conditional redirects can vary by geography, user agent, cookie state, or time and may not represent stable operator infrastructure.",
        "Common redirectors and shared tracking or CDN services can create false destination clusters; corroborate with source-page context."
      ],
      "capability_requirements": {
        "required": [
          "http_redirect_extraction",
          "url_normalization"
        ],
        "optional": [
          "http_header_collection",
          "web_fingerprinting"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "inet:url": 1000,
          "inet:fqdn": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "common_saas_redirectors"
          },
          {
            "form": "inet:fqdn",
            "list": "link_shorteners"
          },
          {
            "form": "inet:fqdn",
            "list": "analytics_and_consent_platforms"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_SERVER_BANNER_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HTTP_SERVER_BANNER_CLUSTER.yaml",
      "summary": "Cluster hosts or URLs that expose the same distinctive HTTP server banner or platform header value.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "HTTP Server Banner Cluster",
      "description": "Cluster hosts or URLs that expose the same distinctive HTTP server banner or platform header value.",
      "source": "http:server_header",
      "target": "inet:fqdn|inet:ipv4|inet:url",
      "datasets": [
        "osint_web",
        "internet_scan_archives"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Server banners are often default, forged, normalized by proxies, or shared by common hosting stacks.",
        "Internet scan data can be stale, incomplete, or affected by transient middleware and CDN behavior.",
        "Banner reuse is a weak clustering signal unless paired with rarer content, certificate, or hosting evidence."
      ],
      "capability_requirements": {
        "required": [
          "http_header_collection",
          "server_banner_normalization"
        ],
        "optional": [
          "internet_scan_archive_lookup",
          "common_banner_suppression",
          "tls_certificate_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "http:server_header": 100000,
          "inet:fqdn": 100000
        },
        "negative_nodes": [
          {
            "form": "http:server_header",
            "list": "common_default_server_banners"
          },
          {
            "form": "inet:fqdn",
            "list": "common_cdn_or_hosting_domains"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_STATUS_LINE_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HTTP_STATUS_LINE_CLUSTER.yaml",
      "summary": "Cluster HTTP observations by normalized response status line while preserving request context.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "HTTP Status Line Cluster",
      "description": "Cluster HTTP observations by normalized response status line while preserving request context.",
      "source": "http:status_line",
      "target": "inet:url|inet:fqdn|http:response",
      "datasets": [
        "http_scans",
        "proxy_logs",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "HTTP status lines are very weak fingerprints; default servers, middleware, scanners, redirects, CDNs, and WAFs can reuse the same status behavior.",
        "Status-line observations can vary by method, path, user agent, authentication state, region, and time.",
        "A shared status line is triage context only and must not be treated as ownership, compromise, or actor attribution."
      ],
      "capability_requirements": {
        "required": [
          "http_response_capture",
          "http_status_normalization"
        ],
        "optional": [
          "scanner_artifact_suppression",
          "request_context_preservation"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "http:status_line": 1000000,
          "inet:fqdn": 1000000
        },
        "negative_nodes": [
          {
            "form": "http:status_line",
            "list": "common_http_status_lines"
          },
          {
            "form": "inet:fqdn",
            "list": "common_cdn_or_waf_domains"
          },
          {
            "form": "http:response",
            "list": "scanner_or_security_product_responses"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_TITLE_TEMPLATE_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HTTP_TITLE_TEMPLATE_CLUSTER.yaml",
      "summary": "Cluster websites and hosted domains that expose the same distinctive HTTP title or placeholder template marker.",
      "pattern_schema_version": 1.2,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "HTTP Title Template -> FQDN Cluster",
      "description": "Cluster websites and hosted domains that expose the same distinctive HTTP title or placeholder template marker.",
      "source": "web:http:title",
      "target": "inet:fqdn",
      "datasets": [
        "osint_web",
        "shodan_censys",
        "pdns"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Generic placeholder titles, CMS defaults, and reused web themes create obvious false positives unless paired with stronger infra evidence.",
        "HTTP titles are easy to change, localization-sensitive, and often absent or inconsistent across scanners."
      ],
      "capability_requirements": {
        "required": [
          "http_title_collection"
        ],
        "optional": [
          "content_fingerprinting",
          "passive_dns"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "web:http:title": 5000
        },
        "negative_nodes": [
          {
            "form": "web:http:title",
            "list": "popular_cms_default_titles"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 1,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_URI_PATH_PATTERN_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_HTTP_URI_PATH_PATTERN_CLUSTER.yaml",
      "summary": "Cluster URLs or hosts that expose the same distinctive HTTP URI path pattern across telemetry or scan observations.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "HTTP URI Path Pattern Cluster",
      "description": "Cluster URLs or hosts that expose the same distinctive HTTP URI path pattern across telemetry or scan observations.",
      "source": "http:uri:path_pattern",
      "target": "inet:url|inet:fqdn",
      "datasets": [
        "proxy_logs",
        "osint_web",
        "internet_scan_archives"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "URI paths are often default framework routes, CMS files, static resources, or copied phishing-kit paths.",
        "Path-only matches lose query, method, body, and server-context evidence.",
        "High-degree common paths require aggressive negative controls before clustering is useful."
      ],
      "capability_requirements": {
        "required": [
          "http_request_or_scan_path_extraction",
          "uri_path_normalization"
        ],
        "optional": [
          "query_parameter_normalization",
          "common_path_suppression",
          "http_body_fingerprinting"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "http:uri:path_pattern": 100000,
          "inet:url": 1000000
        },
        "negative_nodes": [
          {
            "form": "http:uri:path_pattern",
            "list": "common_framework_or_cms_paths"
          },
          {
            "form": "inet:fqdn",
            "list": "common_hosting_or_cdn_domains"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_IDENTITY_UID_TO_AUTH_SESSIONS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_IDENTITY_UID_TO_AUTH_SESSIONS.yaml",
      "summary": "Pivot from a normalized user identity identifier to authentication sessions observed for that identity.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "Identity UID -> Auth Sessions",
      "description": "Pivot from a normalized user identity identifier to authentication sessions observed for that identity.",
      "source": "identity:user:uid",
      "target": "auth:session",
      "datasets": [
        "identity",
        "auth_logs"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Authentication-session pivots must stay time-bounded; stale or merged sessions can connect unrelated identity activity.",
        "A session associated with an identity can reflect shared accounts, delegated access, service principals, replay, or compromised credentials.",
        "Identity-to-session context is not proof of actor control and should retain source, time, and authentication-method evidence."
      ],
      "capability_requirements": {
        "required": [
          "identity_uid_normalization",
          "auth_session_telemetry"
        ],
        "optional": [
          "mfa_context_join",
          "service_principal_classification"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 91,
        "next_review": "2026-08-25"
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "identity:user:uid": 100000,
          "auth:session": 1000000
        },
        "negative_nodes": [
          {
            "form": "identity:user:uid",
            "list": "shared_or_service_accounts"
          },
          {
            "form": "auth:session",
            "list": "synthetic_or_healthcheck_sessions"
          },
          {
            "form": "auth:session",
            "list": "stale_or_merged_session_records"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_IDENTITY_UID_TO_USER_AGENTS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_IDENTITY_UID_TO_USER_AGENTS.yaml",
      "summary": "Pivot from a normalized user identity identifier to User-Agent strings observed in authentication or web telemetry.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Identity UID -> User-Agents",
      "description": "Pivot from a normalized user identity identifier to User-Agent strings observed in authentication or web telemetry.",
      "source": "identity:user:uid",
      "target": "http:user_agent",
      "datasets": [
        "identity",
        "auth_logs",
        "proxy_logs"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "User-Agent strings are weak identifiers and can be common, spoofed, normalized, truncated, or generated by security products.",
        "Identity-to-User-Agent pivots can be inflated by shared accounts, delegated access, service principals, and browser or app updates.",
        "A User-Agent observed with an identity is context, not actor attribution or proof of a specific endpoint."
      ],
      "capability_requirements": {
        "required": [
          "identity_uid_normalization",
          "user_agent_extraction"
        ],
        "optional": [
          "user_agent_normalization",
          "security_product_user_agent_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "identity:user:uid": 100000,
          "http:user_agent": 10000
        },
        "negative_nodes": [
          {
            "form": "http:user_agent",
            "list": "common_browser_user_agents"
          },
          {
            "form": "http:user_agent",
            "list": "security_product_user_agents"
          },
          {
            "form": "identity:user:uid",
            "list": "shared_or_service_accounts"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_INTEL_OBSERVABLE_TO_TELEMETRY_SIGHTINGS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_INTEL_OBSERVABLE_TO_TELEMETRY_SIGHTINGS.yaml",
      "summary": "Pivot from a normalized intelligence observable to matching sightings across endpoint, mail, network, DNS, or proxy telemetry.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Intel Observable -> Telemetry Sightings",
      "description": "Pivot from a normalized intelligence observable to matching sightings across endpoint, mail, network, DNS, or proxy telemetry.",
      "source": "intel:observable",
      "target": "telemetry:sighting",
      "datasets": [
        "threat_intel",
        "siem",
        "edr",
        "mail_telemetry",
        "proxy_logs",
        "dns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Broad, stale, low-confidence, or commodity observables can match large amounts of unrelated telemetry.",
        "A telemetry sighting of an observable is not actor attribution and should not inherit the source report confidence automatically.",
        "Common or generic observables require corroboration with freshness, sighting context, and confidence before analyst action."
      ],
      "capability_requirements": {
        "required": [
          "intel_observable_normalization",
          "telemetry_sighting_index"
        ],
        "optional": [
          "stix_mapping",
          "sighting_deduplication"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "intel:observable": 1000000
        },
        "negative_nodes": [
          {
            "form": "intel:observable",
            "list": "noisy_or_expired_observables"
          },
          {
            "form": "inet:ipv4",
            "list": "private_or_reserved_ranges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_LOGIN_PAGE_SCRIPT_FINGERPRINT_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_LOGIN_PAGE_SCRIPT_FINGERPRINT_CLUSTER.yaml",
      "summary": "Cluster login pages or hosts that expose the same distinctive JavaScript fingerprint or conditional-rendering script marker.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "multi_hop_inference",
      "name": "Login Page Script Fingerprint Cluster",
      "description": "Cluster login pages or hosts that expose the same distinctive JavaScript fingerprint or conditional-rendering script marker.",
      "source": "javascript:hash|web:behavior:fingerprint",
      "target": "inet:url|inet:fqdn",
      "datasets": [
        "osint_web",
        "url_corpus",
        "internet_scan_archives"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Login-page scripts can be copied from templates, frameworks, phishing kits, legitimate portals, or security products.",
        "Conditional rendering can depend on server replies, cookies, geography, time, or user agent.",
        "A script fingerprint can identify a kit or template, but it does not prove infrastructure ownership.",
        "Common framework scripts and default kit templates create false matches; corroborate with page content and infrastructure context."
      ],
      "capability_requirements": {
        "required": [
          "web_script_extraction",
          "script_fingerprinting"
        ],
        "optional": [
          "dynamic_rendering",
          "phishing_template_suppression",
          "redirect_chain_extraction"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "javascript:hash": 100000,
          "inet:url": 100000
        },
        "negative_nodes": [
          {
            "form": "javascript:hash",
            "list": "common_login_framework_scripts"
          },
          {
            "form": "inet:fqdn",
            "list": "legitimate_identity_provider_hosts"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_MARKETPLACE_SOLD_DOMAIN_CERT_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_MARKETPLACE_SOLD_DOMAIN_CERT_CLUSTER.yaml",
      "summary": "Expand recently sold domains into certificate-linked infrastructure by following post-sale TLS issuance and presentation.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "multi_hop_inference",
      "name": "Marketplace Sold Domain -> TLS Cert -> Infra Cluster",
      "description": "Expand recently sold domains into certificate-linked infrastructure by following post-sale TLS issuance and presentation.",
      "source": "osint:marketplace:sale",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "marketplace",
        "tls",
        "ct",
        "pdns"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Sold domains can be reactivated for benign projects, parking, or speculative holding, so post-sale certificate issuance is not inherently malicious.",
        "Managed certificates, shared hosts, and CT/scanner lag can expand one sold domain into infrastructure that is unrelated or no longer active."
      ],
      "capability_requirements": {
        "required": [
          "marketplace_sale_history",
          "tls_scanning",
          "certificate_normalization"
        ],
        "optional": [
          "ct_history",
          "passive_dns"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "x509:cert": 2000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "letsencrypt_mass_certificates"
          },
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_OPEN_REDIRECT_URL_TO_FINAL_HOSTS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_OPEN_REDIRECT_URL_TO_FINAL_HOSTS.yaml",
      "summary": "Pivot from a URL with open-redirect behavior to final destination hosts observed in redirect chains.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Open Redirect URL -> Final Hosts",
      "description": "Pivot from a URL with open-redirect behavior to final destination hosts observed in redirect chains.",
      "source": "inet:url",
      "target": "inet:fqdn",
      "datasets": [
        "osint_web",
        "proxy_logs",
        "url_corpus"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Open redirect chains often traverse benign websites, SaaS platforms, tracking systems, and security products.",
        "Redirect behavior can depend on geography, user agent, cookies, time, and server-side state.",
        "A redirect target is delivery-chain evidence, not proof that the redirector owner participated.",
        "Common redirect services and shared tracking infrastructure can create false final-host clusters; corroborate with lure and timing evidence."
      ],
      "capability_requirements": {
        "required": [
          "redirect_chain_extraction",
          "url_normalization"
        ],
        "optional": [
          "open_redirect_parameter_detection",
          "conditional_redirect_replay",
          "common_redirector_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "inet:url": 10000,
          "inet:fqdn": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "common_saas_redirectors"
          },
          {
            "form": "inet:fqdn",
            "list": "link_shorteners"
          },
          {
            "form": "inet:fqdn",
            "list": "analytics_and_consent_platforms"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_C2_INFRA",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_SAMPLE_C2_INFRA.yaml",
      "summary": "Detonation-derived C2 infrastructure from file:bytes samples.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "multi_hop_inference",
      "name": "Malware Sample → Sandbox C2 → Infra (IP/FQDN)",
      "description": "Detonation-derived C2 infrastructure from file:bytes samples.",
      "source": "file:bytes",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "sandbox",
        "siem",
        "pdns",
        "abuse_ch"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Detonation output can include sinkholes, researcher infrastructure, or dead configs that never represented live operator control.",
        "Shared hosting and short-lived VPS infrastructure can make malware-adjacent overlap look stronger than it is."
      ],
      "capability_requirements": {
        "required": [
          "malware_sandbox_summary",
          "sample_hash_normalization"
        ],
        "optional": [
          "passive_dns",
          "tls_scanning"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "c2:endpoint": 1000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_MUTEX_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_SAMPLE_MUTEX_CLUSTER.yaml",
      "summary": "Cluster samples reusing mutex names or mutex families while filtering common installer and commodity-software values.",
      "pattern_schema_version": 1.2,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "Mutex Name -> Sample Cluster",
      "description": "Cluster samples reusing mutex names or mutex families while filtering common installer and commodity-software values.",
      "source": "it:exec:mutex",
      "target": "file:bytes",
      "datasets": [
        "sandbox",
        "malware_corpus"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Generic mutex names and framework defaults can cluster unrelated malware or even benign software.",
        "Unpacking and normalization errors can overcount mutex reuse if strings are not canonicalized carefully."
      ],
      "capability_requirements": {
        "required": [
          "malware_static_analysis",
          "sample_hash_normalization"
        ],
        "optional": [
          "common_string_suppression",
          "sample_prevalence_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "it:exec:mutex": 10000
        },
        "negative_nodes": [
          {
            "form": "it:exec:mutex",
            "list": "common_benign_mutexes"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_RICHPE_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_SAMPLE_RICHPE_CLUSTER.yaml",
      "summary": "Cluster Windows samples sharing the same Rich header fingerprint or canonicalized RichPE hash.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "RichPE Fingerprint -> Sample Cluster",
      "description": "Cluster Windows samples sharing the same Rich header fingerprint or canonicalized RichPE hash.",
      "source": "pe:rich:hash",
      "target": "file:bytes",
      "datasets": [
        "sandbox",
        "malware_corpus"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Common toolchains, packers, or vendor build environments can legitimately share RichPE fingerprints.",
        "Packed, stripped, or corrupted samples can reduce coverage and bias the cluster toward better-preserved binaries."
      ],
      "capability_requirements": {
        "required": [
          "pe_metadata_extraction",
          "resource_section_hashing"
        ],
        "optional": [
          "packer_detection",
          "sample_prevalence_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "pe:rich:hash": 10000
        },
        "negative_nodes": [
          {
            "form": "pe:rich:hash",
            "list": "common_compiler_richpe_hashes"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_WEB_CLIENT_UID_TO_IPS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_WEB_CLIENT_UID_TO_IPS.yaml",
      "summary": "Pivot from a normalized browser or web client identifier to source IP addresses observed with that identifier.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Web Client UID -> IPs",
      "description": "Pivot from a normalized browser or web client identifier to source IP addresses observed with that identifier.",
      "source": "web:client:uid",
      "target": "inet:ipv4",
      "datasets": [
        "proxy_logs",
        "browser_telemetry"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Browser/client identifiers can be reset, synced, shared, replayed, truncated, hashed, or scoped to one vendor telemetry source.",
        "NAT, VPN, proxy, carrier-grade NAT, and corporate egress can overjoin many unrelated users or browsers to one IP address.",
        "A browser/client UID to IP match is not actor attribution and should not be treated as proof of endpoint ownership."
      ],
      "capability_requirements": {
        "required": [
          "browser_client_uid_normalization",
          "web_request_source_ip_extraction"
        ],
        "optional": [
          "proxy_chain_parsing",
          "egress_ip_suppression",
          "vpn_or_proxy_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "web:client:uid": 100000,
          "inet:ipv4": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "private_or_reserved_ranges"
          },
          {
            "form": "inet:ipv4",
            "list": "high_volume_corporate_egress_ips"
          },
          {
            "form": "inet:ipv4",
            "list": "known_vpn_proxy_or_tor_egress"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_WEB_CLIENT_UID_TO_URLS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_WEB_CLIENT_UID_TO_URLS.yaml",
      "summary": "Pivot from a normalized browser or web client identifier to URLs and HTTP requests observed with that identifier.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Web Client UID -> URLs",
      "description": "Pivot from a normalized browser or web client identifier to URLs and HTTP requests observed with that identifier.",
      "source": "web:client:uid",
      "target": "inet:url|http:request",
      "datasets": [
        "proxy_logs",
        "browser_telemetry",
        "url_corpus"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Browser/client identifiers can be reset, synced, shared, replayed, truncated, hashed, or scoped to one vendor telemetry source.",
        "URL telemetry can include prefetches, scanners, redirects, embedded resources, and background requests rather than deliberate user navigation.",
        "A browser/client UID match is not actor attribution."
      ],
      "capability_requirements": {
        "required": [
          "browser_client_uid_normalization",
          "web_request_telemetry"
        ],
        "optional": [
          "url_normalization",
          "redirect_chain_extraction",
          "scanner_prefetch_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "web:client:uid": 100000,
          "http:request": 1000000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "browser_prefetch_or_update_domains"
          },
          {
            "form": "http:request",
            "list": "scanner_or_security_product_requests"
          },
          {
            "form": "inet:url",
            "list": "static_embedded_resource_urls"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_WEB_CLIENT_UID_TO_USER_AGENTS",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_WEB_CLIENT_UID_TO_USER_AGENTS.yaml",
      "summary": "Pivot from a normalized browser or web client identifier to User-Agent strings observed with that identifier.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "Web Client UID -> User-Agents",
      "description": "Pivot from a normalized browser or web client identifier to User-Agent strings observed with that identifier.",
      "source": "web:client:uid",
      "target": "http:user_agent",
      "datasets": [
        "proxy_logs",
        "browser_telemetry"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Browser/client identifiers can represent a browser profile, account, cookie jar, device, or product telemetry identity depending on source.",
        "User-Agent strings are weak identifiers and can be common, spoofed, normalized, truncated, or generated by security products.",
        "A browser/client UID to User-Agent match supports context expansion only; it is not actor attribution."
      ],
      "capability_requirements": {
        "required": [
          "browser_client_uid_normalization",
          "user_agent_extraction"
        ],
        "optional": [
          "user_agent_normalization",
          "browser_telemetry_deduplication"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "web:client:uid": 100000,
          "http:user_agent": 10000
        },
        "negative_nodes": [
          {
            "form": "http:user_agent",
            "list": "common_browser_user_agents"
          },
          {
            "form": "http:user_agent",
            "list": "security_product_user_agents"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_WEB_CONTENT_EMBEDDED_CONFIG_STRING_CLUSTER",
      "lane": "working_set",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/CTI_WEB_CONTENT_EMBEDDED_CONFIG_STRING_CLUSTER.yaml",
      "summary": "Cluster URLs or hosted pages that expose the same distinctive embedded configuration string, comment token, or protocol marker.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "multi_hop_inference",
      "name": "Web Content Embedded Config String Cluster",
      "description": "Cluster URLs or hosted pages that expose the same distinctive embedded configuration string, comment token, or protocol marker.",
      "source": "malware:config:string|web:content:token",
      "target": "inet:url|inet:fqdn",
      "datasets": [
        "osint_web",
        "internet_scan_archives",
        "url_corpus"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Embedded web strings can be comments, templates, copied code, analytics markers, or benign application configuration.",
        "High-traffic or compromised sites can host unrelated embedded content, so page ownership and content provenance must stay separate.",
        "A shared embedded config string is clustering evidence, not proof that the page owner controls malware infrastructure."
      ],
      "capability_requirements": {
        "required": [
          "web_content_collection",
          "config_string_extraction"
        ],
        "optional": [
          "html_comment_extraction",
          "script_body_hashing",
          "benign_template_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "web:content:token": 10000,
          "inet:url": 100000
        },
        "negative_nodes": [
          {
            "form": "web:content:token",
            "list": "common_framework_or_analytics_tokens"
          },
          {
            "form": "inet:fqdn",
            "list": "common_hosting_or_cdn_domains"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_DEVICE_FINGERPRINT_TO_ACCOUNT_CLUSTER",
      "lane": "working_set",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/FIN_DEVICE_FINGERPRINT_TO_ACCOUNT_CLUSTER.yaml",
      "summary": "Cluster fraud-linked accounts or identities reusing the same device fingerprint or canonical device profile.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "Device Fingerprint -> Account Cluster",
      "description": "Cluster fraud-linked accounts or identities reusing the same device fingerprint or canonical device profile.",
      "source": "it:device:fingerprint",
      "target": "fin:account|person",
      "datasets": [
        "device_graph",
        "bank_txn",
        "kyc"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Shared devices, emulators, and device-farm infrastructure can connect unrelated users.",
        "Fingerprint drift across SDK or browser updates can fragment true reuse or create synthetic matches.",
        "Account-linking from fingerprints needs KYC or transaction corroboration because false positives are common in shared device pools."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "device_fingerprint_normalization"
        ],
        "optional": [
          "identity_records",
          "emulator_device_farm_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "it:device:fingerprint": 1000
        },
        "negative_nodes": [
          {
            "form": "it:device:fingerprint",
            "list": "shared_enterprise_device_profiles"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_DROP_ADDRESS_CLUSTER",
      "lane": "working_set",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/FIN_DROP_ADDRESS_CLUSTER.yaml",
      "summary": "Cluster accounts, sellers, or identities sharing the same shipping, forwarding, or drop address.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "Drop Address -> Entity Cluster",
      "description": "Cluster accounts, sellers, or identities sharing the same shipping, forwarding, or drop address.",
      "source": "geo:address",
      "target": "org:org|person",
      "datasets": [
        "ecommerce",
        "shipping",
        "kyc"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Apartments, forwarding centres, and commercial mail drops can create benign many-to-one reuse.",
        "Address normalization errors can collapse near-matches or under-segment suites and unit identifiers.",
        "Shared addresses and account records need temporal KYC corroboration to avoid false positives from mail services."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "address_normalization"
        ],
        "optional": [
          "identity_records",
          "forwarder_classification"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "geo:address": 500
        },
        "negative_nodes": [
          {
            "form": "geo:address",
            "list": "fulfillment_centers_and_forwarders"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_ENTITY_SHARED_ACCOUNT_CLUSTER",
      "lane": "working_set",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/FIN_ENTITY_SHARED_ACCOUNT_CLUSTER.yaml",
      "summary": "Cluster people or organisations sharing the same bank, payout, or beneficiary account after filtering processor settlement noise.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "Financial Account -> Shared Entity Cluster",
      "description": "Cluster people or organisations sharing the same bank, payout, or beneficiary account after filtering processor settlement noise.",
      "source": "fin:account",
      "target": "org:org|person",
      "datasets": [
        "bank_txn",
        "kyc"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Processor settlement accounts, treasury sweeps, or shared finance operations can reflect legitimate pooling.",
        "KYC or beneficiary data can be stale or incomplete, so the visible account holder may not be the controlling party."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "account_identifier_normalization"
        ],
        "optional": [
          "identity_records",
          "kyc_context",
          "settlement_account_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "fin:account": 200
        },
        "negative_nodes": [
          {
            "form": "fin:account",
            "list": "known_settlement_accounts"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_MERCHANT_DESCRIPTOR_CLUSTER",
      "lane": "working_set",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/FIN_MERCHANT_DESCRIPTOR_CLUSTER.yaml",
      "summary": "Cluster merchants or storefronts reusing the same descriptor string or canonical billing descriptor.",
      "pattern_schema_version": 1.2,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "Merchant Descriptor -> Merchant Cluster",
      "description": "Cluster merchants or storefronts reusing the same descriptor string or canonical billing descriptor.",
      "source": "fin:merchant:descriptor",
      "target": "fin:merchant",
      "datasets": [
        "payments",
        "ecommerce"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Acquirer-side truncation and generic descriptors can collide across unrelated merchants.",
        "Descriptor reuse alone is weaker than payout, ownership, or settlement evidence and should be treated as supporting context.",
        "Temporal account and KYC context are needed to avoid false positives from shared or generic descriptors."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "descriptor_normalization"
        ],
        "optional": [
          "merchant_profile_context",
          "acquirer_context"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "fin:merchant:descriptor": 2000
        },
        "negative_nodes": [
          {
            "form": "fin:merchant:descriptor",
            "list": "common_processor_descriptors"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_SHARED_PAYOUT_ACCOUNT_CLUSTER",
      "lane": "working_set",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/FIN_SHARED_PAYOUT_ACCOUNT_CLUSTER.yaml",
      "summary": "Cluster merchants, sellers, or beneficiaries routing payouts into the same destination account.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "Payout Account -> Merchant Cluster",
      "description": "Cluster merchants, sellers, or beneficiaries routing payouts into the same destination account.",
      "source": "fin:account",
      "target": "fin:merchant|person",
      "datasets": [
        "payments",
        "bank_txn"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Marketplaces, payment processors, or payroll intermediaries can consolidate payouts for many legitimate recipients.",
        "Account reuse may reflect an upstream intermediary rather than common control by the observed merchants or people.",
        "Temporal KYC and account ownership evidence is needed to avoid false positives from shared payout services."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "payout_account_normalization"
        ],
        "optional": [
          "identity_records",
          "settlement_account_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "fin:account": 500
        },
        "negative_nodes": [
          {
            "form": "fin:account",
            "list": "processor_master_settlement_accounts"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_ACTIVE_SUBDOMAIN_ENUMERATION",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_ACTIVE_SUBDOMAIN_ENUMERATION.yaml",
      "summary": "Discover candidate subdomains under a registrable root using active enumeration tools such as subfinder-style source aggregation and DNS confirmation.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "Active Subdomain Enumeration",
      "description": "Discover candidate subdomains under a registrable root using active enumeration tools such as subfinder-style source aggregation and DNS confirmation.",
      "source": "inet:fqdn",
      "target": "inet:fqdn",
      "datasets": [
        "active_dns",
        "subdomain_osint",
        "dns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Active enumeration discovers names under a root, not proof that each hostname is live, malicious, or independently controlled.",
        "Wildcard DNS, default virtual hosts, resolver poisoning, and stale wordlists can produce false hostnames.",
        "Shared hosting, managed DNS, parking, and provider defaults can surface broad hostname sets that need suppression before expansion."
      ],
      "capability_requirements": {
        "required": [
          "active_subdomain_enumeration",
          "dns_wildcard_detection"
        ],
        "optional": [
          "active_resolution",
          "http_probe"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 92,
        "next_review": "2026-08-26"
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "inet:fqdn": 25000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "wildcard_dns_roots"
          },
          {
            "form": "inet:fqdn",
            "list": "generated_wordlist_artifacts"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_ASN_TO_IP_BLOCKS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_ASN_TO_IP_BLOCKS.yaml",
      "summary": "Enumerate prefixes and live IPs announced by an ASN.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "ASN → IP Blocks",
      "description": "Enumerate prefixes and live IPs announced by an ASN.",
      "source": "net:asn",
      "target": "inet:ipv4",
      "datasets": [
        "bgp"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Transit ASNs and cloud or CDN aggregators announce IP space on behalf of many unrelated customers; a shared ASN is not a shared operator.",
        "BGP origin is the announcing ASN, not the assigned or owning organization; reseller and customer assignments are not visible at this layer.",
        "Prefix delegation can change over time; historical IP/ASN bindings should be timestamped and not treated as current ownership."
      ],
      "capability_requirements": {
        "required": [
          "rir_whois_or_rdap",
          "bgp_history"
        ],
        "optional": [
          "passive_dns",
          "active_resolution"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "net:asn": 1
        },
        "negative_nodes": [
          {
            "form": "net:asn",
            "list": "hyperscaler_asns"
          },
          {
            "form": "net:asn",
            "list": "transit_provider_asns"
          },
          {
            "form": "net:asn",
            "list": "cdn_asns"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_CRT_SH_SUBDOMAINS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_CRT_SH_SUBDOMAINS.yaml",
      "summary": "Discover subdomains via Certificate Transparency entries for a registrable domain.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "CT Logs → Subdomain Enumeration",
      "description": "Discover subdomains via Certificate Transparency entries for a registrable domain.",
      "source": "inet:fqdn",
      "target": "inet:fqdn",
      "datasets": [
        "ct"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Certificate Transparency reveals requested names, not necessarily currently live or controlled subdomains.",
        "Wildcard and SAN-heavy certificates can add noisy names that were never independently deployed.",
        "Common CA defaults and shared CDN or hosting certificates should be corroborated with live DNS, HTTP, or ownership context."
      ],
      "capability_requirements": {
        "required": [
          "ct_history",
          "certificate_normalization"
        ],
        "optional": [
          "dns_wildcard_detection",
          "active_resolution"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 93,
        "next_review": "2026-08-27"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "inet:fqdn": 10000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "wildcard_certificate_names"
          },
          {
            "form": "inet:fqdn",
            "list": "shared_cdn_or_hosting_certificate_names"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_DOMAIN_TO_MX_HOSTS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_DOMAIN_TO_MX_HOSTS.yaml",
      "summary": "Enumerate MX hosts configured for a domain using current or historical DNS observations while preserving observation time.",
      "pattern_schema_version": 1.3,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "Domain -> MX Hosts",
      "description": "Enumerate MX hosts configured for a domain using current or historical DNS observations while preserving observation time.",
      "source": "inet:fqdn",
      "target": "dns:mx|inet:fqdn",
      "datasets": [
        "dns",
        "pdns",
        "rdap"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "demonstrated",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "MX records can be delegated to managed mail providers and usually do not imply domain ownership beyond DNS configuration.",
        "Historical MX records can be stale, parked, sinkholed, or changed after the activity window.",
        "Shared mail providers create high-degree nodes that need suppression for clustering use cases."
      ],
      "capability_requirements": {
        "required": [
          "dns_mx_lookup",
          "dns_name_normalization"
        ],
        "optional": [
          "passive_dns_history",
          "managed_mail_provider_suppression",
          "rdap_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "inet:fqdn": 10000,
          "dns:mx": 100000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "managed_mail_provider_hosts"
          },
          {
            "form": "dns:mx",
            "list": "parked_or_sinkhole_mx_records"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_FQDN_TO_DNS_A_HISTORY",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_FQDN_TO_DNS_A_HISTORY.yaml",
      "summary": "Pivot from an FQDN to IPv4 addresses observed in passive or current DNS A records, preserving observation windows.",
      "pattern_schema_version": 1.3,
      "precision_tier": "low",
      "robustness_class": "domain_expansion",
      "name": "FQDN -> DNS A History",
      "description": "Pivot from an FQDN to IPv4 addresses observed in passive or current DNS A records, preserving observation windows.",
      "source": "inet:fqdn",
      "target": "inet:ipv4",
      "datasets": [
        "pdns",
        "dns",
        "asn"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "DNS A records can be transient, CDN-backed, sinkholed, parked, or reassigned long before later investigation.",
        "A single historical resolution does not imply operator control unless the timing overlaps the investigated activity.",
        "Common CDN, parking, and shared-hosting IPs require corroboration with contemporaneous DNS and service evidence."
      ],
      "capability_requirements": {
        "required": [
          "passive_dns",
          "dns_record_normalization"
        ],
        "optional": [
          "active_resolution",
          "asn_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 1095,
        "degree_caps": {
          "inet:fqdn": 1000,
          "inet:ipv4": 10000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          },
          {
            "form": "inet:ipv4",
            "list": "parking_infrastructure"
          },
          {
            "form": "inet:ipv4",
            "list": "shared_hosting_edges"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_IP_TO_ASN_ORG",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_IP_TO_ASN_ORG.yaml",
      "summary": "Pivot from an IP address to its observed origin ASN and owning or operating organization, preserving observation time.",
      "pattern_schema_version": 1.3,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "IP -> ASN Organization",
      "description": "Pivot from an IP address to its observed origin ASN and owning or operating organization, preserving observation time.",
      "source": "inet:ipv4",
      "target": "net:asn|org:org",
      "datasets": [
        "bgp",
        "rir",
        "rdap"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "BGP origin, RIR allocation, hosting reseller, and customer assignment can point to different organizations for the same IP.",
        "Anycast, cloud providers, and reassigned address space can make current ASN/org context misleading for historical investigations.",
        "Common cloud and shared-hosting ASNs require corroboration with customer-level or temporal allocation evidence."
      ],
      "capability_requirements": {
        "required": [
          "ip_to_asn_mapping",
          "rir_whois_or_rdap"
        ],
        "optional": [
          "bgp_history",
          "hosting_provider_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "inet:ipv4": 10,
          "net:asn": 1000000
        },
        "negative_nodes": [
          {
            "form": "net:asn",
            "list": "public_cloud_and_cdn_asns"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_IP_TO_EXPOSED_RDP",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_IP_TO_EXPOSED_RDP.yaml",
      "summary": "Determine whether an IP exposes RDP and enumerate the observed RDP service surface.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "IP -> Exposed RDP Service",
      "description": "Determine whether an IP exposes RDP and enumerate the observed RDP service surface.",
      "source": "inet:ipv4",
      "target": "it:service:rdp",
      "datasets": [
        "shodan_censys"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Scanner snapshots can miss ephemeral services or record stale exposure after an endpoint changed state.",
        "NAT, protocol gateways, and shared jump hosts can make one IP appear more representative of an operator environment than it really is."
      ],
      "capability_requirements": {
        "required": [
          "rdp_scanning"
        ],
        "optional": [
          "certificate_normalization"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 94,
        "next_review": "2026-08-28"
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "inet:ipv4": 10
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "shared_rdp_gateway_ips"
          },
          {
            "form": "inet:ipv4",
            "list": "scanner_honeypot_or_research_ranges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 1,
          "optional": 1
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_MARKETPLACE_LISTING_TO_DOMAINS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_MARKETPLACE_LISTING_TO_DOMAINS.yaml",
      "summary": "Enumerate domains observed on reseller or auction marketplace listing feeds.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "Marketplace Listing -> Domains",
      "description": "Enumerate domains observed on reseller or auction marketplace listing feeds.",
      "source": "osint:marketplace:listing",
      "target": "inet:fqdn",
      "datasets": [
        "marketplace"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Reseller and auction platforms are broad inventory sources, not threat-only collections, so most listed domains are benign.",
        "Relisting, duplicate feeds, and stale marketplace cache data can preserve domains after a listing changed or disappeared.",
        "Common marketplace inventory and shared reseller feeds require corroboration with current listing details."
      ],
      "capability_requirements": {
        "required": [
          "marketplace_listing_collection"
        ],
        "optional": [
          "domain_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "osint:marketplace:listing": 50000
        },
        "negative_nodes": [
          {
            "form": "osint:marketplace:listing",
            "list": "bulk_reseller_inventory_feeds"
          },
          {
            "form": "osint:marketplace:listing",
            "list": "parking_or_broker_listing_sources"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 1,
          "optional": 1
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_MARKETPLACE_SALE_TO_DOMAINS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_MARKETPLACE_SALE_TO_DOMAINS.yaml",
      "summary": "Enumerate domains observed as sold or transacted on reseller or auction marketplaces.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "Marketplace Sale -> Domains",
      "description": "Enumerate domains observed as sold or transacted on reseller or auction marketplaces.",
      "source": "osint:marketplace:sale",
      "target": "inet:fqdn",
      "datasets": [
        "marketplace"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "A sold marker indicates a marketplace transaction, not who acquired the domain or whether the transfer actually completed.",
        "Marketplace feeds can lag transfers or preserve sale records after re-registration, parking, or benign resale activity.",
        "Common reseller workflows and shared marketplace feeds require corroboration with transfer and registration evidence."
      ],
      "capability_requirements": {
        "required": [
          "marketplace_sale_history"
        ],
        "optional": [
          "domain_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "osint:marketplace:sale": 50000
        },
        "negative_nodes": [
          {
            "form": "osint:marketplace:sale",
            "list": "bulk_reseller_sale_feeds"
          },
          {
            "form": "osint:marketplace:sale",
            "list": "parking_or_broker_transfer_records"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 1,
          "optional": 1
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_MX_TO_DOMAINS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_MX_TO_DOMAINS.yaml",
      "summary": "Find domains pointing to a specific MX; helps detect mass-hosted kits or throwaway mail setups.",
      "pattern_schema_version": 1.2,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "Mail Exchanger → Domains",
      "description": "Find domains pointing to a specific MX; helps detect mass-hosted kits or throwaway mail setups.",
      "source": "inet:fqdn:mx",
      "target": "inet:fqdn",
      "datasets": [
        "pdns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Managed mail providers serve millions of unrelated tenants; a shared MX is not a shared operator.",
        "MX records reflect mail-routing configuration, not domain ownership or operator control.",
        "Email forwarding and DNS-default providers create wide-degree MX clusters that should not be interpreted as adversary infrastructure."
      ],
      "capability_requirements": {
        "required": [
          "dns_public_lookup",
          "dns_mx_lookup"
        ],
        "optional": [
          "passive_dns",
          "managed_mail_provider_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "inet:fqdn:mx": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn:mx",
            "list": "public_mx_providers"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_NS_TO_DOMAINS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_NS_TO_DOMAINS.yaml",
      "summary": "Find domains delegated to a given NS; useful for clustering adversary-managed zones.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "Nameserver → Domains",
      "description": "Find domains delegated to a given NS; useful for clustering adversary-managed zones.",
      "source": "inet:fqdn:ns",
      "target": "inet:fqdn",
      "datasets": [
        "pdns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Provider and reseller nameservers can host large numbers of unrelated zones.",
        "Historical DNS data can retain delegations long after an operator moved or abandoned a domain.",
        "Common provider defaults and shared nameservers require corroboration with domain-specific records and timing."
      ],
      "capability_requirements": {
        "required": [
          "dns_public_lookup",
          "nameserver_enrichment"
        ],
        "optional": [
          "passive_dns",
          "public_suffix_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "inet:fqdn:ns": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn:ns",
            "list": "public_or_managed_dns_provider_nameservers"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_PDNS_ROOT_TO_SUBDOMAINS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_PDNS_ROOT_TO_SUBDOMAINS.yaml",
      "summary": "Enumerate FQDNs observed under a registrable root or apex domain using passive DNS observations.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "enumeration",
      "name": "Passive DNS Root -> Subdomains",
      "description": "Enumerate FQDNs observed under a registrable root or apex domain using passive DNS observations.",
      "source": "inet:fqdn",
      "target": "inet:fqdn",
      "datasets": [
        "pdns",
        "dns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Passive DNS coverage is uneven across resolvers, geographies, and time windows, so absence of a subdomain is not evidence that it never existed.",
        "Wildcard DNS, parking platforms, managed hosting, and scanner artifacts can produce large numbers of low-value hostnames under a root.",
        "Common wildcard and shared-hosting patterns should be corroborated with current DNS and service context before clustering."
      ],
      "capability_requirements": {
        "required": [
          "passive_dns",
          "public_suffix_normalization"
        ],
        "optional": [
          "dns_wildcard_detection",
          "active_resolution"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-26",
        "review_cadence_days": 95,
        "next_review": "2026-08-29"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "inet:fqdn": 25000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "wildcard_dns_roots"
          },
          {
            "form": "inet:fqdn",
            "list": "parked_domain_roots"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_RDAP_EMAIL_TO_DOMAINS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_RDAP_EMAIL_TO_DOMAINS.yaml",
      "summary": "Pivot by registrant email (where disclosed) to enumerate domains; filter privacy/proxy.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "RDAP Registrant Email → Domains",
      "description": "Pivot by registrant email (where disclosed) to enumerate domains; filter privacy/proxy.",
      "source": "rdap:email",
      "target": "inet:fqdn",
      "datasets": [
        "rdap"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Privacy services, forwarding aliases, and shared admin mailboxes can overcluster unrelated domains.",
        "Many registries redact or inconsistently expose email data, which can bias the visible link graph."
      ],
      "capability_requirements": {
        "required": [
          "rdap_enrichment",
          "email_normalization"
        ],
        "optional": [
          "privacy_service_suppression",
          "registrar_reseller_context"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "rdap:email": 5000
        },
        "negative_nodes": [
          {
            "form": "rdap:email",
            "list": "privacy_protect_whois"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_RDAP_REGISTRANT_TO_DOMAINS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_RDAP_REGISTRANT_TO_DOMAINS.yaml",
      "summary": "Pivot by disclosed RDAP registrant entity to enumerate domains while filtering privacy and registrar-noise cases.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "RDAP Registrant -> Domains",
      "description": "Pivot by disclosed RDAP registrant entity to enumerate domains while filtering privacy and registrar-noise cases.",
      "source": "rdap:registrant",
      "target": "inet:fqdn",
      "datasets": [
        "rdap"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Corporate service providers and privacy layers can appear as registrants for unrelated customers.",
        "Registrant entities can change without immediate RDAP updates, leaving stale resolution trails.",
        "RDAP disclosure quality varies sharply by registrar and TLD, so nulls and redactions are common."
      ],
      "capability_requirements": {
        "required": [
          "rdap_enrichment",
          "registrant_normalization"
        ],
        "optional": [
          "entity_normalization",
          "privacy_service_suppression"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "rdap:registrant": 2000
        },
        "negative_nodes": [
          {
            "form": "rdap:registrant",
            "list": "privacy_proxy_registrants"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_TLS_JA3_TO_FQDNS",
      "lane": "working_set",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/OSINT_TLS_JA3_TO_FQDNS.yaml",
      "summary": "Cluster servers or panels that present identical JA3/JA3S fingerprints.",
      "pattern_schema_version": 1.2,
      "precision_tier": "low",
      "robustness_class": "enumeration",
      "name": "TLS JA3 → FQDNs",
      "description": "Cluster servers or panels that present identical JA3/JA3S fingerprints.",
      "source": "tls:ja3",
      "target": "inet:fqdn",
      "datasets": [
        "tls",
        "shodan_censys"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Common TLS client libraries share JA3 fingerprints across large benign populations, so this pivot is inherently noisy.",
        "Middleboxes, fingerprint evolution, and collection bias can make JA3 overlap unstable across time and vantage points."
      ],
      "capability_requirements": {
        "required": [
          "tls_scanning",
          "ja3_fingerprint_extraction"
        ],
        "optional": [
          "common_client_library_suppression",
          "internet_scan_archive_lookup"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "tls:ja3": 5000
        },
        "negative_nodes": [
          {
            "form": "tls:ja3",
            "list": "common_client_library_ja3"
          },
          {
            "form": "tls:ja3",
            "list": "common_scanner_ja3"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "SUPPLY_MAINTAINER_EMAIL_TO_PACKAGES",
      "lane": "working_set",
      "category": "SUPPLY",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/SUPPLY_MAINTAINER_EMAIL_TO_PACKAGES.yaml",
      "summary": "Cluster packages maintained or published by the same maintainer email while filtering privacy and relay addresses.",
      "pattern_schema_version": 1.4,
      "precision_tier": "low",
      "robustness_class": "ownership_signal",
      "name": "Maintainer Email -> Packages",
      "description": "Cluster packages maintained or published by the same maintainer email while filtering privacy and relay addresses.",
      "source": "email:addr",
      "target": "it:prod:softver",
      "datasets": [
        "package_registry",
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Role accounts, relays, and marketplace-managed aliases can span unrelated packages.",
        "Maintainer email is weaker than publisher, repo, or signing evidence and should be treated as corroborative."
      ],
      "capability_requirements": {
        "required": [
          "package_metadata_collection",
          "maintainer_email_normalization"
        ],
        "optional": [
          "privacy_relay_suppression",
          "package_registry_history"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "email:addr": 5000
        },
        "negative_nodes": [
          {
            "form": "email:addr",
            "list": "package_privacy_proxy_addresses"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA",
      "lane": "working_set",
      "category": "SUPPLY",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/SUPPLY_PACKAGE_REPO_TO_DOMAIN_INFRA.yaml",
      "summary": "Bridge software packages to their source repositories and the domains or infrastructure that distribute or operate them.",
      "pattern_schema_version": 1.2,
      "precision_tier": "medium",
      "robustness_class": "domain_expansion",
      "name": "Package -> Repo -> Domain or Infra",
      "description": "Bridge software packages to their source repositories and the domains or infrastructure that distribute or operate them.",
      "source": "it:prod:softver",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "package_registry",
        "osint_web",
        "pdns"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Package-to-repository attribution can break across forks, mirrors, or vendored source releases.",
        "Distribution domains may be CDN or hosting intermediaries rather than developer-controlled infrastructure.",
        "Common registry CDNs and shared release infrastructure require corroboration with package ownership and version context."
      ],
      "capability_requirements": {
        "required": [
          "package_metadata_collection",
          "repo_resolution"
        ],
        "optional": [
          "dns_public_lookup",
          "passive_dns",
          "package_registry_history"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "it:prod:softver": 5000
        },
        "negative_nodes": [
          {
            "form": "code:repo",
            "list": "mass_mirror_repositories"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "SUPPLY_RELEASE_BUCKET_TO_PACKAGES",
      "lane": "working_set",
      "category": "SUPPLY",
      "version": "1.0.0",
      "path": "graph-pivots/working-set/SUPPLY_RELEASE_BUCKET_TO_PACKAGES.yaml",
      "summary": "Cluster packages or release artifacts distributed from the same object-storage release bucket or release endpoint.",
      "pattern_schema_version": 1.4,
      "precision_tier": "medium",
      "robustness_class": "ownership_signal",
      "name": "Release Bucket -> Packages",
      "description": "Cluster packages or release artifacts distributed from the same object-storage release bucket or release endpoint.",
      "source": "cloud:bucket",
      "target": "it:prod:softver",
      "datasets": [
        "package_registry",
        "cloud_asset_inventory"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Shared release buckets and CDN edges can distribute artifacts for many unrelated publishers behind the same bucket reference.",
        "Bucket→package edges should be observed at distribution time; retroactive inference from registry metadata can be misleading after a publisher migrates or revokes a bucket."
      ],
      "capability_requirements": {
        "required": [
          "cloud_bucket_resolution",
          "package_metadata_collection"
        ],
        "optional": [
          "dns_public_lookup",
          "package_registry_history"
        ]
      },
      "review": {
        "last_reviewed": "2026-05-20",
        "review_cadence_days": 90,
        "next_review": "2026-08-18"
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "cloud:bucket": 10000
        },
        "negative_nodes": [
          {
            "form": "cloud:bucket",
            "list": "public_cdn_buckets"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "ADTECH_CREATIVE_SCRIPT_TO_DELIVERY_ENDPOINT",
      "lane": "deferred",
      "category": "ADTECH",
      "version": "0.1.0",
      "path": "graph-pivots/deferred/ADTECH_CREATIVE_SCRIPT_TO_DELIVERY_ENDPOINT.yaml",
      "summary": "Pivot from ad creative HTML, script tags, iframe insertion, or tracking pixel markup to advertiser-controlled delivery, click-log, impression, NOAS, or dynamic CDN endpoints.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Creative Script -> Delivery Endpoint",
      "description": "Pivot from ad creative HTML, script tags, iframe insertion, or tracking pixel markup to advertiser-controlled delivery, click-log, impression, NOAS, or dynamic CDN endpoints.",
      "source": "web:creative",
      "target": "inet:url",
      "datasets": [
        "browser_telemetry",
        "proxy_logs",
        "osint_web",
        "adtech_logs"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "campaign_level",
        "subject_role": "behavioural_cluster",
        "object_role": "tool"
      },
      "hazards": [
        "Third-party creative scripts, verification pixels, and measurement tags are normal in programmatic advertising.",
        "A delivery endpoint can be advertiser-controlled without being malicious.",
        "Shared vendors, CDNs, redirectors, and tracking services can make common scripts appear across unrelated advertisers; corroborate before clustering."
      ],
      "capability_requirements": {
        "required": [
          "web_content_collection",
          "web_script_extraction"
        ],
        "optional": [
          "dynamic_rendering",
          "web_fingerprinting"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "web:creative": 1000,
          "inet:url": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "commodity_ad_verification_pixels"
          },
          {
            "form": "inet:fqdn",
            "list": "known_cdn_static_assets"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "ADTECH_DSP_ID_TO_VENDOR_BUNDLE",
      "lane": "deferred",
      "category": "ADTECH",
      "version": "0.1.0",
      "path": "graph-pivots/deferred/ADTECH_DSP_ID_TO_VENDOR_BUNDLE.yaml",
      "summary": "Pivot from DSP IDs, advertiser IDs, worker domains, bolt domains, benign CDN URLs, and dynamic CDN URLs to a candidate ad-tech vendor or customer bundle.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "ownership_signal",
      "name": "DSP ID -> Vendor Bundle",
      "description": "Pivot from DSP IDs, advertiser IDs, worker domains, bolt domains, benign CDN URLs, and dynamic CDN URLs to a candidate ad-tech vendor or customer bundle.",
      "source": "adtech:dsp:id",
      "target": "org:org|inet:fqdn",
      "datasets": [
        "cti_reports",
        "osint_web",
        "adtech_logs",
        "url_corpus"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "DSP IDs can be local to a platform and may not resolve to globally stable vendors.",
        "White-label, reseller, and bidder-as-a-service deployments can make one DSP bundle serve multiple unrelated customers.",
        "Shared vendors, reseller redirects, and common tracking or CDN endpoints can create false matches; corroborate with platform-specific IDs."
      ],
      "capability_requirements": {
        "required": [
          "web_request_telemetry",
          "adtech_identifier_normalization"
        ],
        "optional": [
          "domain_normalization",
          "vendor_bundle_resolution"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "adtech:dsp:id": 500,
          "adtech:bundle": 500
        },
        "negative_nodes": [
          {
            "form": "org:org",
            "list": "major_public_ad_platforms"
          },
          {
            "form": "inet:fqdn",
            "list": "shared_white_label_dsp_hosts"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "ADTECH_GEO_TARGETING_HEATMAP_TO_CAMPAIGN",
      "lane": "deferred",
      "category": "ADTECH",
      "version": "0.1.0",
      "path": "graph-pivots/deferred/ADTECH_GEO_TARGETING_HEATMAP_TO_CAMPAIGN.yaml",
      "summary": "Link recurring geographic concentration in ad-tech observations to candidate campaign targeting hypotheses when supported by campaign, publisher, or DSP identifiers.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Geo-Targeting Heatmap -> Campaign",
      "description": "Link recurring geographic concentration in ad-tech observations to candidate campaign targeting hypotheses when supported by campaign, publisher, or DSP identifiers.",
      "source": "geo:place",
      "target": "risk:campaign",
      "datasets": [
        "adtech_logs",
        "proxy_logs",
        "browser_telemetry",
        "cti_reports"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "targets",
        "basis": "assessed",
        "scope": "campaign_level",
        "subject_role": "campaign",
        "object_role": "target"
      },
      "hazards": [
        "Ad traffic volume by country can reflect publisher audience composition rather than deliberate targeting.",
        "Location fields in bid streams may be estimated, rounded, stale, or supplied by an upstream partner.",
        "Shared vendor reporting, tracking pixels, and geo-CDN routing can create false targeting patterns; corroborate with campaign configuration."
      ],
      "capability_requirements": {
        "required": [
          "web_request_telemetry",
          "geo_targeting_observation_normalization"
        ],
        "optional": [
          "campaign_context_enrichment",
          "publisher_context"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "geo:place": 5000,
          "adtech:campaign:key": 2000
        },
        "negative_nodes": [
          {
            "form": "geo:place",
            "list": "broad_publisher_audience_baselines"
          },
          {
            "form": "inet:fqdn",
            "list": "high_volume_ad_exchange_endpoints"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "AITS_ABUSE_LANDING_DOMAIN_CLUSTER",
      "lane": "deferred",
      "category": "AITS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/AITS_ABUSE_LANDING_DOMAIN_CLUSTER.yaml",
      "summary": "Link external landing, monetization, or staging domains reused by abusive account clusters.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Abuse Landing Domain -> Account Cluster",
      "description": "Link external landing, monetization, or staging domains reused by abusive account clusters.",
      "source": "inet:fqdn",
      "target": "inet:web:acct",
      "datasets": [
        "platform_abuse",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Shared affiliate, linkhub, or staging domains can connect unrelated abuse accounts and create false positives.",
        "Landing-domain reuse should be corroborated with account behavior, timing, and platform abuse evidence; access to account evidence may be privacy-restricted."
      ],
      "capability_requirements": {
        "required": [
          "restricted_records",
          "platform_abuse_records",
          "domain_normalization"
        ],
        "optional": [
          "web_fingerprinting",
          "account_behavior_context"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "inet:fqdn": 5000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "mainstream_affiliate_and_linkhub_domains"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "AITS_PHONE_OR_PAYMENT_INSTRUMENT_TO_ACCOUNT_CLUSTER",
      "lane": "deferred",
      "category": "AITS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/AITS_PHONE_OR_PAYMENT_INSTRUMENT_TO_ACCOUNT_CLUSTER.yaml",
      "summary": "Cluster abusive model accounts sharing recovery phone numbers or billing instruments across nominally distinct identities.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Phone or Payment Instrument -> Account Cluster",
      "description": "Cluster abusive model accounts sharing recovery phone numbers or billing instruments across nominally distinct identities.",
      "source": "tel:phone|fin:instrument",
      "target": "inet:web:acct",
      "datasets": [
        "platform_abuse",
        "billing"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Family plans, prepaid phones, VoIP pools, shared corporate billing, and payment intermediaries can tie unrelated accounts to the same phone or instrument.",
        "Phone and payment reuse is privacy-sensitive restricted data; corroborate it with account behavior and abuse evidence before clustering."
      ],
      "capability_requirements": {
        "required": [
          "restricted_records",
          "identity_records",
          "financial_records"
        ],
        "optional": [
          "phone_number_normalization",
          "payment_instrument_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "tel:phone|fin:instrument": 1000
        },
        "negative_nodes": [
          {
            "form": "tel:phone|fin:instrument",
            "list": "shared_enterprise_billing_contacts"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "AITS_SHARED_PROMPT_ASSET_CLUSTER",
      "lane": "deferred",
      "category": "AITS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/AITS_SHARED_PROMPT_ASSET_CLUSTER.yaml",
      "summary": "Cluster accounts reusing identical prompt assets, jailbreak snippets, or packaged instruction sets.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Prompt Asset -> Account Cluster",
      "description": "Cluster accounts reusing identical prompt assets, jailbreak snippets, or packaged instruction sets.",
      "source": "file:bytes|message:prompt",
      "target": "inet:web:acct",
      "datasets": [
        "platform_abuse",
        "trust_safety"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Public jailbreak corpora, copied prompt libraries, and common templates can be reused by unrelated accounts and create false positives.",
        "Prompt-asset matches should be corroborated with timing, account behavior, and non-public artifacts; raw prompts may contain privacy-sensitive content."
      ],
      "capability_requirements": {
        "required": [
          "restricted_records",
          "platform_abuse_records",
          "content_fingerprinting"
        ],
        "optional": [
          "privacy_minimization",
          "prompt_asset_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "file:bytes|message:prompt": 5000
        },
        "negative_nodes": [
          {
            "form": "file:bytes|message:prompt",
            "list": "public_prompt_examples"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "AITS_SHARED_TOOL_REPO_TO_ABUSE_ACCOUNTS",
      "lane": "deferred",
      "category": "AITS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/AITS_SHARED_TOOL_REPO_TO_ABUSE_ACCOUNTS.yaml",
      "summary": "Connect shared abuse tooling or prompt-library repositories to model accounts reusing the resulting tools or artifacts.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Abuse Tool Repo -> Account Cluster",
      "description": "Connect shared abuse tooling or prompt-library repositories to model accounts reusing the resulting tools or artifacts.",
      "source": "code:repo",
      "target": "inet:web:acct",
      "datasets": [
        "platform_abuse",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Public tool repositories, forks, mirrors, and tutorial code can be shared across benign and abusive accounts.",
        "Corroborate repository reuse with account behavior and artifact execution; tool adoption alone can create false common-control claims."
      ],
      "capability_requirements": {
        "required": [
          "restricted_records",
          "platform_abuse_records",
          "code_search"
        ],
        "optional": [
          "repository_reputation",
          "tool_artifact_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 730,
        "degree_caps": {
          "code:repo": 10000
        },
        "negative_nodes": [
          {
            "form": "code:repo",
            "list": "benign_public_prompt_repos"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_APP_STORE_DEVELOPER_TO_DOMAINS",
      "lane": "deferred",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CROSS_APP_STORE_DEVELOPER_TO_DOMAINS.yaml",
      "summary": "Connect app-store developer accounts to websites, APIs, and support domains referenced by their published applications.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "App Store Developer -> Domains",
      "description": "Connect app-store developer accounts to websites, APIs, and support domains referenced by their published applications.",
      "source": "app:developer",
      "target": "inet:fqdn",
      "datasets": [
        "app_store",
        "osint_web",
        "pdns"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Shared SDKs, analytics, ad networks, and support vendors can make unrelated developer apps reference common domains.",
        "Developer-account or store metadata can be stale, transferred, or reseller-managed; corroborate with app package content and current domain control."
      ],
      "capability_requirements": {
        "required": [
          "app_store_metadata_collection",
          "dns_public_lookup"
        ],
        "optional": [
          "web_content_collection",
          "package_metadata_collection"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "app:developer": 2000
        },
        "negative_nodes": [
          {
            "form": "app:developer",
            "list": "major_app_marketplace_publishers"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_ASN_ORG_TO_SANCTIONS",
      "lane": "deferred",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CROSS_ASN_ORG_TO_SANCTIONS.yaml",
      "summary": "Check the organization owning an ASN against sanctions (useful in risk screening).",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "missing_negative_controls",
      "name": "ASN Org → Sanctions",
      "description": "Check the organization owning an ASN against sanctions (useful in risk screening).",
      "source": "net:asn",
      "target": "sanction:entry",
      "datasets": [
        "bgp",
        "sanctions"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Shared cloud, hosting, reseller, and transit ASNs can map many unrelated customers to the same organization or sanction-adjacent entity.",
        "Sanctions and ASN organization data change over time; corroborate allocation dates and customer-level evidence to avoid false positives."
      ],
      "capability_requirements": {
        "required": [
          "rir_whois_or_rdap",
          "sanctions_list_access"
        ],
        "optional": [
          "bgp_history",
          "entity_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "net:asn": 1
        },
        "negative_nodes": [
          {
            "form": "net:asn",
            "list": "hyperscaler_or_transit_asns"
          },
          {
            "form": "net:asn",
            "list": "shared_hosting_provider_asns"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_CERT_SUBJECT_TO_LEI_SANCTIONS",
      "lane": "deferred",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CROSS_CERT_SUBJECT_TO_LEI_SANCTIONS.yaml",
      "summary": "Extract certificate subject/organization, map to LEI, and screen against sanctions.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "missing_negative_controls",
      "name": "Cert Subject Org → LEI → Sanctions",
      "description": "Extract certificate subject/organization, map to LEI, and screen against sanctions.",
      "source": "x509:cert",
      "target": "sanction:entry",
      "datasets": [
        "ct",
        "lei",
        "sanctions"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Certificate subject organization fields are free-form, CA-normalized, common, or attacker-controlled and can collide with same-name legal entities.",
        "Sanctions and LEI joins are temporal and entity-resolution sensitive; corroborate current legal records and certificate ownership before risk scoring."
      ],
      "capability_requirements": {
        "required": [
          "certificate_normalization",
          "lei_resolution",
          "sanctions_list_access"
        ],
        "optional": [
          "certificate_subject_normalization",
          "entity_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "x509:cert": 10000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "free_or_shared_ca_default_subjects"
          },
          {
            "form": "x509:cert",
            "list": "generic_certificate_subject_orgs"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_FQDN_TO_ORG_LEI_SANCTIONS",
      "lane": "deferred",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CROSS_FQDN_TO_ORG_LEI_SANCTIONS.yaml",
      "summary": "Bridge a domain to its org via RDAP, map to LEI, and screen against sanctions.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "missing_negative_controls",
      "name": "FQDN → RDAP Org → LEI → Sanctions",
      "description": "Bridge a domain to its org via RDAP, map to LEI, and screen against sanctions.",
      "source": "inet:fqdn",
      "target": "sanction:entry",
      "datasets": [
        "rdap",
        "lei",
        "sanctions"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "RDAP registrants may be privacy-proxied, stale, reseller-owned, common service providers, or same-name collisions rather than the domain controller.",
        "LEI and sanctions joins are temporal; corroborate current registration evidence and avoid treating intermediary links as direct control."
      ],
      "capability_requirements": {
        "required": [
          "rdap_enrichment",
          "lei_resolution",
          "sanctions_list_access"
        ],
        "optional": [
          "privacy_service_suppression",
          "registrar_reseller_context"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "inet:fqdn": 10000
        },
        "negative_nodes": [
          {
            "form": "org:org",
            "list": "privacy_protect_whois"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_PACKAGE_REPO_TO_DOMAIN_INFRA",
      "lane": "deferred",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CROSS_PACKAGE_REPO_TO_DOMAIN_INFRA.yaml",
      "summary": "Bridge repository identity through published packages or release endpoints to the domains or infrastructure serving them.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Repo -> Package -> Domain or Infra",
      "description": "Bridge repository identity through published packages or release endpoints to the domains or infrastructure serving them.",
      "source": "code:repo",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "package_registry",
        "osint_web",
        "pdns"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Package registries, mirrors, CDNs, and abandoned repositories can link unrelated projects to shared distribution infrastructure.",
        "Corroborate repository ownership with signed releases, maintainer history, and current DNS or hosting control before clustering."
      ],
      "capability_requirements": {
        "required": [
          "package_metadata_collection",
          "repo_resolution"
        ],
        "optional": [
          "dns_public_lookup",
          "passive_dns"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "code:repo": 10000
        },
        "negative_nodes": [
          {
            "form": "code:repo",
            "list": "mass_fork_mirrors"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_PHISH_DOMAIN_TO_PAYMENT_PROCESSOR",
      "lane": "deferred",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CROSS_PHISH_DOMAIN_TO_PAYMENT_PROCESSOR.yaml",
      "summary": "Trace phishing pages to their payment processors and connected merchant IDs.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "missing_negative_controls",
      "name": "Phish Domain → Payment Processor → Merchant Network",
      "description": "Trace phishing pages to their payment processors and connected merchant IDs.",
      "source": "inet:fqdn",
      "target": "fin:merchant",
      "datasets": [
        "osint_web",
        "bank_txn"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Large payment processors and checkout providers are shared by many unrelated merchants and create high false-positive risk.",
        "Merchant IDs and processor artifacts are sensitive financial data; corroborate with page content, account-level evidence, and transaction timing."
      ],
      "capability_requirements": {
        "required": [
          "web_content_collection",
          "payment_processor_artifact_extraction"
        ],
        "optional": [
          "financial_records",
          "merchant_profile_context"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "fin:processor": 10000
        },
        "negative_nodes": [
          {
            "form": "fin:merchant",
            "list": "test_or_sandbox_merchant_accounts"
          },
          {
            "form": "fin:merchant",
            "list": "known_good_high_volume_merchants"
          },
          {
            "form": "fin:merchant",
            "list": "shared_checkout_demo_merchants"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_SOCIAL_HANDLE_TO_DOMAIN_INFRA",
      "lane": "deferred",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CROSS_SOCIAL_HANDLE_TO_DOMAIN_INFRA.yaml",
      "summary": "Bridge from social handles to official websites and on to infrastructure for takedown.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "name": "Social Handle → Website → Infra",
      "description": "Bridge from social handles to official websites and on to infrastructure for takedown.",
      "source": "social:handle",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "osint_web",
        "pdns"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Handle reuse across platforms is common and does not guarantee the same person or organisation controls each account.",
        "Domains may reference fans, impersonators, or parked assets rather than infrastructure operated by the handle owner."
      ],
      "capability_requirements": {
        "required": [
          "social_profile_collection",
          "dns_public_lookup"
        ],
        "optional": [
          "passive_dns",
          "domain_ownership_resolution"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "social:handle": 10000
        },
        "negative_nodes": [
          {
            "form": "social:handle",
            "list": "generic_common_usernames"
          },
          {
            "form": "social:handle",
            "list": "fan_impersonator_or_brand_handles"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CROSS_TOOL_REPO_TO_ORG",
      "lane": "deferred",
      "category": "CROSS",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CROSS_TOOL_REPO_TO_ORG.yaml",
      "summary": "Map tool repositories to maintainers/authors and then to their organizations (OSINT).",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Toolcode Repo → Author → Organization",
      "description": "Map tool repositories to maintainers/authors and then to their organizations (OSINT).",
      "source": "code:repo",
      "target": "org:org",
      "datasets": [
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Public repositories, forks, vendor mirrors, and employment changes can misstate who controls or uses a tool.",
        "Corroborate maintainer and organization links with signed commits, release ownership, and current affiliation before inferring relationship."
      ],
      "capability_requirements": {
        "required": [
          "code_search",
          "maintainer_identity_resolution"
        ],
        "optional": [
          "git_metadata",
          "entity_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "code:repo": 100000
        },
        "negative_nodes": [
          {
            "form": "code:repo",
            "list": "mass_fork_mirrors"
          },
          {
            "form": "code:repo",
            "list": "vendor_mirror_or_template_repositories"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_AUTHENTICODE_HASH_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_AUTHENTICODE_HASH_CLUSTER.yaml",
      "summary": "Cluster signed files by normalized Authenticode or signature-derived hash material while preserving certificate and file-hash context.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Authenticode Hash Cluster",
      "description": "Cluster signed files by normalized Authenticode or signature-derived hash material while preserving certificate and file-hash context.",
      "source": "code:authenticode:hash",
      "target": "file:hash|x509:cert",
      "datasets": [
        "malware_corpus",
        "sandbox",
        "code_signing_metadata"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Authenticode, signer, issuer, and certificate-derived hashes can mix certificate identity, signature metadata, timestamping, and file lineage if adapters normalize them inconsistently.",
        "Common or shared enterprise signing services, timestamp authorities, test certificates, and mass-signing infrastructure can create high-degree clusters that require corroborating file lineage.",
        "Promotion needs fixtures that distinguish signature hash, signer certificate, issuer, serial, and file hash semantics before this can graduate."
      ],
      "capability_requirements": {
        "required": [
          "authenticode_metadata_extraction",
          "file_hash_normalization"
        ],
        "optional": [
          "signer_certificate_chain_resolution",
          "timestamp_authority_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "code:authenticode:hash": 100000,
          "x509:cert": 100000
        },
        "negative_nodes": [
          {
            "form": "code:authenticode:hash",
            "list": "timestamp_authority_or_mass_signing_hashes"
          },
          {
            "form": "x509:cert",
            "list": "enterprise_mass_signing_services"
          },
          {
            "form": "x509:cert",
            "list": "test_or_default_signing_certificates"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CAMPAIGN_TOOL_FQDN",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_CAMPAIGN_TOOL_FQDN.yaml",
      "summary": "Campaign-to-domain linkage via shared tool family evidence across sources.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Campaign ↔ Tool → FQDN",
      "description": "Campaign-to-domain linkage via shared tool family evidence across sources.",
      "source": "risk:campaign",
      "target": "inet:fqdn",
      "datasets": [
        "cti_reports",
        "pdns",
        "siem"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Commodity tools and shared hosting can put unrelated campaigns on common domains or infrastructure.",
        "Corroborate tool-family evidence with temporal observations and independent indicators; this pivot is not attribution by itself."
      ],
      "capability_requirements": {
        "required": [
          "cti_report_extraction",
          "tool_family_normalization"
        ],
        "optional": [
          "passive_dns",
          "domain_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 720,
        "degree_caps": {
          "it:prod:soft": 300
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "dynamic_dns_providers"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CERT_ISSUER_VALIDITY_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_CERT_ISSUER_VALIDITY_CLUSTER.yaml",
      "summary": "Expand infrastructure presenting certificates that share the same issuer and validity-duration profile.",
      "pattern_schema_version": 1.2,
      "precision_tier": "low",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Issuer + Validity Certificate Profile -> Infra Cluster",
      "description": "Expand infrastructure presenting certificates that share the same issuer and validity-duration profile.",
      "source": "x509:cert:profile",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "tls",
        "ct"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Large commercial issuers, enterprise intermediates, and managed certificate programs can generate broad benign overlap for the same issuer and validity profile.",
        "Issuer labels alone can hide subordinate CA variation, while validity lengths can cluster unrelated automated issuance pipelines.",
        "Common managed-certificate defaults require corroboration with SAN, subject, hosting, or malware evidence before clustering."
      ],
      "capability_requirements": {
        "required": [
          "tls_scanning",
          "certificate_normalization"
        ],
        "optional": [
          "ct_history"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "x509:cert": 10000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "common_managed_certificate_profiles"
          },
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CLOUD_TENANT_UID_TO_AUTH_EVENTS",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_CLOUD_TENANT_UID_TO_AUTH_EVENTS.yaml",
      "summary": "Pivot from a normalized cloud tenant identifier to authentication events observed within or against that tenant context.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Cloud Tenant UID -> Auth Events",
      "description": "Pivot from a normalized cloud tenant identifier to authentication events observed within or against that tenant context.",
      "source": "cloud:tenant:uid",
      "target": "auth:event|auth:session",
      "datasets": [
        "cloud_audit_logs",
        "auth_logs",
        "identity"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Cloud tenant pivots can cross administrative, customer, service-principal, guest-user, shared-service, and multi-tenant application boundaries.",
        "Auth events can be generated by service principals, automation, health checks, delegated access, and federation flows rather than direct user action.",
        "A tenant-to-auth-event relationship is control-plane context, not ownership, compromise, or actor attribution without corroborating evidence."
      ],
      "capability_requirements": {
        "required": [
          "cloud_tenant_uid_normalization",
          "cloud_auth_event_telemetry"
        ],
        "optional": [
          "service_principal_classification",
          "guest_user_context"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "cloud:tenant:uid": 100000,
          "auth:event": 1000000
        },
        "negative_nodes": [
          {
            "form": "auth:event",
            "list": "synthetic_or_healthcheck_auth_events"
          },
          {
            "form": "identity:user:uid",
            "list": "guest_or_service_principal_accounts"
          },
          {
            "form": "cloud:tenant:uid",
            "list": "multi_tenant_provider_or_demo_tenants"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CLOUD_TENANT_UID_TO_EMAIL_URLS",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_CLOUD_TENANT_UID_TO_EMAIL_URLS.yaml",
      "summary": "Pivot from a normalized cloud tenant identifier to URLs observed in email telemetry associated with that tenant context.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Cloud Tenant UID -> Email URLs",
      "description": "Pivot from a normalized cloud tenant identifier to URLs observed in email telemetry associated with that tenant context.",
      "source": "cloud:tenant:uid",
      "target": "inet:url|email:message",
      "datasets": [
        "cloud_audit_logs",
        "mail_telemetry",
        "url_corpus"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Cloud tenant to email URL pivots can cross administrative, customer, guest-user, service-principal, and multi-tenant application boundaries.",
        "Email URLs can include security rewrites, marketing links, CDNs, shared SaaS links, redirects, and detonation artifacts.",
        "A tenant-to-email-URL relationship is telemetry context only; it is not ownership, compromise, or actor attribution without message and tenant corroboration."
      ],
      "capability_requirements": {
        "required": [
          "cloud_tenant_uid_normalization",
          "email_url_extraction"
        ],
        "optional": [
          "protected_url_decoding",
          "message_trace_join",
          "tenant_message_context"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "cloud:tenant:uid": 100000,
          "inet:url": 1000000
        },
        "negative_nodes": [
          {
            "form": "inet:url",
            "list": "common_email_service_links"
          },
          {
            "form": "inet:fqdn",
            "list": "common_cdn_domains"
          },
          {
            "form": "cloud:tenant:uid",
            "list": "multi_tenant_provider_or_demo_tenants"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CLUSTER_GRAPH_EDGE_EXPLAINED",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_CLUSTER_GRAPH_EDGE_EXPLAINED.yaml",
      "summary": "Represent a proprietary cluster-graph edge only when the contributing lower-level pivot evidence, feature values, cap status, and negative-node decisions are emitted.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Explained Cluster Graph Edge",
      "description": "Represent a proprietary cluster-graph edge only when the contributing lower-level pivot evidence, feature values, cap status, and negative-node decisions are emitted.",
      "source": "graph:cluster",
      "target": "inet:ipv4|inet:fqdn|risk:campaign|threat:cluster",
      "datasets": [
        "cluster_graph",
        "pdns",
        "rdap",
        "tls",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "A proprietary cluster edge can hide high-degree nodes, weak features, or filtered evidence unless all contributing paths are exposed.",
        "Cluster membership is not actor attribution and should not be promoted without lower-level evidence and separate attribution confidence.",
        "Common high-degree features and shared default values can generate false cluster edges; require corroboration from exposed contributing evidence."
      ],
      "capability_requirements": {
        "required": [
          "cluster_feature_export",
          "pivot_edge_provenance"
        ],
        "optional": [
          "negative_node_decisions",
          "analyst_adjudication"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "graph:cluster": 100000
        },
        "negative_nodes": [
          {
            "form": "graph:evidence:path",
            "list": "unsupported_black_box_edges"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_COOKIE_NAME_REUSE_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_COOKIE_NAME_REUSE_CLUSTER.yaml",
      "summary": "Cluster webpages or hostnames that reuse distinctive normalized cookie names or cookie-name namespaces.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Cookie Name Reuse Cluster",
      "description": "Cluster webpages or hostnames that reuse distinctive normalized cookie names or cookie-name namespaces.",
      "source": "web:cookie:name",
      "target": "inet:fqdn|inet:url",
      "datasets": [
        "osint_web",
        "web_crawl"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Common frameworks, consent managers, analytics SDKs, tag managers, A/B testing platforms, and security products create common cookie names across unrelated sites.",
        "Third-party cookies and copied templates can link unrelated domains to the same vendor-controlled namespace.",
        "Cookie values are intentionally out of scope for this pattern unless separately normalized, minimized, and reviewed for privacy impact.",
        "Cookie-name reuse is a weak clustering signal and must be corroborated with page ownership, timing, content, or infrastructure evidence."
      ],
      "capability_requirements": {
        "required": [
          "web_crawling",
          "http_cookie_extraction",
          "cookie_name_normalization"
        ],
        "optional": [
          "javascript_rendering",
          "tag_manager_extraction",
          "common_cookie_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "web:cookie:name": 100000,
          "inet:fqdn": 1000000
        },
        "negative_nodes": [
          {
            "form": "web:cookie:name",
            "list": "common_framework_or_consent_cookie_names"
          },
          {
            "form": "web:cookie:name",
            "list": "analytics_or_tag_manager_cookie_names"
          },
          {
            "form": "inet:fqdn",
            "list": "common_hosting_or_cdn_domains"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 3,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_CVE_EXPLOIT_CAMPAIGN",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_CVE_EXPLOIT_CAMPAIGN.yaml",
      "summary": "Link a CVE to campaigns reported to exploit it, to support attribution and remediation priority.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "CVE → Exploit Usage → Campaign",
      "description": "Link a CVE to campaigns reported to exploit it, to support attribution and remediation priority.",
      "source": "it:sec:vuln",
      "target": "risk:campaign",
      "datasets": [
        "nvd_cve",
        "cti_reports",
        "misp"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Public exploit reporting, opportunistic scanning, and copycat exploitation can make a CVE appear across unrelated campaigns.",
        "Corroborate campaign linkage with toolmarks, timing, and victimology; CVE use alone does not prove attribution or common control."
      ],
      "capability_requirements": {
        "required": [
          "vulnerability_intelligence",
          "cti_report_extraction"
        ],
        "optional": [
          "tool_family_normalization",
          "campaign_context_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "it:sec:vuln": 2000
        },
        "negative_nodes": [
          {
            "form": "it:sec:vuln",
            "list": "mass_scanned_or_wormable_cves"
          },
          {
            "form": "it:sec:vuln",
            "list": "roundup_reported_cves"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_DOMAIN_REGISTRATION_PROFILE_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_DOMAIN_REGISTRATION_PROFILE_CLUSTER.yaml",
      "summary": "Cluster domains that share a narrow, normalized registration profile across registrar, registrant, nameserver, timing, and hosting features.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Domain Registration Profile Cluster",
      "description": "Cluster domains that share a narrow, normalized registration profile across registrar, registrant, nameserver, timing, and hosting features.",
      "source": "domain:registration:profile",
      "target": "inet:fqdn",
      "datasets": [
        "rdap",
        "whois_history",
        "pdns",
        "dns"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Registration profiles are composite, often privacy-protected, and can reflect registrar defaults or reseller workflows rather than operator behavior.",
        "Shared registrars, nameservers, privacy services, and hosting providers can create broad false-positive clusters.",
        "This pattern must not duplicate atomic RDAP, nameserver, DNS, certificate, or ASN pivots that already exist."
      ],
      "capability_requirements": {
        "required": [
          "rdap_or_whois_normalization",
          "domain_registration_feature_extraction"
        ],
        "optional": [
          "privacy_service_suppression",
          "registrar_reseller_context",
          "nameserver_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "domain:registration:profile": 10000,
          "inet:fqdn": 100000
        },
        "negative_nodes": [
          {
            "form": "domain:registrar",
            "list": "commodity_registrars"
          },
          {
            "form": "rdap:registrant",
            "list": "privacy_or_proxy_registrants"
          },
          {
            "form": "dns:nameserver",
            "list": "managed_dns_provider_nameservers"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_DOM_STRUCTURE_HASH_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_DOM_STRUCTURE_HASH_CLUSTER.yaml",
      "summary": "Cluster webpages or hostnames that share a normalized DOM structure hash after crawler and rendering settings are recorded.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "DOM Structure Hash Cluster",
      "description": "Cluster webpages or hostnames that share a normalized DOM structure hash after crawler and rendering settings are recorded.",
      "source": "web:dom:structure_hash",
      "target": "inet:fqdn|inet:url",
      "datasets": [
        "osint_web",
        "web_crawl",
        "web_archive"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Common CMS themes, landing-page builders, parked-domain templates, consent banners, and cloned starter kits can produce unrelated DOM-structure matches.",
        "JavaScript rendering mode, localization, A/B tests, anti-bot responses, and viewport-dependent markup can make the same site hash differently across crawls.",
        "CDN, WAF, registrar holding, and shared SaaS front-door pages can dominate high-degree DOM hashes and must be suppressed before promotion.",
        "DOM structure reuse is a clustering lead only; it must not be treated as ownership, compromise, or attribution without corroborating content or infrastructure evidence."
      ],
      "capability_requirements": {
        "required": [
          "web_crawling",
          "html_normalization",
          "dom_fingerprinting"
        ],
        "optional": [
          "javascript_rendering",
          "content_deduplication",
          "web_archive_lookup"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "web:dom:structure_hash": 100000,
          "inet:fqdn": 1000000
        },
        "negative_nodes": [
          {
            "form": "web:dom:structure_hash",
            "list": "common_cms_or_builder_template_hashes"
          },
          {
            "form": "web:dom:structure_hash",
            "list": "parked_domain_or_registrar_holding_page_hashes"
          },
          {
            "form": "inet:fqdn",
            "list": "common_hosting_or_cdn_domains"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 3,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_ATTACHMENT_AV_CLUSTER_HASH_TO_MESSAGES",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_EMAIL_ATTACHMENT_AV_CLUSTER_HASH_TO_MESSAGES.yaml",
      "summary": "Pivot from an attachment AV cluster hash or similar normalized file-family fingerprint to email messages carrying matching attachments.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Email Attachment AV Cluster Hash -> Messages",
      "description": "Pivot from an attachment AV cluster hash or similar normalized file-family fingerprint to email messages carrying matching attachments.",
      "source": "file:av_cluster_hash",
      "target": "email:message",
      "datasets": [
        "mail_telemetry",
        "file_reputation",
        "malware_analysis"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "AV cluster hashes are implementation-specific and can change across engines, versions, or normalization choices.",
        "Cluster hashes can group benign families, packed files, common templates, or broad malware families too coarsely for precise pivoting.",
        "Mail detonation, forwarding, and bulk campaigns can inflate message counts."
      ],
      "capability_requirements": {
        "required": [
          "attachment_cluster_hash_normalization",
          "mail_attachment_telemetry"
        ],
        "optional": [
          "file_hash_enrichment",
          "av_engine_version_context",
          "bulk_mail_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "file:av_cluster_hash": 100000,
          "email:message": 100000
        },
        "negative_nodes": [
          {
            "form": "file:av_cluster_hash",
            "list": "broad_or_common_av_cluster_hashes"
          },
          {
            "form": "email:message",
            "list": "bulk_or_detonation_generated_messages"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_ATTACHMENT_NAME_TO_MESSAGES",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_EMAIL_ATTACHMENT_NAME_TO_MESSAGES.yaml",
      "summary": "Pivot from a normalized email attachment name to messages that carried attachments with that name.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "enumeration",
      "name": "Email Attachment Name -> Messages",
      "description": "Pivot from a normalized email attachment name to messages that carried attachments with that name.",
      "source": "email:attachment:name",
      "target": "email:message",
      "datasets": [
        "mail_telemetry",
        "file_reputation"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Attachment names are attacker-controlled, user-visible, localized, and frequently generic.",
        "Forwarding, bulk mail, newsletters, templates, and detonation can inflate message counts.",
        "Attachment-name matches should remain exploratory unless paired with file hash, sender, URL, or mailflow context."
      ],
      "capability_requirements": {
        "required": [
          "attachment_name_extraction",
          "message_identifier_normalization"
        ],
        "optional": [
          "file_hash_enrichment",
          "common_attachment_name_suppression",
          "bulk_mail_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "email:attachment:name": 100000,
          "email:message": 100000
        },
        "negative_nodes": [
          {
            "form": "email:attachment:name",
            "list": "common_attachment_names"
          },
          {
            "form": "email:message",
            "list": "bulk_or_marketing_messages"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_HEADER_VALUE_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_EMAIL_HEADER_VALUE_CLUSTER.yaml",
      "summary": "Cluster email messages that share a rare normalized header value such as a mailer marker, charset, custom header, or relay artifact.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Email Header Value Cluster",
      "description": "Cluster email messages that share a rare normalized header value such as a mailer marker, charset, custom header, or relay artifact.",
      "source": "email:header:value",
      "target": "email:message",
      "datasets": [
        "mail_telemetry"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Email header values can be spoofed, rewritten, normalized, stripped, or generated by common mail software.",
        "Headers can contain personal data, internal hostnames, or tenant-specific values that require minimization.",
        "Header-value reuse is weak unless the value is rare and corroborated by attachment, sender, URL, or relay evidence."
      ],
      "capability_requirements": {
        "required": [
          "email_header_parsing",
          "header_value_normalization"
        ],
        "optional": [
          "privacy_minimization",
          "common_mailer_suppression",
          "message_body_context"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "email:header:value": 50000,
          "email:message": 100000
        },
        "negative_nodes": [
          {
            "form": "email:header:value",
            "list": "common_mailer_or_gateway_headers"
          },
          {
            "form": "email:message",
            "list": "bulk_or_marketing_messages"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_MESSAGE_ID_HOST_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_EMAIL_MESSAGE_ID_HOST_CLUSTER.yaml",
      "summary": "Cluster email messages that share the same normalized host or domain component extracted from Message-ID values.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Email Message-ID Host Cluster",
      "description": "Cluster email messages that share the same normalized host or domain component extracted from Message-ID values.",
      "source": "email:message:id:host",
      "target": "email:message",
      "datasets": [
        "mail_telemetry"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Message-ID host components can be forged, templated by mailing software, or inherited from legitimate mail infrastructure.",
        "Large mail platforms and common libraries can produce high-degree host patterns across unrelated messages.",
        "A Message-ID host overlap is weak unless paired with sender, attachment, relay, or campaign context."
      ],
      "capability_requirements": {
        "required": [
          "message_id_parsing",
          "mailflow_identifier_normalization"
        ],
        "optional": [
          "common_mailer_suppression",
          "sender_domain_context",
          "attachment_hash_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "email:message:id:host": 10000,
          "email:message": 100000
        },
        "negative_nodes": [
          {
            "form": "email:message:id:host",
            "list": "common_mail_platform_message_id_hosts"
          },
          {
            "form": "email:message",
            "list": "bulk_or_marketing_messages"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_TEMPLATE_OR_ASSET_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_EMAIL_TEMPLATE_OR_ASSET_CLUSTER.yaml",
      "summary": "Cluster phishing or lure infrastructure reusing the same template asset, image, or packaged email content.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Email Template or Asset Hash -> Host Cluster",
      "description": "Cluster phishing or lure infrastructure reusing the same template asset, image, or packaged email content.",
      "source": "hash:sha256",
      "target": "inet:fqdn",
      "datasets": [
        "mail_telemetry",
        "osint_web",
        "sandbox"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Common templates, stock images, and phishing-kit boilerplate can be shared by unrelated operators or reused by defenders in tests.",
        "Corroborate asset reuse with delivery infrastructure, sender context, and timing before clustering campaigns."
      ],
      "capability_requirements": {
        "required": [
          "email_telemetry",
          "content_fingerprinting"
        ],
        "optional": [
          "phishing_template_suppression",
          "campaign_message_clustering"
        ]
      },
      "controls": {
        "temporal_window_days": 730,
        "degree_caps": {
          "hash:sha256": 5000
        },
        "negative_nodes": [
          {
            "form": "hash:sha256",
            "list": "common_marketing_asset_hashes"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_EMAIL_WEBMAIL_ATTACHMENT_SENDER_DOMAIN_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_EMAIL_WEBMAIL_ATTACHMENT_SENDER_DOMAIN_CLUSTER.yaml",
      "summary": "Pivot from a sender domain seen in webmail attachment telemetry to attachment file hashes and endpoint observations.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Webmail Attachment Sender Domain -> Files",
      "description": "Pivot from a sender domain seen in webmail attachment telemetry to attachment file hashes and endpoint observations.",
      "source": "email:sender:domain",
      "target": "file:bytes|endpoint:uid",
      "datasets": [
        "mail_telemetry",
        "edr",
        "endpoint"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "suspected",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Webmail attachment origin metadata can reflect provider infrastructure, forwarding, cached attachments, or rewritten download URLs rather than sender-controlled infrastructure.",
        "Sender domains can be spoofed, compromised, delegated, or shared across unrelated senders, so this pivot needs strong message and file corroboration."
      ],
      "capability_requirements": {
        "required": [
          "mail_attachment_telemetry",
          "file_hash_normalization"
        ],
        "optional": [
          "sender_authentication_results",
          "endpoint_file_origin_telemetry"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "email:sender:domain": 100000
        },
        "negative_nodes": [
          {
            "form": "email:sender:domain",
            "list": "consumer_webmail_provider_domains"
          },
          {
            "form": "file:origin:url",
            "list": "webmail_provider_attachment_urls"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_ENDPOINT_PROCESS_TO_REMOTE_CONNECTIONS",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_ENDPOINT_PROCESS_TO_REMOTE_CONNECTIONS.yaml",
      "summary": "Pivot from an endpoint process observation to remote network destinations connected by that process.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Endpoint Process -> Remote Connections",
      "description": "Pivot from an endpoint process observation to remote network destinations connected by that process.",
      "source": "endpoint:process",
      "target": "inet:ipv4|inet:fqdn|network:connection",
      "datasets": [
        "edr",
        "endpoint",
        "netflow"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Process-to-remote-connection joins can be distorted by proxy processes, browser helpers, service hosts, injected code, log forwarding, and endpoint telemetry gaps.",
        "Remote endpoints can be CDNs, update services, identity providers, scanners, or shared infrastructure rather than adversary-controlled destinations.",
        "Promotion needs fixtures for parent/child process context, proxy-process suppression, and destination negative controls before operational use."
      ],
      "capability_requirements": {
        "required": [
          "endpoint_process_telemetry",
          "endpoint_network_telemetry"
        ],
        "optional": [
          "process_tree_reconstruction",
          "proxy_process_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 7,
        "degree_caps": {
          "endpoint:process": 100000,
          "network:connection": 1000000
        },
        "negative_nodes": [
          {
            "form": "endpoint:process",
            "list": "common_proxy_or_browser_helper_processes"
          },
          {
            "form": "inet:fqdn",
            "list": "common_cdn_or_update_domains"
          },
          {
            "form": "network:connection",
            "list": "scanner_or_security_product_connections"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_FILE_LSHASH_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_FILE_LSHASH_CLUSTER.yaml",
      "summary": "Cluster files by locality-sensitive hash values while preserving threshold, corpus, and exact-hash context.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "File LSHASH Cluster",
      "description": "Cluster files by locality-sensitive hash values while preserving threshold, corpus, and exact-hash context.",
      "source": "file:lshash",
      "target": "file:hash",
      "datasets": [
        "malware_corpus",
        "sandbox",
        "edr"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Locality-sensitive hashes can overcluster files that share boilerplate, packers, libraries, templates, or benign build artifacts.",
        "Distance thresholds, hash-family configuration, and corpus composition strongly affect matches; promotion needs fixtures for positive, near-miss, and common-benign cases.",
        "An LSH match is a similarity lead, not proof of common authorship, common control, or actor attribution."
      ],
      "capability_requirements": {
        "required": [
          "file_lshash_extraction",
          "file_hash_normalization"
        ],
        "optional": [
          "packer_detection",
          "benign_corpus_prevalence"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "file:lshash": 100000,
          "file:hash": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:lshash",
            "list": "common_library_or_packer_lshashes"
          },
          {
            "form": "file:hash",
            "list": "common_benign_software_hashes"
          },
          {
            "form": "file:lshash",
            "list": "low_entropy_or_short_lshash_values"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_FILE_NAME_TO_HASHES",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_FILE_NAME_TO_HASHES.yaml",
      "summary": "Pivot from a normalized file name to file hashes observed with that name in endpoint, malware-analysis, or file-reputation telemetry.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "enumeration",
      "name": "File Name -> Hashes",
      "description": "Pivot from a normalized file name to file hashes observed with that name in endpoint, malware-analysis, or file-reputation telemetry.",
      "source": "file:name",
      "target": "file:hash",
      "datasets": [
        "endpoint_telemetry",
        "malware_analysis",
        "file_reputation"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "File names are highly reusable, localized, user-controlled, and often generic.",
        "Common tool names, archive contents, installers, and renamed malware can create large false-positive clusters.",
        "File-name pivots should remain exploratory unless paired with path, hash, signature, or behavioral evidence."
      ],
      "capability_requirements": {
        "required": [
          "file_name_normalization",
          "file_hash_observation"
        ],
        "optional": [
          "common_filename_suppression",
          "endpoint_context",
          "sample_prevalence_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "file:name": 100000,
          "file:hash": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:name",
            "list": "common_system_or_tool_filenames"
          },
          {
            "form": "file:hash",
            "list": "common_benign_file_hashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_HTTP_HEADER_FINGERPRINT_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_HTTP_HEADER_FINGERPRINT_CLUSTER.yaml",
      "summary": "Cluster webpages or services that expose the same normalized HTTP response-header fingerprint.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "HTTP Header Fingerprint Cluster",
      "description": "Cluster webpages or services that expose the same normalized HTTP response-header fingerprint.",
      "source": "http:headers:fingerprint",
      "target": "inet:fqdn|inet:url",
      "datasets": [
        "osint_web",
        "http_scanning",
        "tls"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Shared hosting, CDNs, reverse proxies, WAFs, load balancers, and managed application platforms can stamp common header sets across unrelated tenants.",
        "Header order, casing, compression, cache state, redirect depth, and scanner request headers can change the observed fingerprint.",
        "Generic framework, security, and server headers can cluster default deployments rather than operator-controlled infrastructure.",
        "HTTP header fingerprints are weak structural selectors and should be corroborated with content, certificate, DNS, or timing evidence before analyst action."
      ],
      "capability_requirements": {
        "required": [
          "http_response_collection",
          "header_normalization",
          "web_fingerprinting"
        ],
        "optional": [
          "tls_scanning",
          "redirect_following",
          "historical_http_collection"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "http:headers:fingerprint": 100000,
          "inet:fqdn": 1000000
        },
        "negative_nodes": [
          {
            "form": "http:headers:fingerprint",
            "list": "common_cdn_waf_or_framework_header_profiles"
          },
          {
            "form": "http:headers:fingerprint",
            "list": "default_security_header_sets"
          },
          {
            "form": "inet:fqdn",
            "list": "common_hosting_or_cdn_domains"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 3,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_IMAGE_TEXT_REUSE_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_IMAGE_TEXT_REUSE_CLUSTER.yaml",
      "summary": "Cluster image assets or webpages that share distinctive normalized OCR text extracted from rendered images.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Image Text Reuse Cluster",
      "description": "Cluster image assets or webpages that share distinctive normalized OCR text extracted from rendered images.",
      "source": "image:ocr:text_hash",
      "target": "file:image|inet:url",
      "datasets": [
        "image_corpus",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Stock imagery, memes, common logos, boilerplate text, reused screenshots, and public templates can overcluster unrelated actors or campaigns.",
        "OCR output is sensitive to language, font, compression, cropping, watermarking, and model or extractor version.",
        "Bounded semantic descriptions are model- and prompt-dependent; any future use must record extractor and prompt version before promotion.",
        "Image-derived text reuse is a weak lead and must not be treated as common control or attribution without independent corroboration."
      ],
      "capability_requirements": {
        "required": [
          "image_extraction",
          "ocr_extraction",
          "text_normalization"
        ],
        "optional": [
          "perceptual_hashing",
          "bounded_image_description",
          "language_detection",
          "stock_image_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "image:ocr:text_hash": 100000,
          "file:image": 1000000
        },
        "negative_nodes": [
          {
            "form": "image:ocr:text_hash",
            "list": "common_logo_boilerplate_or_template_text_hashes"
          },
          {
            "form": "file:image",
            "list": "stock_image_or_meme_assets"
          },
          {
            "form": "inet:url",
            "list": "common_hosting_or_cdn_domains"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 3,
          "optional": 4
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_PE_SECTION_HASH_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_PE_SECTION_HASH_CLUSTER.yaml",
      "summary": "Cluster PE files by normalized section hashes while retaining section name, entropy, and file-hash context.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "PE Section Hash Cluster",
      "description": "Cluster PE files by normalized section hashes while retaining section name, entropy, and file-hash context.",
      "source": "file:pe:section:hash",
      "target": "file:hash",
      "datasets": [
        "malware_corpus",
        "sandbox",
        "edr"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "PE section hashes can reflect common runtimes, packers, resource templates, linked libraries, or compiler output rather than shared malicious logic.",
        "Section extraction is sensitive to malformed headers, overlay data, packing, and normalization choices.",
        "Promotion needs fixtures for exact section reuse, packed/benign suppressions, and near-collision cases before treating the pivot as operationally useful."
      ],
      "capability_requirements": {
        "required": [
          "pe_section_hash_extraction",
          "file_hash_normalization"
        ],
        "optional": [
          "packer_detection",
          "section_entropy_analysis"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "file:pe:section:hash": 100000,
          "file:hash": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:pe:section:hash",
            "list": "common_runtime_or_library_section_hashes"
          },
          {
            "form": "file:pe:section:hash",
            "list": "packer_stub_section_hashes"
          },
          {
            "form": "file:hash",
            "list": "common_benign_software_hashes"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_PHISHKIT_TO_HOSTING_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_PHISHKIT_TO_HOSTING_CLUSTER.yaml",
      "summary": "Cluster infrastructure hosting the same phishing kit hash or path structure.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Phish Kit → Hosting Domain/IP Cluster",
      "description": "Cluster infrastructure hosting the same phishing kit hash or path structure.",
      "source": "phish:kit",
      "target": "inet:fqdn|inet:ipv4",
      "datasets": [
        "phishtank",
        "abuse_ch",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Popular phishkits, copied path structures, and hosting panels can be shared across unrelated actors.",
        "Corroborate kit or path matches with deployment timing, config values, and infrastructure ownership; hosting reuse is not attribution."
      ],
      "capability_requirements": {
        "required": [
          "web_content_collection",
          "phishing_kit_hashing"
        ],
        "optional": [
          "passive_dns",
          "hosting_provider_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 180,
        "degree_caps": {
          "phish:kit": 10000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "shared_hosting_ranges"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_QR_PAYLOAD_REUSE_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_QR_PAYLOAD_REUSE_CLUSTER.yaml",
      "summary": "Cluster campaign assets or webpages that reuse the same normalized decoded QR payload.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "QR Payload Reuse Cluster",
      "description": "Cluster campaign assets or webpages that reuse the same normalized decoded QR payload.",
      "source": "visual:qr_payload",
      "target": "inet:url|payment:address|identity:account|file:image",
      "datasets": [
        "osint_web",
        "image_corpus",
        "document_assets"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Public QR generators, demo payloads, venue signage, shared payment flows, and URL shorteners can create unrelated decoded-payload reuse.",
        "Image quality, cropping, rotation, compression, and QR error correction can change decode success or produce partial payloads.",
        "Decoded payloads may contain personal, payment, access-token, or invite-link material and require minimization before publication or sharing.",
        "QR payload reuse is a lead for follow-on analysis only; it does not imply common control, campaign membership, or malicious intent without corroboration."
      ],
      "capability_requirements": {
        "required": [
          "image_extraction",
          "qr_decode",
          "payload_normalization"
        ],
        "optional": [
          "barcode_decode",
          "ocr_extraction",
          "url_unshortening",
          "payment_address_parsing"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "visual:qr_payload": 10000,
          "inet:url": 1000000
        },
        "negative_nodes": [
          {
            "form": "visual:qr_payload",
            "list": "demo_or_test_qr_payloads"
          },
          {
            "form": "inet:url",
            "list": "mainstream_url_shorteners_or_shared_payment_landing_pages"
          },
          {
            "form": "payment:address",
            "list": "high_volume_shared_payment_or_bridge_addresses"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 3,
          "optional": 4
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_COMPILATION_TIMESTAMP_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_SAMPLE_COMPILATION_TIMESTAMP_CLUSTER.yaml",
      "summary": "Cluster samples with matching or tightly bounded compilation timestamps after normalization and common-build suppression.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Sample Compilation Timestamp Cluster",
      "description": "Cluster samples with matching or tightly bounded compilation timestamps after normalization and common-build suppression.",
      "source": "file:metadata:compile_time",
      "target": "file:hash",
      "datasets": [
        "malware_analysis",
        "file_reputation"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Compilation timestamps can be forged, zeroed, rounded, inherited from templates, or rewritten by packers.",
        "Common build pipelines can create many samples in tight time windows without shared malicious provenance.",
        "Timestamp clustering should remain exploratory unless combined with stronger static or infrastructure selectors."
      ],
      "capability_requirements": {
        "required": [
          "sample_static_analysis",
          "compilation_timestamp_extraction"
        ],
        "optional": [
          "timestamp_anomaly_detection",
          "packer_detection",
          "sample_prevalence_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "file:metadata:compile_time": 100000,
          "file:hash": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:metadata:compile_time",
            "list": "forged_or_default_compile_timestamps"
          },
          {
            "form": "file:hash",
            "list": "common_benign_file_hashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_FUNCTION_NAME_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_SAMPLE_FUNCTION_NAME_CLUSTER.yaml",
      "summary": "Cluster samples that share rare normalized function names, exported symbols, or recovered debug-symbol names.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Sample Function Name Cluster",
      "description": "Cluster samples that share rare normalized function names, exported symbols, or recovered debug-symbol names.",
      "source": "file:feature:function_name",
      "target": "file:hash",
      "datasets": [
        "malware_analysis",
        "file_reputation"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Function names can come from public source, libraries, debug symbols, decompiler guesses, or common frameworks.",
        "Stripped binaries and compiler optimization can remove or distort function-name evidence.",
        "Function-name clusters need library suppression and corroborating static or behavioral evidence."
      ],
      "capability_requirements": {
        "required": [
          "sample_static_analysis",
          "function_name_extraction"
        ],
        "optional": [
          "library_function_suppression",
          "symbol_source_context",
          "sample_prevalence_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "file:feature:function_name": 100000,
          "file:hash": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:feature:function_name",
            "list": "common_library_or_framework_function_names"
          },
          {
            "form": "file:hash",
            "list": "common_benign_file_hashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_RESOURCE_SECTION_HASH_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_SAMPLE_RESOURCE_SECTION_HASH_CLUSTER.yaml",
      "summary": "Cluster samples that share an exact or normalized hash of an embedded resource section.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Sample Resource Section Hash Cluster",
      "description": "Cluster samples that share an exact or normalized hash of an embedded resource section.",
      "source": "file:resource_section:hash",
      "target": "file:hash",
      "datasets": [
        "malware_analysis",
        "file_reputation"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Resource section hashes can group common packers, compilers, icons, manifests, or benign library resources.",
        "Minor rebuilds and localization changes can alter resource hashes while preserving functional similarity.",
        "The pivot should be paired with prevalence and negative controls for common toolchains before promotion."
      ],
      "capability_requirements": {
        "required": [
          "sample_static_analysis",
          "resource_section_hashing"
        ],
        "optional": [
          "packer_detection",
          "sample_prevalence_enrichment",
          "common_resource_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "file:resource_section:hash": 100000,
          "file:hash": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:resource_section:hash",
            "list": "common_packer_or_icon_resource_hashes"
          },
          {
            "form": "file:hash",
            "list": "common_benign_file_hashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SAMPLE_UNIQUE_STRING_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_SAMPLE_UNIQUE_STRING_CLUSTER.yaml",
      "summary": "Cluster samples that share a rare normalized string extracted from static or decoded content.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Sample Unique String Cluster",
      "description": "Cluster samples that share a rare normalized string extracted from static or decoded content.",
      "source": "file:feature:string",
      "target": "file:hash",
      "datasets": [
        "malware_analysis",
        "file_reputation"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Strings can be copied from public source, libraries, compiler output, debug text, or benign dependencies.",
        "Short, localized, encoded, or common strings create noisy clusters.",
        "String pivots require rarity, context, and negative controls before they should influence analyst conclusions."
      ],
      "capability_requirements": {
        "required": [
          "sample_string_extraction",
          "string_normalization"
        ],
        "optional": [
          "common_string_suppression",
          "library_string_filtering",
          "sample_prevalence_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "file:feature:string": 100000,
          "file:hash": 1000000
        },
        "negative_nodes": [
          {
            "form": "file:feature:string",
            "list": "common_library_or_compiler_strings"
          },
          {
            "form": "file:hash",
            "list": "common_benign_file_hashes"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SBL_HOSTING_RISK",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_SBL_HOSTING_RISK.yaml",
      "summary": "Score IPs by ASN and presence in Spamhaus/abuse.ch datasets to prioritize likely bad infra.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "IP → ASN with SBL/Abuse Reputation",
      "description": "Score IPs by ASN and presence in Spamhaus/abuse.ch datasets to prioritize likely bad infra.",
      "source": "inet:ipv4",
      "target": "net:asn",
      "datasets": [
        "bgp",
        "spamhaus",
        "abuse_ch"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Abuse blocklists, SBL entries, and hosting ASN reputation can lag cleanup or reflect one customer inside shared infrastructure.",
        "Corroborate listing history with current observations; risk scoring should not label all tenants of a provider as malicious."
      ],
      "capability_requirements": {
        "required": [
          "abuse_feed_ingestion",
          "asn_enrichment"
        ],
        "optional": [
          "passive_dns",
          "hosting_provider_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 1095,
        "degree_caps": {
          "net:asn": 1
        },
        "negative_nodes": [
          {
            "form": "net:asn",
            "list": "hyperscaler_or_shared_hosting_asns"
          },
          {
            "form": "reputation:list",
            "list": "remediated_blocklist_entries"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_SHORT_LIVED_CERT_INFRA_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_SHORT_LIVED_CERT_INFRA_CLUSTER.yaml",
      "summary": "Expand infrastructure presenting certificates that match a short-lived validity profile.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Short-Lived TLS Certificate Profile -> Infra Cluster",
      "description": "Expand infrastructure presenting certificates that match a short-lived validity profile.",
      "source": "x509:cert:lifetime_profile",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "tls",
        "ct"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Short-lived certificates are increasingly normal in automated PKI ecosystems, so lifespan alone is too weak to imply malicious infrastructure.",
        "Test, staging, and ephemeral cloud deployments can overproduce the same signal while having no adversary relevance.",
        "Common ACME defaults and shared cloud automation can create false clusters; corroborate with SAN, hosting, and CTI context."
      ],
      "capability_requirements": {
        "required": [
          "tls_scanning",
          "certificate_normalization"
        ],
        "optional": [
          "ct_history"
        ]
      },
      "controls": {
        "temporal_window_days": 120,
        "degree_caps": {
          "x509:cert": 5000
        },
        "negative_nodes": [
          {
            "form": "x509:cert",
            "list": "common_acme_short_lived_certificates"
          },
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_THREAT_CVE_TOOL_IP",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_THREAT_CVE_TOOL_IP.yaml",
      "summary": "Pivot from a report-derived named-threat, CVE, and tool-family co-mention to contextual IP infrastructure observations.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Threat → CVE → Tool → IP",
      "description": "Pivot from a report-derived named-threat, CVE, and tool-family co-mention to contextual IP infrastructure observations.",
      "source": "risk:threat",
      "target": "inet:ipv4",
      "datasets": [
        "cti_reports",
        "nvd_cve",
        "pdns",
        "siem"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Named threat, CVE, and tool reports can be broad, stale, or based on public exploit adoption by unrelated actors.",
        "Corroborate IP links with observation time, tool telemetry, and independent reporting; the chain does not prove threat attribution."
      ],
      "capability_requirements": {
        "required": [
          "cti_report_extraction",
          "vulnerability_intelligence",
          "passive_dns"
        ],
        "optional": [
          "tool_family_normalization",
          "ip_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 540,
        "degree_caps": {
          "it:prod:soft": 300
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "known_vpn_exits"
          },
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_THREAT_TOOLS_SHARED_INFRA",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_THREAT_TOOLS_SHARED_INFRA.yaml",
      "summary": "Suggest related threats when their tool families lead to overlapping infrastructure.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Threat ↔ Threat via Shared Tool/Infra",
      "description": "Suggest related threats when their tool families lead to overlapping infrastructure.",
      "source": "risk:threat",
      "target": "risk:threat",
      "datasets": [
        "pdns",
        "siem",
        "cti_reports"
      ],
      "hop_count": 4,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Commodity tools and public malware builders can create common infrastructure features across unrelated threats.",
        "Corroborate shared infrastructure with campaign timing and multiple evidence paths; do not infer actor relationship from tool overlap alone."
      ],
      "capability_requirements": {
        "required": [
          "cti_report_extraction",
          "tool_family_normalization"
        ],
        "optional": [
          "passive_dns",
          "cluster_feature_export"
        ]
      },
      "controls": {
        "temporal_window_days": 540,
        "degree_caps": {
          "it:prod:soft": 300
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_THREAT_TOOL_FQDN_IP",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_THREAT_TOOL_FQDN_IP.yaml",
      "summary": "Tool-family infrastructure discovery via observed domains and their current/previous IPs.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Threat → Tool → FQDN → IP",
      "description": "Tool-family infrastructure discovery via observed domains and their current/previous IPs.",
      "source": "risk:threat",
      "target": "inet:ipv4",
      "datasets": [
        "pdns",
        "siem",
        "misp",
        "abuse_ch",
        "cti_reports"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "DNS history can include sinkholes, shared hosting, CDNs, parking, and reassigned IPs unrelated to the tool operator.",
        "Corroborate domain-to-IP timing with tool-family evidence; current resolutions alone are not attribution."
      ],
      "capability_requirements": {
        "required": [
          "cti_report_extraction",
          "passive_dns"
        ],
        "optional": [
          "tool_family_normalization",
          "ip_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 720,
        "degree_caps": {
          "it:prod:soft": 300,
          "inet:fqdn": 500
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "dynamic_dns_providers"
          },
          {
            "form": "inet:fqdn",
            "list": "public_resolvers"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_TLS_CERT_SUBJECT_PROFILE_TO_INFRA",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_TLS_CERT_SUBJECT_PROFILE_TO_INFRA.yaml",
      "summary": "Pivot from a normalized TLS certificate subject profile to infrastructure observed presenting certificates with that profile.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "TLS Certificate Subject Profile -> Infrastructure",
      "description": "Pivot from a normalized TLS certificate subject profile to infrastructure observed presenting certificates with that profile.",
      "source": "x509:subject",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "certificate_transparency",
        "internet_scan_archives",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "TLS subject profiles are weaker than certificate fingerprints because subject fields can be copied, templated, self-signed, or auto-generated.",
        "Shared hosting, reverse proxies, captive portals, and security products can expose certificates unrelated to the investigated service.",
        "Subject-profile matches require negative controls for commodity certificate templates and default organizational strings."
      ],
      "capability_requirements": {
        "required": [
          "tls_certificate_collection",
          "certificate_subject_normalization"
        ],
        "optional": [
          "certificate_fingerprint_extraction",
          "spki_hashing",
          "common_subject_template_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "x509:subject": 50000,
          "inet:ipv4": 100000
        },
        "negative_nodes": [
          {
            "form": "x509:subject",
            "list": "common_self_signed_or_default_subjects"
          },
          {
            "form": "inet:fqdn",
            "list": "shared_tls_termination_hosts"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_TOOL_RELAY_INFRA_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_TOOL_RELAY_INFRA_CLUSTER.yaml",
      "summary": "Find relay infrastructure linked to a tool family via shared hosting, ASN, and pdns co-location.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Tool Family → Relay/Proxy Infra Cluster",
      "description": "Find relay infrastructure linked to a tool family via shared hosting, ASN, and pdns co-location.",
      "source": "it:prod:soft",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "pdns",
        "bgp",
        "siem"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Relay infrastructure may use shared VPNs, proxies, cloud providers, or commodity tooling reused by unrelated operators.",
        "Corroborate ASN and PDNS co-location with temporal overlap and tool-specific evidence; common hosting is a false-positive source."
      ],
      "capability_requirements": {
        "required": [
          "tool_family_normalization",
          "passive_dns"
        ],
        "optional": [
          "asn_enrichment",
          "hosting_provider_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 540,
        "degree_caps": {
          "net:asn": 1000
        },
        "negative_nodes": [
          {
            "form": "net:asn",
            "list": "known_scanner_asns"
          },
          {
            "form": "inet:ipv4",
            "list": "shared_hosting_ranges"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_URLHAUS_REPO_COOCCURRENCE_INFRA",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_URLHAUS_REPO_COOCCURRENCE_INFRA.yaml",
      "summary": "Pivot from abuse-listed infrastructure through code-repository co-occurrence to additional domains or IPs, preserving repository and extraction provenance.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "URLhaus Repo Co-Occurrence -> Infra",
      "description": "Pivot from abuse-listed infrastructure through code-repository co-occurrence to additional domains or IPs, preserving repository and extraction provenance.",
      "source": "inet:ipv4|inet:fqdn|inet:url",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "abuse_ch",
        "code_search",
        "git_metadata",
        "url_corpus"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "suspected",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Code repositories frequently contain copied indicators, sample configs, blocklists, tests, or security research artifacts unrelated to operator infrastructure.",
        "Repository co-occurrence can inflate weak associations unless commit provenance, file context, and benign-project filters are preserved.",
        "Common sample repositories and shared indicator lists need corroboration with commit context before linking infrastructure."
      ],
      "capability_requirements": {
        "required": [
          "abuse_ch_urlhaus",
          "code_search",
          "git_metadata"
        ],
        "optional": [
          "secret_scanning_context",
          "repository_reputation"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "abuse:urlhaus:record": 1000,
          "code:repo": 5000
        },
        "negative_nodes": [
          {
            "form": "code:repo",
            "list": "mass_fork_mirrors"
          },
          {
            "form": "code:repo",
            "list": "benign_security_research_repos"
          },
          {
            "form": "inet:fqdn",
            "list": "package_registry_domains"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_WEBPAGE_SCRIPT_BEHAVIOR_CLUSTER",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_WEBPAGE_SCRIPT_BEHAVIOR_CLUSTER.yaml",
      "summary": "Cluster webpages that exhibit the same normalized script behavior fingerprint during rendering or interaction.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Webpage Script Behavior Cluster",
      "description": "Cluster webpages that exhibit the same normalized script behavior fingerprint during rendering or interaction.",
      "source": "web:behavior:fingerprint",
      "target": "inet:url|inet:fqdn",
      "datasets": [
        "osint_web",
        "url_corpus",
        "web_dynamic_analysis"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Script behavior can be framework-driven, environment-dependent, obfuscated, or shared by benign templates.",
        "Dynamic analysis can observe scanner artifacts, consent banners, anti-bot logic, or security products rather than malicious page logic.",
        "Behavior clusters require negative controls and should not imply page ownership or actor attribution."
      ],
      "capability_requirements": {
        "required": [
          "webpage_dynamic_analysis",
          "script_behavior_fingerprinting"
        ],
        "optional": [
          "javascript_hashing",
          "dom_snapshot_collection",
          "benign_template_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "web:behavior:fingerprint": 100000,
          "inet:url": 1000000
        },
        "negative_nodes": [
          {
            "form": "web:behavior:fingerprint",
            "list": "common_framework_or_consent_behaviors"
          },
          {
            "form": "inet:fqdn",
            "list": "common_hosting_or_cdn_domains"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_WEB_CLIENT_UID_TO_ENDPOINTS",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_WEB_CLIENT_UID_TO_ENDPOINTS.yaml",
      "summary": "Pivot from a normalized browser or web client identifier to endpoint identities only when telemetry provides an explicit client-to-endpoint binding.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Web Client UID -> Endpoints",
      "description": "Pivot from a normalized browser or web client identifier to endpoint identities only when telemetry provides an explicit client-to-endpoint binding.",
      "source": "web:client:uid",
      "target": "endpoint:uid",
      "datasets": [
        "proxy_logs",
        "browser_telemetry",
        "edr",
        "endpoint"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "suspected",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Browser/client identifiers do not inherently identify an endpoint; they can map to browser profiles, accounts, cookie jars, devices, or vendor-local telemetry identities.",
        "Endpoint joins can be inflated by shared devices, roaming profiles, virtual desktops, proxy attribution, log forwarding, or stale inventory bindings.",
        "A browser/client UID to endpoint match is not actor attribution and needs independent endpoint telemetry before operational use."
      ],
      "capability_requirements": {
        "required": [
          "browser_client_uid_normalization",
          "endpoint_binding_telemetry"
        ],
        "optional": [
          "edr_device_identity_resolution",
          "proxy_endpoint_join",
          "identity_inventory_join"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "web:client:uid": 100000,
          "endpoint:uid": 10000
        },
        "negative_nodes": [
          {
            "form": "endpoint:uid",
            "list": "shared_or_kiosk_endpoints"
          },
          {
            "form": "endpoint:uid",
            "list": "virtual_desktop_or_terminal_hosts"
          },
          {
            "form": "http:request",
            "list": "proxy_attributed_requests"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 3
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "CTI_WEB_SEARCH_QUERY_TO_CLIENT_UIDS",
      "lane": "deferred",
      "category": "CTI",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/CTI_WEB_SEARCH_QUERY_TO_CLIENT_UIDS.yaml",
      "summary": "Pivot from a minimized web search query observation to browser or web client identifiers seen with that query.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "robustness_class": "multi_hop_inference",
      "name": "Web Search Query -> Client UIDs",
      "description": "Pivot from a minimized web search query observation to browser or web client identifiers seen with that query.",
      "source": "web:search:query",
      "target": "web:client:uid",
      "datasets": [
        "restricted_search_telemetry",
        "browser_telemetry"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "theoretical",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "observation"
      },
      "hazards": [
        "Web search query pivots are privacy-sensitive and should remain deferred unless queries are minimized to a narrow atomic relationship with strict publication controls.",
        "Queries can be generic, copied, suggested, auto-completed, translated, or generated by scanners and browser features.",
        "A shared query and client UID relationship is behavioral context, not actor attribution or proof of user intent."
      ],
      "capability_requirements": {
        "required": [
          "web_search_query_telemetry",
          "browser_client_uid_normalization"
        ],
        "optional": [
          "query_minimization",
          "scanner_prefetch_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 7,
        "degree_caps": {
          "web:search:query": 10000,
          "web:client:uid": 100000
        },
        "negative_nodes": [
          {
            "form": "web:search:query",
            "list": "common_or_autocomplete_queries"
          },
          {
            "form": "web:search:query",
            "list": "privacy_sensitive_queries_excluded_from_publication"
          },
          {
            "form": "web:client:uid",
            "list": "scanner_or_automation_client_ids"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_BANK_TXN_TO_SANCTIONED_COUNTERPART",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_BANK_TXN_TO_SANCTIONED_COUNTERPART.yaml",
      "summary": "Flag accounts transacting with sanctioned entities or intermediaries.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Bank Account → Transactions → Sanctioned Counterparty",
      "description": "Flag accounts transacting with sanctioned entities or intermediaries.",
      "source": "fin:account",
      "target": "sanction:entry",
      "datasets": [
        "bank_txn",
        "sanctions"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Sanctions screening and transaction data are sensitive, regulated, and time-dependent; list membership can change after the transaction date.",
        "Shared accounts, correspondents, and intermediaries can create false positives; corroborate with KYC and payment-chain context."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "sanctions_list_access"
        ],
        "optional": [
          "kyc_context",
          "payment_chain_context"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "fin:transaction": 100000
        },
        "negative_nodes": [
          {
            "form": "fin:account",
            "list": "correspondent_or_intermediary_bank_accounts"
          },
          {
            "form": "fin:transaction",
            "list": "batch_or_test_payment_records"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_BENEFICIAL_OWNER_TO_SANCTIONS",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_BENEFICIAL_OWNER_TO_SANCTIONS.yaml",
      "summary": "Screen entities controlled by a person against sanctions via reported beneficial ownership.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Beneficial Owner → Controlled Entities → Sanctions",
      "description": "Screen entities controlled by a person against sanctions via reported beneficial ownership.",
      "source": "person",
      "target": "sanction:entry",
      "datasets": [
        "lei",
        "opencorp",
        "sanctions"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Beneficial-ownership records can be stale, nominee-based, shared by service providers, jurisdiction-limited, or inconsistent across registries.",
        "Sanctions exposure is temporal and legal-sensitive; corroborate ownership percentage, control date, and KYC records before scoring entities."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "identity_records",
          "sanctions_list_access"
        ],
        "optional": [
          "beneficial_ownership_resolution",
          "entity_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "person": 200
        },
        "negative_nodes": [
          {
            "form": "person",
            "list": "nominee_directors_or_service_providers"
          },
          {
            "form": "person",
            "list": "stale_or_below_threshold_ownership_records"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_CRYPTO_OFFRAMP_COUNTERPARTY_CLUSTER",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_CRYPTO_OFFRAMP_COUNTERPARTY_CLUSTER.yaml",
      "summary": "Trace recurring crypto addresses through withdrawal or cash-out paths to shared off-ramp accounts, merchants, or beneficiary entities.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Crypto Address -> Off-Ramp Counterparty Cluster",
      "description": "Trace recurring crypto addresses through withdrawal or cash-out paths to shared off-ramp accounts, merchants, or beneficiary entities.",
      "source": "crypto:address",
      "target": "fin:account|fin:merchant|org:org",
      "datasets": [
        "blockchain",
        "bank_txn",
        "payments"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Exchange deposit addresses, processors, mixers, and omnibus accounts can group unrelated crypto users.",
        "Off-ramp data is restricted financial and KYC evidence; corroborate shared account links with timing and transaction context to avoid false positives."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "crypto_transaction_enrichment"
        ],
        "optional": [
          "kyc_context",
          "offramp_account_resolution"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "ledger:tx": 100000
        },
        "negative_nodes": [
          {
            "form": "crypto:address",
            "list": "exchange_hot_wallets"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_CRYPTO_TX_TO_SANCTIONED",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_CRYPTO_TX_TO_SANCTIONED.yaml",
      "summary": "Trace on‑chain flows to sanctioned addresses/entities.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Crypto Address → On‑Chain Tx → Sanctioned Address/Entity",
      "description": "Trace on‑chain flows to sanctioned addresses/entities.",
      "source": "crypto:address",
      "target": "sanction:entry",
      "datasets": [
        "blockchain",
        "sanctions"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Blockchain heuristics can over-attribute flows through mixers, exchanges, bridges, or shared custody accounts.",
        "Sanctions lists and address clusters are temporal; corroborate transaction timing and ownership before drawing compliance conclusions."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "crypto_transaction_enrichment",
          "sanctions_list_access"
        ],
        "optional": [
          "address_cluster_context",
          "transaction_timing_context"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "ledger:tx": 100000
        },
        "negative_nodes": [
          {
            "form": "crypto:address",
            "list": "exchange_or_custody_addresses"
          },
          {
            "form": "crypto:address",
            "list": "high_volume_non_sanctioned_bridge_addresses"
          },
          {
            "form": "ledger:tx",
            "list": "dust_or_airdrop_transactions"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_KYC_DOCUMENT_REUSE_CLUSTER",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_KYC_DOCUMENT_REUSE_CLUSTER.yaml",
      "summary": "Cluster people or accounts reusing the same KYC document image, scan, or canonical document hash.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "KYC Document Hash -> Identity Cluster",
      "description": "Cluster people or accounts reusing the same KYC document image, scan, or canonical document hash.",
      "source": "file:bytes",
      "target": "person|fin:account",
      "datasets": [
        "kyc",
        "fraud_ops"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Shared scanners, stock document samples, templates, or document-theft victims can create false identity clusters.",
        "KYC documents are sensitive personal data; use only with lawful access and corroborate with account behavior and verified fraud context."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "identity_records",
          "document_hash_normalization"
        ],
        "optional": [
          "kyc_context",
          "document_template_suppression"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "file:bytes": 500
        },
        "negative_nodes": [
          {
            "form": "file:bytes",
            "list": "known_template_documents"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_MULE_RECRUITMENT_SOCIAL_TO_PAYOUT",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_MULE_RECRUITMENT_SOCIAL_TO_PAYOUT.yaml",
      "summary": "Tie mule-recruitment personas or social handles to payout accounts advertised, routed, or onboarded through recruitment channels.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Recruitment Persona -> Payout Account",
      "description": "Tie mule-recruitment personas or social handles to payout accounts advertised, routed, or onboarded through recruitment channels.",
      "source": "social:handle",
      "target": "fin:account",
      "datasets": [
        "social",
        "osint_web",
        "bank_txn"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Recruitment posts, handles, and payment instructions can be copied, impersonated, or reused by intermediaries.",
        "Payout account data is restricted financial evidence; corroborate temporal account control and recruitment context before identifying mule networks."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "social_profile_collection"
        ],
        "optional": [
          "payout_account_normalization",
          "recruitment_context_extraction"
        ]
      },
      "controls": {
        "temporal_window_days": 730,
        "degree_caps": {
          "social:handle": 10000
        },
        "negative_nodes": [
          {
            "form": "social:handle",
            "list": "benign_job_recruiters"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_ORG_LEI_PARENT_SANCTIONS",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_ORG_LEI_PARENT_SANCTIONS.yaml",
      "summary": "Screen organizations via LEI ‘who owns whom’ up the chain and check against sanctions.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Org → LEI → Parent → Sanctions",
      "description": "Screen organizations via LEI ‘who owns whom’ up the chain and check against sanctions.",
      "source": "org:org",
      "target": "sanction:entry",
      "datasets": [
        "lei",
        "sanctions"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "LEI parent relationships, shared holding structures, and sanctions lists can lag restructures, ownership changes, or jurisdiction-specific legal interpretations.",
        "Corroborate temporal ownership, control, and sanctions effective dates; do not treat a parent link as automatic prohibited activity."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "lei_resolution",
          "sanctions_list_access"
        ],
        "optional": [
          "beneficial_ownership_resolution",
          "entity_normalization"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "lei:record": 10
        },
        "negative_nodes": [
          {
            "form": "lei:record",
            "list": "stale_parent_relationships"
          },
          {
            "form": "lei:record",
            "list": "intermediate_holding_companies"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_ORG_OFFICER_SHARE_CLUSTER",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_ORG_OFFICER_SHARE_CLUSTER.yaml",
      "summary": "Cluster companies by shared officers/directors to identify shell networks.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Org Officer/Director → Cross‑Directorship Cluster",
      "description": "Cluster companies by shared officers/directors to identify shell networks.",
      "source": "person",
      "target": "org:org",
      "datasets": [
        "opencorp"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Common professional directors, formation agents, family names, and stale registry records can connect unrelated companies.",
        "Officer data can be jurisdiction-limited and privacy-sensitive; corroborate with KYC, address, and temporal appointment evidence."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "identity_records"
        ],
        "optional": [
          "officer_record_normalization",
          "company_registry_context"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "person": 200
        },
        "negative_nodes": [
          {
            "form": "person",
            "list": "nominee_directors_or_formation_agents"
          },
          {
            "form": "person",
            "list": "mass_professional_officers"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_REFUND_DESTINATION_ACCOUNT_CLUSTER",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_REFUND_DESTINATION_ACCOUNT_CLUSTER.yaml",
      "summary": "Cluster merchants or actors whose refunds repeatedly terminate in the same beneficiary account or refund receiver.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Refund Destination Account -> Merchant Cluster",
      "description": "Cluster merchants or actors whose refunds repeatedly terminate in the same beneficiary account or refund receiver.",
      "source": "fin:account",
      "target": "fin:merchant|person",
      "datasets": [
        "payments",
        "bank_txn",
        "ecommerce"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Refund receivers, processors, and settlement accounts can be shared legitimately by marketplaces or service providers.",
        "Bank account data is restricted; corroborate account control, refund timing, and merchant context before treating reuse as fraud."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "payout_account_normalization"
        ],
        "optional": [
          "merchant_profile_context",
          "refund_timing_context"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "fin:account": 500
        },
        "negative_nodes": [
          {
            "form": "fin:account",
            "list": "merchant_customer_support_accounts"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_REGISTERED_ADDRESS_CLUSTER",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_REGISTERED_ADDRESS_CLUSTER.yaml",
      "summary": "Identify mass‑registration addresses linked to many entities (possible formation agents).",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Registered Address → Company Cluster",
      "description": "Identify mass‑registration addresses linked to many entities (possible formation agents).",
      "source": "geo:address",
      "target": "org:org",
      "datasets": [
        "opencorp"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Registered agents, mail drops, coworking spaces, and residential blocks can create common address clusters at scale.",
        "Address data can be privacy-sensitive and stale; corroborate with officer, account, and temporal registry context before inferring control."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "address_normalization"
        ],
        "optional": [
          "identity_records",
          "company_registry_context"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "geo:address": 10000
        },
        "negative_nodes": [
          {
            "form": "geo:address",
            "list": "registered_agent_addresses"
          },
          {
            "form": "geo:address",
            "list": "virtual_office_or_maildrop_addresses"
          },
          {
            "form": "geo:address",
            "list": "large_residential_or_coworking_addresses"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_SUPPLIER_SPLIT_PAYMENTS",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_SUPPLIER_SPLIT_PAYMENTS.yaml",
      "summary": "Detect order splitting or structuring across suppliers linked by officers/addresses.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Supplier → Split Payments Pattern",
      "description": "Detect order splitting or structuring across suppliers linked by officers/addresses.",
      "source": "org:org",
      "target": "org:org",
      "datasets": [
        "bank_txn",
        "opencorp"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Shared officers or addresses can reflect procurement agents, affiliates, or registration services rather than coordinated structuring.",
        "Payment records are restricted financial data; corroborate order timing, account control, and sanctions or KYC context before flagging split payments."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "payment_chain_context"
        ],
        "optional": [
          "beneficial_ownership_resolution",
          "kyc_context"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "org:org": 10000
        },
        "negative_nodes": [
          {
            "form": "org:org",
            "list": "shared_procurement_agents"
          },
          {
            "form": "org:org",
            "list": "registration_service_shared_entities"
          }
        ],
        "negative_node_count": 2,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_SYNTHETIC_IDENTITY_ATTRIBUTE_CLUSTER",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_SYNTHETIC_IDENTITY_ATTRIBUTE_CLUSTER.yaml",
      "summary": "Link synthetic or mule identities reusing the same contact, address, or profile attributes across nominally distinct personas.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Synthetic Identity -> Shared Attribute Cluster",
      "description": "Link synthetic or mule identities reusing the same contact, address, or profile attributes across nominally distinct personas.",
      "source": "person",
      "target": "person",
      "datasets": [
        "kyc",
        "fraud_ops"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Shared phones, addresses, IPs, or devices can come from families, dorms, employers, proxies, or reused data brokers.",
        "Identity attributes are privacy-sensitive; corroborate with KYC, account behavior, and temporal patterns before clustering synthetic identities."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "identity_records"
        ],
        "optional": [
          "attribute_normalization",
          "kyc_context"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "person": 1000
        },
        "negative_nodes": [
          {
            "form": "email:addr",
            "list": "disposable_email_domains"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "FIN_TRADE_PARTNER_SANCTIONS",
      "lane": "deferred",
      "category": "FIN",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/FIN_TRADE_PARTNER_SANCTIONS.yaml",
      "summary": "Cross‑border trade partners screened against sanctions lists.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Importer/Exporter → Trade Partner → Sanctions",
      "description": "Cross‑border trade partners screened against sanctions lists.",
      "source": "org:org",
      "target": "sanction:entry",
      "datasets": [
        "sanctions",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Trade counterparties, shared intermediaries, ownership chains, and sanctions lists change over time and vary by jurisdiction.",
        "Corroborate shipment date, beneficial ownership, and account or payment context; avoid false positives from same-name or intermediary partners."
      ],
      "capability_requirements": {
        "required": [
          "financial_records",
          "sanctions_list_access"
        ],
        "optional": [
          "trade_record_normalization",
          "beneficial_ownership_resolution"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "org:org": 100000
        },
        "negative_nodes": [
          {
            "form": "org:org",
            "list": "freight_forwarders_or_customs_brokers"
          },
          {
            "form": "org:org",
            "list": "free_trade_zone_intermediaries"
          },
          {
            "form": "org:org",
            "list": "same_name_unresolved_entities"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "HUM_BLUETOOTH_PROXIMITY",
      "lane": "deferred",
      "category": "HUMINT_SIGINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/HUM_BLUETOOTH_PROXIMITY.yaml",
      "summary": "Proximity graph from Bluetooth beacon observations to infer meetings.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Device → Bluetooth Proximity → Device",
      "description": "Proximity graph from Bluetooth beacon observations to infer meetings.",
      "source": "device:device",
      "target": "device:device",
      "datasets": [
        "siem"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Dense public venues, transit, and office environments create near-certain false positives for co-presence.",
        "Bluetooth collection can carry significant privacy and consent implications depending on jurisdiction and collection method."
      ],
      "capability_requirements": {
        "required": [
          "bluetooth_observation_collection",
          "spatiotemporal_correlation"
        ],
        "optional": [
          "venue_context",
          "legal_review"
        ]
      },
      "controls": {
        "temporal_window_days": 7,
        "degree_caps": {
          "device:device": 100000
        },
        "negative_nodes": [
          {
            "form": "device:device",
            "list": "transit_hub_observations"
          },
          {
            "form": "device:device",
            "list": "conference_or_public_venue_devices"
          },
          {
            "form": "device:device",
            "list": "beacon_or_kiosk_devices"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "HUM_CDR_COLOCATION_LINK",
      "lane": "deferred",
      "category": "HUMINT_SIGINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/HUM_CDR_COLOCATION_LINK.yaml",
      "summary": "Infer links between MSISDNs via repeated co‑location in time and space (tower/sector).",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Phone → CDR → Co‑Location Link",
      "description": "Infer links between MSISDNs via repeated co‑location in time and space (tower/sector).",
      "source": "telecom:msisdn",
      "target": "telecom:msisdn",
      "datasets": [
        "cdr"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "CDR access is regulated in many jurisdictions and may require lawful-intercept or similarly restricted authority.",
        "Dense urban tower coverage, roaming, and shared sectors create systemic false positives without strong temporal controls."
      ],
      "capability_requirements": {
        "required": [
          "cdr_access",
          "spatiotemporal_correlation"
        ],
        "optional": [
          "tower_geography",
          "legal_review"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "telecom:cdr": 200000
        },
        "negative_nodes": [
          {
            "form": "telecom:cdr",
            "list": "dense_urban_sector_observations"
          },
          {
            "form": "telecom:cdr",
            "list": "roaming_gateway_records"
          },
          {
            "form": "telecom:cdr",
            "list": "mass_event_tower_observations"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "HUM_PERSON_EMAIL_ORG_LINK",
      "lane": "deferred",
      "category": "HUMINT_SIGINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/HUM_PERSON_EMAIL_ORG_LINK.yaml",
      "summary": "Associate a person to an organization via corporate email domains observed in communications.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Person Email → Organization Link",
      "description": "Associate a person to an organization via corporate email domains observed in communications.",
      "source": "person",
      "target": "org:org",
      "datasets": [
        "osint_web",
        "rdap"
      ],
      "hop_count": 3,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Corporate email usage can reflect contractors, temporary roles, or historical affiliations rather than current membership.",
        "Forwarders, aliases, and consumer mailboxes using branded domains can misstate organisational control.",
        "Lawful authority, jurisdiction, privacy constraints, and corroboration are required because shared aliases and stale emails create false positives."
      ],
      "capability_requirements": {
        "required": [
          "communication_metadata",
          "domain_ownership_resolution"
        ],
        "optional": [
          "employment_context"
        ]
      },
      "controls": {
        "temporal_window_days": 1095,
        "degree_caps": {
          "email:addr": 1000
        },
        "negative_nodes": [
          {
            "form": "email:addr",
            "list": "role_or_shared_mailboxes"
          },
          {
            "form": "email:addr",
            "list": "contractor_or_alumni_aliases"
          },
          {
            "form": "email:addr",
            "list": "consumer_forwarding_aliases"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 1
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "HUM_PERSON_FIN_ACCOUNTS_LINK",
      "lane": "deferred",
      "category": "HUMINT_SIGINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/HUM_PERSON_FIN_ACCOUNTS_LINK.yaml",
      "summary": "Link persons by shared devices/IPs used to access multiple accounts within short windows.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Person → Financial Accounts Link",
      "description": "Link persons by shared devices/IPs used to access multiple accounts within short windows.",
      "source": "person",
      "target": "person",
      "datasets": [
        "bank_txn",
        "siem"
      ],
      "hop_count": 4,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "CGNAT, shared Wi-Fi, and corporate NAT create systemic false matches when IP reuse is interpreted as person-level linkage.",
        "Financial-access telemetry is highly sensitive and may be legally restricted or require explicit governance approval."
      ],
      "capability_requirements": {
        "required": [
          "regulated_account_access_logs",
          "device_or_network_correlation"
        ],
        "optional": [
          "kyc_context",
          "legal_review"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "inet:ipv4": 10000
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "public_proxies_vpns"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "HUM_PNR_COTRAVEL_LINK",
      "lane": "deferred",
      "category": "HUMINT_SIGINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/HUM_PNR_COTRAVEL_LINK.yaml",
      "summary": "Identify co‑travelers via shared PNR/segments within a time window.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "PNR → Co‑Travel Link",
      "description": "Identify co‑travelers via shared PNR/segments within a time window.",
      "source": "travel:pnr",
      "target": "person",
      "datasets": [
        "pnr"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Shared itineraries do not by themselves establish association, intent, or operational collaboration.",
        "PNR data is regulated and often restricted to travel operators or law-enforcement-style access models.",
        "Use only under lawful authority and jurisdiction-specific privacy controls; corroborate co-travel to avoid false positives from group bookings."
      ],
      "capability_requirements": {
        "required": [
          "pnr_access",
          "itinerary_correlation"
        ],
        "optional": [
          "seat_or_booking_context",
          "legal_review"
        ]
      },
      "controls": {
        "temporal_window_days": 30,
        "degree_caps": {
          "travel:pnr": 100000
        },
        "negative_nodes": [
          {
            "form": "travel:pnr",
            "list": "group_booking_records"
          },
          {
            "form": "travel:pnr",
            "list": "package_tour_or_crew_itineraries"
          },
          {
            "form": "travel:pnr",
            "list": "mass_delay_or_rebooking_events"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "large_degree_cap"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "HUM_WIFI_BSSID_CONTACT_CHAIN",
      "lane": "deferred",
      "category": "HUMINT_SIGINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/HUM_WIFI_BSSID_CONTACT_CHAIN.yaml",
      "summary": "Detect co‑presence via devices seen on the same BSSID within time windows.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "restricted_data_access",
      "name": "Device → Wi‑Fi BSSID → Co‑Presence",
      "description": "Detect co‑presence via devices seen on the same BSSID within time windows.",
      "source": "device:device",
      "target": "device:device",
      "datasets": [
        "siem"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Public hotspots and enterprise guest networks create extremely high-degree noise for shared-BSSID inference.",
        "MAC randomization, reused access-point identifiers, and venue churn can distort apparent contact chains.",
        "Lawful access, jurisdiction, and privacy controls are required; corroborate shared BSSID contact chains to avoid false positives in dense venues."
      ],
      "capability_requirements": {
        "required": [
          "wifi_observation_data",
          "spatiotemporal_correlation"
        ],
        "optional": [
          "venue_context",
          "legal_review"
        ]
      },
      "controls": {
        "temporal_window_days": 14,
        "degree_caps": {
          "net:wifi:bssid": 10000
        },
        "negative_nodes": [
          {
            "form": "net:wifi:bssid",
            "list": "public_hotspot_bssids"
          },
          {
            "form": "net:wifi:bssid",
            "list": "enterprise_guest_network_bssids"
          },
          {
            "form": "net:wifi:bssid",
            "list": "reused_or_randomized_ap_identifiers"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "IO_CONTENT_HASH_TO_ACCOUNT_CLUSTER",
      "lane": "deferred",
      "category": "IO",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/IO_CONTENT_HASH_TO_ACCOUNT_CLUSTER.yaml",
      "summary": "Cluster coordinated accounts reusing identical media assets, documents, or attachments across posts and campaigns.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Content Hash -> Account Cluster",
      "description": "Cluster coordinated accounts reusing identical media assets, documents, or attachments across posts and campaigns.",
      "source": "hash:sha256",
      "target": "inet:web:acct",
      "datasets": [
        "social",
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Stock media, memes, templates, and reposted documents can be common across unrelated accounts.",
        "Corroborate exact content-hash reuse with timing, behavior, and campaign context; identical media alone is not common control."
      ],
      "capability_requirements": {
        "required": [
          "platform_abuse_records",
          "content_fingerprinting"
        ],
        "optional": [
          "social_profile_collection",
          "campaign_context_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "hash:sha256": 5000
        },
        "negative_nodes": [
          {
            "form": "hash:sha256",
            "list": "stock_media_hashes"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "IO_CROSS_PLATFORM_HANDLE_CLUSTER",
      "lane": "deferred",
      "category": "IO",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/IO_CROSS_PLATFORM_HANDLE_CLUSTER.yaml",
      "summary": "Link common handle strings or aliases reused across platforms by coordinated or inauthentic personas.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Cross-Platform Handle -> Account Cluster",
      "description": "Link common handle strings or aliases reused across platforms by coordinated or inauthentic personas.",
      "source": "social:handle",
      "target": "inet:web:acct",
      "datasets": [
        "social"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Common usernames, fan accounts, impersonators, and namespace collisions can create false cross-platform links.",
        "Corroborate handle reuse with profile metadata, timing, and behavioral evidence before clustering accounts."
      ],
      "capability_requirements": {
        "required": [
          "platform_abuse_records",
          "social_profile_collection"
        ],
        "optional": [
          "handle_normalization",
          "profile_metadata_extraction"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "social:handle": 10000
        },
        "negative_nodes": [
          {
            "form": "social:handle",
            "list": "generic_common_usernames"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "IO_FORGED_DOCUMENT_TEMPLATE_CLUSTER",
      "lane": "deferred",
      "category": "IO",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/IO_FORGED_DOCUMENT_TEMPLATE_CLUSTER.yaml",
      "summary": "Cluster operators or campaigns reusing the same forged-document templates, seals, or layout artifacts.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Forged Document Template -> Operator Cluster",
      "description": "Cluster operators or campaigns reusing the same forged-document templates, seals, or layout artifacts.",
      "source": "file:bytes",
      "target": "inet:web:acct|risk:campaign",
      "datasets": [
        "social",
        "media_monitoring",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Public templates, copied seals, and common editing tools can produce similar documents across unrelated accounts or campaigns.",
        "Defender, analyst, or researcher reproduction and replay of forged-document templates can create benign matches unless testing and training artifacts are suppressed.",
        "Corroborate template reuse with distribution timing, account behavior, and additional artifacts; template match alone is weak evidence."
      ],
      "capability_requirements": {
        "required": [
          "platform_abuse_records",
          "content_fingerprinting"
        ],
        "optional": [
          "document_template_suppression",
          "campaign_context_enrichment"
        ]
      },
      "controls": {
        "temporal_window_days": 1825,
        "degree_caps": {
          "file:bytes": 2000
        },
        "negative_nodes": [
          {
            "form": "file:bytes",
            "list": "public_press_release_templates"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 3,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "IO_SHARED_SHORTENER_OR_TRACKING_CLUSTER",
      "lane": "deferred",
      "category": "IO",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/IO_SHARED_SHORTENER_OR_TRACKING_CLUSTER.yaml",
      "summary": "Cluster IO properties reusing the same shortener, redirector, or campaign-tracking domain across accounts or sites.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Shortener or Tracking Domain -> IO Property Cluster",
      "description": "Cluster IO properties reusing the same shortener, redirector, or campaign-tracking domain across accounts or sites.",
      "source": "inet:fqdn",
      "target": "inet:web:acct|inet:fqdn",
      "datasets": [
        "social",
        "osint_web"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Public shorteners, campaign platforms, and tracking vendors are shared across many unrelated accounts and domains.",
        "Corroborate redirect and tracking reuse with landing content, timing, and operator-controlled artifacts; expect false positives."
      ],
      "capability_requirements": {
        "required": [
          "platform_abuse_records",
          "redirect_resolution"
        ],
        "optional": [
          "web_fingerprinting",
          "tracking_id_extraction"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "inet:fqdn": 2000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "mainstream_link_shorteners"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_REVERSE_DNS_HOST_CLUSTER",
      "lane": "deferred",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/OSINT_REVERSE_DNS_HOST_CLUSTER.yaml",
      "summary": "Cluster hosts reusing uncommon PTR or reverse-DNS hostnames while filtering commodity provider naming patterns.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Reverse DNS Hostname -> Host Cluster",
      "description": "Cluster hosts reusing uncommon PTR or reverse-DNS hostnames while filtering commodity provider naming patterns.",
      "source": "inet:fqdn",
      "target": "inet:ipv4|inet:fqdn",
      "datasets": [
        "dns",
        "pdns"
      ],
      "hop_count": 2,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Provider default PTR names, recycled hostnames, and cloud templates can create common reverse-DNS values across unrelated hosts.",
        "Corroborate PTR reuse with DNS timing, service banners, certificates, and hosting context; reverse DNS alone is weak."
      ],
      "capability_requirements": {
        "required": [
          "dns_public_lookup",
          "passive_dns"
        ],
        "optional": [
          "reverse_dns_lookup",
          "hosting_provider_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 365,
        "degree_caps": {
          "inet:fqdn": 10000
        },
        "negative_nodes": [
          {
            "form": "inet:fqdn",
            "list": "provider_reverse_dns_zones"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_SHARED_IP_TO_DOMAINS",
      "lane": "deferred",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/OSINT_SHARED_IP_TO_DOMAINS.yaml",
      "summary": "Enumerate domains co-hosted on the same IP address during an overlapping observation window.",
      "pattern_schema_version": 1.3,
      "precision_tier": "exploratory",
      "deferred_reason": "needs_fixtures",
      "robustness_class": "multi_hop_inference",
      "name": "Shared IP -> Co-Hosted Domains",
      "description": "Enumerate domains co-hosted on the same IP address during an overlapping observation window.",
      "source": "inet:ipv4",
      "target": "inet:fqdn",
      "datasets": [
        "pdns",
        "dns",
        "asn"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "suspected",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Shared hosting, CDN edges, parking providers, and recycled cloud IPs can connect thousands of unrelated domains.",
        "Co-hosting only has evidentiary value when the DNS observation windows overlap the investigated activity and the IP is not provider-dominated."
      ],
      "capability_requirements": {
        "required": [
          "passive_dns",
          "temporal_dns_history",
          "asn_enrichment"
        ],
        "optional": [
          "active_resolution",
          "hosting_provider_classification"
        ]
      },
      "controls": {
        "temporal_window_days": 90,
        "degree_caps": {
          "inet:ipv4": 500
        },
        "negative_nodes": [
          {
            "form": "inet:ipv4",
            "list": "cdn_edges"
          },
          {
            "form": "inet:ipv4",
            "list": "shared_hosting_edges"
          },
          {
            "form": "inet:ipv4",
            "list": "parking_infrastructure"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 2
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 3,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "OSINT_TRACKING_ID_TO_DOMAINS",
      "lane": "deferred",
      "category": "OSINT",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/OSINT_TRACKING_ID_TO_DOMAINS.yaml",
      "summary": "Cluster domains/pages sharing the same analytics or ad-tracking identifier.",
      "pattern_schema_version": 1.4,
      "precision_tier": "exploratory",
      "deferred_reason": "high_cardinality",
      "robustness_class": "enumeration",
      "name": "Tracking ID (GA/FB Pixel) → Domains",
      "description": "Cluster domains/pages sharing the same analytics or ad-tracking identifier.",
      "source": "web:tracking:id",
      "target": "inet:fqdn",
      "datasets": [
        "osint_web"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level",
        "subject_role": "behavioural_cluster",
        "object_role": "behavioural_cluster"
      },
      "hazards": [
        "Analytics tags, ad pixels, agency-managed accounts, and shared tracking vendors can appear on many unrelated domains.",
        "Corroborate tracking-ID reuse with page ownership, timing, and content or infrastructure evidence; high-degree IDs produce false positives.",
        "Demo IDs, staging containers, copied templates, and tag-manager defaults can make unrelated domains look connected.",
        "Treat tracking-ID reuse as weak correlation or fan-out context, not as ownership proof or attribution."
      ],
      "capability_requirements": {
        "required": [
          "web_fingerprinting",
          "tracking_id_extraction"
        ],
        "optional": [
          "web_crawling",
          "tag_manager_extraction",
          "tracking_id_normalization",
          "domain_ownership_resolution"
        ]
      },
      "controls": {
        "temporal_window_days": 1095,
        "degree_caps": {
          "web:tracking:id": 10000
        },
        "negative_nodes": [
          {
            "form": "web:tracking:id",
            "list": "common_analytics_or_ad_network_ids"
          },
          {
            "form": "web:tracking:id",
            "list": "agency_or_tag_manager_container_ids"
          },
          {
            "form": "web:tracking:id",
            "list": "shared_testing_or_demo_tracking_ids"
          }
        ],
        "negative_node_count": 3,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 4,
        "capability_counts": {
          "required": 2,
          "optional": 4
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": true,
          "state": "controls_published",
          "reasons": [
            "deferred_reason_high_cardinality"
          ],
          "warnings": [

          ]
        }
      }
    },
    {
      "id": "SUPPLY_SBOM_DEPENDENCY_TO_PRODUCTS",
      "lane": "deferred",
      "category": "SUPPLY",
      "version": "1.0.0",
      "path": "graph-pivots/deferred/SUPPLY_SBOM_DEPENDENCY_TO_PRODUCTS.yaml",
      "summary": "Enumerate downstream products inheriting exposure through an SBOM-declared dependency relationship.",
      "pattern_schema_version": 1.2,
      "precision_tier": "exploratory",
      "deferred_reason": "insufficient_hazards",
      "name": "Dependency -> Downstream Product Exposure",
      "description": "Enumerate downstream products inheriting exposure through an SBOM-declared dependency relationship.",
      "source": "it:prod:softver",
      "target": "it:prod:softver",
      "datasets": [
        "sbom",
        "package_registry",
        "vuln_db"
      ],
      "hop_count": 1,
      "assessment": {
        "claim": "indicates",
        "basis": "assessed",
        "scope": "entity_level"
      },
      "hazards": [
        "Common transitive dependencies, vendored packages, and version-range drift can make SBOM links overstate actual exposure.",
        "Corroborate dependency reachability with product version, build metadata, and exploitability context; dependency presence alone is not compromise."
      ],
      "capability_requirements": {
        "required": [
          "sbom_ingestion",
          "dependency_graph_resolution"
        ],
        "optional": [
          "package_metadata_collection",
          "version_range_resolution"
        ]
      },
      "controls": {
        "temporal_window_days": 3650,
        "degree_caps": {
          "it:prod:softver": 50000
        },
        "negative_nodes": [
          {
            "form": "it:prod:softver",
            "list": "ubiquitous_base_libraries"
          }
        ],
        "negative_node_count": 1,
        "provenance": {
          "min_unique_sources": 1
        }
      },
      "presentation": {
        "hazard_count": 2,
        "capability_counts": {
          "required": 2,
          "optional": 2
        },
        "review_status": "not_reviewed",
        "high_cardinality": {
          "applies": false,
          "state": "not_flagged",
          "reasons": [

          ],
          "warnings": [

          ]
        }
      }
    }
  ],
  "artifacts": {
    "schema": "schemas/pivot_pattern.schema.json",
    "patterns_bundle": "artifacts/patterns.tar.gz",
    "fixtures_bundle": "artifacts/fixtures.tar.gz",
    "release_manifest": "artifacts/release-manifest.json",
    "license_summary": "LICENSE",
    "license_code": "LICENSE-CODE",
    "license_data": "LICENSE-DATA",
    "notice": "NOTICE",
    "trademark_policy": "TRADEMARK.md"
  }
};
