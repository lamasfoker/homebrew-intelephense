# homebrew-intelephense

Unofficial Homebrew tap for [Intelephense](https://intelephense.com), the PHP language server.

Installed with a **private, vendored Node.js runtime** — it never touches any Node.js you have
on `PATH` (system, nvm, volta, etc). `brew uninstall` removes it all cleanly.

## Install

```sh
brew tap lamasfoker/intelephense
brew install intelephense
```

## Usage

`intelephense` is a language server, not an interactive CLI. Point your editor's LSP client at
it; it runs over stdio, node-ipc, a socket, or a named pipe:

```sh
intelephense --stdio
intelephense --node-ipc
intelephense --socket=<port>
intelephense --pipe=<name>
```

See [intelephense-docs](https://github.com/bmewburn/intelephense-docs) for editor-specific setup
and configuration options.

## Updates

`.github/workflows/update.yml` checks npm for new intelephense releases weekly (and can be run
manually via `gh workflow run update.yml`), rebuilds and tests the formula, and opens a
self-merging PR when the build passes. It also keeps the vendored Node.js runtime pinned to the
current LTS release.
