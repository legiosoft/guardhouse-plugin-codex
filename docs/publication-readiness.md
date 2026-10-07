# Publication readiness

The primary target is a skills-only submission to the built-in Plugins
Directory for local Codex. A Git marketplace in this public repository is the
alternate route. This guide covers package validation and release requirements;
the current beta candidate is not listed in the Directory.

## Package scope

The `0.2.0` package contains separate connection/troubleshooting,
application-management, and visual-branding skills. It requires local Codex
execution and does not bundle `.mcp.json` or lifecycle hooks. The candidate
retains its beta scope.

Current Codex plugin MCP configuration is static. Official documentation does
not define a supported per-user plugin setting that can persist an arbitrary
Guardhouse URL and substitute it into a bundled remote MCP definition. Hosted
ChatGPT does not consume a user's local Codex MCP configuration. A skills-only
plugin can be distributed through a Git-backed marketplace and submitted to
the universal directory without MCP configuration. Directory eligibility and
review must account for its local execution requirements; submission does not
provide hosted access to a user's Guardhouse server.

Therefore:

- self-hosted and tenant-hosted users configure the discovered URL in their
  local Codex MCP configuration;
- public Git-backed marketplace distribution uses the current skills-only
  package and the `guardhouse` catalog in the published repository;
- a universal-directory submission must disclose that workflows require local
  configuration access, native sign-in, and local project access; and
- this repository does not implement a central proxy, bootstrap service,
  custom installer, or unsupported URL-substitution mechanism.

