# Jade

[![CI](https://github.com/agustinrhcp/jade/actions/workflows/ci.yml/badge.svg)](https://github.com/agustinrhcp/jade/actions/workflows/ci.yml)

A statically typed, functional language that compiles to readable Ruby.
Inspired by Elm. Type inference, union types, exhaustive pattern matching, and
typed boundaries to Ruby.

**[agustinrhcp.github.io/jade](https://agustinrhcp.github.io/jade/)** — the
pitch, and a [tour](https://agustinrhcp.github.io/jade/tour.html) whose
examples compile and run in the browser.

## What it looks like

```jade
module Greeter exposing (greet)

def greet(name: Maybe(String)) -> String
  case name
  in Just(n) then "Hello, " ++ n
  in Nothing then "Hello, stranger"
  end
end
```

compiles to:

```ruby
module Greeter
  extend self

  module Internal
    extend self

    def greet(name)
      case name
      in Jade::Maybe::Just(n) then ("Hello, " + n)
      in Jade::Maybe::Nothing then "Hello, stranger"
      end
    end
  end

  def self.greet(name)
    Internal.greet(decode(name))
  end
end
```

There's no runtime VM and no FFI. The pure logic lives in `Internal`; the public
`Greeter.greet` decodes the untrusted Ruby argument (`nil`-or-`String`) into a
`Maybe` before handing it to the typed core:

```ruby
Greeter.greet("Ada")   # => "Hello, Ada"
Greeter.greet(nil)     # => "Hello, stranger"
```

## Getting started

```ruby
# Gemfile
gem 'jade-lang'
```

Point it at your source, then `require` modules by name. Each `.jd` compiles to
`.jade/build/<module>.rb` on first require, and only when the source is newer:

```ruby
require 'jade'

Jade.setup do |config|
  config.source_root = 'src'
end

Jade.require('greeter')

Greeter.greet('Ada')   # => "Hello, Ada"
```

Tools that run outside your app — `jade check`, the language server — read a
`jade.json` at the project root instead:

```json
{ "source_roots": ["src"] }
```

It's plain Ruby on disk, so it sits inside a Rails app like any other file.

## If it doesn't work out

Run the compiler one last time, commit the generated `.rb`, and drop the `.jd`
files. The output is already plain Ruby — no rewrite, no migration.

Worst case: you wrote Ruby with a nicer authoring layer for a while.

## Tooling

```
jade check [file...]      # type-check; exits 1 on errors, generates nothing
jade fmt [-i|-c] [file]   # format .jd source (stdin or file)
jade lsp                  # language server over stdio
jade q hover FILE:L:C     # headless JSON queries — hover/symbols/defn/refs
jade q api List.fold      # stdlib signatures, read from the registry
```

`jade fmt` is deterministic and idempotent; wire it into your editor or a
pre-commit hook. For tools that don't speak LSP, `jade q` answers the same
questions as one-shot JSON — which is also what makes coding agents workable
here, along with the generated Ruby giving them a second source of truth.

## Standard library

`Basics`, `String`, `Char`, `List`, `Dict`, `Set`, `Tuple`, `Maybe`, `Result`,
`Task`, `Decode`, `Encode`, `Bytes`, `Calendar`, `Clock`, `Decimal`, `Show`,
`Debug`. Stdlib operations compile inline rather than through a runtime
dispatch layer.

## Docs

- [the tour](https://agustinrhcp.github.io/jade/tour.html) — the language, with a console
- [docs/syntax.md](docs/syntax.md) — the full syntax reference
- [docs/interop.md](docs/interop.md) — the Ruby boundary: ports, decoding, what crosses
- [docs/json.md](docs/json.md) — `Decode` / `Encode`, by hand and auto-derived
- [docs/testing.md](docs/testing.md) — stubbing Tasks, the RSpec matchers
- [docs/stdlib.md](docs/stdlib.md) — module-by-module map
- [docs/lsp.md](docs/lsp.md) — language server and `jade q` setup
- [examples/](examples/) — runnable `.jd` files

## Status

Early and experimental — being tried out on small projects.

**In progress:** `Comparable` derivation for user types, partial record types
in signatures, a stable REPL.

**Not great for:** throwaway scripts, libraries you ship to other Ruby
projects (they'd inherit the dependency), and performance-critical hot paths
(output is YJIT-friendly but unbenchmarked).

## License

[MIT](LICENSE).
