# Syntax reference

A tour of the language. The shorter "what does Jade look like" answer is in the [README](../README.md); this page covers everything you'll write.

## Functions

```jade
module Greetings exposing (greet)

def greet(name: String) -> String
  "Hello, " ++ name ++ "!"
end
```

Annotations are required on function signatures; everything else is inferred. Function bodies close with `end`.

→ [`examples/basics_examples.jd`](../examples/basics_examples.jd)

## Union types

```jade
type Shape
  = Circle(Float)
  | Rectangle(Float, Float)
```

Variants can carry positional payloads (as above) or keyed payloads when positional args get hard to read:

```jade
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

The keyed payload is an anonymous record, so `r.paid_amount` and `{ r | paid_amount: 0 }` work as usual.

→ [`examples/custom_types.jd`](../examples/custom_types.jd)

## Structs (named records)

```jade
struct Person = {
  name: String,
  age: Int,
}


def make() -> Person
  Person("Paul", 55)                   # positional
end


def make_kw() -> Person
  Person(name: "Paul", age: 55)        # kwargs (canonical)
end


def older(p: Person) -> Person
  { p | age: p.age + 1 }               # record update
end


def older_pipe(p: Person) -> Person
  p |> .age=(p.age + 1)                # update sugar in pipelines
end
```

Anonymous records do not coerce into nominal structs. Passing `{ name: "Paul", age: 55 }` where `Person` is expected is a type error.

→ [`examples/records.jd`](../examples/records.jd)

## Anonymous records, tuples, generics

```jade
def origin() -> { x: Int, y: Int }
  { x: 0, y: 0 }
end


def swap(pair: (Int, String)) -> (String, Int)
  (a, b) = pair
  (b, a)
end


type Result(a, e)
  = Ok(a)
  | Err(e)
```

## Primitives and `Never`

`Int`, `Float`, `Bool`, `String`, `Char`. `Char` literals use single quotes: `'a'`, `'Z'`, `'\n'`.

`Never` is a type with no possible values — a variant that can't be built. The compiler knows this, so you can destructure past it:

```jade
def unwrap(r: Result(Int, Never)) -> Int
  Ok(n) = r
  n
end
```

## Zero-arg functions as values

```jade
def pi() -> Float
  3.14
end

area = pi * radius * radius       # parens optional
also = pi() * radius * radius     # equivalent
flag = True                       # bare ctor is the value
none = Nothing
```

Constructors with payloads are unchanged: `Just(x)`, `Ok(value)`.

## Pattern matching

```jade
def describe(shape: Shape) -> String
  case shape
  in Circle(_) then "a circle"
  in Rectangle(_, _) then "a rectangle"
  end
end
```

`case` has to cover every shape the value could take — exhaustive pattern matching, enforced by the compiler. The trailing wildcard can be written as `else`:

```jade
def describe_size(n: Int) -> String
  case n
  in 0 then "empty"
  in 1 then "one"
  else "many"
  end
end
```

For boolean branches, use a ternary or the block `if/then/else/end`:

```jade
absolute = n < 0 ? 0 - n : n

# multi-statement form:
if n < 0 then
  log_negative(n)
  0 - n
else
  n
end
```

Multi-statement case branches drop `then` and indent under the header:

```jade
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

**Lists** match with `[]` and `[head | tail]`:

```jade
def sum(list: List(Int)) -> Int
  case list
  in [] then 0
  in [x | xs] then x + sum(xs)
  end
end
```

The rest of a list pattern (after `|`) must be a name or wildcard.

**Destructuring with `=`** works for records and tuples (use `case` for lists, the compiler rejects a partial `=` binding):

```jade
{ name:, age: } = person
(first, second) = pair
```

**The `<-` operator** unwraps the value inside a `Maybe`, `Result`, or `Task` and short-circuits if it isn't there. Write the happy path top-to-bottom; failures take care of themselves:

```jade
def safe_sum(a: Maybe(Int), b: Maybe(Int)) -> Maybe(Int)
  x <- a
  y <- b
  Just(x + y)
end
```

If `a` or `b` is `Nothing`, the rest of the function is skipped. `Result` short-circuits on `Err`; `Task` short-circuits on the failure arm.

→ [`examples/pattern_matching.jd`](../examples/pattern_matching.jd), [`examples/maybe_examples.jd`](../examples/maybe_examples.jd)

## Pipes, lambdas, currying

```jade
result = numbers
  |> List.filter((x) -> { x > 0 })
  |> List.map((x) -> { x * 2 })
```

Lambdas use `(params) -> { body }`. They're the one block that uses braces.

A `_` in a function-call argument position curries the call. Each `_` becomes a unary lambda parameter, in left-to-right order:

```jade
add5   = add(_, 5)        # Int -> Int
incr   = add(1, _)        # Int -> Int
mkPair = Pair(_, _)       # a -> b -> Pair(a, b)
```

Useful for building decoders piece by piece:

```jade
Decode.succeed(Person(_, _, _))
  |> Decode.required("name", Decode.string)
  |> Decode.required("age", Decode.int)
```

`_` is only valid as a direct argument inside a call — not as a bare expression or operator operand.

## Interfaces

Like a Ruby module you `extend` into a class, but resolved at compile time from the argument types. `Eq`, `Comparable`, and `Appendable` ship built-in. `++` works on `String` and `List` via `Appendable`.

```jade
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

User-defined:

```jade
interface Show(a) with
  show : a -> String
end


implements Show(Person) with
  show: (p) -> { p.name ++ " (age " ++ String.from_int(p.age) ++ ")" }
end


def describe(p: Person) -> String
  show(p)                          # picks the right impl from p's type
end
```

The right-hand side of an `implements` clause can be either an inline lambda or a function reference (`show: show_person`).

→ [`examples/interfaces.jd`](../examples/interfaces.jd)

## Modules and imports

```jade
module MyModule exposing (foo, bar)

import Maybe exposing (Maybe(..), map)
import List
```

`MyType(..)` re-exports the type along with its constructors. Works the same way for `struct` declarations.

## How it compiles

Source on the left, the Ruby it actually compiles to on the right. Nothing in the compiled column is machinery you can't trace.

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
end
```

</td></tr>
</table>

When something behaves unexpectedly, the path is the same as in any Ruby project: open the file, read the code. There's no opaque runtime between the source and what executes.

A public `Sample.area` method is generated alongside `Internal.area` whenever `area`'s arguments are `Decodable` and its return is `Encodable` — it decodes Ruby args, runs the function, encodes the return. See [interop.md](interop.md) for that side. (`Shape` has no `Decodable` instance above, so the public method would raise `NotExposed` if called.)
