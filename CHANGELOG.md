# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- A parse error inside a `uses`, `interface`, or `implements` block where the
  entries are separated by newlines instead of commas says so, instead of only
  reporting the next entry as an unexpected token.

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

[Unreleased]: https://github.com/agustinrhcp/jade/compare/v0.3.1...HEAD
[0.3.1]: https://github.com/agustinrhcp/jade/compare/v0.3.0...v0.3.1
[0.3.0]: https://github.com/agustinrhcp/jade/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/agustinrhcp/jade/compare/v0.1.1...v0.2.0
[0.1.1]: https://github.com/agustinrhcp/jade/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/agustinrhcp/jade/releases/tag/v0.1.0
