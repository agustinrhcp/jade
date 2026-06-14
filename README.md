# Jade

[![CI](https://github.com/agustinrhcp/jade/actions/workflows/ci.yml/badge.svg)](https://github.com/agustinrhcp/jade/actions/workflows/ci.yml)

A statically typed, functional language that compiles to readable Ruby.
Inspired by Elm. Type inference, union types, exhaustive pattern matching, and
typed boundaries to Ruby.

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
    # validate the incoming Ruby value, then call the pure function
    Internal.greet(decode(name))
  end
end
```

There's no runtime VM and no FFI. The pure logic lives in `Internal`; the public
`Greeter.greet` decodes the untrusted Ruby argument (`nil`-or-`String`) into a
`Maybe` before handing it to the typed core. Calling it from Ruby:

```ruby
Greeter.greet("Ada")   # => "Hello, Ada"
Greeter.greet(nil)     # => "Hello, stranger"
```

## Features

**`Maybe` instead of `nil`.** `Maybe(a)` makes absence explicit, and the
compiler flags any `case` that forgets the `Nothing` branch. Errors are values
too:

```jade
module Accounts exposing (withdraw)

def withdraw(balance: Int, amount: Int) -> Result(Int, String)
  amount > balance ? Err("insufficient funds") : Ok(balance - amount)
end
```

**Union types and exhaustive pattern matching.** Add a variant and every
`case` that needs a new branch becomes a compile error:

```jade
module Shapes exposing (area_of)

type Shape
  = Circle(Float)
  | Rectangle(Float, Float)


def area_of(shape: Shape) -> Float
  case shape
  in Circle(r) then 3.14 * r * r
  in Rectangle(w, h) then w * h
  end
end
```

**Records with structural update and field access:**

```jade
module Users exposing (birthday, name_of)

struct User = {
  name: String,
  age: Int
}


def birthday(user: User) -> User
  { user | age: user.age + 1 }
end


def name_of(user: User) -> String
  user.name
end
```

**Pipes.** `|>` passes a value into the next function:

```jade
module Pipeline exposing (shout)

def shout(words: List(String)) -> String
  words
    |> List.map(String.to_upper)
    |> String.join(" ")
end
```

Everything above is inferred end to end — annotations on `def` signatures are
checked, not required internally.

## More of the language

**Lambdas and currying.** Lambdas are `(params) -> { body }`. A `_` in an
argument position curries that call — each `_` becomes a parameter, left to
right, so `discount(10, _)` is a one-argument function:

```jade
module Pricing exposing (net)

def discount(rate: Int, price: Int) -> Int
  price - price * rate / 100
end


def net(prices: List(Int)) -> List(Int)
  prices
    |> List.map(discount(10, _))
    |> List.filter((p) -> { p > 50 })
end
```

**Interfaces.** `==` / `!=` (Eq), `compare` (Comparable — returns `LT` / `EQ` /
`GT`), and `++` (Appendable) are built in and resolve from the argument types
at compile time, no annotation needed. You can define your own, with
implementations dispatched by type:

```jade
module Shows exposing (describe)

struct Person = {
  name: String,
  age: Int
}


interface Show(a) with
  show : a -> String
end


implements Show(Person) with
  show: (p) -> { p.name ++ " (" ++ String.from_int(p.age) ++ ")" }
end


def describe(p: Person) -> String
  show(p)
end
```

**Modules and imports.** One module per file; `exposing` lists the public
surface. Pull names in by module, or selectively:

```jade
module App exposing (run)

import Mathx exposing (double)


def run(n: Int) -> Int
  double(n) + 1
end
```

## JSON

`Decode.from_json` derives a decoder from the return type and `Encode.encode`
derives the encoder, so a struct round-trips without a hand-written decoder or
encoder. A missing field comes back as an `Err`, not a `nil`:

```jade
module Api exposing (parse, render)

import Encode
import Decode exposing (DecodeError)


struct User = {
  name: String,
  age: Int
}


def parse(json: String) -> Result(User, DecodeError)
  Decode.from_json(json)
end


def render(user: User) -> String
  Encode.encode_to_string(Encode.encode(user))
end
```

```ruby
Api::Internal.parse('{"name":"Ada","age":40}')
# => Ok(User(name: "Ada", age: 40))

Api::Internal.parse('{"name":"Ada"}')
# => Err(MissingField("age"))

Api::Internal.render(Api::User.new(name: "Ada", age: 40))
# => "{\"name\":\"Ada\",\"age\":40}"
```

When you need them, the pieces are explicit too: `Decode.field`,
`Decode.list`, and `Decode.succeed(User(_, _)) |> Decode.required(...)` build
decoders by hand — the `_` currying again.

## Side-effect-free testing

Jade functions are pure; effects go through `Task`, declared in a `uses`
block. A function that doesn't use a `Task` takes data in and returns data, so
you test it by passing values and asserting on the result — no mocks.

When you do hit a boundary, you stub the `Task`. Here's a Jade module that
calls a Ruby mailer, and the RSpec that drives it:

```jade
# src/signup.jd
module Signup exposing (run)

uses Mailer with
  deliver : String -> Task(Bool, String)
end


def run(email: String) -> Task(Bool, String)
  deliver(email)
end
```

```ruby
# spec/signup_spec.rb
require 'jade'
require 'jade/tasks'
require 'jade/tasks/rspec'

Jade.setup { |c| c.source_root = 'src' }

module Mailer
  extend Jade::Port
  task(:deliver) { |t, email| t.ok(Mail.welcome(email).deliver) }
end

Jade.require('signup')

RSpec.describe 'Signup' do
  include Jade::Tasks::RSpec

  it 'sends a welcome mail to the new address' do
    all_calls_to(Mailer.deliver) { |t, _email| t.ok(true) }

    expect(Signup::Internal.run('ada@example.com').run).to be_ok(true)
    expect(Mailer.deliver).to have_been_called.with('ada@example.com')
  end

  it 'surfaces a delivery failure as Err' do
    all_calls_to(Mailer.deliver) { |t, _email| t.err("smtp down") }

    expect(Signup::Internal.run('ada@example.com').run).to be_err("smtp down")
  end
end
```

`all_calls_to` sets a persistent stub; `next_call_to` queues one-shot answers.
`have_been_called` chains `.with(...)`, `.once`, `.times(n)`. Matchers include
`be_ok`, `be_err`, `be_just`, and `be_nothing`. Because effects only happen
through `Task`, a function's return type tells you whether it performs IO.

## Using Jade from Ruby

The gem is `jade-lang`; the library you `require` is still `jade`. A RubyGems
release is coming — for now, install from a path or a git ref:

```ruby
# Gemfile
gem 'jade-lang', path: '../jade'
# or: gem 'jade-lang', git: 'https://github.com/agustinrhcp/jade'
```

Point it at your source, then `require` modules by name. Jade compiles each
`.jd` to `.jade/build/<module>.rb` on first require (and only when the source
is newer), then loads it:

```ruby
require 'jade'

Jade.setup do |config|
  config.source_root = 'src'      # where your .jd files live
  # config.build_dir = '.jade/build'   (default)
end

Jade.require('greeter')

Greeter.greet('Ada')   # => "Hello, Ada"
```

Existing Ruby calls into Jade, and Jade calls into Ruby through `uses` blocks.
It's plain Ruby on disk, so it sits inside a Rails app like any other file.

## If it doesn't work out

Run the compiler one last time, commit the generated `.rb`, and drop the `.jd`
files. The output is already plain Ruby — no rewrite, no migration. The
`jade-eject` skill automates removing the gem dependency, but it isn't required.

Worst case: you wrote Ruby with a nicer authoring layer for a while.

## Editors and agents

There's a language server — type errors, inferred types, and jump-to-definition
in any editor that speaks LSP. For tools that don't, `jade q` answers the same
questions as one-shot JSON (hover, definition, references, symbols).

In our experience coding agents like Claude Code and Cursor handle Jade well:
the syntax is close enough to the ML family (Elm, OCaml, Haskell) that models
have useful priors, and the generated Ruby gives them a second source of truth
to check against. No promises that holds for every model — it's just held up
for us so far.

## Tooling

A single `jade` binary fronts the toolchain:

```
jade fmt [-i|-c] [file]   # format .jd source (stdin or file)
jade lsp                  # language server over stdio (hover, defn, refs, diagnostics)
jade q hover FILE:L:C     # headless JSON queries — hover/symbols/defn/refs
```

`jade fmt` is deterministic and idempotent; wire it into your editor or a
pre-commit hook.

## Standard library

`Basics`, `String`, `Char`, `List`, `Dict`, `Set`, `Tuple`, `Maybe`, `Result`,
`Task`, `Decode`, `Encode`, `Bytes`, `Calendar`, `Clock`. Stdlib operations
compile inline rather than through a runtime dispatch layer.

## Docs

- [docs/syntax.md](docs/syntax.md) — the full language tour
- [docs/interop.md](docs/interop.md) — the Ruby boundary: ports, decoding, what crosses
- [docs/json.md](docs/json.md) — `Decode` / `Encode`, by hand and auto-derived
- [docs/testing.md](docs/testing.md) — stubbing Tasks, the RSpec matchers
- [docs/stdlib.md](docs/stdlib.md) — module-by-module map
- [docs/lsp.md](docs/lsp.md) — language server and `jade q` setup
- [examples/](examples/) — runnable `.jd` files

## Status

Early and experimental — being tried out on small projects.

**In progress:** `Comparable` / `Show` derivation for user types, partial
record types in signatures, a stable REPL.

**Not great for:** throwaway scripts, libraries you ship to other Ruby
projects (they'd inherit the dependency), and performance-critical hot paths
(output is YJIT-friendly but unbenchmarked).

## License

[MIT](LICENSE).
