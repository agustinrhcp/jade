// Emits escaped HTML, so it serves pre-baked markup and live compiler output.

const KW = new Set(['module', 'def', 'type', 'struct', 'exposing', 'case', 'in',
  'then', 'end', 'uses', 'with', 'extend', 'self', 'do', 'true', 'false', 'nil',
  'if', 'else', 'return', 'interface', 'implements', 'import']);

const TOKEN = /(--[^\n]*|#[^\n]*)|("(?:[^"\\]|\\.)*")|(\b\d+(?:\.\d+)?\b)|(\b[A-Z][A-Za-z0-9_]*\b)|(\b[a-z_][A-Za-z0-9_?!]*\b)/g;

export const esc = (s) => s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');

const wrap = (cls, t) => (cls ? `<span class="${cls}">${esc(t)}</span>` : esc(t));

export function code(src) {
  let out = '', last = 0, m;
  TOKEN.lastIndex = 0;

  while ((m = TOKEN.exec(src)) !== null) {
    out += esc(src.slice(last, m.index));
    if (m[1]) out += wrap('t-com', m[1]);
    else if (m[2]) out += wrap('t-str', m[2]);
    else if (m[3]) out += wrap('t-num', m[3]);
    else if (m[4]) out += wrap('t-typ', m[4]);
    else if (m[5]) out += KW.has(m[5]) ? wrap('t-kw', m[5]) : esc(m[5]);
    last = m.index + m[0].length;
  }

  return out + esc(src.slice(last));
}

function scan(src, re, pick) {
  let out = '', last = 0, m;
  re.lastIndex = 0;

  while ((m = re.exec(src)) !== null) {
    out += esc(src.slice(last, m.index));
    out += wrap(pick(m), m[0]);
    last = m.index + m[0].length;
  }

  return out + esc(src.slice(last));
}

export const HL = {
  code,

  error: (src) => scan(src, /(error:)|(warning:)|(-->)|(\^+)|(\|)|(^[ ]*\d+(?=[ ]*\|))/gm,
    (m) => (m[1] ? 't-err' : m[2] ? 't-typ' : m[4] ? 't-caret' : 't-gutter')),

  cli: (src) => scan(src, /(#[^\n]*)|(^\$ [^\n]*)|(^jade\b)/gm, (m) => (m[1] ? 't-com' : 't-kw')),

  json: (src) => scan(src, /("(?:[^"\\]|\\.)*"\s*:)|("(?:[^"\\]|\\.)*")|([{}\[\],])|(^\$ [^\n]*)/gm,
    (m) => (m[4] ? 't-kw' : m[1] ? 't-key' : m[2] ? 't-str' : 't-gutter')),

  irb: (src) => scan(src, /(^irb> .*)|(^=>)|(^ *Jade::Interop::\w+)/gm,
    (m) => (m[1] ? 't-kw' : m[2] ? 't-gutter' : 't-err')),

  lies: (src) => src.split('\n').map((line) =>
    !/^\s*#/.test(line)
      ? code(line)
      : line.split('Jade::Interop::DecodeError')
          .map((p) => wrap('t-com', p))
          .join('<span class="t-err">Jade::Interop::DecodeError</span>')).join('\n'),
};

// The boundary sits at the end of the module at two-space indent.
export function splitRuby(text) {
  const lines = text.split('\n');
  const at = lines.findIndex((l) => /^  (def self\.|BOUNDARY_[A-Z0-9_]+ =)/.test(l));
  if (at === -1) return { core: text, boundary: '' };

  return {
    core: lines.slice(0, at).join('\n').replace(/\s+$/, '') + '\nend',
    boundary: lines
      .slice(at, lines[lines.length - 1] === 'end' ? -1 : undefined)
      .join('\n')
      .replace(/\s+$/, ''),
  };
}

export function renderRuby(pane, text) {
  const { core, boundary } = splitRuby(text);
  pane.innerHTML = code(core);

  const host = pane.parentElement;
  host.querySelector('.boundary')?.remove();
  if (!boundary) return;

  const count = boundary.split('\n').filter((l) => l.trim()).length;
  const details = document.createElement('details');
  details.className = 'boundary';
  details.innerHTML = `<summary>${count} more lines, the Ruby boundary</summary><pre class="code"></pre>`;
  details.querySelector('pre').innerHTML = code(boundary);
  host.appendChild(details);
}

export function highlightAll(root = document) {
  root.querySelectorAll('[data-hl]:not([data-gen])').forEach((el) => {
    const fn = HL[el.dataset.hl];
    if (fn) el.innerHTML = fn(el.textContent);
  });
}

export function renderOutput(pane, { ruby, rendered, failed }) {
  if (failed) {
    pane.parentElement.querySelector('.boundary')?.remove();
    pane.innerHTML = HL.error(rendered);
    return;
  }

  renderRuby(pane, ruby || '');
  if (rendered) pane.innerHTML = HL.error(rendered) + '\n\n' + pane.innerHTML;
}
