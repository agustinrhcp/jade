# What Jade guarantees

A list to paste into a design doc, with the code that proves each line. Every
example on this page is compiled by the test suite, and every error is the
compiler's real output, not a paraphrase.

1. Every case of a union is handled, and adding a case breaks the build.
2. There is no nil. A value that may be absent says so in its type.
3. A record cannot be built with a field missing.
4. A branch that can never run is an error, not dead code.
5. Data from Ruby is validated at the boundary, or rejected with a message
   that names the field.
6. A function Ruby cannot call safely is not callable from Ruby.
7. If a function reaches the outside world, its type says so.
8. Nothing divides by zero.
9. You can leave. `jade eject` writes the Ruby and the gem stops mattering.

## 1. Every case is handled

```jade compiles
module Invoices exposing (Status(..), label)

type Status
  = Draft
  | Sent
  | Paid


def label(s: Status) -> String
  case s
  in Draft then "draft"
  in Sent then "sent"
  in Paid then "paid"
  end
end
```

Adding a fourth case to `Status` does not fail at the definition, it fails at
every `case` that stopped being complete, which is the point. Leaving one out
reads the same way:

```jade fails
module PartialInvoices exposing (Status(..), label)

type Status
  = Draft
  | Sent
  | Paid


def label(s: Status) -> String
  case s
  in Draft then "draft"
  in Sent then "sent"
  end
end
```

```text expected
error: Pattern match is not exhaustive. Missing cases:
  Paid
```

The missing case is named. There is no default arm to forget to remove.

## 2. There is no nil

A value that may be absent is a `Maybe`, and a `Maybe` is not the value. The
type checker will not let one stand in for the other:

```jade fails
module Shouting exposing (shout)

def shout(name: Maybe(String)) -> String
  String.to_upper(name)
end
```

```text expected
error: Function call mismatch, expected (String) -> String but found (Maybe(String)) -> String
```

Opening it is the only way through, and the compiler counts the arms:

```jade compiles
module Greeting exposing (greet)

def greet(name: Maybe(String)) -> String
  case name
  in Just(n) then "hello " ++ n
  in Nothing then "hello"
  end
end
```

## 3. A record cannot be built with a field missing

```jade fails
module Users exposing (User(..), make)

struct User = {
  name: String,
  email: String
}


def make -> User
  User(name: "ada")
end
```

```text expected
error: `User` is missing field `email:`
```

## 4. A branch that can never run is an error

Dead code in a `case` usually means the model changed and a branch was left
behind. It does not compile:

```jade fails
module Shadowed exposing (Status(..), label)

type Status
  = Draft
  | Sent


def label(s: Status) -> String
  case s
  in Draft then "draft"
  in Sent then "sent"
  in Draft then "again"
  end
end
```

```text expected
error: This branch can never match.
```

## 5. Ruby data is validated at the boundary

Values from Ruby are decoded on the way in. A value of the wrong shape does
not reach your code, and the rejection names the path it walked:

```jade compiles
module Orders exposing (Line(..), total)

struct Line = {
  sku: String,
  cents: Int
}


def total(lines: List(Line)) -> Int
  List.sum(List.map(lines, (l) -> { l.cents }))
end
```

```ruby raises
Orders.total([{ 'sku' => 'a', 'cents' => 'lots' }])
```

```text expected
Orders.total(lines)[0].cents: expected Int, got String ("lots")
```

A field the hash never had is reported as missing rather than blamed on its
type, so a renamed key does not read as a type error:

```ruby raises
Orders.total([{ 'sku' => 'a' }])
```

```text expected
Orders.total(lines)[0].cents: missing field `cents`
```

## 6. What Ruby cannot call safely, it cannot call

A function whose signature has no meaning across the boundary, here one taking
a function as an argument, is not exposed to Ruby at all. It is a Jade-internal
function that other Jade code can use:

```jade compiles
module Filters exposing (Line(..), pick)

struct Line = {
  sku: String,
  cents: Int
}


def pick(lines: List(Line), f: Line -> Bool) -> List(Line)
  List.filter(lines, f)
end
```

```ruby raises
Filters.pick([], ->(line) { true })
```

```text expected
Filters.pick is not exposed to Ruby. argument 2 of type (Line) -> Bool has no Decodable instance
```

The alternative, a boundary that quietly accepts a Ruby proc and hopes, is how
a type system stops being load-bearing at the edge where it matters most.

## 7. IO is in the type

Everything outside the process reaches Jade through a port, and a port has to
return a `Task`:

```jade fails
module Sneaky exposing (now)

uses Jade::Clock with
  now : Int
end
```

```text expected
error: Port `now` must return a Task type, e.g. `now: Task(Ok, Err)`
```

A `Task` is a description of work, not the result of it, so a function cannot
quietly perform IO and hand back a plain value. Trying makes the mismatch the
whole error:

```jade fails
module Leaky exposing (stamp)

uses Jade::Clock with
  now : Task(Int, Never)
end


def stamp -> String
  String.from_int(now())
end
```

```text expected
error: Function call mismatch, expected (Int) -> String but found (Task(Int, Never)) -> String
```

So the guarantee reads off the signature, with nothing to audit: **a function
whose return type is not a `Task` did no IO**, and neither did anything it
called.

```jade compiles
module Pricing exposing (Line(..), subtotal)

struct Line = {
  sku: String,
  cents: Int
}


def subtotal(lines: List(Line)) -> Int
  List.sum(List.map(lines, (l) -> { l.cents }))
end
```

What is not yet distinguished is *which* outside world: a `Task` that reads the
clock and a `Task` that calls a payment provider have the same shape.

## 8. Nothing divides by zero

`/` takes a divisor known not to be zero. A literal is known, so ordinary
arithmetic is written the ordinary way:

```jade compiles
module Rates exposing (to_euros)

def to_euros(cents: Int) -> Int
  cents / 100
end
```

A literal zero is the one case the compiler can see is wrong, and it says that
rather than reporting a type it could not match:

```jade fails
module ZeroDiv exposing (bad)

def bad(n: Int) -> Int
  n / 0
end
```

```text expected
error: Cannot divide by zero.
```

A divisor that is a value has to be checked, and `non_zero` is where that
happens. It hands back a `Maybe`, so the caller decides what an absent answer
means:

```jade compiles
module Shares exposing (each)

def each(total: Int, people: Int) -> Maybe(Int)
  Maybe.map(non_zero(people), (d) -> { total / d })
end
```

Skipping the check does not compile:

```jade fails
module ValueDiv exposing (bad)

def bad(n: Int, d: Int) -> Int
  n / d
end
```

```text expected
error: Right side of (/) expects NonZero(Int) but found Int
```

`NonZero` has no constructor, so `non_zero` is the only way to hold one, and it
is erased at runtime: dividing costs what dividing costs in Ruby.

## 9. You can leave

`jade eject` writes every module as plain Ruby, vendors the runtime those files
call, and rewrites their requires to point at each other. The result runs with
the gem uninstalled. Jade's own CI ejects its examples and runs them that way,
so the exit is tested rather than promised.

That is the guarantee under the other six: adopting Jade is reversible, and
what you would be left with is Ruby you can read.

## What is not on this list

Claims Jade does not make today, so nobody has to discover them later:

- **Nothing checks that a function ends.** A recursion with no base case type
  checks and runs until the stack does not.
