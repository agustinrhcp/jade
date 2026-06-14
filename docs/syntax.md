# Syntax reference

A tour of the language. The shorter "what does Jade look like" answer is in the
[README](../README.md); this page covers what you'll actually write. Every
snippet here compiles.

## Functions

```jade
module Greetings exposing (greet)

def greet(name: String) -> String
  "Hello, " ++ name ++ "!"
end
```

Annotations are required on function signatures; everything else is inferred.
Bodies close with `end`. A zero-argument function is written without parens —
`def greet -> String`.

→ [`examples/basics_examples.jd`](../examples/basics_examples.jd)

## Union types

```jade
module Shapes exposing (Shape)

type Shape
  = Circle(Float)
  | Rectangle(Float, Float)
```

Variants carry positional payloads (above) or keyed payloads when the
positional args get hard to read:

```jade
module Charges exposing (paid)

type Charge
  = Refund(Int)
  | Settled(paid_amount: Int, tax_amount: Int, issued_amount: Int)


def paid(c: Charge) -> Int
  case c
  in Refund(n) then n
  in Settled(r) then r.paid_amount + r.tax_amount
  end
end
```

The keyed payload is an anonymous record, so `r.paid_amount` and
`{ r | paid_amount: 0 }` work as usual.

→ [`examples/custom_types.jd`](../examples/custom_types.jd)

## Structs (named records)

```jade
module People exposing (make, make_kw, older, older_pipe)

struct Person = {
  name: String,
  age: Int
}


def make -> Person
  Person("Paul", 55)
end


def make_kw -> Person
  Person(name: "Paul", age: 55)
end


def older(p: Person) -> Person
  { p | age: p.age + 1 }
end


def older_pipe(p: Person) -> Person
  p |> .age=(p.age + 1)
end
```

Anonymous records do not coerce into nominal structs: passing
`{ name: "Paul", age: 55 }` where a `Person` is expected is a type error.

→ [`examples/records.jd`](../examples/records.jd)

## Anonymous records and tuples

```jade
module Pairs exposing (origin, swap)

def origin -> { x: Int, y: Int }
  { x: 0, y: 0 }
end


def swap(pair: (Int, String)) -> (String, Int)
  (Tuple.second(pair), Tuple.first(pair))
end
```

Tuple elements are read with `Tuple.first` / `Tuple.second`, or matched in a
`case` (`in (a, b) then …`).

## Primitives and `Never`

`Int`, `Float`, `Bool`, `String`, `Char`. `Char` literals are single
characters in single quotes: `'a'`, `'Z'`.

`Never` is a type with no values — a variant that can't be built. The compiler
knows this, so you can destructure past it:

```jade
module Unwrap exposing (unwrap)

def unwrap(r: Result(Int, Never)) -> Int
  Ok(n) = r
  n
end
```

## Zero-arg functions as values

A zero-arg function is referenced by name, with or without parens:

```jade
module Geometry exposing (area)

def pi -> Float
  3.14
end


def area(radius: Float) -> Float
  pi * radius * radius
end
```

Bare constructors are values too: `True`, `Nothing`. Constructors with payloads
are called: `Just(x)`, `Ok(value)`.

## Pattern matching

```jade
module Sizes exposing (describe_size)

def describe_size(n: Int) -> String
  case n
  in 0 then "empty"
  in 1 then "one"
  else "many"
  end
end
```

`case` must cover every shape the value can take — exhaustiveness is enforced by
the compiler. The trailing wildcard is written `else`.

A branch with multiple statements drops `then` and indents under the header:

```jade
module Areas exposing (area)

type Shape
  = Circle(Float)
  | Rectangle(Float, Float)
  | Triangle(Float, Float, Float)


def area(shape: Shape) -> Float
  case shape
  in Circle(r) then 3.14 * r * r
  in Rectangle(w, h) then w * h
  in Triangle(a, b, c)
    s = (a + b + c) / 2.0
    s * (s - a) * (s - b) * (s - c)
  end
end
```

**Lists** match with `[]` and `[head | tail]`; the rest after `|` must be a
name or wildcard:

```jade
module Sums exposing (sum)

def sum(list: List(Int)) -> Int
  case list
  in [] then 0
  in [x | xs] then x + sum(xs)
  end
end
```

**Destructuring with `=`** binds the fields of a record (use `case` for a list
— a partial `=` binding on a list is rejected):

```jade
module Names exposing (greet)

struct Person = {
  name: String,
  age: Int
}


def greet(person: Person) -> String
  { name:, age: } = person
  "Hi " ++ name
end
```

**The `<-` operator** unwraps the value inside a `Maybe`, `Result`, or `Task`
and short-circuits if it isn't there, so you write the success path top to
bottom:

```jade
module SafeSum exposing (safe_sum)

def safe_sum(a: Maybe(Int), b: Maybe(Int)) -> Maybe(Int)
  x <- a
  y <- b
  Just(x + y)
end
```