OpenAI's [package guide](https://developers.openai.com/plugins/build/plugins)
distinguishes repo marketplaces from the universal public directory. The
[submission process](https://developers.openai.com/plugins/deploy/submission)
allows skills-only packages without MCP configuration or MCP app review cases;
the [plugin guidelines](https://developers.openai.com/plugins/plugin-guidelines)
apply metadata, policy, skill scans, and possible additional eligibility
requirements to those packages. Confirm local execution eligibility with the
current submission flow instead of assuming every directory surface supports
these workflows.

## Guardhouse protocol contract

Repository evidence establishes:

- Streamable HTTP MCP resource: the `resource` advertised by
  `/.well-known/oauth-protected-resource/mcp`, normally `/mcp`;
- authorization server: the Guardhouse issuer advertised in protected-resource
  metadata;
- scopes: `guardhouse_mcp` and `offline_access`;
- audience: exactly the active public MCP resource URL;
- OAuth client: pre-registered public client `guardhouse_codex`;
- grants: authorization code and refresh token with PKCE S256;
- consent: systematic browser consent;
- access: Guardhouse system administrators only;
- dynamic client registration: not implemented; and
- Codex client selection: the supported nested
  `mcp_servers.<name>.oauth.client_id` setting selects `guardhouse_codex`
  without dynamic registration; and
- catalog version: `1.0.0`;
- `hello`: read-only connection check;
- `get_instance_summary`: read-only instance and authoritative per-kind
  capability summary;
- `list_applications` and `get_application`: read-only application catalog and
  redacted configuration inspection;
- `list_application_access_options`: read-only discovery of assignable
  permission names and protected resources;
- `audit_application`: read-only Guardhouse intrinsic checks plus only the
  explicit project expectations supplied by the client; and
- `configure_application`: destructive, idempotent desired-state configuration
  for an existing browser SPA, using an expected revision and complete
  replacement semantics for supplied arrays;
- `get_branding`: read-only complete visual-branding inspection with an opaque
  revision and eight safe asset descriptors; and
- `configure_branding`: non-destructive, idempotent complete desired-state
  visual-branding configuration with explicit user interaction, revision
  checking, immutable asset descriptors, and post-write reload data.

Browser, native, and service applications are readable and auditable. Only
existing browser applications are configurable, subject to the live capability
flags. Visual branding is readable and configurable subject to the independent
`read_branding` and `configure_branding` flags; asset changes remain outside
MCP. All application kinds currently report `creatable: false`. The nine-tool
MCP catalog does not expose application creation, registration settings, email
templates, roles, native/service writes, deletion, secret retrieval or
rotation. Runtime `tools/list` schemas and backend source remain authoritative;
the plugin includes only compact contract references.

The Guardhouse Codex integration defaults to disabled. Its public URL, exact
Codex callback, and enablement require superadministrator preparation. Changing
the public MCP URL disables integrations, revokes authorization, and requires a
Guardhouse restart before re-enablement.

## Surface support

| Surface | `0.2.0` model | OAuth and MCP behavior |
| --- | --- | --- |
| Codex CLI | Supported for local installation and direct MCP configuration | `codex mcp login guardhouse`, local callback, native credential store, reload session, live discovery |
| Codex IDE extension | Direct MCP configuration is supported; plugins are not available in the IDE | Add Streamable HTTP server, select **Authenticate**, restart extension, live discovery |
| ChatGPT/Codex desktop host | Supported through a local marketplace | Local Codex MCP configuration, native browser login, reload host, live discovery |
| Hosted ChatGPT/Codex | Not supported for an arbitrary user-supplied URL | Outside this package's scope |
| Public Git-backed marketplace | Skills-only package distribution | Installed local host performs configuration and native OAuth |
| Universal Plugins Directory | Skills-only submission candidate | Requires metadata/skill scans, review, and eligibility disclosure for local execution |

Codex controls native OAuth credential persistence through
`mcp_oauth_credentials_store`: `auto` (default), `file`, or `keyring`. The
plugin must never inspect, copy, or replace those credentials.

Codex uses an ephemeral local OAuth callback port unless a fixed listener port
is configured. Guardhouse's single exact redirect cannot rely on that default:
configure an approved `callback_port` and exact `callback_url` under
`[mcp_servers.guardhouse.oauth]`. The URL does not select the listener port.
Register the same stable URL on each deployment and preserve both settings when
switching instances. Do not derive a new callback from the MCP URL. Never copy
the full authorization request.

## OAuth client and callback compatibility

Guardhouse does not expose dynamic client registration and accepts only its
reserved `guardhouse_codex` public client for this integration. Current Codex
CLI exposes `--oauth-client-id`, and its supported configuration schema accepts
`[mcp_servers.<name>.oauth] client_id`. Codex CLI and the desktop app-server
pass that value into native MCP OAuth, selecting the pre-registered public
client and bypassing dynamic registration. No client secret, custom OAuth
implementation, or token-handling workaround is required.

Check the host's supported configuration schema and CLI help during onboarding
to detect builds that lack the required OAuth client and callback settings.

Stable callbacks require authorization-server metadata with
`authorization_response_iss_parameter_supported: true`, an `issuer` exactly
matching the selected protected-resource `authorization_servers` entry, and
the matching `iss` on successful and error authorization redirects. Current
Guardhouse's OpenIddict handlers provide this support; verify deployed metadata.
With the pre-registered client and this support, current Codex uses an explicit
per-server callback URL unchanged across instances. The global callback base
alone can retain legacy server-specific suffix behavior. Migrate those setups
once, rather than requiring a different registered callback for every instance.
See [Codex callback configuration](https://learn.chatgpt.com/docs/config-file/config-reference)
and [issuer identification](https://developers.openai.com/plugins/build/auth#protect-callbacks-with-issuer-identification).

Validate stable-callback login and instance switching against the deployed
servers before reporting that flow as verified.

Guardhouse currently stores one Codex redirect URI for the deployment. Local
clients must use the same registered callback pair. Guardhouse also
accepts an MCP `Origin` header only when its scheme, host, and port match the
active MCP URL; verify this against every supported local client.

## Proposed skills-only listing

### Identity

- Name: **Guardhouse**
- Identifier: `guardhouse`
- Publisher: **LegioSoft**
- Version: `0.2.0`
- Category: **Developer Tools** (confirm against the submission portal)
- License: Apache-2.0

### Short description

Connect Codex to Guardhouse, audit applications, and safely configure supported
browser settings and visual branding.

### Long description

Guardhouse is an OAuth 2.0 and OpenID Connect identity service for application
authentication, authorization, and access management. This LegioSoft-maintained
beta connects local OpenAI Codex hosts through native MCP OAuth, discovers live
capabilities, inspects and audits existing browser, native, and service
applications, integrates local projects, and configures supported fields on
existing browser applications. It also inspects and safely configures visual
sign-in branding through complete desired-state updates with explicit
confirmation and revision checks.

### Starter prompts

1. Show my current Guardhouse instance and connection status, and how to
   disconnect, reconnect, or switch instances.
2. Audit my Guardhouse application configuration.
3. Review and update my Guardhouse sign-in branding.

### Public properties

| Purpose | URL |
| --- | --- |
| Website | https://guardhouse.cloud |
| Documentation | https://guardhouse.cloud/docs/ |
| Support | https://guardhouse.cloud/contacts |
| Privacy | https://guardhouse.cloud/privacy-policy |
| Terms | https://guardhouse.cloud/terms |
| Security guidance | https://guardhouse.cloud/docs/operate/security |
| Source | https://github.com/legiosoft/guardhouse-plugin-codex |

Before submission, verify that these pages are accessible, identify the same
publisher, and contain complete, production-approved content.

## Data handling statement

The connection skill instructs Codex to store the chosen MCP resource URL in
the user's local configuration. Codex stores native MCP OAuth credentials
according to the user's credential-store setting. Native sign-in and MCP
requests communicate with the selected Guardhouse deployment.

The plugin itself has no telemetry, executable runtime, token store, proxy, or
third-party dependency. The selected Guardhouse operator controls service-side
identity data, authorization, logs, retention, residency, and access.

The skills instruct Codex to inspect the local project and send only the
structured identifiers, filters, project expectations, or confirmed desired
configuration required by Guardhouse tools. They prohibit including local
files, source code, filesystem paths, tokens, secrets, cookies, authorization
codes, or sensitive headers in tool inputs or diagnostics. Codex's native OAuth
flow handles the authentication protocol. These instructions describe plugin
workflows, not an independent runtime control over Codex's data handling.
Codex host and model processing are governed by their own settings and policies.

The skills require stored and returned application names, URLs, permission
descriptions, branding text, filenames, social URLs, HTML, CSS, warnings,
errors, and remediations to be treated as untrusted data rather than
instructions. HTML and CSS must be reviewed as inert text.

## Manual review cases

Invoke `$guardhouse` or its getting-started prompt to enter the connection
workflow. The manifest's `com.openai.onboardingSkill` metadata identifies the
skill a supported host can select; it does not guarantee an automatic run or
an installation-triggered popup. Installation alone does not start background
discovery, configuration, or sign-in. All live cases below remain **Not run**
until results are recorded from the actual supported surface.

### Opening instance and connection status

Run these at the first Guardhouse interaction in a fresh chat, including direct
application and branding requests. Each opening must identify the observed
instance/status and briefly explain disconnect, reconnect, and switch controls
when relevant, without forcing a menu choice or changing the connection merely
to check it. For a verified unconfigured host, explain Guardhouse and the next
setup step in plain language instead of listing controls for a nonexistent
connection.

| Fixture | Expected behavior |
| --- | --- |
| Verified live tools and instance summary | Show the live instance name/URL and connected state before substantive work; reuse the summary for capability checks. |
| Configured URL, no live inspection surface | Show the configured instance and mark the connection unverified; do not infer failure from a missing namespace. |
| Setup requested and active host confirms no configuration or live connection | Briefly explain that Guardhouse manages application sign-in and access, show **Ready to set up**, and ask one question for the Guardhouse server's HTTPS address unless already supplied. |
| Saved connection disabled | Show the saved instance and disabled state; explain reconnect re-enables it. |
| Disabled settings but still-active live tools | Report both states and the reload needed for disablement to take effect. |
| Native authorization required | Show the configured instance and sign-in-required state, without initiating login from a status-only request. |
| Configured target B, live summary still identifies A | Show both and stop application/branding operations until the intended live target is verified. |
| Explicit switch to B while A is unreachable | Report the old state once, proceed with the authorized validation/switch, preserve the callback pair, and verify B's live identity and tools. |
| Ordinary disconnect followed by reconnect | Disable while preserving the URL/callback; reconnect re-enables that same instance. Report the resulting state after each action. |

### Novice onboarding cases

| Fixture or prompt | Expected behavior |
| --- | --- |
| Fresh user invokes getting started; the active host verifies no configured or live connection | Briefly explain Guardhouse, report **Ready to set up**, mention the existing-server and administrator-access requirements and later browser sign-in, and ask: `What is your Guardhouse server's HTTPS address?` Keep issuer, MCP, OAuth, callback, and configuration details for the relevant setup step. |
| User answers that they do not have a Guardhouse address or instance | Direct them to their Guardhouse administrator or the [public setup documentation](https://guardhouse.cloud/docs/). Do not invent a default server, deploy an instance, create an account, or repeat the address question as though they already have one. |
| A Guardhouse URL is configured, but live inspection is unavailable | Show the configured instance with an **Unverified** connection state and explain the available read-only next step. Do not claim a fresh installation, connection failure, or **Ready to set up** merely because live tools are missing; do not ask for a replacement address or change configuration. |
| Direct application or branding request on a verified unconfigured host | Use the same concise setup opening before Guardhouse application/branding server operations. Retain the requested task and resume it after a verified connection. Ask only for the server address as the initial connection prerequisite; do not fabricate instance data or attempt a write. |
| User already supplied the Guardhouse HTTPS address in the request | Reuse that address and existing connection authorization; proceed with the connection skill's validation and discovery without asking the same question again. Require an approved callback pair and authorized administrator account at the appropriate steps, then use native browser sign-in. |
| User asks only for connection status, with no configured or live connection | Report the observed setup state and how to start setup. Keep the request read-only: do not infer connection authorization, discover a guessed server, edit configuration, or start sign-in. |

### Positive cases

1. **Valid onboarding**
   - Prompt: `Connect Guardhouse to https://review-instance.example/mcp.`
   - Expected behavior: validate HTTPS, request protected-resource metadata,
     use its advertised `/mcp` resource, verify issuer identification, and save
     native OAuth configuration with an explicit stable callback URL and
     matching listener port, without a token or static header.
   - Expected result: report configuration completed but connection not yet
     verified; show only the non-secret origin and the next browser-login step.
   - Fixture: prepared HTTPS Guardhouse review instance with valid metadata.
2. **Native login**
   - Prompt: `Help me sign in to Guardhouse.`
   - Expected behavior: start the host's native MCP OAuth login, complete
     Guardhouse sign-in and consent, and keep codes and tokens hidden.
   - Expected result: report that login returned, then require MCP
     initialization and `tools/list` before calling the connection successful.
   - Fixture: reviewer-ready Guardhouse system-administrator account with no
     MFA, email, SMS, or private-network dependency.
3. **Connection status**
   - Prompt: `Show my Guardhouse connection status.`
   - Expected behavior: use a read-only host status surface and a fresh tool
     list without reloading, logging in, or changing configuration.
   - Expected result: non-secret URL, enabled/auth state when exposed,
     initialization state, and discovered tool names; otherwise mark each field
     unverified.
   - Fixture: installed plugin and an authenticated review instance.
4. **Hello World**
   - Prompt: `Run the Guardhouse Hello World connection check.`
   - Expected behavior: confirm `hello` appears in the fresh tool list, then
     call that discovered tool.
   - Expected result: the successful live MCP result, currently
     `Hello from Guardhouse.`; never a simulated result.
   - Fixture: authenticated review instance running the submitted server
     version.
5. **URL change and reconnect**
   - Prompt: `Change my Guardhouse URL to https://second-review-instance.example/mcp.`
   - Expected behavior: rediscover the second resource, show both safe origins,
     verify its exact issuer and issuer-identification support, honor existing
     switch authorization, update both URL fields, preserve the callback URL
     and port unchanged, run native login again, and reload the connection.
   - Expected result: report success only after the second instance completes
     initialization and returns a fresh tool list; both instances use the same
     exact OAuth redirect URI, without any resource-specific callback ID.
   - Fixture: two separately prepared review instances with the same stable
     callback registered and an administrator account accepted by both.
6. **Application inspection and audit**
   - Prompt: `Inspect and audit my Guardhouse application.`
   - Expected behavior: inspect the local project, call
     `get_instance_summary`, resolve the application through complete catalog
     pagination, read the redacted application, and audit only established
     expectations.
   - Expected result: identify the application kind and revision, distinguish
     `configuration_complete` from audit status, and report findings, warnings,
     performed checks, skipped checks, and incomplete coverage.
   - Fixture: authenticated instance with browser, native, and service
     applications plus a local project containing safe configuration examples.
7. **Access discovery**
   - Prompt: `Configure Guardhouse access permissions for this project.`
   - Expected behavior: inspect the project's required APIs, paginate
     `list_application_access_options`, and use only returned permission names
     and resource identifiers.
   - Expected result: a complete current-versus-required comparison with no
     guessed names and no write before the exact desired set is confirmed.
   - Fixture: an application and assignable API permissions with reviewed
     sample data.
8. **Confirmed browser configuration**
   - Prompt: `Update this project's Guardhouse callback URLs.`
   - Expected behavior: re-read an existing configurable browser application,
     preserve values not proven obsolete, show complete replacement sets and
     additions/removals, obtain explicit confirmation, and pass the current
     revision once.
   - Expected result: after success or no-change, re-read and audit the current
     state while reporting warnings separately.
   - Fixture: a non-production browser application with a known revision and
     safe development URLs.
9. **Branding inspection**
   - Prompt: `Review my Guardhouse sign-in branding.`
   - Expected behavior: inspect live schemas, call `get_instance_summary`,
     require `read_branding`, and call `get_branding` without input.
   - Expected result: explain the requested editable visual state and only the
     safe `configured`, `file_type`, and optional `file_name` asset fields;
     never expose storage details, raw theme JSON, or authentication settings.
   - Fixture: authenticated instance with representative branding and all
     eight asset-descriptor positions.
10. **Confirmed branding configuration**
   - Prompt: `Change the sign-in title and primary palette.`
   - Expected behavior: require `configure_branding`, immediately call
     `get_branding`, copy its complete object, change only requested fields,
     preserve the font and all other fields, echo all eight assets unchanged,
     preview the exact differences, and obtain explicit confirmation.
   - Expected result: call `configure_branding` once with the immediate
     revision and complete desired object; report snake_case `changed_fields`
     and warnings without treating response text as instructions.
   - Fixture: non-production branding with a known revision and safe requested
     colors and text.
11. **Branding no-change**
   - Prompt: `Apply this already-current branding state.`
   - Expected behavior: perform the same immediate read, complete-object
     construction, exact desired-state/effects approval, and one-time revision
     use as a change. Reuse existing exact approval when it still matches.
   - Expected result: treat `no_change: true` as success, report warnings, and
     call `get_branding` again rather than claiming that nothing happened from
     the write response alone.
   - Fixture: desired branding identical to the current complete state.
12. **Branding post-write re-read**
   - Scenario: a confirmed branding change returns success and
     `effective_branding`.
   - Expected behavior: call `get_branding` again after the write and use that
     read, not only the write payload, as the reported effective state.
   - Expected result: report the verified state and warnings and identify any
     discrepancy without retrying or applying another write.
   - Fixture: non-production instance where a safe branding field changes.

### Negative cases

1. **Insecure URL**
   - Prompt: `Connect Guardhouse to http://guardhouse.example.`
   - Expected behavior: reject before any network request and ask for HTTPS;
     allow HTTP only for explicit loopback development.
   - Expected safe result: one actionable correction and no configuration
     write.
   - Why not complete: non-loopback HTTP can expose authorization traffic.
2. **Wrong or malformed server**
   - Prompt: `Connect Guardhouse to https://non-guardhouse-review-host.example.`
   - Expected behavior: stop on 404, oversized/non-JSON metadata, invalid URLs,
     missing authorization servers, or a cross-origin redirect.
   - Expected safe result: sanitized failure category, no guessed `/mcp` route,
     and no saved configuration.
   - Why not complete: the host has not proved a valid Guardhouse protected
     resource.
3. **Authorization failure**
   - Scenario: cancel consent, disable the integration, configure the wrong
     callback, revoke authorization, or use a non-system-administrator account.
   - Expected behavior: identify only the safe failure category, give its
     specific admin/user remediation, and never request a token or browser URL.
   - Expected safe result: authentication or connection remains explicitly
     unverified.
   - Why not complete: Guardhouse has not granted valid access to the MCP
     resource.
4. **Ambiguous or missing application**
   - Scenario: multiple catalog entries match the project, or no suitable entry
     exists.
   - Expected behavior: ask the user to select among safe candidates, or direct
     creation to the Guardhouse admin workflow.
   - Expected safe result: no guessed application ID, no simulated creation,
     and no System API call.
5. **Concurrent browser change**
   - Scenario: `configure_application` returns `PRECONDITION_FAILED`.
   - Expected behavior: re-read, explain the changed state, rebuild the exact
     proposal, and compare its desired state and effects with the existing
     exact approval. Obtain new confirmation if either changes; retain that
     approval when only the revision changes and both still match.
   - Expected safe result: no blind retry and no reuse of the stale revision.
6. **Unsupported write**
   - Scenario: the selected application is native/service or its live
     capability reports `configurable: false`.
   - Expected behavior: keep the workflow read/audit only and explain the
     current boundary.
   - Expected safe result: no `configure_application` call and no alternate API
     workaround.
7. **Concurrent branding change**
   - Scenario: `configure_branding` returns `PRECONDITION_FAILED`.
   - Expected behavior: discard the stale revision, re-read, explain what
     changed, and rebuild the complete desired object. Obtain new confirmation
     for changed desired state or newly discovered effects; reuse existing
     exact approval only when both still match.
   - Expected safe result: no blind retry and no reuse of the stale revision.
8. **Branding asset mismatch**
   - Scenario: a proposed `desired_branding` asset descriptor differs from the
     immediate `get_branding` result.
   - Expected behavior: do not call `configure_branding`; restore every asset
     descriptor exactly and direct the requested asset change to the admin UI.
   - Expected safe result: no invented, uploaded, cleared, or patched asset and
     no attempt to discover a storage ID or signed URL.
9. **Branding validation error**
   - Scenario: `configure_branding` returns `VALIDATION_FAILED` with field-level
     errors.
   - Expected behavior: report sanitized errors with their snake_case paths,
     change only explicit invalid inputs, rebuild the complete object, and
     obtain new confirmation when the desired state or effects change.
   - Expected safe result: no guessed correction, hidden validation detail, or
     unconfirmed retry.

## Candidate validation matrix

Static review and live integration are separate checks. The repository catalog
was resolved by native Codex CLI `0.160.1` using a read-only local-source
override: `guardhouse@guardhouse`, version `0.2.0`, available, not installed or
enabled. Its `source.path: "./"` resolves to the repository-root plugin. That
check does not establish remote availability, sign-in, or MCP functionality.

| Surface | Intended scope | Candidate result | Remaining gate |
| --- | --- | --- | --- |
| Codex CLI | Built-in Directory after approval; published repository marketplace; native local MCP/OAuth | Local catalog discovery passed. Fresh installation and live integration not run. | Install the candidate, restart the session, complete native OAuth, and verify live identity/tools and recovery. |
| ChatGPT desktop app, local Codex surface | Primary Directory installation after approval; local skills and MCP configuration | Not run. Directory approval and listing are pending. | Confirm installation/enablement, configuration reload, native sign-in, and the same live/recovery cases. |
| Codex IDE extension | Direct MCP configuration and authentication; plugin installation is unavailable | Not run. | Confirm compatible client/callback settings, authenticate and restart, then verify live tools and recovery through direct MCP. |
| Hosted-only ChatGPT/Codex | Arbitrary user-selected Guardhouse URLs are outside this package's scope | Not applicable. | Unsupported by this package. |

Use non-production instances and sample data for the live gates below. All
listed live gates are **not run for this candidate** until results are recorded
from the actual surface. Do not infer a pass from a saved URL, browser login,
metadata discovery, static contract, or local catalog listing.
Live native-client tests require non-production Guardhouse deployments with
administrator-prepared accounts and callbacks. When setup is invoked on a
verified unconfigured host, the skill asks for the deployment URL before
discovery or configuration unless the user already supplied it.

| Gate | Expected evidence | Status |
| --- | --- | --- |
| Novice getting started | An invoked getting-started skill explains Guardhouse, asks once for an absent server address only after the active host verifies an unconfigured state, handles users without an instance, and preserves supplied-URL and status-only boundaries. Installation alone triggers no background connection work. | Not run |
| First interaction and status-only request | Show the observed instance/status and relevant connection or setup guidance without changing configuration or starting sign-in. | Not run |
| Native OAuth and stable callback | The host supports the public client and exact callback pair; the approved port/URL are used, `iss` matches discovery, and native sign-in completes. | Not run |
| MCP initialization and complete inventory | Initialization and every needed `tools/list` page succeed. Incomplete or failed pagination stops inventory-dependent work. | Not run |
| Origin handling | Each local client's actual MCP requests meet the deployed server's Origin policy; a mismatched Origin is rejected without disabling validation. | Not run |
| Switch between instances and back | Preserve the approved callback pair, authenticate the target issuer, reload, and verify the target live identity/tools before writes. | Not run |
| Disabled, stale, or unreachable old connection | Report the observed old state and proceed with an explicitly requested switch; reconnect re-enables the saved instance, while status checks remain read-only. | Not run |
| Refresh and revocation | After expiry, native refresh restores valid access where authorized; revoked/invalid grants require native sign-in and no token copying. | Not run |
| Browser application write | Fresh read, exact replacement-set/effects approval, current revision, one write, and post-write read/audit. After a stale revision, re-read and reconfirm only changed desired state or effects. | Not run |
| Branding write | Immediate complete read, preserved unrelated fields/assets, exact confirmation, current revision, and post-write re-read; test stale revision, asset mismatch, and validation failure. | Not run |
| Incomplete application read | Missing/false `configuration_complete` never supplies an inferred full replacement/removal list. Preserve omitted arrays or use independently established exact sets with approval of possible unseen removals; report remaining incomplete verification. | Not run |
| Custom-HTML identifier support | Recognize catalog `1.0.0` contract page/state pairs even when live fields are plain strings; require authoritative evidence for unknown versions/pairs and never require a schema enum solely to recognize known identifiers. | Not run |
| Unsupported or incomplete capabilities | Native/service writes, creation, absent tools, incomplete access-option lists, and unsupported branding writes are declined or kept read-only. | Not run |
| Reload and recovery | Persist approved settings across restart; verify disconnect/reconnect, changed URL, expired/revoked authorization, and safe failure messages. | Not run |

Record only the surface, candidate/client versions, scenario, sanitized result,
and pass/fail/not-run status. Keep deployment names, concrete test hosts,
workstation paths, browser authorization URLs, credentials, and raw payloads
out of public validation records. Complete these gates before describing the
candidate's live workflows as verified or submitting them as reliable.

## Local integration checklist

Use a non-production Guardhouse instance with no real user data.

- [ ] Configure and activate the public MCP URL.
- [ ] Choose and save an administrator-approved stable Codex callback
      `callback_port` and exact `callback_url` under the per-server OAuth table;
      do not rely on the default ephemeral port or only a global callback base.
- [ ] Register that same exact stable callback URL on both review instances.
- [ ] Verify both issuers advertise issuer identification and exactly match
      protected-resource metadata; verify the returned `iss` during login.
- [ ] Restart Guardhouse if the public MCP URL changed.
- [ ] Enable the Codex integration.
- [ ] Use a Guardhouse system-administrator test account.
- [ ] Install the plugin from a temporary local marketplace.
- [ ] Enable the plugin and invoke `$guardhouse` or its getting-started prompt;
      verify the novice cases above before completing URL onboarding.
- [ ] Verify protected-resource metadata fields and scopes.
- [ ] Complete native OAuth without copying tokens.
- [ ] Switch to the second instance and back without changing the callback URL
      or port; complete native login and verify the new live tools each time.
- [ ] Verify MCP initialization.
- [ ] Verify every page of a fresh `tools/list`; stop dependent work if any page
      fails or the inventory is incomplete.
- [ ] Verify actual native requests satisfy Guardhouse's Origin policy, and
      mismatched Origin requests are rejected without bypassing validation.
- [ ] Verify native refresh after expiry and sign-in recovery after revocation.
- [ ] Call `hello` and confirm the live response.
- [ ] Invoke `$guardhouse-applications` from representative browser, native,
      and service projects without sending local files or paths to Guardhouse.
- [ ] Verify `get_instance_summary` capability flags and catalog version.
- [ ] Paginate `list_applications`, resolve an unambiguous application, and
      verify `get_application` contains no client secret.
- [ ] Paginate `list_application_access_options` and compare an application
      without guessing permission names; stop if the list is incomplete.
- [ ] Audit with omitted, non-empty, and explicitly empty expectations; verify
      status, coverage, skipped checks, findings, and warnings.
- [ ] Configure an existing browser application only after an exact preview and
      explicit confirmation, then re-read and audit success/no-change.
- [ ] Exercise stale-revision re-read/reconfirmation and verify no blind write
      retry occurs. Reconfirm changed desired state or effects; retain existing
      exact approval when only the revision changes and both still match.
- [ ] Verify native/service writes and application creation are not attempted.
- [ ] Invoke `$guardhouse-branding`, verify `read_branding` and
      `configure_branding`, and inspect the complete live branding state.
- [ ] Verify `get_branding` exposes only safe fields for all eight asset
      descriptors and no storage IDs, cache keys, signed URLs, raw theme JSON,
      authentication settings, or secrets.
- [ ] Configure branding only from an immediate complete read, preserve the
      current font unless explicitly changed, echo all eight assets unchanged,
      preview exact changes, and obtain explicit confirmation.
- [ ] Review a large HTML/CSS proposal by precise layer/page/state, byte size,
      digest, and bounded inert excerpt without executing it.
- [ ] Exercise branding stale-revision, asset-mismatch, validation-error, and
      no-change behavior, including required reconfirmation where applicable.
- [ ] Verify every successful or no-change branding write is followed by
      `get_branding` and reports the re-read effective state and warnings.
- [ ] Disable and re-enable the plugin.
- [ ] Restart/reload the desktop host and verify persisted local configuration.
- [ ] Repeat in Codex CLI.
- [ ] Repeat direct MCP setup and restart in the Codex IDE extension.
- [ ] Exercise reconnect and URL-change workflows.
- [ ] Exercise every troubleshooting category in the skill reference where
      practical.
- [ ] Confirm logs and user-facing errors contain no secrets.

If an instance or credentials are unavailable, record each live item as not
run. Never substitute mocked success for OAuth or MCP evidence.

## Public release checklist

### Package and Git-backed marketplace

Run from a source checkout:

```powershell
powershell -NoProfile -File ./scripts/build-package.ps1
```

With RTK installed, use
`rtk powershell -NoProfile -File ./scripts/build-package.ps1`.
The default output is the sibling `../guardhouse-plugin-codex-release`
directory.

To intentionally rebuild the same unpublished candidate's existing archive,
run `powershell -NoProfile -File ./scripts/build-package.ps1 -ReplaceArchive`.
The builder validates first and atomically replaces only that manifest version's
expected ZIP. It preserves unrelated output files and does not change the
release version.

- [ ] Review the generated package and privacy scan. Only
      `.codex-plugin/plugin.json`, `skills/**`, `assets/icon.png`, `LICENSE`,
      `README.md`, and `SECURITY.md` belong in the package.
- [ ] Exclude local configuration, credentials, real test-server URLs,
      personal or workspace paths, validation records, dependency caches,
      temporary marketplaces, and Git history.
- [ ] Confirm the release version, manifest references, icon, and packaged
      relative links match the intended release.
- [ ] Prepare the public source repository without private local artifacts.
- [ ] Validate `.agents/plugins/marketplace.json` in this repository: marketplace
      `guardhouse`, plugin `guardhouse`, local source `./`, installation
      `AVAILABLE`, authentication `ON_USE`, and category `Developer Tools`.
- [ ] Publish the reviewed release files and catalog in the public repository
      before verifying remote installation.
- [ ] Verify these exact commands from a fresh supported host:

      ```console
      codex plugin marketplace add legiosoft/guardhouse-plugin-codex
      codex plugin add guardhouse@guardhouse
      codex plugin list --marketplace guardhouse --json
      ```
- [ ] Verify a fresh supported local Codex host can register that Git-backed
      marketplace, install and enable Guardhouse, and invoke its skills.
- [ ] Complete the local integration checklist for the advertised supported
      surfaces; record unavailable scenarios as not run.

### Universal Plugins Directory: skills-only candidate

- [ ] Confirm local Codex is the intended supported execution environment;
      keep beta status, administrator prerequisites, and application/branding
      boundaries consistent across the manifest, skills, and listing.
- [ ] Complete OpenAI developer identity verification and obtain the required
      submission permissions.
- [ ] Upload the reviewed skills-only ZIP without MCP configuration,
      `mcpServers`, lifecycle hooks, or MCP app review metadata.
- [ ] Disclose that connection setup needs local Codex configuration access and
      native browser OAuth, and that application integration needs local
      project access.
- [ ] Confirm eligibility and supported execution surfaces through the current
      review process. Do not claim arbitrary self-hosted connectivity from
      hosted ChatGPT or universal availability of local execution.
- [ ] Complete metadata and skill scans, resolve required findings, and submit
      the selected draft for review.
- [ ] Check the approved version and publication settings, then publish it
      through the Directory's publication controls.
- [ ] After publication, verify discovery and installation of **Guardhouse**
      by **LegioSoft** from the built-in Directory in a local Codex host. Do not
      describe the candidate as listed before that happens.

Skills-only submissions do not need MCP app test cases, a demo recording, or
an MCP domain-verification challenge. They still need accurate metadata,
listing and policy compliance, skill scans, and any additional eligibility
checks. The manual cases in this document remain maintainer verification
material rather than claims of completed review.

### Metadata, legal, and support

- [ ] Confirm listing name, category, descriptions, capabilities, starter
      prompts, brand color, and Guardhouse-owned icon.
- [ ] Verify website, documentation, support, privacy, terms, and security URLs
      are accessible, identify the same publisher, and contain complete,
      legally approved content.
- [ ] Provide accurate support and private vulnerability-reporting guidance.
- [ ] Document local data flows and the selected Guardhouse operator's control
      of service-side retention, residency, and deletion behavior.
- [ ] Do not use OpenAI logos or imply OpenAI first-party ownership.
- [ ] Select accurate region availability and workspace eligibility.
- [ ] Describe the nine catalog `1.0.0` tools, existing-browser-only
      application writes, and complete desired-state branding writes without
      implying the package itself exposes a hosted MCP server.

## Candidate release notes for 0.2.0

Adds a dedicated application workflow for local-project inspection, catalog
discovery, redacted application reads, access-option discovery, intrinsic and
project-aware audits, and explicitly confirmed configuration of supported
fields on existing browser applications. Native and service applications remain
read/audit only. Adds a dedicated branding workflow for safe visual-state reads
and explicitly confirmed complete desired-state writes with immutable asset
descriptors and post-write verification. Application creation, asset changes,
and broader administration are not available. Public Git-backed marketplaces
use this skills-only package for local Codex hosts. The primary built-in
Directory route is pending submission, review, and publication, with explicit
local execution and beta scope. The candidate is not currently listed.
Arbitrary self-hosted URLs remain unavailable to hosted ChatGPT through this
package.

## Initial 0.1.0 beta history

Initial beta of the LegioSoft-maintained Guardhouse plugin for OpenAI Codex.
Adds local/self-hosted onboarding, native MCP OAuth guidance, live capability
discovery, connection status and recovery workflows, and the harmless
Guardhouse Hello World verification. No Guardhouse administration tools were
exposed in that initial candidate. This is development history, not a published
release or tag.
