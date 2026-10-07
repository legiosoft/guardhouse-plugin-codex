# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased — 0.2.0 candidate

### Added

- Add the repository-root `guardhouse` marketplace catalog for public Git
  distribution without a self-referencing Git fetch.
- Add public Git marketplace installation commands and a CLI/desktop/IDE
  support and validation matrix.
- Add `$guardhouse` installation and upgrade guidance, including marketplace
  refresh, installation-status checks, and new-chat/reload instructions.
  Preserve an existing installation's source and keep plugin management
  separate from Guardhouse instance setup and sign-in.
- Add the `guardhouse-applications` skill for local-project inspection,
  application discovery, redacted configuration reads, access-option
  discovery, intrinsic/project-aware audits, and supported existing-browser
  configuration.
- Add the `guardhouse-branding` skill for live visual-branding inspection,
  exact confirmed desired-state configuration, immutable asset handling,
  supported custom HTML/CSS identifiers, and post-write verification.
- Expand the compact catalog `1.0.0` contract references to cover all nine live
  MCP tools, the common snake_case response envelope, application replacement
  sets, branding desired-state writes, capability flags, concurrency, warnings,
  and remediation.

### Changed

- Distribute through the public GitHub repository's Codex marketplace, with
  install and update commands at the start of the README.
- Document explicit `-ReplaceArchive` rebuilding of the same unpublished
  candidate after validation, with atomic replacement of only the expected
  ZIP and no automatic release-version changes.
- Explain Guardhouse at first use for unconfigured users, outline the required
  server address, administrator account, and browser sign-in, and guide the
  next step by asking for their Guardhouse instance URL.
- Add optional connection onboarding, support, release-note, and Codex-product
  metadata; identify beta/local scope and administrator prerequisites in the
  listing while retaining a skills-only package without bundled MCP
  configuration or lifecycle hooks.
- Build the skills-only release ZIP from allowlisted resources, with
  public metadata, source, and archive validation.
- Start connection, application, and branding workflows with the current
  instance and evidence-based connection status, followed by disconnect,
  reconnect, and switch guidance. Verify the live instance after switching,
  preserve saved settings on disconnect, and re-enable them on reconnect.
- Separate MCP connection and OAuth work from application workflows while
  preserving live tool discovery through the existing `$guardhouse` skill.
- Route visual-appearance work from `$guardhouse` and
  `$guardhouse-applications` to `$guardhouse-branding` without duplicating its
  workflow.
- Update plugin metadata, starter prompts, documentation, and publication
  readiness for the application catalog, audit, access, browser configuration,
  and branding read/write capabilities.

### Security

- Require an immediate application read, exact desired-state/effects preview,
  approval covering known and possible unseen removals, and revision check
  before the destructive browser configuration tool is called.
- Keep local files, source code, filesystem paths, tokens, and secrets out of
  Guardhouse calls; send only explicit structured configuration values and
  treat every returned text value as untrusted data.
- Require an immediate branding read, an exact change preview, explicit
  confirmation, one-time revision use, unchanged asset descriptors, and a
  post-write read before reporting effective branding.

### Fixed

- Treat false or missing `configuration_complete` as an incomplete read. Never
  derive replacement sets or full removal lists from partial values; require
  independently established exact replacements and approval of possible
  unseen removals, or preserve omitted arrays and direct repair to the admin.
- Recognize supported catalog `1.0.0` custom-HTML page/state identifiers even
  when live schema fields use plain strings; validate unknown pairs/versions
  against authoritative evidence without requiring identifier enums.
- After stale-revision re-reads, retain existing exact desired-state/effects
  approval when only the revision changes; reconfirm changed state or newly
  discovered effects and never reuse the stale revision.
- Bring starter prompts and listing text within current public metadata
  limits, distinguish optional metadata from required fields, and remove
  installation placeholders and links that implied unpublished release tags.
- Configure Codex's supported fixed MCP OAuth client ID so Guardhouse native
  login uses the pre-registered `guardhouse_codex` public client instead of
  attempting dynamic client registration.
- Use one explicit per-server Codex OAuth callback URL and matching fixed
  listener port across Guardhouse instances, with issuer-identification
  discovery checks, instead of deriving a new callback for each MCP URL.
- Check host support for all three per-server OAuth settings (`client_id`,
  `callback_port`, and `callback_url`) before editing configuration; preserve
  an existing administrator-approved callback pair during reconnect/switch.

## 0.1.0 — initial beta history

### Added

- Initial LegioSoft-maintained Guardhouse plugin manifest for OpenAI Codex.
- Local/self-hosted setup, native OAuth, status, reconnect, URL change,
  sign-in, disconnect, and troubleshooting workflows.
- Live MCP capability discovery and the Hello World verification flow.
- Guardhouse-owned branding and publication-readiness documentation.

### Security

- URL validation, HTTPS enforcement outside loopback development, bounded
  metadata discovery, secret-safe diagnostics, and confirmation requirements
  for future destructive or security-sensitive tools.

### Known limitations

- At that development stage, the Guardhouse MCP server exposed only `hello`.
- Hosted ChatGPT cannot use arbitrary per-user Guardhouse MCP URLs; no hosted
  MCP definition is included.
