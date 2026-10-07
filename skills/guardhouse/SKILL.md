---
name: guardhouse
description: Install or upgrade the Guardhouse Codex plugin, get started with Guardhouse, connect, authenticate, inspect connection status, reconnect, change URL, disconnect, or diagnose a self-hosted Guardhouse MCP server in a local OpenAI Codex host. Use for plugin installation and update guidance, first-use onboarding, server URL changes, OAuth sign-in, live tool discovery, or the Hello World connection check across Codex CLI, the Codex IDE extension, and the ChatGPT/Codex desktop host. Use guardhouse-applications for application work and guardhouse-branding for visual appearance; arbitrary self-hosted URLs are not available to hosted-only ChatGPT.
---

# Guardhouse

Connect a local Codex host to the Guardhouse server chosen by the user. Let Codex
handle MCP and OAuth natively; this skill supplies the safe setup and diagnosis
workflow. It also explains how to install and upgrade this plugin from GitHub.

## Plugin installation and upgrade requests

For installing or upgrading the **Codex plugin**, or questions about those
steps, use [the installation and upgrade guide](references/plugin-installation.md)
before any connection workflow. Package help does not require a Guardhouse
instance or sign-in. Explain commands for a how-to question; execute package
changes only when requested. If "upgrade Guardhouse" could mean the plugin or
the server, clarify the target before changing either.

## Start with the current connection

For connection, application, or branding work, read and apply
[the current-instance and connection-status check](references/connection-status.md).
Tell the user the configured and, when verified, live Guardhouse instance,
its connection status, and how to disconnect, reconnect, or switch to another
URL. Use the same opening for application and branding work. Refresh the
summary after a connection change without repeating it for every tool call.
For an observed unconfigured installation, use the reference's first-use
explanation: what Guardhouse does, why a server connection is needed, and the
one next setup action. Do not assume the user knows MCP or OAuth terminology,
and do not present connection-management controls before a connection exists.

## Operating rules

- Follow the user's explicit instructions within platform constraints. Reuse
  existing authorization for the same exact action; do not ask for it again.
- Ask one actionable question at a time.
- Explain that the server URL identifies the user's Guardhouse deployment and
  that browser login grants Codex access to it.
- Never ask for or accept an access token, refresh token, authorization code,
  client secret, cookie, or sensitive header.
- Never implement OAuth, persist credentials, or copy credentials between
  machines. Codex owns MCP OAuth credential handling.
- Never report a successful connection until the live server completes MCP
  initialization and returns a valid `tools/list` response.
- Discover tools after authentication. Do not assume that `hello` is the only
  tool forever or invent tools that the server did not advertise.
- Treat the current `hello` tool as harmless only when its live schema and
  annotations still confirm that behavior. Route application inspection,
  audit, access, local integration, and configuration to
  `$guardhouse-applications`. Route sign-in branding inspection, review, and
  configuration to `$guardhouse-branding`. Do not duplicate either workflow
  here.
- Sanitize errors. Do not print sensitive headers, codes, tokens, cookies, or
  complete raw responses.

## Choose the workflow

- For plugin installation, updates, or upgrade instructions, follow
  [references/plugin-installation.md](references/plugin-installation.md).
- For getting started, first-use onboarding, connect, or change URL, follow
  **Connect** after the opening check.
- For status, reconnect, sign in again, or disconnect, follow **Manage a
  connection**.
- For requests about a Guardhouse application, callback/logout URLs, browser
  origins, access permissions, refresh tokens, or local-project integration,
  invoke `$guardhouse-applications`. If its required live tools are missing,
  complete this connection workflow first.
- For requests about sign-in branding, visual appearance, palettes, colors,
  typography, layout, backgrounds, branding text, social links, assets, or
  supported custom HTML/CSS, invoke `$guardhouse-branding`. If its required
  live tools are missing, complete this connection workflow first.
- For any failure, read
  [references/troubleshooting.md](references/troubleshooting.md) and apply the
  matching remediation.
- If the user is in hosted ChatGPT or another hosted-only surface, explain that
  an MCP-backed hosted connection requires a fixed production MCP endpoint.
  Arbitrary per-user Guardhouse URLs are not supported there. A skills-only
  listing would not make local MCP configuration available to hosted ChatGPT.
  Do not offer a proxy, bootstrap service, or configuration workaround.

## Connect

### 1. Confirm the local surface

Proceed only in Codex CLI, the Codex IDE extension, or the ChatGPT/Codex desktop
host. These local clients use the user's Codex MCP configuration.

If the current surface cannot edit or reload that configuration, explain what
is missing and give the next local action instead of claiming setup is complete.

