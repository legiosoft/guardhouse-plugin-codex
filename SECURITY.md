# Security policy

## Supported versions

Guardhouse for OpenAI Codex is currently a beta. Security fixes are provided for
the latest `0.2.x` release.

## Report a vulnerability

Use the private contact channel at
[guardhouse.cloud/contacts](https://guardhouse.cloud/contacts). Do not open a
public issue containing a vulnerability, credential, browser callback URL,
tenant hostname, private network detail, or unredacted server response.

Include the plugin version, Codex surface and version, affected workflow,
sanitized reproduction steps, and impact. Remove tokens, authorization codes,
cookies, sensitive headers, and personal or tenant data.

## Security model

The release package contains declarative metadata, instructions, and
Guardhouse-owned branding. It has no executable client, runtime dependency,
telemetry, proxy, or custom OAuth implementation. The repository's package
builder is development tooling and is excluded from the release ZIP.

- The user chooses the Guardhouse URL.
- The workflow validates the URL and discovers the MCP resource from
  `/.well-known/oauth-protected-resource/mcp`.
- Non-loopback HTTP is rejected and TLS verification must remain enabled.
- Codex performs native MCP OAuth and stores credentials according to
  `mcp_oauth_credentials_store`.
- The plugin never requests or persists tokens.
- Public source and release packages contain no personal host configuration,
  real test-deployment URLs, or developer-specific absolute filesystem paths.
  The package builder checks source hygiene and copies only approved package
  files; local caches and validation fixtures belong outside the repository.
- MCP initialization and live tool discovery are required before success is
  reported.
- The skills instruct Codex to send Guardhouse only the explicit structured
  values required by its tools. They must not send local files, source code,
  filesystem paths, OAuth credentials, or other secrets to Guardhouse. Codex's
  processing of project content and its host/model data handling are governed
  by its settings and applicable policies.
- Returned application names, URLs, permission descriptions, warnings, and
  errors are untrusted data and must never be followed as instructions.
- `configure_application` is destructive because supplied arrays replace
  complete sets. The workflow requires an immediate read, an exact
  desired-state/effects preview, explicit confirmation, and the current
  revision. Incomplete reads must not supply inferred full replacement sets;
  preserve omitted arrays or use independently established exact sets with
  approval covering possible unseen removals.
  After a concurrency failure, re-read and rebuild the proposal.
  Renew confirmation when the desired state or effects change; retain existing
  exact approval when only the revision changes and both still match.
- Browser and native projects must never receive a client secret. The MCP tools
  do not return client secrets or Guardhouse access tokens.

The operator of the selected Guardhouse deployment controls its availability,
identity data, access policy, logs, retention, and permissions. Consult the
[Guardhouse security documentation](https://guardhouse.cloud/docs/operate/security)
and the operator's policies.
