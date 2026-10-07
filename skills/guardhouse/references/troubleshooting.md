# Guardhouse connection troubleshooting

Use this reference only after sanitizing observations. Never expose tokens,
authorization codes, cookies, sensitive headers, full internal exception
payloads, or unreviewed raw server responses.

For every failure, state:

1. what step failed;
2. the safe evidence, such as status code, hostname, or error category;
3. one next action; and
4. what response will prove the problem is fixed.

## URL and network failures

| Failure | Safe diagnosis | Next action | Success evidence |
| --- | --- | --- | --- |
| Invalid or unsupported URL | The value is not an absolute HTTP(S) URI, contains credentials/query/fragment, or uses a path other than `/` or `/mcp`. | Ask for the Guardhouse deployment root or full `/mcp` URL. | Protected-resource metadata passes the resource, authorization-server, scope, and URL checks. |
| Insecure HTTP URL | Non-loopback HTTP can expose authorization traffic. | Require HTTPS. Allow HTTP only for `localhost`, `127.0.0.0/8`, or `[::1]` in an explicit development setup. | The validated URL uses HTTPS or an allowed loopback exception. |
| DNS failure | The hostname cannot be resolved from this machine. | Ask the user to check the hostname, VPN, split DNS, or hosts configuration. | DNS resolves and the metadata endpoint is reachable. |
| Connection refused/unreachable | The host resolved but no service accepted the connection. | Check Guardhouse service health, port, firewall, reverse proxy, and VPN. | An HTTPS response arrives from the metadata endpoint. |
| TLS/certificate failure | The certificate is expired, untrusted, mismatched, or the TLS handshake failed. | Fix the server certificate or install the organization's trusted CA through normal system administration. Never disable certificate validation. | A verified TLS connection succeeds. |
| Timeout | DNS, TLS, metadata, OAuth, initialization, or a tool call exceeded its limit. | Identify the timed-out stage, retry once, then check network and server health. Do not keep retrying indefinitely. | The same stage completes within the configured timeout. |

## Discovery and protocol failures

| Failure | Safe diagnosis | Next action | Success evidence |
| --- | --- | --- | --- |
| Wrong route or HTTP 404 | The protected-resource metadata path or advertised MCP resource is not served. | Request `/.well-known/oauth-protected-resource/mcp` on the supplied authority. Use its `resource`; do not guess another route. Ask the Guardhouse admin to verify the public MCP URL and reverse-proxy routing. | Metadata succeeds and the advertised `/mcp` URL responds to MCP initialization. |
| OAuth discovery failure | The protected-resource metadata is missing a valid authorization server, or the issuer's OAuth/OIDC metadata is unavailable or inconsistent. | Ask the Guardhouse admin to verify issuer/public URL configuration and well-known endpoints. | Codex native login discovers an authorization endpoint and begins browser sign-in. |
| Malformed server response | JSON is invalid, oversized, has the wrong content type, or required fields have invalid types/URLs. | Stop without saving the URL. Ask the admin to inspect the reverse proxy and Guardhouse version. | A bounded JSON response passes all metadata checks. |
| Incompatible MCP response | Initialization or `tools/list` is not valid for the MCP protocol expected by the current Codex client. | Record only protocol version, safe status, and sanitized error category; upgrade the older side or check proxy response transformation. | MCP initialization and `tools/list` both return valid protocol responses. |
| Connected with no tools | Initialization succeeded but `tools/list` is empty. | Report the state accurately. Ask the admin to verify the Guardhouse integration/version; do not invent capabilities. | A fresh `tools/list` returns at least one advertised tool. |
| Host inspection unavailable | The current session exposes neither MCP status nor live Guardhouse tools. This does not prove the server is disconnected. | Make no change. Ask the user to check `codex mcp list`, `/mcp`, or the desktop/IDE MCP settings view. | A supported host surface reports configuration and initialization state. |

## Guardhouse and OAuth failures

| Failure | Safe diagnosis | Next action | Success evidence |
| --- | --- | --- | --- |
| Integration disabled | Guardhouse rejects authorization, token exchange, or MCP access because the Codex integration is off or an MCP URL change is pending restart. | Ask a Guardhouse superadministrator to configure the public URL and callback, restart if required, then enable Codex. | Native login completes and MCP initialization is authorized. |
| Client registration failure | Codex attempted dynamic registration instead of using Guardhouse's pre-registered `guardhouse_codex` public client. | Confirm the current Codex build exposes `--oauth-client-id`, then set `[mcp_servers.guardhouse.oauth] client_id = "guardhouse_codex"` and retry native login. If that supported option is unavailable, update Codex. Do not implement custom OAuth. | Native login reaches Guardhouse browser sign-in without a dynamic-registration error. |
| Login cancelled or access denied | The user cancelled consent, denied access, or Guardhouse rejected the account. | Ask whether they want to retry. If denied, confirm they are signing in with a Guardhouse system-administrator account. | The browser returns a successful native OAuth callback. |
| OAuth callback failure | The stable redirect URI does not exactly match the one configured in Guardhouse, the listener port is mismatched or unavailable, or the callback was blocked. | Configure the approved matching `callback_port` and exact `callback_url` under `[mcp_servers.guardhouse.oauth]`, then register that same stable URL on every connected instance. Preserve the pair when switching. Show only the non-secret redirect URI; never share the full authorization URL or code. Check local firewall and browser handoff. | Codex receives the callback and completes token exchange. |
| Instance-specific callback generated | The host retained legacy callback settings, has not loaded the explicit per-server callback, or cannot verify issuer identification. | Confirm the exact per-server callback pair is saved and loaded, and discovery advertises `authorization_response_iss_parameter_supported: true` with the exact expected issuer. Update an incompatible host or deployment; do not register a new callback per instance. Use native authorization controls if a fresh login is needed, without inspecting credentials. | Login uses the same exact registered callback after switching MCP URLs. |
| Authorization response issuer mismatch | The server advertised issuer identification but the callback omitted `iss` or returned a different issuer. | Have the administrator correct the metadata and redirect responses so `iss`, discovery `issuer`, and the selected protected-resource `authorization_servers` value match exactly. Do not bypass issuer validation. | Codex validates the returned issuer and completes native token exchange. |
| Expired or revoked authorization | A previously working connection now receives an authorization failure. | Run native MCP login again. If Guardhouse's public MCP URL changed, have an admin complete restart/re-enable first. | Login succeeds and a fresh `tools/list` is authorized. |
| Insufficient Guardhouse permissions | Login succeeds or reaches consent, but the account cannot authorize/call MCP. | Use a Guardhouse system-administrator account or ask an administrator to review access. Do not suggest bypassing authorization. | The signed-in account completes consent and `tools/list` succeeds. |

## Safe diagnostics

- Prefer hostname, route, status code, timing, TLS category, and MCP phase.
- Redact query strings even though valid Guardhouse URLs should not contain one.
- Do not display request or response authorization headers.
- Do not dump discovery, token, callback, or MCP bodies without first selecting
  known non-secret fields.
- Do not turn off TLS checks, origin checks, PKCE, consent, or permission checks.
- Do not ask the user to paste browser URLs because they can contain
  authorization codes.
- A configuration write proves only that configuration changed. A browser
  callback proves only that login returned. Connection success requires MCP
  initialization plus a valid `tools/list`.
