# Jade

A statically typed, functional language that compiles to Ruby. Jade is designed around three pillars: **simplicity** (one way to do things), **safety** (type inference + exhaustive pattern matching), and **interoperability** (safe, easy escape hatches into Ruby).

> Early development. Not yet ready for production use.

---

## Using Jade from Ruby

```ruby
# Gemfile
gem 'jade', path: '/path/to/jade'
```

```ruby
require 'jade'

Jade.setup do |config|
  config.source_root = 'src'    # where your .jd files live
  config.build_dir   = '.jade'  # where compiled .rb files are written
end

Jade.require('my_module')

# The module is now available as a Ruby constant
MyModule.my_function.call('hello')
```

---

## Language Tour

### Functions

```jade
module Greetings exposing (greet)

def greet(name: String) -> String
  "Hello, " ++ name ++ "!"
end
```

### Types

Jade infers types throughout — annotations are only required on function signatures.

**Primitives:** `Int`, `Float`, `Bool`, `String`, `Char`

`Char` literals use single quotes: `'a'`, `'Z'`, `'\n'`.

**Union types:**
```jade
type Shape = Circle(Float) | Rectangle(Float, Float)
```

**Structs (named records):**
```jade
struct Person = { name: String, age: Int }
```

**Anonymous records:**
```jade
def origin() -> { x: Int, y: Int }
  { x: 0, y: 0 }
end
```

**Tuples:**
```jade
def swap(pair: (Int, String)) -> (String, Int)
  (a, b) = pair
  (b, a)
end
```

**Generic types:**
```jade
type Result(a, e) = Ok(a) | Err(e)
```

**`Never`** is a bottom type representing an impossible value. It marks a union variant that can never be constructed — the exhaustiveness checker understands this, so you can destructure without matching the impossible case:

```jade
-- Ok is the only possible case, so destructuring works
def unwrap(r: Result(Int, Never)) -> Int
  Ok(n) = r
  n
end
```

### Pattern Matching

The compiler enforces exhaustiveness — missing a case is a type error.

```jade
def describe(shape: Shape) -> String
  case shape
  of Circle(_)      then "a circle"
  of Rectangle(_, _) then "a rectangle"
  end
end
```

**List patterns:**
```jade
def sum(list: List(Int)) -> Int
  case list
  of []       then 0
  of [x, *xs] then x + sum(xs)
  end
end
```

**Destructuring with `=`:**
```jade
{ name:, age: } = person
(first, second) = pair
[head, *tail]   = list
```

**Monadic bind with `<-`** (in Maybe/Result context):
```jade
name <- Maybe.map(user, .name)
```

### Lambdas

```jade
double = (x) -> { x * 2 }
add    = (a, b) -> { a + b }
```

### Pipe Operators

```jade
result = numbers
  |> List.filter((x) -> { x > 0 })
  |> List.map((x) -> { x * 2 })
```

### String and List Concatenation

`++` works on both `String` and `List` via the `Appendable` interface:

```jade
full = first ++ " " ++ last
all  = list_a ++ list_b
```

### Interfaces

Interfaces are like typeclasses. `Eq`, `Comparable`, and `Appendable` are built-in.

```jade
-- Works for any type with an Eq instance
def are_equal(a: a, b: a) -> Bool
  a == b
end

-- Works for any type with a Comparable instance
def larger(a: a, b: a) -> a
  case compare(a, b)
  of GT then a
  of _  then b
  end
end
```

**Custom interfaces:**
```jade
implements Show(Person) with
  show: (p) -> { p.name ++ " (age " ++ String.from_int(p.age) ++ ")" }
end
```

### Modules and Imports

```jade
module MyModule exposing (foo, bar)

import Maybe exposing (Maybe(..), map)
import List
```

### Interop with Ruby

```jade
uses Time with
  now: () -> Int
end

def current_time() -> Int
  Time.now()
end
```

Jade guards return values at the interop boundary — if Ruby returns the wrong type you get a clear runtime error instead of silent corruption.

---

## Standard Library

| Module | Contents |
|--------|----------|
| `Maybe` | `Just(a)` / `Nothing`, `map`, `and_then`, `with_default` |
| `Result` | `Ok(a)` / `Err(e)`, `map`, `and_then`, `map_error` |
| `List` | `map`, `filter`, `fold`, `zip`, `sort`, `length`, `range`, and more |
| `String` | `length`, `reverse`, `split`, `trim`, `to_int`, `contains`, and more |
| `Char` | `to_code`, `from_code`, `is_digit`, `is_alpha`, `is_alpha_num`, `is_upper`, `is_lower` |
| `Tuple` | `first`, `second`, `map_first`, `map_second` |
| `Basics` | `Eq`, `Comparable`, `Appendable`, `Mappable`, `Chainable`, `Ordering` |

---

## Examples

See the [`examples/`](examples/) directory:

| File | Covers |
|------|--------|
| [`basics_examples.jd`](examples/basics_examples.jd) | Arithmetic, strings, conditionals |
| [`pattern_matching.jd`](examples/pattern_matching.jd) | Lists, literal patterns, recursion |
| [`maybe_examples.jd`](examples/maybe_examples.jd) | Safe nullability and chaining |
| [`records.jd`](examples/records.jd) | Structs, record update, destructuring |
| [`custom_types.jd`](examples/custom_types.jd) | Union types and exhaustive matching |
| [`interfaces.jd`](examples/interfaces.jd) | Generic functions with inferred constraints |
| [`interop.jd`](examples/interop.jd) | Calling Ruby from Jade safely |

---

## Roadmap

### Compiler
- **Incremental compilation** — currently recompiles everything on every run
- **Better error messages** — parsing errors are structured and include source location, but coverage is still limited; more error sites need to be wired up
- **Multi-error collection** — parser returns the first error; should collect all errors in one pass

### Language Features
- **Ranges** — `1..10`, `1...10`
- **No-arg functions as constants** — `def pi() -> Float` should be callable as `pi`, not `pi()`
- **No-arg constructors as constants** — `Nothing` instead of `Nothing()`
- **Holes for currying** — `map(_, double)` as sugar for `(list) -> { map(list, double) }`
- **List pattern matching** — pattern matching on list literals in `case` expressions

### Type System
- **Unresolved constraint error messages** — constraint propagation works but error messages need improvement
- **Row polymorphism** — partial record types in function signatures

### Tooling
- **Language Server (LSP)** — go-to-definition, hover types, inline errors
- **Diagnostics** — structured error output for editor integration
- **`jade fmt`** — formatter CLI entrypoint (formatter exists internally)

### Interop and Runtime
- **Tasks** — interop calls should return `Task` since they interact with the world and can fail
- **`Jade::Interop.ok` / `.error` / `.always`** — helpers for wrapping Ruby return values
- **Decoding Ruby / JSON values** — a decoder layer for safely converting untyped Ruby or JSON data into typed Jade values

### Infrastructure
- **Reference index pass** — track symbol usages for unused import detection and dead code warnings
