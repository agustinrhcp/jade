# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `Assignable` also derives for structs, naming one column per field in
  declaration order. A field renamed to dodge a keyword (`type_`) maps back to
  the column it came from. Generic structs derive at the type they are applied
  to. Inert unless jade-sql is loaded.

### Changed

- The derived jade-sql interface is now `Sql.Assignable`, was `Sql.SqlMapper`.
  It is matched by name, so jade-sql must move to the new name in the same
  release.

## [0.7.0]

### Added

- **`^Ctor` — the constructor, curried.** `Decode.succeed(Spec(_, _, _, _))`
  opens an applicative decode pipeline, and those underscores are coupled to
  the struct's arity: add a field and every pipeline needs another one,
  reported as a type mismatch at the pipeline rather than at the struct.
  `^Spec` desugars to exactly the same curried lambda, with the arity read off
  the resolved constructor. Works on variants as well as structs.

### Fixed

- **A constraint on a compound type holding a free var gets its dictionary.**
  A polymorphic function whose body needed something like
  `Decodable(List(a))`, `Decodable(Maybe(a))`, or `Decodable({ value: a })`
  crashed codegen with `undefined method 'map' for nil` — no span, no message.
  The derived instance depends on `Decodable(a)`, but only *bare* var
  constraints earn a dict param, so the enclosing function took none and the
  dep had nothing to bind to. Those deps are now surfaced as constraints of
  their own, so the function takes the dict and callers pass their witness
  down. Should a dep still find no dict in scope, codegen now fails naming the
  constraint instead of handing `nil` on to the pretty-printer.
- **The `Encodable` deriver keeps its free-var deps.** The mirror of the above,
  and quieter: `Encodable(List(a))` with `a` free dropped the derivation
  outright, and `Encode.encode(items)` compiled to Ruby referencing an
  `impl_arg` that was never bound — a `NameError` at run time, no compile-time
  complaint. The deriver now falls back to the constraint marker for a free
  var, the way `Decodable` already did.
- **A witness reaches a callee declared later in the file.** A polymorphic
  function calling a polymorphic function declared below it lost the interface
  witness — the call type-checked, then died at run time missing a dictionary
  argument. Moving the callee above the caller fixed it, which is what made
  this look like it was about lambdas. The collecting pass walks declarations
  in source order, so the callee's constraints weren't known yet; it now
  repeats until the constraint sets stop growing.
- **Anonymous records of the same shape compare equal across modules.** Each
  module hoisted its own class per record shape, so `{ x: 1 }` built in one
  module compared false against the same record built in another — both have
  type `{ x: Int }`, and it type-checks fine, so nothing warned you. A record
  decoded at a port boundary compared false against either. Shapes now resolve
  through the interned `Jade::Runtime.record` registry, named under
  `Jade::Records` so they don't inspect as belonging to whichever module
  happened to assign one first.
- **`struct Probe` in `module Probe` loads.** It type-checked clean and died at
  Ruby load with `uninitialized constant Probe::Probe::Probe` — the emitter
  wrote an unrooted `Probe::Probe[n]` from inside `module Probe`, while the
  boundary decoder three lines below already wrote `::Probe::Probe`. Unions
  escaped it because their generated constants are the variants. All three
  unrooted sites are now rooted.
- **`Eq` on a variant-less union is native equality.** A union with no variants
  represents an opaque native (`Decode.Value`, `List`), and the derived `Eq`
  was one case branch per variant plus a `_ then false` fallthrough — with no
  variants, the fallthrough was the whole function and `x == x` answered false,
  no warning, no type error.

### Changed

- Generated output moves for any code that names a constructor or builds an
  anonymous record. A project that CI-checks committed artifacts will see a
  diff.


## [0.6.0]

### Fixed

