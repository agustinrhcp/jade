# Jade

[![CircleCI](https://dl.circleci.com/status-badge/img/gh/agustinrhcp/jade/tree/master.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/gh/agustinrhcp/jade/tree/master)

A functional, type-safe language that compiles to readable Ruby. Inspired by Elm.

## What it looks like

```jade
def greet(user: Maybe(User)) -> String
  case user
  in Just(u) then "Hello, " ++ u.name
  in Nothing then "Hello, stranger"
  end
end
```

compiles to:

```ruby
def greet(user)
  case user
  in Jade::Maybe::Just(u) then "Hello, " + u.name
  in Jade::Maybe::Nothing then "Hello, stranger"
  end
end
```

No runtime VM. No FFI. The compiled output is Ruby you'd write yourself.

## Will my agents work?

Yes. Claude Code, Cursor, and friends handle Jade well out of the box — the syntax is close enough to ML-family languages (Elm, OCaml, Haskell) that models have strong priors about it, and the generated Ruby gives them a second source of truth to check their work against.

Even better with the LSP: the same type errors, inferred types, and jump-to-definition the editor uses are visible to your agent. For agents that don't speak LSP, `bin/jade-q` exposes the same compiler intelligence as one-shot JSON queries — hover, defn, refs, symbols. Worth wiring up if you're leaning on agents heavily. See [docs/lsp.md](docs/lsp.md).

## Why

**No more `nil` checks scattered through every method.** Jade has `Maybe(a)` and the compiler tells you when you forgot the empty case. Same for `Result` — errors are values, not exceptions hidden three layers deep.

**Union types and exhaustive pattern matching.** Model your domain precisely. When you add a case, every match site that needs updating becomes a compile error, not a 2am Sentry alert.

**Faster feedback.** The type checker catches a wide class of bugs before you've left the editor. Type errors inline, jump-to-definition, hover for inferred types, autocomplete that knows what you mean. Works in any editor that speaks LSP.

## Side-effect-free testing by default

This is the one that changes how you work day-to-day.

Jade functions are pure by default. IO lives in `Task`, in explicit `uses` blocks, at the edges of your program. Everything in the middle — the actual business logic — is just functions over values.

The bulk of your test suite stops needing mocks. You pass in data, you assert on the return value. Tests run in milliseconds and read like the spec they're testing. When you do need to stub a `Task` at a boundary, the API for that lives in [docs/testing.md](docs/testing.md) — but it's one place at the edge, not 30 lines deep in a unit test.

The boundary between "logic" and "IO" stops being a convention you try to maintain and becomes something the compiler enforces.

## Without losing the Ruby ecosystem

Jade isn't trying to replace Ruby — it's a better way to author it. Existing Ruby calls into Jade, Jade calls into Ruby. Gems work. Rails works. The details are their own conversation: see [docs/interop.md](docs/interop.md).

## Performance

Compiled Jade is consistent. The same source produces the same Ruby every time — no JIT-style spookiness, no behaviour-dependent fast paths, no hidden dispatch tables. You can read what runs.

In practice that lands a little faster than the Ruby most people write under deadline pressure, because the codegen takes time to think about shapes a human author wouldn't bother with — flat method dispatch, inlined intrinsics, YJIT-friendly record layouts. There are no published benchmarks; this isn't selling a speedup. The point is that the abstraction is roughly free.

## If it doesn't work out

You leave. Run the compiler one last time, commit the `.rb`, drop the `.jd`. No lock-in, no rewrite, no migration. The `jade-eject` skill mechanises the gem-removal step, but the output is already plain Ruby you can ship without it.

Worst case: "I wrote Ruby with a nicer authoring layer for a while."

## Install

Jade isn't on RubyGems yet — install from a local path or a git ref:

```ruby
# Gemfile
gem 'jade', path: '/path/to/jade'
# or:
# gem 'jade', git: 'https://github.com/agustinrhcp/jade'
```

```ruby
require 'jade'

Jade.setup do |config|
  config.source_root = 'src'
  config.build_dir   = '.jade'
end

Jade.require('my_module')

MyModule.my_function('hello')
```

## Status

What works: full type checker with inference, pattern matching with completeness checks, generic ports, `Decode` / `Encode` with auto-derivation for structs, `Decode.Params` for partial inputs, language server (hover, goto-definition, find-references, diagnostics, document symbols), pretty-printed Ruby codegen with stdlib operations compiled inline, tail-recursive functions compiled to loops, JSON in / JSON out end-to-end.

What doesn't yet: partial record types in user signatures, ranges, automatic `Comparable` / `Show` for user types *(in progress)*, Elm encoder generation for full-stack projects *(in design)*.

Not great for: throwaway scripts, libraries you ship to other Ruby projects (they'd inherit the gem dependency), performance-critical hot paths (output is YJIT-friendly but unbenchmarked).

## Docs

- [docs/syntax.md](docs/syntax.md) — language reference
- [docs/interop.md](docs/interop.md) — Ruby ↔ Jade boundary, ports, decoding
- [docs/testing.md](docs/testing.md) — stubbing API and RSpec matchers
- [docs/stdlib.md](docs/stdlib.md) — module-by-module breakdown
- [docs/lsp.md](docs/lsp.md) — language server setup
- [examples/](examples/) — runnable `.jd` files
