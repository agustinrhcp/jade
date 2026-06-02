# Standard library

Every module's source lives in [`lib/jade/stdlib/`](../lib/jade/stdlib/) — short, readable Ruby. This is a map of what's where.

## At a glance

| Module          | What's there |
|-----------------|--------------|
| `Basics`        | Interfaces (`Eq`, `Comparable`, `Appendable`, `Mappable`, `Chainable`) and `Never` |
| `Maybe`         | Optional values without `nil` |
| `Result`        | Errors as values, no exceptions |
| `List`          | Immutable list operations |
| `String`        | Text manipulation |
| `Char`          | Character predicates and codes |
| `Tuple`         | Pair accessors |
| `Task`          | Side-effecting actions |
| `Decode`        | Parse JSON / Ruby data into typed values |
| `Decode.Params` | Partial / PATCH-style input decoders |
| `Encode`        | Serialize Jade values back to JSON, auto-derived for structs |
| `Dict`          | Immutable key-value map |
| `Set`           | Immutable set |
| `Bytes`         | Opaque byte buffer |
| `Calendar`      | Dates |
| `Clock`         | Timestamps and monotonic timing |

## Notable contents

- **`Basics`** — the built-in interfaces (`Eq`, `Comparable`, `Appendable`, `Mappable`, `Chainable`), the `Ordering` type (`LT`, `EQ`, `GT`), and `Never`. `++` works on `String`, `List`, and `Bytes` because they have `Appendable`.
- **`Maybe`** — `Just(a)` / `Nothing`, plus `map`, `and_then`, `with_default`. Use this instead of `nil`.
- **`Result`** — `Ok(a)` / `Err(e)`, plus `map`, `and_then`, `map_error`, `on_error`, `sequence`. Use this instead of raising for recoverable errors.
- **`List`** — `map`, `filter`, `fold`, `zip`, `sort`, `length`, `range`, `head`, `tail`, `take`, `drop`, etc.
- **`String`** — `length`, `reverse`, `split`, `trim`, `to_int`, `contains`, `uncons`, `cons`, `from_char`, `map`.
- **`Char`** — `to_code`, `from_code`, `is_digit`, `is_alpha`, `is_alpha_num`, `is_upper`, `is_lower`.
- **`Tuple`** — `first`, `second`, `map_first`, `map_second`.
- **`Task`** — `succeed`, `fail`, `map`, `and_then`, `on_error`, `sequence`. See [interop.md](interop.md) for how Tasks cross the Ruby boundary.
- **`Decode`** — pipeline-style decoders. `string`, `int`, `float`, `bool`, `list`, `field`, `at`, `succeed`, `required`, `optional`, `nullable`, `map`, `and_then`. Auto-derived for `struct` types via `Decodable`.
- **`Decode.Params`** — PATCH-style decoder builder. Only fields present in the input show up in the output; missing fields don't error. Useful for partial-update endpoints.
- **`Encode`** — symmetric to `Decode`. `string`, `int`, `float`, `bool`, `list`, `object`. Auto-derived for `struct` types via `Encodable`.
- **`Dict`** — immutable map with structural equality. `empty`, `singleton`, `get`, `member`, `insert`, `update`, `remove`, `size`, `is_empty`, `keys`, `values`, `to_list`, `from_list`, `map`, `filter`, `fold`, `union`, `merge`.
- **`Set`** — immutable set. `empty`, `singleton`, `insert`, `remove`, `member?`, `size`, `empty?`, `to_list`, `from_list`, `map`, `filter`, `fold`, `union`, `intersect`, `diff`.
- **`Bytes`** — opaque byte buffer. `empty`, `width`, `from_list` / `to_list`, `from_string` / `to_string`. Implements `Eq` and `Appendable`.
- **`Calendar`** — `Date`, `today`, date arithmetic. Days, months, years; no time-of-day (use `Clock` for that).
- **`Clock`** — `Instant`, `now`, monotonic timing. Sub-second precision; the bridge to wall-clock time lives here.