Before editing configuration, confirm that the installed host supports all
three per-server OAuth settings: `oauth.client_id`, `oauth.callback_url`, and
`oauth.callback_port`. Use that host's settings UI, configuration schema, or
documentation matching its installed version. A client-ID CLI option alone
does not prove callback-setting support, and current online documentation does
not establish support in an older installed host. If the settings cannot be
verified, require a host update or a supported local client before proceeding;
do not save ignored keys or accept an instance-specific callback as a fallback.

### 2. Ask for the Guardhouse URL

Ask:

> What is the HTTPS web address of the Guardhouse server you want to use?
> Use the server's main address, not a link to an individual settings page.

Accept a full `/mcp` URL or the deployment root. Do not guess a tenant URL.
If the user already supplied the target URL, use it without asking again.
If they do not know the address or have no deployment, apply the first-use
guidance in the shared opening reference before continuing setup.

### 3. Validate and normalize

Parse the value as an absolute URI and apply all of these checks before making a
request:

- Limit the input to 2,048 characters and trim surrounding whitespace.
- Require `https`.
- Permit `http` only for an explicit loopback development host: `localhost`, an
  address in `127.0.0.0/8`, or `[::1]`.
- Reject embedded credentials, query strings, fragments, backslashes, invalid
  ports, and schemes other than HTTP(S).
- Accept only an empty/root path or `/mcp`, ignoring a trailing slash.
- Do not treat names such as `localhost.example.com` as loopback.

Normalize scheme and host casing and remove a default port only through a
standards-compliant URI parser. Preserve the validated authority.

### 4. Discover the real MCP resource

Request this endpoint on the validated authority:

```text
/.well-known/oauth-protected-resource/mcp
```

Use a short timeout, accept only JSON, and cap the response read to 64 KiB. Do
not silently follow a redirect to a different authority.

Validate the response:

- `resource` is an absolute HTTPS URL, or an allowed loopback HTTP URL.
- The resource has no credentials, query, or fragment and its path is `/mcp`.
- `authorization_servers` contains at least one absolute HTTPS issuer, or an
  allowed loopback HTTP issuer, with no credentials, query, or fragment.
- `scopes_supported`, when present, includes both `guardhouse_mcp` and
  `offline_access`.
- `bearer_methods_supported`, when present, includes `header`.

The `resource` value is the MCP URL. Do not blindly append `/mcp` to the user's
input. If the resource or authorization server uses a different authority,
explain the mismatch and ask the user to confirm that authority before making
another request or saving it.

Read the selected authorization server's OAuth/OIDC discovery metadata with
the same timeout, size, and redirect limits. Require its `issuer` to exactly
match the selected `authorization_servers` value and
`authorization_response_iss_parameter_supported` to be `true`. Do not normalize
the issuer for comparison. This allows Codex to validate the returned `iss`
parameter and safely share one callback across Guardhouse instances. If the
deployment lacks this support, explain that it needs an update before stable
callback setup; do not substitute an instance-specific callback.

### 5. Prepare a stable OAuth callback

Inspect only non-secret callback configuration, not stored credentials:

- `mcp_servers.guardhouse.oauth.callback_port`
- `mcp_servers.guardhouse.oauth.callback_url`
- the legacy top-level `mcp_oauth_callback_port` and `mcp_oauth_callback_url`,
  only to reuse an existing approved listener port and callback base.

Configure an explicit fixed `callback_port` and exact `callback_url` under
`[mcp_servers.guardhouse.oauth]`. Reuse the approved callback across every
Guardhouse instance, including when changing the MCP URL. Do not derive a
callback from the resource URL or append a server-specific ID. With the
pre-registered client and verified issuer identification, current Codex uses
this explicit callback unchanged.

For a normal local host, use a loopback callback URL whose explicit port matches
`callback_port`. The URL does not select the listener port. If no approved pair
exists or the ports differ, explain the constraint and ask for a matching pair;
do not invent a port. Show the proposed non-secret settings before editing them
and obtain confirmation unless the user has already authorized that exact
change. Preserve unrelated global callback settings.

Register the same exact callback URL for `guardhouse_codex` on each deployment
once. Existing installations using a resource-specific suffix need a one-time
migration to this stable callback. A top-level callback base alone can retain
legacy suffix behavior, so always save the explicit per-server pair. If native
login still generates a suffixed redirect, stop and check that the current host
loaded the per-server settings, supports them, and discovered issuer
identification; do not ask the administrator to register a different callback
for every instance. Use only Codex's documented native controls if a fresh
authorization is needed. Never inspect or move saved credentials.

Use a non-local callback URL only for an intentional remote-host setup; Codex
binds a non-local callback listener on all interfaces, so call out the exposure
before saving it and still set the listener port explicitly. Never expose the
full authorization URL, `state`, code challenge, or authorization code.

Guide these as separate, one-action exchanges.

Also explain that a Guardhouse administrator must configure the public MCP URL,
enable the Codex integration after registering the callback, and ensure the
signing-in account has Guardhouse system-administrator access.

