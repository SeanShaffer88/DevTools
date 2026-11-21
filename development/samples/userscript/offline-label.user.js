// ==UserScript==
// @name         Offline Example Label
// @namespace    org.devtools.samples
// @version      1.0.0
// @description  Add one local label to the exact example page.
// @match        https://example.com/*
// @grant        none
// @run-at       document-end
// ==/UserScript==
(() => {
  "use strict";
  if (document.getElementById("devtools-offline-label")) return;
  const note = document.createElement("p");
  note.id = "devtools-offline-label";
  note.textContent = "Offline Sample";
  document.body.appendChild(note);
})();
