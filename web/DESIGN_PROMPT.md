# Jade landing page — design prompt

Copy everything below the line into a design/frontend model. It is written
to produce a single static `index.html` + `style.css`, no framework, so the
output can be judged on looks alone and later ported into Astro.

All Jade source and all compiled Ruby below is real output from the compiler
at `~/code/ruby/jade` (master) — that checkout is the syntax source of truth,
not this worktree's `examples/` or `README.md`, both of which are stale.

---

Design and build a single-page landing site for **Jade**, a statically typed
functional language that compiles to readable Ruby.

Deliver one `index.html` and one `style.css`. No frameworks, no build step,
no JS beyond a few lines for the example tabs. Fonts from Google Fonts are
fine. It must look finished, not wireframed.

## The positioning

Jade is a **compilation layer, not a platform**. Everything on this page
should reinforce that it goes *into* an existing Ruby codebase rather than
replacing one: you compile the modules where types earn their keep, call
them from Ruby as ordinary constants, and leave the rest of the app alone.
It is not a framework, not a runtime you build your app inside, and not an
all-or-nothing migration.

Three claims carry that, in order of importance:

1. **It's per-module.** You add one `.jd` file to an app that already
   exists. There's no "Jade app."
2. **The output is Ruby you'd have written.** Which is why the diptych is
   the hero — it's the proof, not an illustration.
3. **The boundary is typed in both directions**, so the layer has a real
   edge rather than leaking into everything it touches.

**Honesty constraints — these are load-bearing, do not soften them:**

- There *is* a runtime. Generated files open with `require 'jade/runtime'`.
  "Thin" means a small adoption surface — one gem (`jade-lang`), one
  transitive dependency (`base64`), plain Ruby out — **not** "no runtime."
  Never write "zero runtime", "no dependencies", or "just Ruby."
- Do not claim adoption numbers, production users, benchmarks, or
  performance wins. The README says the output is YJIT-friendly but
  unbenchmarked; the page must not imply otherwise.
- Do not call it a Ruby "replacement" or imply Ruby is the problem. The
  pitch is additive.

## Tone

Minimalist and confident. Lots of whitespace. Editorial rather than
startup-marketing: no gradient blobs, no glassmorphism, no floating 3D
mockups, no badge soup, no "Trusted by" logos, no emoji. Closer to a
well-set essay than to a SaaS homepage. The code is the hero — everything
else recedes.

## Palette

Warm off-white canvas, near-black text, jade green used sparingly as the
single accent. Code panes are dark and sit on the light page like inset
terminals.

```
--paper        #FBFAF7   page background
--paper-sunk   #F3F2ED   alternating section band
--ink          #121815   body text
--ink-soft     #5F6B65   secondary text, captions
--rule         #E2E0D9   hairlines, borders
--jade         #00A86B   primary accent (links, buttons, arrow, underlines)
--jade-deep    #04724D   hover / pressed
--jade-wash    #E7F4EE   tint fills
--console      #0C1411   code pane background
--console-ink  #D8E3DD   code pane default text
--jade-bright  #3DDC97   accent on dark (keywords, prompt glyph)
```

Rules: jade accent must never exceed roughly 5% of any viewport. No jade
backgrounds on large blocks. Never put jade text on jade wash.

## Type

- Headings: **Instrument Serif**, regular weight, tight leading, no letter
  spacing tricks. Big — the hero headline should be 56–72px on desktop.
- Body and UI: **Inter**, 16–17px, 1.6 line height, max ~62ch measure.
- Code: **JetBrains Mono**, 13–14px, 1.65 line height.

If a variant is wanted, an all-grotesk version (Inter for headings too, at
tighter tracking) is acceptable — but ship the serif version first.

## Layout

Single column, 1080px max content width, generous vertical rhythm
(96–128px between sections). Hairline `--rule` dividers instead of shadows
or cards wherever a boundary is needed. Everything left-aligned; nothing
centered except the footer.

## Sections, in order

### 1. Hero

- Small wordmark `jade` top-left in the header, mono, with a jade dot or
  jade underline. Right side: `Docs`, `Tooling`, `GitHub` as plain text
  links — the first two are in-page anchors.