Guardhouse currently uses a pre-registered public client named
`guardhouse_codex`, requires PKCE S256, and does not expose dynamic client
registration. Current Codex supports an explicit public MCP OAuth client ID.
For CLI-based setup, confirm that `codex mcp add --help` exposes
`--oauth-client-id`, in addition to the per-server callback support checked
above, then configure the nested client setting shown below. This selects the
pre-registered client and avoids dynamic registration. If the installed host
lacks the supported settings, stop and ask the user to update that host; do not
implement custom OAuth.

### 6. Configure Codex

Use a supported local Codex mechanism: the MCP settings UI, the current
`codex mcp` CLI, or the user's `~/.codex/config.toml`. Inspect current CLI help
before constructing a CLI command. Preserve unrelated settings and do not
overwrite a non-Guardhouse server already named `guardhouse` without asking.

The equivalent configuration is:

```toml
[mcp_servers.guardhouse]
url = "<discovered resource URL>"
auth = "oauth"
enabled = true
scopes = ["guardhouse_mcp", "offline_access"]
oauth_resource = "<discovered resource URL>"
default_tools_approval_mode = "writes"

[mcp_servers.guardhouse.oauth]
client_id = "guardhouse_codex"
callback_port = <approved fixed listener port>
callback_url = "<approved stable callback URL>"
```

Do not add `enabled_tools`: the host must discover present and future tools from
the server. Do not add a client secret, bearer token, or static authorization
header.

### 7. Start native sign-in

Start Codex's native MCP OAuth login:

- In the IDE or desktop MCP settings, select Guardhouse and **Authenticate**.
- In the CLI, run `codex mcp login guardhouse`.

Tell the user that Codex will open or continue a browser flow. Ask them to sign
in to Guardhouse and approve access, then wait for their result. If the stable
callback has not yet been registered or the integration is disabled, wait for
the administrator to complete that setup before starting native login. Do not
interpret configuration or discovery as a completed login.

Codex stores the resulting MCP credentials according to its
`mcp_oauth_credentials_store` setting (`auto`, `file`, or `keyring`); never
inspect or move those credentials.

### 8. Reload and verify

Reload the MCP connection: restart the IDE extension, reload the desktop host,
or reopen the CLI session when needed. Use the host's live MCP status and tool
discovery to verify:

1. MCP initialization succeeds.
2. `tools/list` returns a valid response.
3. Report the discovered Guardhouse tool names and descriptions in plain
   language.

Refresh the opening instance/status summary. When `get_instance_summary` is
available, verify that its live `public_mcp_url` matches the new target before
reporting a switch successful or continuing application or branding work.

If the connection succeeds with no tools, report that exact state. Do not call
it a fully working Guardhouse integration.

When `hello` is discovered, offer:

> Guardhouse is connected. Would you like me to run the harmless Hello World
> connection check?

If the user accepts or already asked for the check, call the live discovered
`hello` tool. Report success only from its successful MCP response.

## Manage a connection

### Status

Apply [the shared opening check](references/connection-status.md), including
the available connection controls. A status request authorizes only read-only
inspection, not a reload, login, reconnect, disconnect, or configuration change.

### Reconnect

Keep the validated URL and stable callback pair. If the user requested reconnect
and the local connection is disabled, re-enable it without replacing its
settings. Reload the host connection and retry initialization and `tools/list`.
If authorization is expired or revoked, run native MCP login again. Refresh the
instance/status summary; do not claim reconnection from a settings change alone.

### Change the Guardhouse URL

Repeat URL validation and protected-resource discovery. Show the old and new
non-secret origins, ask before replacing an existing working configuration,
unless the user has already authorized the switch, then update both `url` and
`oauth_resource`. Verify the new issuer's identification support and preserve
the existing per-server callback port and URL unchanged. The new deployment
must register that same stable callback; switching does not require a new
callback ID. Start native login again and verify the new live tool list. Never
reuse, copy, or manually delete tokens.

Changing the public MCP URL inside Guardhouse itself is an administrator action
that disables integrations, revokes existing authorizations, and requires a
Guardhouse restart before re-enablement.

### Sign in again

Run the host's native MCP login for `guardhouse`, complete browser consent, then
reload and verify. If Codex needs stored authorization cleared, use only the
current host's documented UI or a command shown by `codex mcp --help`.

### Disconnect

For an ordinary disconnect request, set `enabled = false`, preserving the
saved instance and callback settings for reconnection. Do not ask the user to
choose removal unless their request is ambiguous. Reload the host connection
as needed, then report the configured disabled state and any still-active live
session separately. Remove only the Guardhouse server table and its nested
OAuth settings when the user explicitly requests removal, preserving every
unrelated setting. Explain that local disablement or removal does not itself
revoke authorization at the Guardhouse server.
