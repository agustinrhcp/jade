# jade-sql

Type-safe SQL for Jade. Builds queries and mutations from a generated
schema, renders them to `(String, List(Value))`, and runs them against
ActiveRecord via a Task port that auto-decodes rows into typed Jade
structs.

## Install

```ruby
# Gemfile
gem 'jade',     path: '/path/to/jade'
gem 'jade-sql', path: '/path/to/jade/extensions/jade_sql'
```

To execute queries at runtime, opt into the AR-backed task port:

```ruby
# config/initializers/jade_sql.rb (or similar)
require 'jade-sql/runtime'
```

To get the rake task for schema generation:

```ruby
# Rakefile (or lib/tasks/jade.rake)
load Gem.find_files('jade-sql/tasks.rake').first
```

## Generate `schema.jd` from `db/structure.sql`

```bash
bundle exec rake jade:schema
```

Reads `db/structure.sql`, writes `app/jade/schema.jd`. Knobs:

| ENV     | Default              | What                                      |
|---------|----------------------|-------------------------------------------|
| INPUT   | `db/structure.sql`   | source DDL file                           |
| OUTPUT  | `app/jade/schema.jd` | destination                               |
| TABLES  | (all)                | comma-separated whitelist                 |
| MODULE  | `Schema`             | module name in the generated file         |

Multiple schemas in one app (e.g. for gradual migration):

```bash
bundle exec rake jade:schema \
  TABLES=invoices,charges \
  MODULE=Schema.Billing \
  OUTPUT=app/jade/schema/billing.jd
```

