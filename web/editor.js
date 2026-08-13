// A textarea layered over a highlighted <pre>: transparent text, visible caret,
// scroll positions kept in step. Keeps the page working without JS — the
// source is real text in the markup either way.

export function mountEditor(textarea, highlight) {
  const mirror = textarea.parentElement.querySelector('[data-mirror]');
  const sync = () => { mirror.innerHTML = highlight(textarea.value) + '\n'; };

  sync();
  textarea.addEventListener('input', sync);

  textarea.addEventListener('scroll', () => {
    mirror.scrollTop = textarea.scrollTop;
    mirror.scrollLeft = textarea.scrollLeft;
  });

  textarea.addEventListener('keydown', (e) => {
    if (e.key !== 'Tab' || e.shiftKey) return;
    e.preventDefault();

    const { selectionStart: start, selectionEnd: end, value } = textarea;
    textarea.value = value.slice(0, start) + '  ' + value.slice(end);
    textarea.selectionStart = textarea.selectionEnd = start + 2;
    textarea.dispatchEvent(new Event('input'));
  });
}
