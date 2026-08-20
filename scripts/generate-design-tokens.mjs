import { readFile, writeFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const sourcePath = resolve(root, "design/tokens.json");
const cssPath = resolve(root, "assets/generated/design-tokens.css");
const swiftPath = resolve(root, "ios/BurnerList/DesignSystem/BurnerTokens.generated.swift");
const check = process.argv.includes("--check");
const source = JSON.parse(await readFile(sourcePath, "utf8"));

const value = token => token.$value;
const kebab = name => name.replace(/[A-Z]/g, letter => `-${letter.toLowerCase()}`);
const cssValue = token => {
  const raw = value(token);
  return typeof raw === "object" ? `${raw.value}${raw.unit}` : raw;
};

const themeBlock = (name, theme) => {
  const selector = name === "default" ? ":root" : `[data-theme="${name}"]`;
  const declarations = Object.entries(theme.color)
    .filter(([key]) => !key.startsWith("$"))
    .map(([key, token]) => `  --${kebab(key)}: ${cssValue(token)};`);
  return `${selector} {\n${declarations.join("\n")}\n}`;
};

const dimensionDeclarations = [
  ...Object.entries(source.radius).filter(([key]) => !key.startsWith("$")).map(([key, token]) => `  --radius-${key}: ${cssValue(token)};`),
  ...Object.entries(source.space).filter(([key]) => !key.startsWith("$")).map(([key, token]) => `  --space-${key}: ${cssValue(token)};`),
  ...Object.entries(source.layout).filter(([key]) => !key.startsWith("$")).map(([key, token]) => `  --layout-${kebab(key)}: ${cssValue(token)};`)
];

const css = `/* Generated from design/tokens.json. Do not edit directly. */\n${themeBlock("default", source.theme.default).replace("\n}", `\n${dimensionDeclarations.join("\n")}\n}`)}\n\n${Object.entries(source.theme).filter(([name]) => name !== "default").map(([name, theme]) => themeBlock(name, theme)).join("\n\n")}\n`;

const hexColor = hex => {
  const match = /^#([0-9a-f]{2})([0-9a-f]{2})([0-9a-f]{2})$/i.exec(hex);
  if (!match) return null;
  return match.slice(1).map(component => (parseInt(component, 16) / 255).toFixed(3));
};
const swiftColors = Object.entries(source.theme.default.color)
  .filter(([key, token]) => !key.startsWith("$") && hexColor(value(token)))
  .map(([key, token]) => {
    const [red, green, blue] = hexColor(value(token));
    return `    static let ${key} = Color(red: ${red}, green: ${green}, blue: ${blue})`;
  });
const swiftDimensions = [
  ...Object.entries(source.radius).filter(([key]) => !key.startsWith("$")).map(([key, token]) => `    static let radius${key.toUpperCase()}: CGFloat = ${value(token).value}`),
  ...Object.entries(source.space).filter(([key]) => !key.startsWith("$")).map(([key, token]) => `    static let space${key}: CGFloat = ${value(token).value}`),
  ...Object.entries(source.layout).filter(([key]) => !key.startsWith("$")).map(([key, token]) => `    static let ${key}: CGFloat = ${value(token).value}`)
];
const swift = `// Generated from design/tokens.json. Do not edit directly.\nimport SwiftUI\n\nenum BurnerTokens {\n${swiftColors.join("\n")}\n\n${swiftDimensions.join("\n")}\n}\n`;

async function emit(path, contents) {
  if (check) {
    const current = await readFile(path, "utf8").catch(() => "");
    if (current !== contents) throw new Error(`${path.replace(`${root}/`, "")} is stale. Run node scripts/generate-design-tokens.mjs`);
  } else {
    await writeFile(path, contents);
  }
}

await Promise.all([emit(cssPath, css), emit(swiftPath, swift)]);
console.log(check ? "Design token outputs are current." : "Generated web and iOS design tokens.");
