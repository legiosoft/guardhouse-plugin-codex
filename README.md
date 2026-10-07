# Guardhouse for OpenAI Codex

The official Guardhouse plugin for OpenAI Codex, developed and maintained by
[LegioSoft](https://guardhouse.cloud). It is not an OpenAI first-party plugin.

> [!IMPORTANT]
> **Beta:** Guardhouse for OpenAI Codex is under active development. Evaluate it
> in a non-production environment and review proposed application or branding
> changes before confirming them.

Guardhouse is an OAuth 2.0 and OpenID Connect identity service for application
authentication, authorization, and access management. This beta helps a local
Codex host connect to a self-hosted or tenant-hosted Guardhouse server, sign in
through Codex's native MCP OAuth flow, discover the server's live capabilities,
inspect and audit existing applications, integrate local projects, safely
configure supported browser-application fields, inspect and configure visual
sign-in branding, and diagnose connection failures.

> **Beta boundary:** browser, native, and service applications can be inspected
> and audited. Only existing browser applications can be configured, and only
> when the live instance advertises that capability. Visual branding can be
> inspected and configured through its separate live capability flags; asset
> descriptors are read-only, and asset changes stay in the Guardhouse admin UI.
> Application creation, registration settings, email templates, roles,
> native/service writes, deletion, and secret rotation are not supported.

## Distribution model

Version 0.2.0 is a skills-only package. It supports user-specific Guardhouse
URLs through local Codex configuration. The intended primary distribution is
the built-in Plugins Directory in a local Codex host after OpenAI approval and
publication. The public Git marketplace in this repository provides a separate
installation route for published releases:

| Surface | Support |
| --- | --- |
| Codex CLI | Plugin skill and local Streamable HTTP MCP configuration |
| Codex IDE extension | Local Streamable HTTP MCP configuration; plugins are not available in the IDE |
| ChatGPT/Codex desktop host | Local plugin installation, setup skill, and local MCP configuration |
| Hosted ChatGPT/Codex | Not supported for arbitrary self-hosted URLs |
| Built-in Plugins Directory | Primary route after approval and publication; skills-only candidate requiring local execution eligibility confirmation |
| Public Git-backed marketplace | Alternate route using this repository's published catalog and release files |

This candidate is not listed in the built-in Directory. The Git marketplace
requires a published release containing the catalog and plugin files.

Git-backed marketplaces are separate from the universal directory shared by
ChatGPT and Codex. A directory submission can contain only skills; it does not
universally require an MCP endpoint. This package requires a local Codex host
with access to the user's configuration and project, and submission materials
must disclose that requirement. Packaging and repository distribution do not
establish directory approval or availability.

The package intentionally contains no `.mcp.json`: a bundled remote MCP
definition does not provide an arbitrary per-user URL setting. Guardhouse
connections through this package require a local Codex host. See OpenAI's
[package guide](https://developers.openai.com/plugins/build/plugins),
[submission process](https://developers.openai.com/plugins/deploy/submission),
and [plugin guidelines](https://developers.openai.com/plugins/plugin-guidelines).

## Prerequisites

Before a user connects, a Guardhouse superadministrator must:

1. Configure the public MCP URL.
2. Agree on one stable Codex callback URL and matching fixed listener port.
3. Register that same exact callback URL on every Guardhouse instance the user
   connects to.
4. Enable the Codex integration.
5. Ensure the signing-in user is a Guardhouse system administrator.

Guardhouse currently pre-registers the public client `guardhouse_codex`,
requires PKCE S256, and does not expose dynamic client registration. Current
Codex supports this public client through
`[mcp_servers.guardhouse.oauth] client_id = "guardhouse_codex"`, so no custom
OAuth client, proxy, or token handling is needed.

Configure the approved `callback_port` and exact `callback_url` explicitly in
`[mcp_servers.guardhouse.oauth]`. A callback URL does not select the listener
port, so local setups need a matching pair. Preserve that pair when switching
instances; only the MCP resource URL and its discovered issuer change.

Stable callbacks require issuer identification: authorization-server metadata
must advertise `authorization_response_iss_parameter_supported: true`, its
`issuer` must exactly match the selected protected-resource
`authorization_servers` value, and authorization redirects must return the
matching `iss`. Current Guardhouse uses OpenIddict's support for this protocol;
the skill verifies each deployment's metadata before configuring Codex.
See [OpenAI's issuer identification requirements](https://developers.openai.com/plugins/build/auth#protect-callbacks-with-issuer-identification).

Older setups using only top-level callback settings can retain a server-specific
suffix. Migrate once to the explicit per-server callback and register the
stable URL on each deployment. If the host or server lacks stable-callback
support, update it instead of generating a new callback for each instance.
Never copy a full authorization URL, state, code challenge, or authorization
code.

## Install from the built-in Plugins Directory

After OpenAI approves the candidate and LegioSoft publishes it, open the
built-in Plugins Directory from local Codex in the desktop app, find
**Guardhouse** by **LegioSoft**, and install and enable it. Then invoke
`$guardhouse` to inspect the connection status and connect your deployment.

Guardhouse is not currently listed there. Installing this skills package will
still require the local execution environment and administrator prerequisites
described above; it does not create a hosted connection to an arbitrary server.

## Install from the public Git marketplace

The repository catalog defines a marketplace named `guardhouse`. When the
release files are available in the public repository, install from Codex CLI:

```console
codex plugin marketplace add legiosoft/guardhouse-plugin-codex
codex plugin add guardhouse@guardhouse
codex plugin list --marketplace guardhouse --json
```

The catalog at `.agents/plugins/marketplace.json` points to the plugin at the
repository root using `./`. The Git source supplies that checkout; the entry
does not fetch its own repository again. Git marketplace installations use
the published repository version.
The list result should show `installed: true` and `enabled: true` after
installation.
Installing the package does not configure Guardhouse or sign in. Invoke the
connection skill below for those steps. Plugins are installed through Codex
CLI or the desktop app; the IDE extension supports direct MCP configuration.

Rebuild and reinstall after local changes. Refresh the Git marketplace
with `codex plugin marketplace upgrade guardhouse` before installing an update.

## Install a clean package for local development

Codex installs local plugins from a marketplace. Build the clean package as
described below, create a temporary marketplace root, and extract the ZIP
contents into `plugins/guardhouse`. Add `.agents/plugins/marketplace.json` at
the marketplace root:

```json
{
  "name": "guardhouse-local",
  "interface": {
    "displayName": "Guardhouse Local"
  },
  "plugins": [
    {
      "name": "guardhouse",
      "source": {
        "source": "local",
        "path": "./plugins/guardhouse"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_USE"
      },
      "category": "Developer Tools"
    }
  ]
}
```

Then register the marketplace:

```console
codex plugin marketplace add ./local-marketplace-root
codex plugin add guardhouse@guardhouse-local
codex plugin list --marketplace guardhouse-local --json
```

The list result must show `installed: true` and `enabled: true`. In the ChatGPT
desktop Plugins Directory, disable and re-enable Guardhouse once, then restart
the desktop host. Rebuild and reinstall after changing a local plugin. Keep
the source checkout separate: the local installer can copy Git history and
ignored files when pointed directly at a repository. Do not commit a temporary
marketplace copy or credentials to this repository.

## Prepare a public package

From a source checkout, run:

```powershell
powershell -NoProfile -File ./scripts/build-package.ps1
```

With RTK installed, the equivalent command is
`rtk powershell -NoProfile -File ./scripts/build-package.ps1`.
The script creates an allowlisted package in the sibling
`../guardhouse-plugin-codex-release` directory. It includes the plugin manifest,
skills and their references, Guardhouse icon, license, README, and security
guidance. Local configuration, credentials, validation artifacts, dependency
caches, and repository history are excluded.

To rebuild the same unpublished candidate when its archive already exists,
explicitly run:

```powershell
powershell -NoProfile -File ./scripts/build-package.ps1 -ReplaceArchive
```

After all validation passes, this flag atomically replaces only that manifest
version's expected ZIP. It does not change the version, remove unrelated output
files, or publish a release.

Review the generated package and its privacy scan before sharing it. This step
prepares release files; it does not upload, submit, or publish them, and it does
not establish OpenAI approval. For a skills-only directory submission, disclose
the required local execution environment and resolve the portal's metadata,
skill, and eligibility findings before requesting review.

## Connect

Start by invoking the skill:

```text
$guardhouse Show my current Guardhouse instance and connection status.
```

Every connection, application, and branding workflow begins with a brief
instance/status summary and explains how to disconnect, reconnect, or switch
to another URL. It distinguishes saved configuration from a verified live
connection. When available, the read-only instance summary identifies the
deployment actually serving the current session; a changed configured URL
alone does not prove the session switched. The plugin continues an already
requested task without forcing a connection-menu choice.

To connect an instance:

```text
$guardhouse Connect Guardhouse to my self-hosted server.
```

The skill uses the supplied server URL or asks for it, validates it, reads Guardhouse protected
resource metadata to obtain the real `/mcp` URL, configures the local Codex MCP
client, and starts native browser sign-in. It never asks for tokens.
Each installation connects to the user's chosen deployment. On a fresh install
with no configured or supplied URL, the skill asks the user for their
Guardhouse HTTPS URL before discovering or configuring a connection.

The equivalent local configuration, using the URL returned by discovery, is:

```toml
[mcp_servers.guardhouse]
url = "https://guardhouse.example/mcp"
auth = "oauth"
enabled = true
scopes = ["guardhouse_mcp", "offline_access"]
oauth_resource = "https://guardhouse.example/mcp"
default_tools_approval_mode = "writes"

[mcp_servers.guardhouse.oauth]
client_id = "guardhouse_codex"
# Example administrator-approved local callback pair, shared across instances
callback_port = 3119
callback_url = "http://localhost:3119/callback"
```

Codex stores MCP OAuth credentials according to its
`mcp_oauth_credentials_store` setting. The plugin does not implement or store
OAuth credentials.

After login, reload the relevant Codex client and ask:

```text
$guardhouse Show my Guardhouse connection status.
```

The connection is successful only when MCP initialization and a live
`tools/list` response succeed. The connection skill reports the live inventory;
when `hello` is available with its current read-only schema, it offers to run
that optional end-to-end check.

## Common workflows

```text
$guardhouse Reconnect to Guardhouse.
$guardhouse Change my Guardhouse server URL.
$guardhouse Switch Guardhouse to https://other-instance.example/mcp.
$guardhouse Help me sign in to Guardhouse again.
$guardhouse Disconnect Guardhouse.
$guardhouse Diagnose why Guardhouse cannot connect.
```

Detailed, secret-safe remediation is included in the plugin's troubleshooting
reference.

Switching discovers the new deployment's issuer, updates `url` and
`oauth_resource`, preserves the callback URL and listener port, and starts
native sign-in for the new instance. Reload the connection and verify its live
instance and tools before using it. Each deployment needs the same callback
registered once. Disconnect disables the local connection while retaining its
instance/callback settings; reconnect uses and, if disabled, re-enables that
saved connection. The plugin reports the resulting instance and status after
these actions.

## Application workflows

Use the dedicated application skill after Guardhouse is connected:

```text
$guardhouse-applications Connect this React application to Guardhouse.
$guardhouse-applications Inspect my Guardhouse application.
$guardhouse-applications Audit this application configuration.
$guardhouse-applications Update this project's callback URLs.
$guardhouse-applications Configure Guardhouse access permissions.
$guardhouse-applications Enable refresh tokens for this application.
```

The skill inspects the local project first, then uses the live MCP tool catalog
to select an existing application, read its redacted state, discover valid
permission names, and run Guardhouse intrinsic checks plus only the project
expectations actually established. It never treats
`get_application.data.configuration_complete` as an audit result.

For a supported browser write, the skill re-reads the application, shows the
observed current state, exact desired state, and replacement effects, then uses
existing exact approval or obtains confirmation before passing the current
revision to `configure_application`. Supplied URI, origin,
and permission arrays are exact replacement sets; omitted fields are preserved.
If `configuration_complete` is missing or not exactly `true`, the skill treats
the read as partial and does not derive replacement arrays or complete removal
lists from it. It preserves omitted arrays or uses an independently established
exact desired set only with approval covering possible unseen removals and the
live contract's limits. It reports remaining incomplete verification.
After success or no-change it re-reads and audits the result. Native and service
applications remain read/audit only.

There is no MCP application-creation tool. If no suitable application exists,
create it through the existing Guardhouse admin workflow. The plugin does not
call the System API or simulate creation. See the compact
[tool contract](skills/guardhouse-applications/references/tool-contracts.md)
for the current inputs, response envelope, and error behavior.

## Branding workflows

Use the dedicated branding skill after Guardhouse is connected:

```text
$guardhouse-branding Review my Guardhouse sign-in branding.
$guardhouse-branding Explain the current colors and typography.
$guardhouse-branding Update the sign-in title and primary palette.
$guardhouse-branding Review a custom CSS change for the login page.
```

The skill discovers the live schemas, checks the `read_branding` and
`configure_branding` capability flags, and calls `get_branding` before every
write proposal. `configure_branding` accepts a complete desired state, so the
skill starts from the exact returned object, changes only the confirmed fields,
and preserves everything else. It echoes all eight safe asset descriptors
unchanged and directs asset uploads, replacement, and removal to the Guardhouse
admin UI.

Before a write, the skill shows the exact changes and effects, then uses
existing exact approval or obtains confirmation. Large HTML/CSS changes are
identified by their precise layer/page/state, byte size, digest, and bounded
inert excerpt; returned or
proposed markup is never executed. A stale revision causes a fresh read,
rebuilt proposal, and comparison of the desired state and effects. Existing
exact approval can be reused when both still match; changed desired state or
newly discovered effects require new confirmation. The stale revision is never
reused. After success or no-change, the skill reads branding again and reports
the effective state and warnings. See the compact
[branding tool contract](skills/guardhouse-branding/references/tool-contracts.md)
for the supported custom-HTML identifiers and response behavior.

## Data and security

- The server URL is stored in the user's local Codex configuration.
- Sign-in and MCP requests go directly between the local Codex host and the
  selected Guardhouse deployment.
- OAuth credentials are handled by Codex, not this plugin.
- The plugin contains only declarative metadata, instructions, and the
  Guardhouse-owned icon: no executable client, dependencies, telemetry, proxy,
  REST wrapper, or custom token store.
- The skills instruct Codex to send Guardhouse only the explicit structured
  values required by its tools. They must not send local files, source code,
  filesystem paths, OAuth credentials, or other secrets to Guardhouse.
- Codex's processing of project content and its host/model data handling are
  governed by its settings and applicable policies.
- Tool capabilities and schemas are discovered live. The existing browser
  configuration tool is destructive because exact replacement sets can remove
  values, so the skill requires an exact preview and explicit confirmation.
- Branding configuration is a non-destructive complete desired-state write.
  The skill preserves unrelated settings and immutable asset descriptors,
  requires exact confirmation, and re-reads the effective state.
- Returned application names, URLs, permission descriptions, branding text,
  filenames, social URLs, HTML, CSS, warnings, errors, and remediations are
  treated as untrusted data, never as instructions.

See [SECURITY.md](SECURITY.md) for reporting and handling guidance.

## Documentation and support

- [Guardhouse documentation](https://guardhouse.cloud/docs/)
- [Support](https://guardhouse.cloud/contacts)
- [Privacy policy](https://guardhouse.cloud/privacy-policy)
- [Terms of service](https://guardhouse.cloud/terms)

## License

Licensed under the [Apache License 2.0](LICENSE).