- Headline: **A functional compilation layer for the Ruby you already
  have.**
- Subhead, two lines, `--ink-soft`: Write the parts that deserve types in
  a statically typed functional language. Compile them to Ruby you'd have
  written yourself, and call them from the app you already have.
- One more line beneath, smaller, mono, `--ink-soft`: `one gem · per-module
  · the compiled Ruby is yours`
- Two CTAs: primary is a solid jade button `Read the tour`; secondary is a
  text link with a jade underline, `See it compile ↓`.
- Directly beneath, no section break: the diptych. It should be visible or
  nearly visible above the fold. The whole pitch is that one image.

### 2. The diptych — the centerpiece

Two dark console panes side by side, equal width, ~24px gutter. Left is
Jade source, right is the Ruby it compiles to.

Pane chrome: a thin top bar in a slightly lighter shade than the pane, with
a mono filename on the left (`custom_types.jd` / `custom_types.rb`) and
nothing else. No macOS traffic lights, no window shadows. Square corners or
a 6px radius, pick one and hold it everywhere.

Between the panes, vertically centered, a small jade `→` in a circle with a
1px jade ring, sitting on the page background and overlapping both panes.
On mobile the panes stack and the arrow rotates to `↓`.

Above the panes, a row of small mono tabs to switch examples — inactive
tabs are `--ink-soft` plain text, the active tab is `--ink` with a 2px jade
underline. No pill backgrounds. Three tabs: **Pattern matching**,
**Pipelines**, **Records**.

Both panes must scroll independently on overflow, and the pair must never
cause horizontal page scroll.

Use exactly this content for the first tab (real compiler output — do not
rewrite it):

Left pane, `custom_types.jd`:

```
module CustomTypes exposing (area, describe, perimeter)

type Shape
  = Circle(Float)
  | Rectangle(Float, Float)
  | Triangle(Float, Float, Float)


def area(shape: Shape) -> Float
  case shape
  in Circle(r) then 3.14159 * r * r
  in Rectangle(w, h) then w * h
  in Triangle(a, b, c)
    s = (a + b + c) / 2.0
    s * (s - a) * (s - b) * (s - c)
  end
end


def describe(shape: Shape) -> String
  case shape
  in Circle(_) then "circle"
  in Rectangle(_, _) then "rectangle"
  in Triangle(_, _, _) then "triangle"
  end
end
```

Right pane, `custom_types.rb`:

```ruby
module CustomTypes
  extend self

  Circle = Data.define(:_1) do
    def circle?; true; end
    def rectangle?; false; end
    def triangle?; false; end
  end

  Rectangle = Data.define(:_1, :_2) do
    def circle?; false; end
    def rectangle?; true; end
    def triangle?; false; end
  end

  module Internal
    extend self

    def area(shape)
      case shape
      in CustomTypes::Circle(r) then ((3.14159 * r) * r)
      in CustomTypes::Rectangle(w, h) then (w * h)
      in CustomTypes::Triangle(a, b, c) then
        s = ((((a + b) + c)) / 2.0)
        (((s * ((s - a))) * ((s - b))) * ((s - c)))
      end
    end

    def describe(shape)
      case shape
      in CustomTypes::Circle(_) then "circle"
      in CustomTypes::Rectangle(_, _) then "rectangle"
      in CustomTypes::Triangle(_, _, _) then "triangle"
      end
    end
  end
end
```

For the other two tabs, reuse these pairs:

**Pipelines** — `maybe_examples.jd`:

```
def safe_divide(a: Int, b: Int) -> Maybe(Int)
  case b == 0
  in True then Nothing
  in False then Just(a / b)
  end
end


def find_first(list: List(Int), predicate: Int -> Bool) -> Maybe(Int)
  List.filter(list, predicate) |> List.head
end
```

compiling to:

```ruby
def safe_divide(a, b)
  case (b == 0)
  in true then Jade::Maybe::Nothing[]
  in false then Jade::Maybe::Just[(a / b)]
  end
end

def find_first(list, predicate)
  list.filter(&predicate)
      .then { |xs| xs.empty? ? Jade::Maybe::Nothing[] : Jade::Maybe::Just[xs.first] }
end
```

