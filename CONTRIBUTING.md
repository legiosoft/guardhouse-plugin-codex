# Contributing

Thank you for helping improve the official Guardhouse plugin for OpenAI Codex.

## Scope

Keep the plugin small and declarative. Prefer manifest configuration and concise
skills over executable code. Do not:

- duplicate Codex's MCP or OAuth client;
- add an HTTP/REST wrapper or generic action dispatcher around Guardhouse;
- add a custom token store;
- invent Guardhouse tools or server routes;
- add `.mcp.json` until a fixed hosted endpoint is approved;
- add dependencies without a demonstrated requirement; or
- include secrets, credentials, tenant data, or private server responses.

Keep this public repository independent of a developer's machine and test
deployment. Use reserved `.example` domains and generic relative paths in
examples. Never copy personal Codex configuration, test-server URLs, absolute
workstation paths, downloaded runtimes, dependency caches, or validation
records into the repository. Run local experiments outside the plugin tree.

Backend changes belong in the Guardhouse server repository and require separate
approval.

## Make a change

1. Create a focused branch.
2. Follow every applicable `AGENTS.md`.
3. Keep plugin identifier `guardhouse` and product terminology consistent.
4. Update documentation and `CHANGELOG.md` when behavior changes.
5. Validate every affected skill, the manifest, JSON, YAML, and internal links.
6. Exercise relevant manual cases without using production secrets.
7. Build the release ZIP with `scripts/build-package.ps1`. Its explicit
   file list excludes development tooling and local artifacts; `.gitignore`
   alone does not control what the local plugin installer copies.
8. Open a focused pull request describing the behavior and validation.

Do not add a unit-test project or test framework for this declarative package.
Use the official Codex plugin tooling and the manual integration checklist in
[docs/publication-readiness.md](docs/publication-readiness.md).

## Writing

Use clear language, ask one actionable question at a time, and distinguish a
configuration change from a verified MCP response. Keep error examples
sanitized. State the current capability boundary accurately: browser, native,
and service applications are readable/auditable; only existing browser
applications support bounded confirmed application writes. Visual branding is
readable and supports complete desired-state writes when its live capabilities
allow them; branding assets remain admin-UI-only. Do not claim application
creation, registration settings, email templates, roles, native/service writes,
deletion, or secret rotation.

By contributing, you agree that your contribution is licensed under
Apache-2.0.