- **A `Maybe` return encodes its element.** A function returning `Maybe(T)`
  handed Ruby the internal `Data` object whenever `T` was a union, or a struct
  holding one — no error, just an un-encoded value across the boundary. The
  specialized encoder fell back to emitting the raw element when it couldn't
  specialize it, instead of declining so the generic encoder could take over;
  `decode`, five lines above it, already declined correctly. `Maybe(Int)` and
  `Maybe(SomeStruct)` were unaffected, which is why it stayed hidden — identity
  happens to be right for primitives. Both derived and hand-written
  `Encodable` instances are now applied, and a `Maybe` field of a struct
  unwraps the same way a `Maybe` return does.
- **Boundary decode errors name the right side.** `DecodeError` reported
  "Port returned a value that failed to decode" for every failure, including
  values Ruby passed *into* an exposed function, where no port is involved —
  sending you to look for a `uses` block that may not exist. Argument failures
  now read "Ruby passed a value that failed to decode"; port returns are
  unchanged.
- **A symbol-keyed Hash says so.** Structs cross the boundary as a Hash with
  string keys, so `Person.birthday(name: "Ada", age: 40)` used to fail with
  `expected String, got null` — each field independently reading `nil`, naming
  neither the cause nor the fix. It is now caught where the whole hash is in
  scope, listing the offending keys and the correction. Hashes mixing string
  and symbol keys are left alone; that is a real shape mismatch, and the
  per-field errors describe it better than a guess would.
- **A module declared under the wrong file name is now a compile error.** A
  module is keyed by the name its file implies — imports resolve `Shop.Cart`
  to `shop/cart.jd` and back — but nothing checked that against what the file
  declared. `module Cart` in `orders.jd` compiled clean and emitted a `Cart`
  module whose own type references pointed at `Orders`, so the first call
  raised `NameError: uninitialized constant Cart::Internal::Orders` far from
  the cause. It now fails at compile time, pointing at the declared name and
  offering both the rename and the move.

## [0.5.0]

### Added

- **`jade check [FILE...]`** type-checks and prints diagnostics without
  generating anything — the same front end the language server runs, exiting 1
  if there were errors. With no arguments it checks every `.jd` under the
  source root. Closes the loop for editors, CI, and anything that just edited a
  file and wants to know whether it invented a function.
- **`jade q api [MODULE|NAME]`** and **`jade q find TERM`** report the public
  surface of everything a module can call — signatures, interface constraints,
  a struct's fields, a type's variants and what it implements, an interface and
  what implements it — read out of the registry rather than the source. Source
  is the wrong thing to read: stdlib modules are written two ways (Jade in a
  heredoc, a Ruby DSL), so grepping `lib/jade/stdlib/` finds neither `List.map`
  nor half the modules' functions at all, and an extension gem's modules aren't
  in your tree to grep. Inside a project the listing spans the stdlib, the
  project's own modules and any extension gem's, each tagged with its `origin`;
  without a `jade.json` it falls back to the stdlib, so the query still answers
  from any directory. A module that won't compile is reported under `skipped`
  rather than silently missing.
- **`jade q syntax [FORM]`** reports how a form is written — `lambda` is
  `(args) -> { body }`, plus `def`, `type`, `struct`, `case`, `if`, `module`,
  `import`, `interface`, `implements`, `uses`. Signatures answer "does this
  function exist and what does it take", never "how is a lambda spelled", and
  that second question has its own wrong answers. It serves the corpus the
  editor already offers as completions, so the two can't drift; needs no
  project and reads no files.

- **`AGENTS.md`** — idiom and gotchas for writing Jade: reach for `Maybe.map` /
  `with_default` over a `case` that only unwraps and rewraps, which stdlib
  modules are auto-imported and which need an `import`, that zero-argument
  entries are values and `Dict.empty()` is a compile error, what derives (`Eq`,
  `Show`, `Encodable`, `Decodable`) and what doesn't (`Comparable`), and how
  interfaces and encode/decode fit together. Deliberately not a function list —
  that's `jade q api`, and a copy would rot. Every claim in it was checked
  against the compiler.