The right pane's `find_first` is one long line in the raw output; wrapping it
onto two lines as shown is the only editorial liberty taken anywhere in this
document.

**Records** — `records.jd`:

```
struct Person = {
  name: String,
  age: Int,
  email: String
}


def birthday(person: Person) -> Person
  { person | age: person.age + 1 }
end


def full_name(first: String, last: String) -> { full: String, length: Int }
  name = first ++ " " ++ last
  {
    full: name,
    length: String.length(name),
  }
end
```

compiling to:

```ruby
Record_full_length = Data.define(:full, :length)

Person = Data.define(:name, :age, :email)

module Internal
  extend self

  def birthday(person)
    person.with(age: (person.age + 1))
  end

  def full_name(first, last)
    name = (first + (" " + last))
    Record_full_length[name, name.length]
  end
end
```

### 3. Syntax colouring

Restrained. Four colours plus the default, nothing more, and no italics
except comments.

- Keywords (`module`, `def`, `type`, `struct`, `exposing`, `case`, `in`,
  `then`, `end`, `uses`, `with`, and Ruby's `module`, `def`, `end`, `in`,
  `then`, `extend`, `self`): `--jade-bright`
- Type names and constructors (`Shape`, `Circle`, `Float`, `Data`): a soft
  warm sand, around `#E8C99B`
- Strings: a muted sage, around `#9BC5A2`
- Numbers: `#C9B8E8`
- Comments: `--ink-soft` lifted for contrast, around `#6E7D76`, italic
- Everything else: `--console-ink`

Both panes use the same theme — that similarity is part of the argument.

### 4. Highlights

Four items, in a 2×2 grid on desktop and stacked on mobile, separated by
hairlines rather than card borders. Each is a short mono label, a one-line
headline, two lines of prose, and a 3–6 line code fragment in a small dark
pane. Restate no more than the following:

1. **`Maybe` instead of `nil`** — Absence is a type, and errors are values.
   No `NoMethodError` on nil, ever.
   ```
   def withdraw(balance: Int, amount: Int) -> Result(Int, String)
     amount > balance ? Err("insufficient funds") : Ok(balance - amount)
   end
   ```

2. **Inference, not annotation** — Annotate the signature; the compiler
   works out the rest.
   ```
   def shout(words: List(String)) -> String
     words
       |> List.map(String.to_upper)
       |> String.join(" ")
   end
   ```

3. **Records, updated structurally** — Field access and update are
   expressions, and the result keeps its type.
   ```
   def birthday(user: User) -> User
     { user | age: user.age + 1 }
   end
   ```

