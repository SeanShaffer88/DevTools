'use strict';
// Original local-only demonstration: no persistence or network.
const form = document.getElementById('note-form');
form.querySelector('button').disabled = false;
form.addEventListener('submit', event => {
  event.preventDefault();
  const value = document.getElementById('note').value.trim();
  if (!value) {
    document.getElementById('status').textContent = 'Enter a note first.';
    document.getElementById('note').focus();
    return;
  }
  document.getElementById('preview').textContent = value;
  document.getElementById('status').textContent = 'Preview updated. Nothing was saved.';
});
