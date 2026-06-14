# Language server

Jade ships a language server, run as `jade lsp`. It speaks LSP over stdio and
works in any editor with an LSP client.

## What it does

- **Diagnostics.** Type and parse errors are streamed to the editor as you type.
- **Hover.** Hover any name, local, or expression to see its inferred type.
- **Go to definition.** Jump from a use site to where a name is declared —
  across modules, into the stdlib, and to interface implementations.
- **Find references.** Every use of a name across the project, declaration
  included.
- **Document symbols.** The editor's outline ("show all functions in this
  file") works.

## Editor setup

The server is `jade lsp` on stdio. Point your editor's LSP client at it for
files matching `*.jd`.

### Neovim

```lua
-- Treat *.jd files as filetype "jd"
vim.filetype.add({ extension = { jd = 'jd' } })

vim.lsp.start({
  name = 'jade-lsp',
  cmd = { 'jade', 'lsp' },
  root_dir = vim.fs.dirname(vim.fs.find({ 'Gemfile', '.git' }, { upward = true })[1]),
  filetypes = { 'jd' },
})
```

### VS Code

No published extension yet. The server works with any LSP-client extension that
lets you point at a custom command (e.g. `vscode-languageclient` with a small
wrapper that runs `jade lsp`).

### Other editors

If your editor speaks LSP, it'll work — the server depends on no editor-specific
bridge.

## For agents that don't speak LSP

`jade q` exposes the same compiler intelligence as one-shot JSON over stdout —
handy for agents and scripts that don't want to manage a JSON-RPC session:

```
jade q hover    file.jd:LINE:COL   # type info at a position
jade q defn     file.jd:LINE:COL   # goto-definition target
jade q refs     file.jd:LINE:COL   # all references (incl. declaration)
jade q symbols  file.jd            # document outline
```

`LINE` and `COL` are 0-indexed (LSP convention). Paths are relative to the
project root; compile results are cached at `.jade/cache`, so repeat queries are
fast.

## What it doesn't do yet

- Autocomplete
- Refactor / rename
- Code actions (e.g. "add the missing case to this `case`")
- Workspace-wide symbol search

These are the natural next features; the current server is the minimum useful
surface.