- The gem now ships `docs/` and `AGENTS.md`, so a project that installs
  jade-lang gets them instead of README links pointing at nothing.

### Changed

- **Decoding a row returned from a port is roughly eight times cheaper.**
  A derived decoder was a composition of combinators rebuilt and walked
  for every row; a profile put 88% of the time inside the interpreter and
  70 allocations on a four-field row. Deriving now emits one node
  carrying every key, its decoder and the constructor, applied once
  rather than curried through a closure per field; the interpreter
  returns values unwrapped, with failures on a sentinel, so nothing
  allocates a `Result` per node; and each descriptor decodes itself
  instead of being matched out of a twenty-branch `case`. A four-field
  row went 9.58 to 1.19 µs and 70 allocations to 5.
- **`Decimal`, `Clock.Instant` and `Calendar.Date` read their text form
  in Ruby** rather than parsing it through Jade-level combinators, which
  cost a fresh decoder, two `Maybe`s and a tuple for every value. The
  text forms are unchanged, so JSON output and existing ports are
  unaffected. One input changes meaning: a trailing exponent marker
  (`"825e-4e"`) used to read as `825e-4`, because splitting on every
  `"e"` dropped the empty trailing piece, and is rejected now.
- **Encoding a value back out to Ruby is cheaper by the same route.** A
  derived record encoder built a pair per field and folded the list back
  into a hash, with an intrinsic lookup for both per field per value; it
  builds the hash directly. `Encodable(Instant)` writes its string in
  Ruby next to the reader that parses it. Handing a four-field struct
  back to a Ruby caller cost 2.26 µs/row over the internal form and now
  costs 0.17 — what a caller waits for and what `Internal` measures have
  converged.
- **`Calendar.from_rata_die` is closed form.** It walked a year at a time
  to find the year, then December backwards to find the month, allocating
  a `Month` and a tuple per step through two twelve-branch `case`
  statements. It is reached from `Clock.to_iso`, `Clock.on_date` and
  `Calendar.add`, so this is not only an interop win — any Jade code
  doing date arithmetic pays it.
- The `case` completion snippet offers one `in` branch per variant instead of
  an `else` fallback. `else` is for matching literals, where exhaustiveness
  isn't available — not the default shape of a `case`.
- **A missing qualified name now suggests the one you meant.** `List.fold_left`
  answers ``help: did you mean `List.fold`?`` instead of a bare "not found" —
  the candidates are the module's exposed values, so the suggestion is drawn
  from what actually exists. Suggestions go through the alias the module was
  imported under (`L.post`, not `Ledger.post`), since that's what the call site
  can say. Local variables, types and constructors already did this;
  module-qualified access was the gap.

### Fixed

- **Operator precedence was lost inside an infix chain's operands.**
  `(1 + 2 * 3) + 0` was 9, `(10 - 4 / 2) + 0` was 3, and
  `id(1 + 2 * 3) + 0` was 9. Shunting-yard ran on a chain's own operators
  but treated every operand as an atom and returned it unfixed, so a
  grouping, a call argument, a lambda body, a ternary branch or a record
  value sitting in a chain kept the shape the parser built — left to
  right, no precedence. Standing alone the same expression was fine,
  which is why `1 + 2 * 3` and `(1 + 2 * 3)` both gave 7 and nothing
  caught it. **This changes generated output for code that hit it**: a
  project that commits generated artifacts and CI-checks them for drift
  will see a diff, and the new bytes are the correct arithmetic.
- **`Clock.on_date` reported the previous day for pre-1970 instants.**
  `Clock.floor_div` subtracted one from the quotient for a negative
  dividend with a remainder — the right correction when `/` truncates
  toward zero, which Jade's doesn't; it already floors, so it floored
  twice. `at_time` was unaffected, so `to_iso(-1)` read
  `"1969-12-30T23:59:59Z"`: the time right, the date a day out. Exact
  midnight was always correct, because the double correction only applies
  when there is a remainder.