4. **Instances derive** — `Eq`, `Show`, `Encodable` and `Decodable` come
   free for structs and unions. (`Comparable` does not — don't imply it.)
   ```
   struct User = {
     name: String,
     age: Int
   }
   ```

### 5. Errors that point at the problem

This section carries the "exhaustive pattern matching" pitch better than a
grid tile can, so give it a full-width band on `--paper-sunk`.

Left column, ~40% width: heading **Add a variant, and every `case` that
forgot it stops compiling.** One sentence of prose beneath it: The check is
structural — the compiler names the cases you're missing, not just the line.

Right column: one dark console pane, chrome label `$ jade check shapes.jd`.
This is verbatim compiler output — reproduce the alignment and the caret
runs exactly:

```
error: Pattern match is not exhaustive. Missing cases:
  Triangle(_, _, _)
   --> shapes.jd:10:3
   |
10 |   case shape
   |   ^^^^^^^^^^
11 |   in Circle(_) then "circle"
12 |   in Rectangle(_, _) then "rectangle"
13 |   end
   | ^^^^^ non-exhaustive pattern match
   |

1 error in .
```

Colour it: the word `error:` in a muted red (`#E27C7C`) and bold; the
`-->`, the gutter pipes and the line numbers in `--ink-soft`; the caret runs
`^^^` in `--jade-bright`; the quoted source lines in `--console-ink`. Do not
syntax-highlight the quoted source — it is quoted text, not code.

### 6. Effects have a type

Heading: **Nothing reaches the outside world without saying so.** Then two
lines of prose: Jade has no implicit side effects. Every call out to Ruby is
declared in a `uses` block, takes a `Task` return type, and doesn't run until
something runs it — so a function's signature tells you whether it does IO.

Lay this out as three narrow panes in a row (stacking on mobile), captioned
above each in mono `--ink-soft`. It reads left to right as one story.

Pane 1 — `declare it in Jade`:

```
uses Mailer with
  deliver : String -> Task(Bool, String)
end


def run(email: String) -> Task(Bool, String)
  deliver(email)
end
```

Pane 2 — `implement it in Ruby`:

```ruby
module Mailer
  extend Jade::Port

  task :deliver do |t, email|
    t.ok(Mail.welcome(email).deliver)
  end
end
```

Pane 3 — `nothing runs until you run it`:

```ruby
task = Signup::Internal.run('ada@example.com')  # nothing has happened
task.run                                        # => Ok(true)

Signup.run('ada@example.com')                   # => ["ok", true]
Signup.run!('ada@example.com')                  # => true, raises on err
```

One closing line under the row, `--ink-soft`: Because effects are values,
tests stub them without touching the network — there are RSpec matchers for
it.

### 7. The boundary is typed in both directions

This is the section that makes "layer" mean something, so give it weight: a
full-width band, `--paper-sunk`.

Heading: **A typed edge, not a leaky one.** Prose, two or three lines:
Arguments are decoded on the way in and encoded on the way out. Ruby sees
ordinary hashes, strings and numbers — never Jade's internal
representation — and Jade never sees a value that didn't typecheck.

Then a two-column layout.

Left column, heading `generated, not hand-written`: a dark pane of real
compiled output. This is the guarantee made concrete — the compiler derives
this from `struct Person` with no decoder written by hand:

```ruby
def self.decode_person(value)
  Jade::Interop::Boundary.hash("Person", value).then do |h|
    ::Records::Person[
      Jade::Interop::Boundary.string("String", h["name"]),
      Jade::Interop::Boundary.integer("Int", h["age"]),
      Jade::Interop::Boundary.string("String", h["email"]),
    ]
  end
end

def self.encode_person(p)
  { "name" => p.name, "age" => p.age, "email" => p.email }
end
```

Right column, heading `when Ruby lies`: a dark pane showing what happens
when a port returns the wrong shape. Colour the `raises` line's error class
in the same muted red as §5.

```ruby
task :raw_fetch do |t, id|
  t.ok({ name: "Paul" })   # oops — missing :id
end

Users.fetch(1)
# => raises Jade::Interop::DecodeError:
#    Port returned a value that failed to decode at value:
#    missing field `id` ({name: "Paul"})
```

Caption beneath the pair, `--ink-soft`, one line: A port returning the wrong
shape is a bug, not a runtime condition — the boundary raises rather than
pass a malformed value inward.

Then a short closing note, set as plain prose, no pane: For JSON that isn't
a boundary crossing, `Decode` and `Encode` are ordinary composable pipelines,
and both auto-derive for structs. Link the words `Decode` and `Encode` to
`docs/json.md`.

### 8. A layer, not a platform

The positioning stated plainly, near the end, once the reader believes the
code. No background change, no pane — just a heading and a short list with
hairline separators.

Heading: **It goes in the app you already have.**

- **Per module.** Point Jade at a source root and `require` modules by
  name. Each `.jd` compiles to `.jade/build/<module>.rb` on first require,
  and only when the source changed. There is no "Jade app."
- **Ordinary constants on the Ruby side.** A compiled module is a module.
  `Signup.run(email)` is just a method call — nothing to boot, no context
  to thread.
- **One gem.** `jade-lang`, which depends on `base64` and nothing else.
- **You can leave.** The compiled Ruby is the deliverable — readable, in
  your tree, under your version control. Drop the gem and you keep the
  output.

Set that last bullet slightly apart — a little extra space above it, and
the words "You can leave" in `--jade`. It's the objection-killer and should
land last.

### 9. One binary

A short band, no background change. Heading **The whole toolchain is one
command.** Then a dark console pane listing the real surface — do not invent
subcommands, these four are all that exist:

```
jade check [file...]      # type-check; exits 1 on errors, generates nothing
jade fmt [-i|-c] [file]   # format .jd source (stdin or file)
jade lsp                  # language server over stdio
jade q hover FILE:L:C     # headless JSON queries — hover/defn/refs/symbols
```

Beside it (or beneath, on mobile) two short paragraphs, each ~2 lines:

- **In your editor.** A language server ships in the box — type errors,
  inferred types, jump-to-definition in anything that speaks LSP. `jade fmt`
  is deterministic and idempotent; wire it to a pre-commit hook.
- **For coding agents.** `jade q` answers the same questions as one-shot
  JSON, so a tool that doesn't speak LSP can still ask. `jade q api` reads
  signatures straight from the compiler's registry, so the answer can't
  drift from the compiler.

Under the agent paragraph, one more small console pane showing a real query
and its real answer:

```
$ jade q api List.fold
{
  "name": "fold",
  "qualified_name": "List.fold",
  "kind": "function",
  "signature": "List.fold : (List(a), b, (b, a) -> b) -> b"
}
```

JSON colouring: keys in `--console-ink` at 70% opacity, string values in the
muted sage `#9BC5A2`, braces and punctuation in `--ink-soft`.

Keep the claim modest — the README's own wording is that agents have "held
up for us so far," with no promises. Do not upgrade that into "built for AI"
or any similar line.

### 10. Docs

A plain hairline-separated list, no cards, no icons. Mono link labels on the
left, one-line `--ink-soft` description on the right, right-aligned or in a
second column:

```
syntax.md     the full language tour
interop.md    the Ruby boundary: ports, decoding, what crosses
json.md       Decode / Encode, by hand and auto-derived
testing.md    stubbing Tasks, the RSpec matchers
stdlib.md     module-by-module map
lsp.md        language server and jade q setup
examples/     runnable .jd files
```

### 11. Status

Two short lines, `--ink-soft`, no styling flourish. Honesty is the point —
the site should not read as though this is 1.0:

**Early and experimental** — being tried out on small projects. In progress:
`Comparable` derivation for user types, partial record types in signatures,
a stable REPL. Not great for: throwaway scripts, libraries you ship to other
Ruby projects, and performance-critical hot paths.

### 12. Install / closing

One dark console strip, full content width. The gem is published, so the
Gemfile line is all it takes — show it in a pane with a `Gemfile` chrome
label:

```ruby
gem 'jade-lang'
```

Verified against the released gem: `jade-lang` 0.4.0 pulls in `base64` and
nothing else, and all three diptych examples compile and run under it.

Under it, one caption line in `--ink-soft`: Modules compile to
`.jade/build/` on first require. Then two text links: `Language tour` and
`GitHub`, and a thin footer — `Jade — MIT licensed` on the left, a jade dot
on the right. Nothing else.

## Interaction

- Tabs swap diptych content instantly, no animation beyond a 120ms opacity
  fade.
- Links: jade underline that thickens from 1px to 2px on hover, 120ms.
- Buttons: `--jade` → `--jade-deep` on hover, no lift, no shadow.
- Respect `prefers-reduced-motion`.
- No scroll-triggered reveals, no parallax, no counters.

## Responsive

Breaks at 900px: diptych stacks, arrow rotates, highlights go single
column, hero headline drops to 40px. Code panes get `overflow-x: auto`
individually; the page body never scrolls sideways.

## Dark mode

Support `prefers-color-scheme: dark`: canvas goes to `#0C1411`, text to
`#D8E3DD`, rules to `#1E2A25`, and the code panes go one step *darker*
than the page (`#070D0B`) so they still read as inset. Jade accent becomes
`--jade-bright`. The syntax theme is unchanged in both modes.

## Deliberately out of scope

No nav dropdown, no sidebar, no search, no blog list, no testimonials, no
newsletter capture, no cookie banner, no live playground (that comes
later — leave the `See it compile ↓` CTA pointing at the diptych).
