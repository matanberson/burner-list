const variants = new Set(["primary", "secondary", "ghost", "icon"]);

export function createButton({ label, variant = "secondary", disabled = false, title } = {}) {
  if (!variants.has(variant)) throw new TypeError(`Unknown button variant: ${variant}`);
  const button = document.createElement("button");
  button.type = "button";
  button.className = `ds-button ds-button--${variant}`;
  button.disabled = disabled;
  if (title) button.title = title;
  button.textContent = label ?? "";
  return button;
}

export function createTextField({ type = "text", placeholder = "", multiline = false, disabled = false } = {}) {
  const field = document.createElement(multiline ? "textarea" : "input");
  field.className = "ds-field";
  if (!multiline) field.type = type;
  field.placeholder = placeholder;
  field.disabled = disabled;
  return field;
}

export function createCheckbox({ checked = false, disabled = false, label } = {}) {
  const input = document.createElement("input");
  input.type = "checkbox";
  input.className = "ds-checkbox";
  input.checked = checked;
  input.disabled = disabled;
  if (label) input.setAttribute("aria-label", label);
  return input;
}
