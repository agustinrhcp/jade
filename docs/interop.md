# Interop with Ruby

Jade has no implicit side effects. All interaction with the outside world goes through `uses` blocks, and every port returns a `Task`.

## Declaring a port

```jade
uses Time with
  now : Task(Int, Never)
end


def current_time() -> Task(Int, Never)
  now()
end
```

On the Ruby side, register the port with `Jade::Port`. The block receives a helper `t` for `t.ok(value)` / `t.err(error)`:

```ruby
module Time
  extend Jade::Port

  task :now do |t|
    t.ok(::Time.now.to_i)
  end
end
```

The block must return `t.ok(value)` or `t.err(error)` — never another `Task`. Composition (`map`, `and_then`, `sequence`) lives in Jade.

## Calling Jade from Ruby

Every exposed function gets two callable forms:

```ruby
# Boundary form — args decoded, return encoded, Task runs eagerly
MyModule.current_time      # => ['ok', 1748102400]
MyModule.current_time!     # => 1748102400 (bang form raises on err)

# Internal form — keeps the Task as a value you can compose
task = MyModule::Internal.current_time
task.run                   # => Jade::Result::Ok[1748102400]
```

At the boundary, Ruby values are **decoded into Jade values** on the way in and **encoded back to Ruby** on the way out. For `Task` functions, the decoder for the ok arm runs against whatever the port returned — so a signature like `Task(User, NetworkError)` stays clean and you don't thread a separate `DecodeError` through every call.

## What can cross the boundary

A function gets a Ruby-callable boundary wrapper only if every argument type is `Decodable` and the return type is `Encodable`. Anything else — a function value, an unbound type variable, a custom type without an `Encodable` instance — compiles fine, but calling it from Ruby raises `Jade::Interop::NotExposed`. The `Internal` form still works; you just can't reach it from plain Ruby.

If a port returns something that doesn't decode to the declared type, the boundary raises `Jade::Interop::DecodeError`. This is on purpose: a port returning the wrong shape is a programming bug, not a runtime condition to recover from — let it surface loudly. Example:

```jade
module Users exposing (fetch)

struct User = { id: Int, name: String }


uses Backend with
  raw_fetch : Int -> Task(User, NetworkError)
end


def fetch(id: Int) -> Task(User, NetworkError)
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
# => raises Jade::Interop::DecodeError: expected field 'id' on User
```

The Jade caller never sees a malformed `User` — the bug is caught at the entry point. The `NetworkError` arm stays meaningful (it's for real network failures), and you don't have to add a `BadShapeFromPort` variant to it.

## What the compiled boundary looks like

For a Jade function with primitive args:

```jade
module Sample exposing (absolute)

def absolute(n: Int) -> Int
  n < 0 ? 0 - n : n
end
```

The compiler emits:

```ruby
module Sample
  extend self

  module Internal
    extend self

    def absolute(n)
      ((n < 0) ? (0 - n) : n)
    end
  end

  BOUNDARY_DEC_0 = Jade::Runtime.intr("Decode.int").call
  BOUNDARY_ENC_0 = Jade::Runtime.intr("Encode.int")

  def self.absolute(__p0__)
    __d0__ = Jade::Interop::Boundary.decode_or_raise(BOUNDARY_DEC_0, __p0__)
    BOUNDARY_ENC_0.call(Internal.absolute(__d0__))
  end
end
```

Two surface methods (`Internal.absolute` and `self.absolute`), one decoder + one encoder cached as module constants. The boundary work is visible — not hidden inside a runtime hook.
