import { code, renderRuby, splitRuby, highlightAll, renderOutput } from './highlight.js';
import { attach } from './playground.js';
import { mountEditor } from './editor.js';

highlightAll();

document.querySelectorAll('[data-gen]').forEach((el) => {
  if (el.dataset.part === 'boundary') el.innerHTML = code(splitRuby(el.textContent).boundary);
  else renderRuby(el, el.textContent);
});

/* ---- diptych tabs ---- */

const tabs = [...document.querySelectorAll('.tabs button')];
const panels = tabs.map((t) => document.getElementById(t.getAttribute('aria-controls')));
const reduce = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
let current = 0;

function show(i) {
  if (i === current) return;
  const from = panels[current], to = panels[i];
  tabs[current].setAttribute('aria-selected', 'false');
  tabs[i].setAttribute('aria-selected', 'true');
  current = i;

  if (reduce) { from.hidden = true; to.hidden = false; return; }

  from.classList.add('fade');
  setTimeout(() => {
    from.hidden = true;
    from.classList.remove('fade');
    to.hidden = false;
    to.classList.add('fade');
    requestAnimationFrame(() => to.classList.remove('fade'));
  }, 120);
}

tabs.forEach((t, i) => {
  t.addEventListener('click', () => show(i));
  t.addEventListener('keydown', (e) => {
    const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
    if (!d) return;
    e.preventDefault();
    const next = (current + d + tabs.length) % tabs.length;
    tabs[next].focus();
    show(next);
  });
});

/* ---- live diptych ---- */

const status = document.querySelector('[data-status]');

attach([...document.querySelectorAll('textarea[data-src]')].map((editor) => {
  mountEditor(editor, code);
  const out = editor.closest('.ex').querySelector('[data-gen]');

  return {
    editor,

    status(text, kind) {
      status.textContent = text;
      if (kind) status.dataset.kind = kind;
      else status.removeAttribute('data-kind');
    },

    render: (result) => renderOutput(out, result),
  };
}));
