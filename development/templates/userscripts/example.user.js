// ==UserScript==
// @name         Local example status control
// @namespace    https://example.com/devtools-original
// @version      1.0.0
// @description  User-triggered local status; no requests or persistence.
// @match        https://example.com/*
// @run-at       document-idle
// @noframes
// @grant        none
// @license      MIT
// ==/UserScript==
(() => {
  'use strict';
  if (document.getElementById('devtools-original-example')) return;
  const box = document.createElement('section');
  box.id = 'devtools-original-example';
  box.setAttribute('aria-label', 'Local example');
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = 'Show local status';
  const status = document.createElement('p');
  status.setAttribute('role', 'status');
  button.addEventListener('click', () => { status.textContent = 'Local example active. No data was sent.'; });
  box.append(button, status);
  document.body.append(box);
})();
