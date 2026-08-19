# Handoff: Burner List Design System

## Overview
This is the full design system for Burner List (web app + iOS wrapper), reverse-engineered from the live codebase (`index.html`, `styleguide.html`, `design/tokens.json`, SwiftUI `BurnerTheme`). It documents tokens, components, content voice, and visual rules so future UI work — on web or iOS — stays consistent.

## Where the actual component library lives
The component library is not this folder — it's the **Burner List Design System** project (a separate Claude project). This handoff bundle is an index into it, not a copy of it: the `.jsx` files there are the real, current implementation; duplicating them here would just drift out of sync. Give Claude Code access to that project (or re-export this bundle from it later) rather than treating this README as the source.

## About the files in this bundle
- `reference/tokens/*.css` — the canonical color/type/spacing/effects tokens (5 themes: Sand, Sage, Slate, Clay, Lavender). These mirror `design/tokens.json` in the app repo — treat the app's `tokens.json` → `design-tokens.css`/Swift pipeline as the actual source of truth; these CSS files are a readable mirror of the same values.
- `reference/components/**/*.prompt.md` — one file per component (Button, TaskRow, Sidebar, Modal, etc.) describing its markup structure, states, and behavior. Pair each with the live component in the design system project (not included as code here to avoid drift) and reimplement it natively in the target file (vanilla JS class/module or SwiftUI view) — the app doesn't use React.
- `reference/guideline_cards/*.card.html` — visual specimen sheets (tokens, type, spacing, per-component states). Open these in a browser to see them rendered.
- `reference/ui_kit_html/README.md` — describes the clickable auth → board flow; view the live version in the design system project for the actual interaction reference.

## Fidelity
High-fidelity. Colors, spacing, radii, and type values are pulled directly from the app's own token file (`design/tokens.json`) and CSS/SwiftUI source — treat exact values as final, not placeholders.

## How to use this with Claude Code
1. Keep this folder (or just `README.md` + `reference/tokens/`) in the BurnerList repo, e.g. under `docs/design-system/`.
2. Add a line to the repo's `CLAUDE.md`: "Check `docs/design-system/README.md` before styling or building any UI; tokens must match `design/tokens.json`."
3. For a specific screen, open the matching component in the design system project (or its `.prompt.md` here) as the target shape, and edit the real target file (`index.html`, `ios/BurnerList/Features/...`).
4. Use the `.card.html` pages and the design system's live UI kit as visual ground truth — screenshot or open them side by side with the app during review.

## Design Tokens
See `reference/tokens/colors.css` (5 themes), `spacing.css` (4px scale: 4/8/12/16/20/24/32/40), `typography.css` (Inter for UI, Caveat for brand/display only), `effects.css` (shadows, motion durations).

## Components
Core: Button, Checkbox, TextField · Tasks: TaskRow, ZonePanel, PostponeMenu · Navigation: Sidebar, ViewToggle · Feedback: Toast, StateRow · Overlays: Modal, QuickAddOverlay · Brand: ThemeSwatches, QuoteBox, AuthForm

Each has a `.d.ts` (prop contract), `.jsx` (reference implementation), and `.prompt.md` (behavior/state notes) in `reference/components/<category>/`.

## Content & Voice
Plain, calm, sentence case. No exclamation points, no hype. Empty/error states are short and reassuring ("Offline — changes will sync when connected."). Emoji used exactly once, in the wordmark (🍳 Burner List 🔥) — nowhere else.

## Do / Do not
**Do:** preserve the Front Burner / Back Burner / Kitchen Sink layout as the core object; keep UI dense enough for daily repeated use; strengthen component consistency; improve iOS ergonomics.
**Do not:** make it look like a marketing page; bury tasks in heavy chrome; overuse gradients/oversized type; lose the theme system.

## Sources
Built from the attached `BurnerList/` codebase: `index.html`, `styleguide.html`, `design/tokens.json`, `ios/BurnerList/DesignSystem/BurnerTheme.swift`, `ios/BurnerList/Features/AuthenticationView.swift`.
