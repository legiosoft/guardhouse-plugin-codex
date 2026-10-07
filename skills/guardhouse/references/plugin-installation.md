# Install and upgrade the Guardhouse Codex plugin

Use this guide for the plugin package, not for upgrading a Guardhouse server or
changing its connection. Install and upgrade help requires no Guardhouse server
address, account, MCP discovery, callback configuration, or browser sign-in.

## Explain or perform the requested action

For "How do I install/upgrade?", give the relevant commands and next step.
Do not run an installation, fetch updates, or change configuration merely to
answer that question. For an explicit install or upgrade request, use Codex's
native plugin commands when available and proceed within that authorization.
Check the installed CLI's help before executing commands. If plugin commands
are unavailable, explain that a compatible Codex CLI is needed; do not invent
commands or add a custom updater.

For an upgrade action, establish the installed plugin ID and marketplace source
through safe plugin metadata from the active host/profile:

```console
codex plugin list --json
codex plugin marketplace list --json
```

Inspect only the relevant plugin/source/version fields. Do not print entire
configuration files or inspect credentials. An empty result from another
profile does not prove the user's active installation is absent. If its source
cannot be established, give instructions or clarify the installation route
before changing it.

## Install from the public GitHub repository

With a compatible Codex CLI installed, run:

```console
codex plugin marketplace add legiosoft/guardhouse-plugin-codex
codex plugin add guardhouse@guardhouse
codex plugin list --marketplace guardhouse --json
```

The repository's catalog is named `guardhouse`, and the plugin is
`guardhouse@guardhouse`. Codex downloads the repository and installs its plugin
files. OpenAI publisher verification or public Plugins Directory review is not
required for this Git-backed route. Managed workspace policies may restrict
installation sources; respect those policies.

If a marketplace named `guardhouse` already points somewhere else, explain the
conflict before replacing it. Use the repository's default branch unless the
user explicitly selects a published branch, tag, or commit with `--ref`. Do
not invent a release tag or use sparse paths that omit the plugin resources.

Verify the list result identifies the expected source and reports the plugin
as installed and enabled. Start a new Codex chat or reload the local desktop
host so it loads the installed skills, then ask:

```text
$guardhouse Help me get started with Guardhouse.
```

Installation makes the skills available. Connecting to a Guardhouse instance
is a subsequent request; installation alone does not authorize it. The IDE
extension uses direct MCP configuration rather than this plugin installation.

## Upgrade an existing public Git installation

For `guardhouse@guardhouse` installed from the repository above, run:

```console
codex plugin marketplace upgrade guardhouse
codex plugin add guardhouse@guardhouse
codex plugin list --marketplace guardhouse --json
```

The first command refreshes the Git marketplace checkout. The second installs
or refreshes the selected plugin from that checkout. Verify the resulting
installed version and source before reporting success. A pinned tag or commit
stays selected until the user chooses another ref; refreshing does not switch
it to the default branch.

Start a new chat or reload the desktop host to use the updated instructions.
Do not claim that the current chat has already reloaded its skill context or
promise automatic background updates for individual Git installations.
If a command fails, report the safe failure and the next corrective action;
do not report success from a repository fetch alone.

## Local development or another installation source

Use the observed marketplace name and source. A local copy such as
`guardhouse@guardhouse-local` needs its maintainer to rebuild or refresh the
clean package at that marketplace's plugin path, then reinstall from that
same marketplace and reload the host. Git marketplace upgrade does not rebuild
a local package. Do not silently migrate a local, workspace-managed, or other
installation to the public Git source or install a duplicate plugin.

Package maintenance does not require changing the Guardhouse MCP server table,
callback, authorization, or selected instance. Keep those connection settings
outside the install/upgrade workflow.

See the official
[marketplace commands](https://learn.chatgpt.com/docs/developer-commands#codex-plugin-marketplace)
and [Git-backed package guide](https://developers.openai.com/plugins/build/plugins#add-a-marketplace-from-the-cli).
