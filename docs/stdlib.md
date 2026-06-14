# Standard library

Every module's source lives in [`lib/jade/stdlib/`](../lib/jade/stdlib/) — short,
readable Ruby. This is a map of what's where.

| Module | What's there |
|--------|--------------|
| `Basics` | The built-in interfaces — `Eq`, `Comparable`, `Appendable`, `Mappable`, `Chainable` — plus the `Ordering` type (`LT` / `EQ` / `GT`) and `Never`. `++` works on `String`, `List`, and `Bytes` via `Appendable`. |
| `Maybe` | Optional values without `nil`: `Just(a)` / `Nothing`, with `map`, `and_then`, `with_default`. |
| `Result` | Errors as values, no exceptions: `Ok(a)` / `Err(e)`, with `map`, `and_then`, `map_error`, `on_error`, `sequence`. |
| `List` | Immutable lists: `map`, `filter`, `fold`, `zip`, `sort`, `length`, `range`, `head`, `tail`, `take`, `drop`, … |
| `String` | Text: `length`, `reverse`, `split`, `trim`, `to_int`, `contains`, `uncons`, `cons`, `from_char`, `map`. |
| `Char` | Character predicates and codes: `to_code`, `from_code`, `is_digit`, `is_alpha`, `is_alpha_num`, `is_upper`, `is_lower`. |
| `Tuple` | Pair accessors: `first`, `second`, `map_first`, `map_second`. |
| `Task` | Side-effecting actions: `succeed`, `fail`, `map`, `and_then`, `on_error`, `sequence`. See [interop.md](interop.md) for how Tasks cross the Ruby boundary. |
| `Decode` | Parse JSON / Ruby data into typed values: `string`, `int`, `float`, `bool`, `list`, `field`, `at`, `succeed`, `required`, `optional`, `nullable`, `map`, `and_then`. Auto-derived for `struct` types. See [json.md](json.md). |
| `Decode.Params` | PATCH-style decoders: only fields present in the input appear in the output, missing fields don't error. For partial-update endpoints. |
| `Encode` | Symmetric to `Decode`: `string`, `int`, `float`, `bool`, `list`, `object`. Auto-derived for `struct` types via `Encodable`. |
| `Dict` | Immutable key-value map with structural equality: `empty`, `get`, `member`, `insert`, `update`, `remove`, `keys`, `values`, `to_list`, `from_list`, `map`, `filter`, `fold`, `union`, `merge`. |
| `Set` | Immutable set: `empty`, `insert`, `remove`, `member?`, `to_list`, `from_list`, `map`, `filter`, `fold`, `union`, `intersect`, `diff`. |
| `Bytes` | Opaque byte buffer: `empty`, `width`, `from_list` / `to_list`, `from_string` / `to_string`. Implements `Eq` and `Appendable`. |
| `Calendar` | Dates and date arithmetic: `Date`, `today`. Days, months, years; no time of day — use `Clock`. |
| `Clock` | Timestamps and monotonic timing: `Instant`, `now`. Sub-second precision; the bridge to wall-clock time. |

Stdlib operations compile inline rather than through a runtime dispatch layer,
so the generated Ruby calls the underlying operation directly.
