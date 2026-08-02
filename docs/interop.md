# Interop with Ruby

Jade has no implicit side effects. All interaction with the outside world goes
through `uses` blocks, and every port returns a `Task`.

## Declaring a port

The `uses` block declares the boundary types; the names come into scope
unqualified. **Declarations are separated by commas** — a newline alone ends
the block, so a second entry without a comma before it reads as a parse error
(`Unexpected token "entries", expected end`).

A port takes as many arguments as its type says: `A, B -> Task(…)` is a
two-argument port, called `entries(key, limit)`. Parenthesising the arguments
means something else — `(A, B) -> Task(…)` is a *one*-argument port taking a
tuple, called `entries((key, limit))`.

```jade
module Store exposing (page)

uses KeyValue with
  members : String -> Task(List(String), String),
  entries : String, Int -> Task(List(String), String)
end


def page(key: String) -> Task(List(String), String)
  entries(key, 20)
end
```

On the Ruby side, register the port with `Jade::Port`. The block receives a
helper `t` for `t.ok(value)` / `t.err(error)`, then one parameter per declared
argument:

```ruby
module KeyValue
  extend Jade::Port

  task :members do |t, key|
    t.ok(REDIS.smembers(key))
  end

  task :entries do |t, key, limit|
    t.ok(REDIS.lrange(key, 0, limit - 1))
  end
end
```

The block must return `t.ok(value)` or `t.err(error)` — never another `Task`.
Composition (`map`, `and_then`, `sequence`) lives in Jade. (Pick a port module
name that doesn't shadow a Ruby constant you rely on — `task :members` defines
`KeyValue.members`.)

## What crosses the boundary

A port is the same boundary as a Jade function called from Ruby, pointed the
other way, and it converts in both directions: **arguments are encoded on the
way out, and the return value is decoded on the way back**. Ruby sees wire
values — strings, numbers, hashes, arrays — never Jade's internal
representation.

```jade
uses Scheduling with
  shift_months : Instant, Int -> Task(Instant, Never)
end
```

```ruby
module Scheduling
  extend Jade::Port

  task :shift_months do |t, iso, months|
    # iso is "2026-08-01T12:00:00Z", not a Jade::Clock::Instant
    t.ok(Time.iso8601(iso).then { |at| (at << -months).iso8601 })
  end
end
```

Every argument type therefore needs an `Encodable` instance, the same way every
`Task` arm needs a `Decodable` one. A type with neither is a compile error
naming the argument:

```
Port `shift_months` cannot encode argument 1 (`Shape`): no Encodable instance
```

Declare the argument as `Decode.Value` to opt out and hand Ruby the value
untouched — the arg-side counterpart of a `Decode.Value` return arm. `Value` has
instances on both sides, so the opt-out holds when it's nested too: a
`List(Value)` argument, or a struct with a `Value` field, crosses element by
element with each one left alone.

## Calling Jade from Ruby

An exposed function gets two callable forms:

```ruby
# Boundary form — args decoded, return encoded, Task runs eagerly
Store.page("recent")     # => ["ok", ["a", "b"]]
Store.page!("recent")    # => ["a", "b"]   (bang form unwraps, raises on err)

# Internal form — keeps the Task as a value you can compose
task = Store::Internal.page("recent")
task.run                 # => Jade::Result::Ok[["a", "b"]]
```

At the boundary, Ruby values are **decoded into Jade values** on the way in and
**encoded back to Ruby** on the way out. For `Task` functions the ok-arm decoder
runs against whatever the port returned, so a signature like `Task(User, String)`
keeps its declared error type — you don't thread a separate `DecodeError`
through every call.

## When a function is callable from Ruby

The unit here is the **function**, not the type. A function is exposed to Ruby
only when **all of its parameters are `Decodable` and its return type is
`Encodable`**. If any parameter can't be decoded, or the return can't be
encoded, that whole function isn't exposed — it compiles fine and its `Internal`
form still works, but calling the public `Module.fn` from plain Ruby raises
`Jade::Interop::NotExposed`. The error names the part that disqualified it
(e.g. `argument 1 of type Shape has no Decodable instance`).

What takes a function out of Ruby's reach is a parameter or return type with no
`Decodable` / `Encodable` instance — a function value, an unbound type variable,
or a custom union you haven't given an instance.

If a port returns something that doesn't decode to the declared type, the
boundary raises `Jade::Interop::DecodeError`. This is on purpose: a port
returning the wrong shape is a programming bug, not a runtime condition to
recover from, so the boundary raises rather than pass on a malformed value.

```jade
module Users exposing (fetch)

struct User = {
  id: Int,
  name: String
}


uses Backend with
  raw_fetch : Int -> Task(User, String)
end


def fetch(id: Int) -> Task(User, String)
  raw_fetch(id)
end
```

```ruby
module Backend
  extend Jade::Port

  task :raw_fetch do |t, id|
    t.ok({ name: "Paul" })   # oops — missing :id
  end
end

Users.fetch(1)
# => raises Jade::Interop::DecodeError:
#    Port returned a value that failed to decode at value: missing field `id` ({name: "Paul"})
```

The Jade caller never sees a malformed `User` — the bug is caught at the entry
point, and the error arm (here `String`) stays meaningful for real failures.

## What the compiled boundary looks like

For a function with a primitive argument:

```jade
module Sample exposing (absolute)

def absolute(n: Int) -> Int
  n < 0 ? 0 - n : n
end
```

the compiler emits:

```ruby
module Sample
  extend self

  module Internal
    extend self

    def absolute(n)
      if ((n < 0))
        (0 - n)
      else
        n
      end
    end
  end

  def self.absolute(n)
    Internal.absolute(Jade::Interop::Boundary.integer("Int", n))
  end
end
```

Two surface methods — `Internal.absolute` (pure) and `self.absolute` (the
boundary). `Int` has a specialized fast-path coercion; richer types decode
through cached `Decode` constants instead. Either way the boundary work is
visible in the file, not hidden inside a runtime hook.
