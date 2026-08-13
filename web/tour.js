import { HL, code, renderRuby } from './highlight.js';
import { attach } from './playground.js';
import { mountEditor } from './editor.js';

document.querySelectorAll('[data-hl]').forEach((el) => {
  const fn = HL[el.dataset.hl];
  if (fn) el.innerHTML = fn(el.textContent);
});

// Static until asked. The first `try it` boots the VM; every later one reuses
// it, so the cost is paid once and only by readers who want it.
const panels = [];

document.querySelectorAll('[data-try]').forEach((button) => {
  const block = document.getElementById(button.dataset.try);
  const source = block.querySelector('pre').textContent;

  button.addEventListener('click', () => {
    if (block.dataset.live) return;
    block.dataset.live = 'yes';
    button.remove();

    block.innerHTML = `
      <div class="ex">
        <div class="pane">
          <div class="chrome">${block.dataset.file}<span class="hint">editable</span></div>
          <div class="editor">
            <pre class="code" data-mirror aria-hidden="true"></pre>
            <textarea class="code" spellcheck="false" autocapitalize="off" autocorrect="off"
              autocomplete="off" aria-label="Jade source, editable"></textarea>
          </div>
        </div>
        <div class="pane">
          <div class="chrome">${block.dataset.file.replace(/\.jd$/, '.rb')}</div>
          <div class="scroll"><pre class="code"></pre></div>
        </div>
      </div>
      <p class="status" data-status>starting the compiler…</p>`;

    const editor = block.querySelector('textarea');
    const out = block.querySelector('.scroll pre');
    const status = block.querySelector('[data-status]');

    editor.value = source;
    mountEditor(editor, code);

    const panel = {
      editor,
      eager: true,

      status(text, kind) {
        status.textContent = text;
        if (kind) status.dataset.kind = kind;
        else status.removeAttribute('data-kind');
      },

      render({ ruby, rendered, failed }) {
        if (failed) {
          out.parentElement.querySelector('.boundary')?.remove();
          out.innerHTML = HL.error(rendered);
          return;
        }

        renderRuby(out, ruby || '');
        if (rendered) out.innerHTML = HL.error(rendered) + '\n\n' + out.innerHTML;
      },
    };

    panels.push(panel);
    attach([panel]);
    editor.focus();
  });
});

/* ---- section index ---- */

const links = [...document.querySelectorAll('.toc a')];
const sections = links.map((a) => document.querySelector(a.getAttribute('href')));

const spy = new IntersectionObserver((entries) => {
  entries
    .filter((e) => e.isIntersecting)
    .forEach((e) => {
      const i = sections.indexOf(e.target);
      links.forEach((a, j) => a.classList.toggle('here', i === j));
    });
}, { rootMargin: '-10% 0px -80% 0px' });

sections.forEach((s) => s && spy.observe(s));
