# Tour: sidebar + a console — design prompt

Two changes to the existing Jade site (https://agustinrhcp.github.io/jade/).
Everything below the line is the prompt.

---

Two changes to an existing site. Keep its established language exactly: warm
off-white `#FBFAF7`, near-black `#121815`, jade `#00A86B` used sparingly as the
only accent, dark code panes `#0C1411`, Inter for text, JetBrains Mono for code,
hairline `#E2E0D9` rules instead of cards or shadows, dark mode via
`prefers-color-scheme`. No gradients, no shadows, no emoji. Deliver the two
pieces as HTML + CSS I can drop into `tour.html` and `style.css`.

## 1. The tour needs a sidebar, not a top nav

Today the tour's section index is a sticky horizontal strip under the header
that scrolls sideways on narrow screens. Replace it with a left sidebar.

- Fixed/sticky column on the left, roughly 200–240px, full height, its own
  scroll if the list outgrows the viewport.
- Content column sits to its right, keeping its ~720px measure for prose.
- Eleven entries: Values and primitives, Functions, Union types, Structs and
  records, Pattern matching, Conditionals, Pipes and lambdas, Maybe and Result,
  Interfaces, Modules and imports, Reaching Ruby.
- Mono, ~12px, `#5F6B65`. The active entry goes near-black with a 2px jade
  marker on its left edge. Active state follows scroll position.
- The site wordmark (`jade.`) sits at the top of the sidebar; a link back to the
  home page sits under the section list, separated by a hairline.
- Below ~900px the sidebar collapses to a single sticky bar at the top of the
  viewport showing only the current section name, which opens the full list on
  tap. Don't reintroduce a sideways-scrolling strip.

## 2. `try it` becomes a console

Each tour section shows a read-only Jade example with a `try it` button. Today
pressing it swaps in a two-pane editor: Jade on the left, compiled Ruby on the
right. **Add a third thing: a console that runs the code.**

This is real, not a mock. The compiler and a Ruby runtime are in the page via
WebAssembly. Pressing `try it` compiles the module, loads it, and from then on
typed expressions evaluate against it in about a millisecond.

Design the expanded state. Requirements:

- **The editor stays on the left.** Jade source, editable, mono, dark pane with
  a filename chrome bar (`values.jd`).
- **The right side carries two views, switchable:** `compiled.rb` (what exists
  today) and `console`. Use the same understated tab treatment as the landing
  page's example tabs — plain text, 2px jade underline on the active one, no
  pills. Console is the default view on the tour; the compiled Ruby is the
  landing page's argument, the console is the tour's.
- **The console** is a transcript plus an input line. Show:
  - a prompt glyph in jade, then the typed expression
  - the result on the next line, prefixed `=>` in `#5F6B65`
  - errors with the class name in muted red `#E27C7C`, message beneath
  - a starting line already run, so there is something to read before typing —
    e.g. `Values.total` → `42`
- **The input line** sits at the bottom of the transcript, same mono, caret in
  jade, no border box — it should read as the next line of the transcript, not
  as a form field. Up/down arrow recalls history.
- **Editing the source reloads the module.** Show that: a dim line in the
  transcript like `— reloaded values.jd —` rather than clearing history.

### States you must design

These all happen. Don't design only the happy path.

1. **Booting.** The first `try it` on the page downloads ~9 MB and takes a few
   seconds; later ones are instant. Show progress inline where the console will
   be (`starting the compiler…`, `loading…`). Nothing else on the page should
   move or block.
2. **A compile error.** The source doesn't compile, so there is nothing to run.
   The compiled-Ruby view shows the compiler's own output — source excerpt with
   caret runs under the offending span, `error:` in red. The console should say
   the module didn't compile rather than pretending it's live. Real example:
   ```
   error: Pattern match is not exhaustive. Missing cases:
     Triangle(_)
      --> shapes.jd:10:3
      |
   10 |   case shape
      |   ^^^^^^^^^^
   ```
3. **A function that can't be called from Ruby.** Some are only reachable
   internally. The real error is:
   ```
   Jade::Interop::NotExposed: Values.initial is not exposed to Ruby.
   ```
   Design a one-line follow-up suggesting the internal form — `try
   Values::Internal.initial` — as a dim hint under the error, not a dialog.
4. **A plain Ruby error**, e.g. `NoMethodError: undefined method 'nope' for
   module Values`. Same treatment as any error.
5. **Long output** that overflows the pane width, and **a long transcript** that
   overflows its height. Both scroll within the pane; the page must never scroll
   sideways.

### Heights

The editor and the right pane should be equal height and stay put as the
transcript grows — around 400–460px, with the transcript scrolled to its
newest line. Don't let the section reflow every time someone presses enter.

## What not to do

Don't add a run button — evaluation happens on enter, compilation happens on
edit. Don't add a toolbar, a settings gear, a share control, or a "powered by"
badge. Don't animate the transcript. Don't put a border around the console; the
pane is the border.