Type map: `bigint`/`integer`/`smallint` → `Int`, `varchar`/`text`/`char` →
`String`, `boolean` → `Bool`, `jsonb`/`json` → `Decode.Value`, `date` →
`Calendar.Date`, `timestamp` → `Clock.Instant`, `uuid` → `Uuid` (from
`Sql.Uuid`). Unknown types fail loudly with the table+column name.
`decimal`, `bytea` aren't mapped yet — see
[TODO](#known-limitations--todos).

For each table, the generator emits:

```jade
struct PatientsCols       = { id: Expr(Int), name: Expr(String), ... }
struct MaybePatientsCols  = { id: Expr(Maybe(Int)), name: Expr(Maybe(String)), ... }

def patients() -> Table(PatientsCols, MaybePatientsCols)
  table("patients", "patients", ..., ["id"])
end
```

Strict cols mirror NOT NULL constraints; the maybe version wraps every
field in `Maybe` for left-join projections. The default alias is the
table name; override per-call with `aliased` (see joins below).

## Build queries

```jade
import Sql exposing(Expr, column, eq, is_not_null, to_expr)
import Sql.Query exposing(Q, Selector, from, join, where, select, field, to_sql)
import Schema exposing(patients, orders)

struct Row = { id: Int, name: String, total: Int }

def rich_patients() -> Q(Selector(Row))
  p <- from(patients())
  o <- join(orders(), (o) -> { p.id |> eq(o.person_id) })

  select(Row(_, _, _))
  |> field(p.id)
  |> field(p.name)
  |> field(o.total)
  |> where(p.age |> is_not_null)
  |> where(o.total |> eq(to_expr(100)))
end
```

Notes:
- `<-` is bind-chain — exposes each joined table's columns to the rest of
  the chain. `p` and `o` are the projected column accessors.
- `select(Row(_, _, _))` uses placeholders. Each subsequent `field(...)`
  fills one slot in declared order.
- `to_sql(q)` returns `(String, List(Value))`.

### Sorting and grouping

`order(q, e)` appends an ASC term; `order_desc(q, e)` appends a DESC
term. `group(q, e)` appends a GROUP BY column. Repeated calls
accumulate in declared order:

```jade
import Sql.Query exposing(order, order_desc, group)

rich_patients()
  |> group(p.country)
  |> group(p.city)
  |> order_desc(o.total)
  |> order(p.name)
-- ... GROUP BY p.country, p.city ORDER BY o.total DESC, p.name
```

Aggregate functions (`COUNT`, `SUM`, ...) and `HAVING` aren't built in
yet — for those, use the raw-SQL escape hatch (`execute_*`) until
they land.

### Pagination

`limit(q, n)` and `offset(q, n)` append `LIMIT`/`OFFSET` clauses. Both
take a plain `Int` and render inline (not as parameters), so the
returned `List(Value)` is unaffected:

```jade
import Sql.Query exposing(limit, offset)

def page(n: Int) -> Q(Selector(Row))
  rich_patients()
    |> limit(20)
    |> offset(n * 20)
end
```

Calling `limit`/`offset` more than once overrides the previous value
(last call wins).

### Self-joins

The schema's default alias = table name. Override with `aliased`:

```jade
p <- from(patients())
c <- patients() |> aliased("c") |> join((c) -> { p.id |> eq(c.parent_id) })
```

### Left joins with nullable views

`left_join` switches the joined table to its maybe-column view:

```jade
p <- from(persons())
o <- left_join(orders(), (o) -> { p.id |> eq(o.person_id) })
-- `o` is MaybeOrdersCols; field types are Expr(Maybe(Int)) etc.
```

For predicates that lift a non-null column into the nullable side,
`nullable`:

```jade
p.id |> nullable |> eq(o.person_id)  -- Expr(Int) → Expr(Maybe(Int))
```

## Build mutations

Define codec interfaces for your domain type:

```jade
import Sql exposing(Assignment, SqlMapper, Identified, assign)
import Encode exposing(encode)
import Decode exposing(Value)

struct Patient = { id: Int, name: String, balance: Int }

implements SqlMapper(Patient) with
  to_assigns: encode_patient
end

implements Identified(Patient) with
  pk_values: encode_patient_pk
end

def encode_patient(p: Patient) -> List(Assignment)
  [
    assign("name",    p.name),
    assign("balance", p.balance)
  ]
end

def encode_patient_pk(p: Patient) -> List(Value)
  [encode(p.id)]
end
```

`assign(col, value)` is shorthand for
`Assignment(col, "?", [encode(value)])`. For non-`?` placeholders
(e.g. `"balance + ?"` for increments) use the `Assignment(...)`
constructor directly.

Then the mutation API works on values directly:

```jade
import Sql.Mutation exposing(insert, update, delete, insert_all, update_all, delete_all, to_sql)

p |> insert(patients()) |> to_sql        -- INSERT INTO patients (name, balance) VALUES (?, ?)
p |> update(patients()) |> to_sql        -- UPDATE patients SET name = ?, balance = ? WHERE id = ?
p |> delete(patients()) |> to_sql        -- DELETE FROM patients WHERE id = ?

[p1, p2] |> insert_all(patients()) |> to_sql

patients()
|> update_all((p) -> { p.balance |> eq(to_expr(0)) },
              (p) -> { [p.archived |> set_(to_expr(True))] })
|> to_sql

patients()
|> delete_all((p) -> { p.archived |> eq(to_expr(True)) })
|> to_sql
```

### RETURNING

`returning` is the mutation-side counterpart to `select` for queries.
It takes a closure that receives the table's column accessors and
builds a `Selector` projecting them into a target type:

```jade
import Sql exposing(Selector, select, field)
import Sql.Mutation exposing(insert, returning, to_sql)

-- INSERT INTO patients (name, balance) VALUES (?, ?) RETURNING p.id, p.name, p.balance
np
|> insert(patients())
|> returning((p) -> {
  select(Patient(_, _, _))
  |> field(p.id)
  |> field(p.name)
  |> field(p.balance)
})
|> to_sql                    -- or |> run_one to execute
```

Combined with `Sql.Run.run_one`, the inserted row decodes into the
target struct:

```jade
def create(np: NewPatient) -> Task(Patient, SqlError)
  np |> insert(patients()) |> returning((p) -> {
    select(Patient(_, _, _))
    |> field(p.id)
    |> field(p.name)
    |> field(p.balance)
  })
  |> run_one
end
```

`insert` / `update` / `delete` need `SqlMapper(a)` + `Identified(a)`.
`insert_all` needs only `SqlMapper`. `update_all`/`delete_all` build
the SET / WHERE clauses directly from the column accessors — no codec.

`SqlMapper` is also implemented for `List(Assignment)` itself, so you
can pass an assignment list to `insert` directly when you've already
built it (e.g. from a sparse changeset):

```jade
sparse_changes
|> List.and_then(field_to_assigns)
|> insert(_, patients())
```

### Timestamps

`Mutation.insert`/`update` emit only the columns you explicitly set —
they don't auto-fill `created_at` / `updated_at`. Two ways to handle
NOT NULL timestamp columns:

**1. DB-side defaults (recommended).** Let the schema own timestamp
policy:

```sql
ALTER TABLE patients ALTER COLUMN created_at SET DEFAULT now();
ALTER TABLE patients ALTER COLUMN updated_at SET DEFAULT now();
```

The mutation builder stays a thin SQL emitter; the DB fills in
defaults for any column the INSERT didn't list.

**2. Explicit injection in app code.** When you want Jade to carry the
timestamp values (Rails-style), tack assignments onto the list before
the call:

```jade
def with_timestamps(assigns: List(Assignment), now: Instant)
    -> List(Assignment)
  assigns ++ [assign("created_at", now), assign("updated_at", now)]
end

def create(p: Patient, now: Instant) -> Mutation(Int, PatientsCols)
  encode_patient(p)
    |> with_timestamps(now)
    |> insert(_, patients())
end
```

### UUIDs

`Sql.Uuid` defines an opaque `Uuid` type plus generation/parse helpers.
The schema generator emits `Uuid` for `uuid` columns:

```jade
import Sql.Uuid exposing (Uuid, v4, v7, parse, to_string)

-- DB-side generation (recommended for PKs):
-- ALTER TABLE patients ALTER COLUMN id SET DEFAULT gen_random_uuid();

-- App-side generation (idempotency keys, child-row pre-linking, …):
def make_request_id -> Task(Uuid, Never)
  v7    -- time-ordered, friendlier to DB index locality than v4
```

`v4` and `v7` are zero-arg Tasks (`def v4 -> Task(Uuid, Never)`); call
them without parens. `parse(String) -> Maybe(Uuid)` accepts the
canonical 8-4-4-4-12 form (case-insensitive, stored lowercase).
`to_string(Uuid) -> String` for the canonical text form.

`Encodable(Uuid)` and `Decodable(Uuid)` impls are in the module, so
Uuids flow through SQL params, RETURNING decoding, and JSON boundaries
without extra wiring.

## Run queries and mutations

`Sql.Run` exposes the runners as a polymorphic interface over anything
`Renderable` (Q, Mutation, ...) plus a raw-SQL escape hatch:

```jade
import Sql.Run exposing(SqlError, run_count, run_one, run_many, execute_count, execute_one, execute_many)

-- Affected count for INSERT/UPDATE/DELETE
def update_paul(p: Patient) -> Task(Int, SqlError)
  p |> update(patients()) |> run_count
end

-- A single row, decoded into Patient
def find(id: Int) -> Task(Patient, SqlError)
  patient_by_id_query(id) |> run_one
end

-- Many rows, decoded
def all() -> Task(List(Patient), SqlError)
  all_patients_query() |> run_many
end

-- Raw SQL escape hatch — bypass the typed builders
def count_active() -> Task(Int, SqlError)
  execute_count(("SELECT COUNT(*) FROM patients WHERE archived = ?", [Encode.encode(False)]))
end
```

`run_count` / `run_one` / `run_many` accept anything that implements
`Sql.Renderable` (Q, Mutation). Internally they call `render(r) |> execute_*`,
where `render` is the interface method that resolves to each container's
`to_sql`. For raw SQL, skip the builder and call `execute_*` directly with
a `(String, List(Value))` pair.

Row decoding is automatic — the caller's type (`Patient`, `List(Patient)`)
threads its `Decodable` instance into the polymorphic port. The runtime
returns plain Ruby hashes from AR, and they're decoded into typed structs
at the boundary.

`SqlError` variants:
- `DbError(String)` — AR `StatementInvalid` message
- `NotFound` — `run_one` with zero rows
- `NotUnique` — `run_one` with more than one row

A decode mismatch (column type doesn't match the field type) raises on
the Ruby side rather than becoming a recoverable error — schema drift is
a programmer bug.

## Known limitations / TODOs

- **Type mappings missing:** `decimal`/`numeric` (needs a Decimal type),
  `bytea` (binary).
- **RETURNING is column-name-list only.** Expression returning
  (e.g. `RETURNING id + 1`) needs raw SQL.
- **No transactions.** Each `run_*` runs in its own AR connection
  invocation. `ActiveRecord::Base.transaction` works at the Ruby layer
  but isn't exposed in Jade yet.
- **No preloads (eager-loading).** Building a `Patient` together with
  its `orders` requires two queries and manual zipping. A DataLoader
  layer is planned — see `~/vault/claude/jade/notes/preloads-in-jade.md`.
- **`update_all`/`delete_all` predicates use aliased columns.** The SQL
  ends up with `p.balance = ?` rather than `balance = ?`. Cosmetic for
  most DBs; the SQL is correct.
- **`?` inside string literals.** The runtime translates `?` to `$n`
  on Postgres for AR's `exec_query`/`exec_update` path; a literal `?`
  inside a string in user-supplied SQL would be mis-translated. Fix
  when someone hits it.

## Testing without a DB

The Task dispatcher can be stubbed. From RSpec:

```ruby
require 'jade/tasks/rspec'

describe MyApp do
  include Jade::Tasks::RSpec

  it 'queries patients' do
    all_calls_to(JadeSql::Runtime.port_execute_many) do |t, _pair|
      t.ok([
        { "id" => 1, "name" => "Paul", "balance" => 100 }
      ])
    end

    expect(MyApp.list.call.run).to be_ok
  end
end
```

The three ports are `port_execute_count`, `port_execute_one`,
`port_execute_many` — `Sql.Run.execute_*` and `Sql.Run.run_*` ultimately
dispatch through these. Stub them with
`all_calls_to(JadeSql::Runtime.port_execute_*) { |t, pair| ... }`.

## File layout

```
extensions/jade_sql/
  jade-sql.gemspec
  lib/
    jade-sql.rb              # registers the extension
    jade-sql/
      sql.jd                 # Sql module — Value, Expr, Table, codec interfaces
      sql/
        query.jd             # Sql.Query — bind-chain Q, from/join/where/select
        mutation.jd          # Sql.Mutation — codec-driven insert/update/delete
        run.jd               # Sql.Run — Task ports + run_count/one/many
      runtime.rb             # AR-backed task port (opt-in)
      tasks.rake             # jade:schema task
      bin/
        generate_schema.rb   # schema generator (CLI + library)
  README.md
```