- **Anonymous records decoded from the same shape now compare equal.**
  The derived decoder built its constructor from a bare `Data.define`,
  which mints a fresh class each time the decoder is built, so
  `{ x: 1, y: "a" }` decoded twice compared false. It resolves through
  the same interned registry record literals already used. Note this does
  not unify decoded records with *literals* in the general case —
  literals hoist to a per-module constant, so two modules with the same
  shape still get different classes.
- **The tuple decoders no longer build their constructor with
  `Method#curry`.** A curried `Method` built once and called on every
  decode corrupts the heap under GC compaction — a near-null "try to mark
  T_NONE object" crash after enough rows. It is the pattern the
  constructor-curry regression spec exists to prevent; that spec reads
  generated code, so the stdlib's own copy was invisible to it.
- **`Result.on_error` can change the error type**, as its signature has always
  claimed. The `Ok` arm handed back the input rather than rebuilding it, which
  unified the outgoing error type with the incoming one, so
  `Result(Int, String) -> Result(Int, Int)` did not compile. Recovering into a
  different error type is the reason the function takes `e -> Result(a, f)`.
- **A signature no longer renders two distinct type variables as one.** Hover
  reported `Maybe.map : (Maybe(a), (a) -> a) -> Maybe(a)` — a function unable
  to change the element type, which is a different function from the one that
  exists. Variables are identified by an id but print as a name, and nothing
  upstream keeps names distinct; rendering now re-letters a clash instead of
  emitting the same name twice. Declared names are kept where they don't
  collide, so annotated signatures read as written.

- **`docs/stdlib.md` named nine functions that don't exist.** `Char.is_digit`,
  `is_alpha`, `is_alpha_num`, `is_upper`, `is_lower` were renamed to `digit?`,
  `alpha?`, `alpha_numeric?`, `upper?`, `lower?` when predicates took the `?`
  suffix and the doc never followed; `String.contains` is `contains?`,
  `Dict.member` is `member?`, `Tuple.map_first` / `map_second` were never
  implemented, and `Decode.at` doesn't exist (`Decode.index` does). Every
  qualified name in `docs/stdlib.md` and `AGENTS.md` now checks out against the
  registry.

## [0.4.0]

### Changed

- **Port arguments are encoded on the way out**, the mirror of the return value
  being decoded on the way back. A port declared `Instant, Int -> Task(Instant,
  Never)` used to hand Ruby a live `Jade::Clock::Instant` while demanding an ISO
  string back; both sides are now the wire form. **Every argument type needs an
  `Encodable` instance** — a port taking one without it is a compile error
  (``Port `shift` cannot encode argument 1 (`Shape`): no Encodable instance``)
  rather than a value leaking Jade's internals into Ruby. Declare the argument
  as `Decode.Value` to opt out and pass it untouched. A port whose arguments are
  primitives is unaffected; one taking a struct, a `Clock`/`Calendar`/`Decimal`
  type, or a type variable now receives encoded data, so its Ruby side needs
  updating.

### Added

- `Show`, an interface rendering a value the way Jade writes it: `show(B(2))`
  is `"B(2)"`, `show(Point(3, 4))` is `"Point { x: 3, y: 4 }"`, a list shows
  through its elements. Instances ship for the primitives and derive for
  unions, structs and records — including a variant that mixes a type
  parameter with a concrete type. A function shows as `<function>` rather than
  refusing. `Never` has an instance too, so an annotated `Result(a, Never)` —
  what a port-free task returns — is showable; it raises rather than printing
  a plausible string, since it has no values to render.
- `Debug.log(label, value)` prints `label: value` to stderr and returns the
  value untouched, so it drops into a pipeline without changing it.
