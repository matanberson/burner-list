# Burner List repository guidance

## Design-system workflow

Before changing user-facing web or iOS UI:

1. Read `design-system/component-inventory.md`.
2. Open `styleguide.html` and inspect the relevant component and its states.
3. Reuse an existing design-system component. Do not recreate its appearance in feature code.
4. If the component or variant does not exist, add or extend it in the design system first, document its states in the inventory and catalog, then consume it in the product.

`design/tokens.json` is the canonical source for shared visual decisions. Never edit generated token outputs. Do not add raw colors, spacing, radii, shadows, or duplicated component CSS to feature code when a semantic token or component already exists.

Web primitives live in `assets/design-system/`. The visual catalog must import those same production files; it must not maintain lookalike copies. iOS components remain native SwiftUI implementations under `ios/BurnerList/DesignSystem/`, backed by the generated Swift tokens.

Before completing UI work, run:

```bash
node scripts/generate-design-tokens.mjs --check
node scripts/check-design-system.mjs
```

Visually check the affected catalog examples at desktop and mobile widths, including hover/focus, disabled, loading, empty, offline, and error states where applicable.
