// Runs the real Jade compiler in the browser via ruby.wasm.
//
// The page ships with pre-compiled Ruby in the right pane, so it is correct and
// readable before any of this loads. The VM boots lazily on the first edit;
// after that every keystroke recompiles (warm compiles land around 15ms).

const VENDOR = 'vendor';

// Ruby double-quoted strings interpolate #{...}, and both the compiler source
// and user input are full of it — escape before embedding in evaluated Ruby.

// Embeds text as a Ruby string literal.
const rubyLiteral = (text) => JSON.stringify(text).replace(/#/g, '\\#');

// Embeds a JS value as a Ruby literal holding its JSON, for JSON.parse to read.
const rubyString = (value) => rubyLiteral(JSON.stringify(value));

function script(src) {
  return new Promise((resolve, reject) => {
    const el = document.createElement('script');
    el.src = src;
    el.onload = resolve;
    el.onerror = () => reject(new Error(`failed to load ${src}`));
    document.head.appendChild(el);
  });
}

let booting = null;

async function boot(onProgress) {
  onProgress('loading runtime');
  await script(`${VENDOR}/ruby-wasm.umd.js`);

  onProgress('downloading ruby (8.6 MB)');
  const [wasm, bundle] = await Promise.all([
    fetch(`${VENDOR}/ruby+stdlib.wasm`).then((r) => {
      if (!r.ok) throw new Error(`ruby+stdlib.wasm: ${r.status}`);
      return r.arrayBuffer();
    }),
    fetch(`${VENDOR}/lib-bundle.json`).then((r) => {
      if (!r.ok) throw new Error(`lib-bundle.json: ${r.status}`);
      return r.text();
    }),
  ]);

  onProgress('starting vm');
  const { DefaultRubyVM } = window['ruby-wasm-wasi'];
  const { vm } = await DefaultRubyVM(await WebAssembly.compile(wasm), {
    consolePrint: false,
  });

  onProgress('loading compiler');
  vm.eval(`
    require 'json'
    require 'fileutils'

    JSON.parse(${rubyLiteral(bundle)}).each do |path, source|
      full = File.join('/jade/lib', path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, source)
    end

    $LOAD_PATH.unshift('/jade/lib')
    require 'jade'
    require 'jade/diagnostics/renderer'
  `);

  onProgress('warming up');
  compile(vm, 'module Warmup exposing (n)\n\ndef n() -> Int\n  1\nend\n');

  return vm;
}

// Codegen derives cross-module references from the file name, so the overlay
// URI has to match the declared module name or the emitted Ruby refers to a
// module that does not exist.
export function compile(vm, source) {
  const result = vm.eval(`
    source = JSON.parse(${rubyString(source)})
    name = source[/\\Amodule\\s+([A-Z][A-Za-z0-9_]*)/, 1]

    if name.nil?
      JSON.dump({
        'ruby' => nil,
        'severities' => ['error'],
        'rendered' => "error: expected a module declaration, e.g. 'module Shapes exposing (area)'",
      })
    else
      uri = name.gsub(/([a-z0-9])([A-Z])/, '\\\\1_\\\\2').downcase + '.jd'

      begin
        registry = Jade::ModuleLoader.load('/src', uri, overlays: { uri => source }, tolerant: true)
        mod = registry.modules.values.reject { Jade::Stdlib.is_stdlib?(it) }.last

        items = mod ? mod.diagnostics.items : []

        JSON.dump({
          'ruby' => mod&.generated,
          'severities' => items.map { it.severity.to_s },
          'rendered' => Jade::Diagnostics::Renderer
            .new(colors: false)
            .render_all(Jade::Diagnostics::List.new(items:)),
        })
      rescue Jade::CompilationError => e
        # Parse failures raise rather than land in a module's diagnostics, but
        # the exception carries the same list — render it the same way so a
        # syntax error still points at the offending span.
        JSON.dump({
          'ruby' => nil,
          'severities' => e.diagnostics.items.map { it.severity.to_s },
          'rendered' => Jade::Diagnostics::Renderer
            .new(colors: false)
            .render_all(e.diagnostics),
        })
      end
    end
  `);

  return JSON.parse(result.toString());
}

const PREAMBLE = /^(?:\$LOAD_PATH.*|require .*|require_relative .*)\n/gm;

export function attach({ editors, onResult, onStatus }) {
  let vm = null;
  let timer = null;

  async function ensureVm() {
    if (vm) return vm;
    if (!booting) booting = boot(onStatus);
    vm = await booting;
    return vm;
  }

  async function run(editor) {
    try {
      await ensureVm();
    } catch (error) {
      onStatus(`could not start the compiler — ${error.message}`, 'error');
      return;
    }

    const started = performance.now();
    let result;

    try {
      result = compile(vm, editor.value);
    } catch (error) {
      onStatus(`compiler crashed — ${error.message}`, 'error');
      return;
    }

    const elapsed = Math.round(performance.now() - started);
    const errors = result.severities.filter((s) => s === 'error').length;

    onResult(editor, {
      ruby: result.ruby ? result.ruby.replace(PREAMBLE, '').trim() : null,
      rendered: result.rendered,
      failed: errors > 0,
    });

    if (errors) {
      onStatus(`${errors} error${errors > 1 ? 's' : ''}`, 'error');
    } else {
      const warnings = result.severities.length;
      onStatus(
        `compiled in ${elapsed}ms` + (warnings ? ` · ${warnings} warning${warnings > 1 ? 's' : ''}` : ''),
        'ok',
      );
    }
  }

  editors.forEach((editor) => {
    const schedule = () => {
      clearTimeout(timer);
      timer = setTimeout(() => run(editor), 150);
    };

    editor.addEventListener('input', schedule);
    editor.addEventListener('focus', () => { if (!vm) schedule(); }, { once: true });
  });
}