If `a` or `b` is `Nothing`, the rest of the function is skipped. `Result`
short-circuits on `Err`; `Task` on its failure arm.

→ [`examples/pattern_matching.jd`](../examples/pattern_matching.jd),
[`examples/maybe_examples.jd`](../examples/maybe_examples.jd)

## Conditionals

A ternary for one-liners, a block `if`/`else`/`end` when a branch needs more
than one statement:

```jade
module Abs exposing (abs)

def abs(n: Int) -> Int
  n < 0 ? 0 - n : n
end
```

## Pipes, lambdas, currying

```jade
module Nums exposing (clean)

def clean(numbers: List(Int)) -> List(Int)
  numbers
    |> List.filter((x) -> { x > 0 })
    |> List.map((x) -> { x * 2 })
end
```

Lambdas are `(params) -> { body }` — the one construct that uses braces.

A `_` in an argument position curries the call: each `_` becomes a parameter,
left to right, so `add(_, 5)` is a one-argument function.

```jade
module Curry exposing (add_five, add_one)

def add(a: Int, b: Int) -> Int
  a + b
end


def add_five(n: Int) -> Int
  add(_, 5)(n)
end


def add_one(n: Int) -> Int
  add(1, _)(n)
end
```

It's most useful for building decoders field by field:

```jade
module Decoding exposing (person)

import Decode exposing (DecodeError)


struct Person = {
  name: String,
  age: Int
}


def person(json: String) -> Result(Person, DecodeError)
  decoder = Decode.succeed(Person(_, _))
    |> Decode.required("name", Decode.string)
    |> Decode.required("age", Decode.int)

  Decode.decode_string(decoder, json)
end
```

`_` is only valid as a direct argument inside a call — not as a bare expression
or operator operand.

## Interfaces

Resolved at compile time from the argument types, like a Ruby module you
`extend` — except the compiler picks the implementation. `Eq` (`==` / `!=`),
`Comparable` (`compare`, returning `LT` / `EQ` / `GT`), and `Appendable` (`++`
on `String` and `List`) ship built in:

```jade
module Compare exposing (are_equal, larger)

def are_equal(a: a, b: a) -> Bool
  a == b
end


def larger(a: a, b: a) -> a
  case compare(a, b)
  in GT then a
  else b
  end
end
```

You can define your own, with implementations dispatched by type:

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
  show: (p) -> { p.name ++ " (age " ++ String.from_int(p.age) ++ ")" }
end


def describe(p: Person) -> String
  show(p)
end
```

The right-hand side of an `implements` clause is an inline lambda or a function
reference (`show: show_person`).

→ [`examples/interfaces.jd`](../examples/interfaces.jd)

## Modules and imports

One module per file; `exposing` lists the public surface (alphabetized).
`import` pulls names in by module or selectively — `Maybe(..)` brings the type
in along with its constructors:

```jade
module Wallet exposing (balance)

import Maybe exposing (Maybe(..), map)
import List


def balance(amount: Maybe(Int)) -> Int
  Maybe.with_default(amount, 0)
end
```

## How it compiles

Source on the left, the Ruby it compiles to on the right. Nothing in the
compiled column is machinery you can't trace.

<table>
<tr><th>Jade</th><th>Compiled Ruby</th></tr>
<tr><td>

```jade
module Sample exposing (area)

type Shape
  = Circle(Float)
  | Rectangle(Float, Float)


def area(shape: Shape) -> Float
  case shape
  in Circle(r) then 3.14 * r * r
  in Rectangle(w, h) then w * h
  end
end
```

</td><td>

```ruby
module Sample
  extend self

  Circle = Data.define(:_1) do
    def circle?; true; end
    def rectangle?; false; end
  end

  Rectangle = Data.define(:_1, :_2) do
    def circle?; false; end
    def rectangle?; true; end
  end

  module Internal
    extend self

    def area(shape)
      case shape
      in Sample::Circle(r) then ((3.14 * r) * r)
      in Sample::Rectangle(w, h) then (w * h)
      end
    end
  end

  def self.area(*)
    raise Jade::Interop::NotExposed.new(
      module_name: "Sample", function_name: :area,
      hint: "argument 1 of type Shape has no Decodable instance",
    )
  end
end
```

</td></tr>
</table>

(The compiled file also carries a short `require` header for the runtime and
stdlib.) When something behaves unexpectedly, the path is the same as in any
Ruby project: open the file, read the code.

A function is exposed to Ruby only when all its parameters are `Decodable` and
its return is `Encodable`; the public `Sample.area` is generated alongside
`Internal.area` to decode the Ruby args, run the function, and encode the
return. Here `area`'s parameter is a `Shape`, which has no `Decodable` instance —
so the function isn't exposed, and the public method raises `NotExposed` if
called. See [interop.md](interop.md) for that side.
