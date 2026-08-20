import { readFile } from "node:fs/promises";

const requiredFiles = [
  "AGENTS.md",
  "CLAUDE.md",
  "design-system/component-inventory.md",
  "assets/app.css",
  "assets/design-system/components.css",
  "assets/design-system/components.js",
  "index.html",
  "styleguide.html"
];

const contents = Object.fromEntries(await Promise.all(requiredFiles.map(async path => [path, await readFile(path, "utf8")])));
const failures = [];

for (const page of ["index.html", "styleguide.html"]) {
  if (!contents[page].includes('/assets/design-system/components.css')) failures.push(`${page} does not import production component CSS`);
}

if (!contents["index.html"].includes('/assets/app.css')) {
  failures.push("index.html does not import application CSS");
}

if (contents["index.html"].includes("<style")) {
  failures.push("index.html contains an inline style block; move application styles to assets/app.css");
}

const componentStylesheetIndex = contents["index.html"].indexOf('/assets/design-system/components.css');
const appStylesheetIndex = contents["index.html"].indexOf('/assets/app.css');
if (componentStylesheetIndex > appStylesheetIndex) {
  failures.push("index.html must load shared component CSS before application CSS");
}

for (const primitive of ["ds-button", "ds-field", "ds-checkbox", "ds-date-lockup"]) {
  if (!contents["assets/design-system/components.css"].includes(`.${primitive}`)) failures.push(`Missing ${primitive} CSS primitive`);
  if (!contents["styleguide.html"].includes(primitive)) failures.push(`Catalog does not render ${primitive}`);
}

if (!contents["index.html"].includes("ds-field") || !contents["index.html"].includes("ds-button")) {
  failures.push("The production app does not consume the shared field and button primitives");
}

if (failures.length) {
  console.error(failures.map(failure => `- ${failure}`).join("\n"));
  process.exitCode = 1;
} else {
  console.log("Design-system contracts are present and consumed by app and catalog.");
}
