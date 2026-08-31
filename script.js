const progressBar = document.getElementById('reading-progress');

function updateReadingProgress() {
  const scrollable = document.documentElement.scrollHeight - window.innerHeight;
  const progress = scrollable > 0 ? Math.min(1, window.scrollY / scrollable) : 0;
  progressBar.style.width = (progress * 100) + '%';
}

window.addEventListener('scroll', updateReadingProgress, { passive: true });
window.addEventListener('resize', updateReadingProgress);
updateReadingProgress();

function copyWithTextarea(query) {
  const textarea = document.createElement('textarea');
  textarea.value = query;
  textarea.setAttribute('readonly', '');
  textarea.style.position = 'fixed';
  textarea.style.left = '-9999px';
  document.body.appendChild(textarea);
  textarea.focus();
  textarea.select();

  let copied = false;
  try {
    copied = document.execCommand('copy');
  } finally {
    textarea.remove();
  }
  return copied;
}

document.querySelectorAll('.copy-query').forEach((button) => {
  button.addEventListener('click', async () => {
    const original = button.textContent;
    const query = button.dataset.query;
    let copied = false;

    if (navigator.clipboard && window.isSecureContext) {
      try {
        await navigator.clipboard.writeText(query);
        copied = true;
      } catch {
        copied = false;
      }
    }

    if (!copied) copied = copyWithTextarea(query);
    if (!copied) window.prompt('Copy this search query:', query);

    button.textContent = copied ? 'Copied' : 'Opened copy box';
    window.setTimeout(() => {
      button.textContent = original;
    }, 1600);
  });
});