- `Encodable` and `Decodable` derive for tuples, `Dict` and `Set`, from their
  elements' instances — the same way `List` and `Maybe` already did. The
  combinators (`Encode.tuple`, `Decode.dict`, …) existed all along; nothing
  resolved them, so a `(String, Int)` port argument or a `Task(Dict(k, v), e)`
  arm was rejected for want of an instance. A tuple crosses as a positional
  array, a dict as `[key, value]` pairs, a set as an array that drops
  duplicates on the way back. Adds the two functions the set instances needed,
  `Encode.set` and `Decode.set`.
- `Encodable` and `Decodable` instances for `Decode.Value`, both the identity,
  plus the `Decode.value` and `Encode.value` functions behind them. `Value` is
  the un-decoded value, and it opted out of conversion only as a whole arm or
  argument: `List(Value)`, `Maybe(Value)`, and a struct with a `Value` field
  had no instance to derive from and were rejected at the boundary.
- A parse error inside a `uses`, `interface`, or `implements` block where the
  entries are separated by newlines instead of commas says so, instead of only
  reporting the next entry as an unexpected token.

### Fixed

- `Eq` derives for a union whose variants carry concrete types. `B(1) == B(1)`
  over `type Box = B(Int) | Empty` took the compiler down with a
  `NoMatchingPatternError`; `Just(1) == Just(1)` only worked because `Maybe`'s
  payload is a type parameter. Variants mixing a parameter with a concrete
  type derive too.
- Diagnostic source excerpts are sliced by byte offset. Spans and line starts
  are the lexer's byte offsets, but the excerpt was cut and measured in
  characters, so one multi-byte glyph anywhere earlier in the file shifted every
  later excerpt and its caret — `def notify_channel(…)` printed as
  `f notify_channel(…)`.
- Exhaustiveness checking no longer collapses when the scrutinee is a tuple.
  `case (a, b)` over two `Maybe`s reported `Missing cases: (_, _)` with all four
  arms present, and the `else` that silenced it hid genuinely missing cases from
  then on. Two bugs: a tuple's element types were replaced with fresh type
  variables, and specializing on a constructor dropped the types of every column
  after it. A constructor the first column never mentions is now answered from
  the rows that would have covered it, which is also what keeps a recursive type
  from expanding forever — the recursion guard that used to do that job is gone,
  and with it the false "exhaustive" verdicts it caused on any second column.
- The missing-constructor diagnostic tells you which `exposing` list is missing
  the `(..)`. When the defining module already exposes `Route(..)` and it's the
  importer's `import Routes exposing (Route)` that brought in the type alone, it
  no longer sends you to the wrong file. It also fires for a variant whose name
  differs from its type's (`Home` of `Route`), which previously got no hint.

## [0.3.1]

### Fixed

- A module whose dependency failed to compile is no longer type checked. It
  reached for bindings the broken module never produced and raised through the
  compiler, naming the importer rather than the module at fault, and the
  original error was never reported. Dependents now say which dependency
  failed, and modules broken independently of each other are all still
  reported.
- The load-path line at the top of every compiled entry module appends the
  application's `lib` instead of prepending it. At position 0 it shadowed, for
  the whole process, any gem sharing a name with a directory under `lib` —
  `sidekiq/`, `sentry/`, `warden/`. The line exists so `uses App::Thing` can
  resolve `lib/app/thing.rb`; it never needed to outrank gems.

## [0.3.0]

### Changed

- `jade fmt` keeps blank lines between leading comment blocks. A section
  banner separated from the declaration below it stays separated, where it
  used to be pulled into that declaration's doc comment. **Formatted output
  differs from 0.2.0**, so a format check in CI reports diffs on the first
  run after upgrading.
- `jade q` requires a `jade.json` and reports what to write when there isn't
  one. It previously assumed the source root was the working directory, which
  could not work for a project whose imports come from extension gems — it
  failed later, inside the loader, instead.
- `Compiler::Config#source_root=` takes one root and refuses a list of more
  than one. A list was accepted before but only its first entry was ever
  read.

### Added

