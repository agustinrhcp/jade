import { HL, code, esc, highlightAll, renderOutput } from './highlight.js';
import { ready, compile, loadModule, evaluate } from './playground.js';
import { mountEditor } from './editor.js';

highlightAll();

const sections = [...document.querySelectorAll('[data-section]')];

/* ---- section index ---- */

const current = document.querySelector('[data-current]');
const links = [...document.querySelectorAll('.rail a[href^="#"], .raillist a[href^="#"]')];

function markActive(slug) {
  links.forEach((a) => a.classList.toggle('here', a.getAttribute('href') === `#${slug}`));
  const section = sections.find((s) => s.id === slug);
  if (section) current.textContent = section.querySelector('h2').textContent;
}

window.addEventListener('scroll', () => {
  const passed = sections.filter((s) => s.getBoundingClientRect().top <= 140);
  markActive((passed[passed.length - 1] || sections[0]).id);
}, { passive: true });

markActive(sections[0].id);

const railbar = document.querySelector('.railbar');
const toggle = document.querySelector('.railtoggle');
const raillist = document.querySelector('.raillist');

toggle.addEventListener('click', () => {
  const open = raillist.hidden;
  raillist.hidden = !open;
  toggle.setAttribute('aria-expanded', String(open));
  toggle.querySelector('.glyph').textContent = open ? 'close' : 'sections';
});

raillist.addEventListener('click', (e) => {
  if (e.target.tagName !== 'A') return;
  raillist.hidden = true;
  toggle.setAttribute('aria-expanded', 'false');
  toggle.querySelector('.glyph').textContent = 'sections';
});

/* ---- one live section at a time ---- */

// The VM holds one loaded module, so opening a second example closes the first
// rather than leaving a console that answers about code you can no longer see.
let open = null;
let vm = null;

async function ensureVm(say) {
  if (vm) return vm;
  vm = await ready(say);
  return vm;
}

function collapse(section) {
  const { block, teardown } = open;
  teardown?.();
  block.innerHTML = `
    <div class="pane">
      <div class="chrome">
        <span>${section.dataset.file}</span>
        <button type="button" class="tryit">try it</button>
      </div>
      <div class="scroll x"><pre class="code sm"></pre></div>
    </div>`;
  block.querySelector('pre').innerHTML = code(open.source);
  block.querySelector('.tryit').addEventListener('click', () => expand(section));
  open = null;
}

function expand(section) {
  if (open) collapse(open.section);

  const block = section.querySelector('.block');
  const source = block.querySelector('pre').textContent;
  const file = section.dataset.file;

  block.innerHTML = `
    <div class="status" data-status>starting the compiler…</div>
    <div class="live">
      <div class="pane">
        <div class="chrome">
          <span>${file}</span>
          <button type="button" class="close">close</button>
        </div>
        <div class="editor">
          <pre class="code" data-mirror aria-hidden="true"></pre>
          <textarea class="code" spellcheck="false" autocapitalize="off" autocorrect="off"
            autocomplete="off" aria-label="Jade source, editable"></textarea>
        </div>
      </div>
      <div class="pane">
        <div class="chrome tabs">
          <button type="button" data-view="console" aria-selected="true">console</button>
          <button type="button" data-view="compiled" aria-selected="false">compiled.rb</button>
        </div>
        <div class="view" data-view="console">
          <div class="transcript" data-transcript></div>
          <div class="prompt">
            <span>&gt;</span>
            <input spellcheck="false" autocapitalize="off" autocorrect="off" autocomplete="off"
              aria-label="Expression to evaluate">
          </div>
        </div>
        <div class="view scroll" data-view="compiled" hidden><pre class="code sm"></pre></div>
      </div>
    </div>
    <p class="foothint">enter evaluates · editing the source reloads the module · ↑ recalls history</p>`;

  const editor = block.querySelector('textarea');
  const statusEl = block.querySelector('[data-status]');
  const transcript = block.querySelector('[data-transcript]');
  const input = block.querySelector('.prompt input');
  const compiled = block.querySelector('[data-view="compiled"] pre');
  const views = [...block.querySelectorAll('.tabs button')];

  editor.value = source;
  mountEditor(editor, code);
  input.placeholder = section.dataset.seed;

  open = { section, block, source, teardown: null };

  const status = (text, kind) => {
    statusEl.textContent = text;
    if (kind) statusEl.dataset.kind = kind;
    else statusEl.removeAttribute('data-kind');
  };

  function say(html, cls) {
    const line = document.createElement('div');
    line.className = cls;
    line.innerHTML = html;
    transcript.appendChild(line);
    transcript.scrollTop = transcript.scrollHeight;
  }

  const showEntry = (expression) => say(`<span class="p">&gt;</span> ${code(expression)}`, 'in');

  function showResult(result) {
    if (result.ok !== undefined) return say(`<span class="p">=&gt;</span> ${code(result.ok)}`, 'ok');

    say(`<span class="cls">${esc(result.cls)}:</span> ${esc(result.msg)}`, 'err');
    if (result.hint) say(esc(result.hint), 'dim');
  }

  views.forEach((button) => button.addEventListener('click', () => {
    views.forEach((b) => b.setAttribute('aria-selected', String(b === button)));
    block.querySelectorAll('.view').forEach((v) => {
      v.hidden = v.dataset.view !== button.dataset.view;
    });
    if (button.dataset.view === 'console') input.focus();
  }));

  block.querySelector('.close').addEventListener('click', () => {
    open.source = editor.value;
    collapse(section);
  });

  let live = false;
  let history = [];
  let pos = -1;

  async function reload(first) {
    const machine = await ensureVm(status);
    const result = compile(machine, editor.value);
    const errors = result.severities.filter((s) => s === 'error').length;

    if (errors) {
      renderOutput(compiled, { rendered: result.rendered, failed: true });
      status(`${errors} error${errors > 1 ? 's' : ''} — module not loaded`, 'error');
      views[1].click();
      if (live) say('— it no longer compiles, so the module is unchanged —', 'dim');
      live = false;
      return;
    }

    renderOutput(compiled, { ruby: result.ruby, rendered: result.rendered, failed: false });
    loadModule(machine, editor.value);
    status('module loaded · evaluates on enter', 'ok');

    if (first) {
      if (section.dataset.note) say(esc(section.dataset.note), 'dim');

      [section.dataset.setup, section.dataset.seed].filter(Boolean).forEach((line) => {
        showEntry(line);
        showResult(evaluate(machine, line));
      });
    } else {
      say(`— reloaded ${file} —`, 'dim');
    }

    live = true;
  }

  const debounce = (() => {
    let timer;
    return () => { clearTimeout(timer); timer = setTimeout(() => reload(false), 400); };
  })();

  editor.addEventListener('input', debounce);

  input.addEventListener('keydown', (e) => {
    if (e.key === 'ArrowUp' || e.key === 'ArrowDown') {
      e.preventDefault();
      if (!history.length) return;
      pos = Math.min(Math.max(pos + (e.key === 'ArrowUp' ? 1 : -1), -1), history.length - 1);
      input.value = pos === -1 ? '' : history[pos];
      return;
    }

    if (e.key !== 'Enter') return;
    e.preventDefault();

    const expression = input.value.trim();
    if (!expression) return;

    input.value = '';
    history = [expression, ...history];
    pos = -1;
    showEntry(expression);

    if (!live) return say('the module did not compile — nothing to run', 'dim');
    showResult(evaluate(vm, expression));
  });

  reload(true).then(() => input.focus());
}

sections.forEach((section) => {
  section.querySelector('.tryit').addEventListener('click', () => expand(section));
});
