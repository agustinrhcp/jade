# Language server

Jade ships with an LSP server: `bin/jade-lsp`. It speaks LSP over stdio and works in any editor with an LSP client.

## What it does

- **Diagnostics.** Type errors and parse errors are streamed to the editor as you type.
- **Hover.** Hover any name, local, or expression to see its inferred type.
- **Go to definition.** Jump from a use site to where a name is declared — including across modules, into the stdlib, and to interface implementations.
- **Find references.** Every use of a name across the project, with the declaration included.
- **Document symbols.** The editor's symbol outline ("show all functions in this file") works.

## Editor setup

The server is just `bin/jade-lsp` on stdio. Point your editor's LSP client at it for files matching `*.jd`.

### Neovim

```lua
vim.lsp.start({
  name = 'jade-lsp',
  cmd = { '/path/to/jade/bin/jade-lsp' },
  root_dir = vim.fs.dirname(vim.fs.find({ 'Gemfile', '.git' }, { upward = true })[1]),
  filetypes = { 'jade' },
})
```

### VS Code

No published extension yet. The server works with any LSP-client extension that lets you point at a custom binary (e.g. `vscode-languageclient` with a tiny wrapper).

### Other editors

If your editor speaks LSP, it'll work — the server doesn't depend on any editor-specific bridge.

## For AI agents that don't speak LSP

There's a headless companion tool: `bin/jade-q`. It exposes the same compiler intelligence as the LSP, but as one-shot JSON over stdout — useful for agents and scripts that don't want to manage a JSON-RPC session.

```
jade-q hover    file.jd:LINE:COL   # type info at a position
jade-q defn     file.jd:LINE:COL   # goto-definition target
jade-q refs     file.jd:LINE:COL   # all references (incl. declaration)
jade-q symbols  file.jd             # document outline
```

`LINE` and `COL` are 0-indexed (LSP convention). Compile results are cached at `.jade/cache`, so repeat queries are fast.

This is the recommended path for Claude Code, Cursor, and similar agents — they get the same signal an editor would, without an LSP client.

## What it doesn't do yet

- Autocomplete suggestions
- Refactor / rename
- Code actions (e.g., "add missing case to this `case`")
- Workspace-wide symbol search

These are the natural next features. The current server is the minimum useful surface.