- `jade.json` manifest, read by `Jade::Project`, giving tools that run
  outside the application — the CLI, an editor's language server, a codegen
  task — the source roots and extension gems that previously existed only as
  Ruby run at boot. `Compiler::Config` seeds from it, and a `Jade.setup`
  block still wins.
- `Encodable` and `Decodable` derive for unions whose variants take no
  arguments, using the variant name in snake_case as the wire form. A union
  mixing nullary and argument-carrying variants does not derive: adding an
  argument to one variant would otherwise change the encoding of all of them.
- `SqlMapper` derives for unions whose variants each carry exactly one value,
  naming the column after the variant. Inert unless jade-sql is loaded.
- Placeholders in keyed calls: `Point(x: _, y: n)` partially applies the way
  `Point(_, n)` already did. Blanks bind in the order the fields are written.
- `Source` records the root it was loaded from, so an application module and
  one shipped by an extension gem can be told apart without a name list.
- `UsageAnalysis::Reference` records the declaration each reference was made
  from, including references with no source range and those inside an
  `implements` block.

### Fixed

- An interface method can be referenced as a value where the expected type
  determines the instance. `Decode.field("k", Decode.decoder)` type-checked
  and then failed in codegen, because the method's constraint named a
  variable that appeared in nothing and so could never be bound.
- A constraint that resolves to a concrete type is discharged rather than
  dropped when a binding is generalized. An interface method referenced
  outside an argument position previously compiled to a bare name and failed
  at runtime.
- Deriving reports which type it could not derive instead of raising through
  the compiler. A struct with one un-derivable field took the whole run down
  with a Ruby backtrace, which `tolerant: true` did not contain.
- `jade fmt` no longer drops comments. A comment above the first declaration
  in a module attached to a node nothing renders, so a module's first
  declaration could never carry a doc comment.
- A type sharing its name with its module no longer generates code that
  resolves the wrong constant.

## [0.2.0]

### Added

- `Decimal` stdlib module: exact base-10 decimals (`coefficient * 10 ^
  exponent`) for money and rates without `Float` rounding. Opaque type built
  with `of(coeff, exp)`, `scaled(unscaled, scale)`, or `parse("0.0825")`;
  arithmetic via `Numeric` (`+` `-` `*` `/`) plus `div` (scaled, half-up),
  `round`, `to_i`, `to_float`, `coefficient`, `exponent`. Decodes/encodes to a
  `<mantissa>e<exponent>` JSON string. (Supersedes jade-sql's `Sql.Decimal`.)

## [0.1.1]

### Fixed

- Generated constructors no longer use Ruby's `Method#curry`, which corrupts
  the heap under GC compaction (an intermittent near-null SIGSEGV,
  "try to mark T_NONE object") when an auto-derived record decoder builds a
  constructor once and calls it on every decode. Construction now goes through
  a GC-safe `Jade::Runtime.curry` (plain procs + an array). Surfaced as a
  segfault decoding records with non-specializable fields (e.g. `Calendar.Date`)
  at volume.

## [0.1.0]

Initial release.

- Functional, type-safe language that compiles to readable Ruby.
- Hindley–Milner type inference with union types, records, and pattern
  matching.
- Standard library (`Maybe`, `Result`, `List`, `String`, `Dict`, and more).
- Interfaces with instance resolution (`Eq`, `Comparable`).
- Ruby interop with typed boundaries (`uses ... with`).
- `jade` CLI dispatcher: `fmt`, `lsp`, `q`.
- Language server and headless query interface for editor/agent tooling.

[Unreleased]: https://github.com/agustinrhcp/jade/compare/v0.6.0...HEAD
[0.6.0]: https://github.com/agustinrhcp/jade/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/agustinrhcp/jade/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/agustinrhcp/jade/compare/v0.3.1...v0.4.0
[0.3.1]: https://github.com/agustinrhcp/jade/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/agustinrhcp/jade/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/agustinrhcp/jade/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/agustinrhcp/jade/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/agustinrhcp/jade/releases/tag/v0.1.0
