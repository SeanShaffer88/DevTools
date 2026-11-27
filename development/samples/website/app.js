"use strict";
let count = 0;
const button = document.getElementById("increment");
const output = document.getElementById("count");
button.addEventListener("click", () => { count = Math.min(count + 1, 1000000); output.textContent = `Count: ${count}`; });
