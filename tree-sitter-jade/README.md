# tree-sitter-jade

Tree-sitter grammar for the Jade programming language.

## Helix setup

Symlink the queries so changes are picked up automatically on restart:

```sh
GRAMMAR_DIR=$(pwd)
QUERIES_DIR=~/.config/helix/runtime/queries/jade

mkdir -p "$QUERIES_DIR"
ln -s "$GRAMMAR_DIR/queries/highlights.scm" "$QUERIES_DIR/highlights.scm"
ln -s "$GRAMMAR_DIR/queries/locals.scm"     "$QUERIES_DIR/locals.scm"
```
