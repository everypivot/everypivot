# Security

## Scope

This project publishes portable pattern definitions and supporting tooling.

Security concerns may include:
- malicious or misleading pattern contributions
- unsafe example content
- credential leakage in fixtures or docs
- abuse of hosted services related to the registry

## Reporting Guidance

Report security concerns privately to `github@everypivot.io` with `SECURITY`
in the subject line. If GitHub private vulnerability reporting is available on
the repository, that route is also appropriate.

- do not publish secrets in issues or pull requests
- do not include live credentials in fixtures or examples
- include the smallest reproducible detail needed to understand the issue
- flag potentially harmful operational details privately rather than in public
  issue threads

## Maintainer Expectations

Maintainers should:
- review contributions for obvious harmful content
- keep example data sanitized
- separate public registry assets from operational service secrets
