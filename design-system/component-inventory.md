# Burner List component inventory

This inventory is the contract between design references, production UI, and the visual catalog at `styleguide.html`.

## Source-of-truth rules

- Shared visual decisions: `design/tokens.json`.
- Generated platform tokens: `assets/generated/design-tokens.css` and `ios/BurnerList/DesignSystem/BurnerTokens.generated.swift`.
- Web component styling: `assets/design-system/components.css`.
- Web application layout and feature styling: `assets/app.css`.
- Web component DOM helpers: `assets/design-system/components.js`.
- Web visual catalog: `styleguide.html`, importing the production design-system files.
- iOS components: native SwiftUI under `ios/BurnerList/DesignSystem/` with Xcode previews.
- Handoff files under `design_handoff_burnerlist/` are reference notes only, not implementation sources.

## Status

| Family | Component | Web | Catalog | iOS | Required states |
| --- | --- | --- | --- | --- | --- |
| Core | Button | Shared primitive | Yes | Primary style | Primary, secondary, ghost, icon, compact 24px icon, disabled |
| Core | TextField | Shared primitive | Yes | `BurnerFieldStyle` | Lighter semantic field surface, text, email, password, multiline, disabled, invalid |
| Core | Checkbox | Shared primitive | Yes | Native usage | Unchecked outline, soft filled checked, disabled |
| Core | PreferenceRow | Shared primitive | Yes | Not started | Off, on, disabled |
| Tasks | TaskRow | App stylesheet implementation | Yes, reference copy | Feature-local | Default, hover, editing, complete, dragging, final-row separator before add action |
| Tasks | ZonePanel | Shared heading fields + app layout | Yes | Feature-local | Empty, populated, long project title, 464px readable content cap aligned toward the center divider, 32px project-zone top inset, 16px title-to-task spacing, drop target |
| Tasks | PostponeMenu | App stylesheet implementation | Partial | Not started | Closed, open, keyboard focus |
| Navigation | Sidebar | App stylesheet implementation | Yes, reference copy | Not started | Closed, persistent desktop, modal mobile, light/dark wordmark, matched 24px open and in-panel close controls, unified navigation icon and label color, selected, standalone credit CTA, credit then theme then account, offline |
| Navigation | DateHeader | Shared typography + app placement | Yes | `BurnerDateHeader` | Today's List with date subtitle, dated list, past list with contextual primary Reschedule action, aggregate view title with descriptive subtitle |
| Navigation | ScopeTabs | Sidebar smart views | Reference copy | `TabView` + `BurnerScopeTabLabel` | Today's List, All Tasks, Upcoming, Previous, selected, loading |
| Navigation | ViewToggle | App stylesheet implementation | Yes, reference copy | Not started | Hidden by default, Burner, Kanban, List |
| Feedback | Toast | App stylesheet implementation | Yes, reference copy | Not started | Confirmation, sync, error |
| Feedback | StateRow | App stylesheet implementation | Yes, reference copy | Not started | Loading, empty, offline, error |
| Overlays | Modal | App stylesheet implementation | Yes, reference copy | Not started | Closed, open, date choice, destructive action |
| Overlays | QuickAddOverlay | App stylesheet implementation | Partial | Not started | Empty, parsed date, invalid input |
| Brand | ThemeSwatches | App stylesheet implementation | Yes, reference copy | Not started | Sand, dark, slate, clay, lavender, hover, selected |
| Brand | QuoteBox | App stylesheet implementation | Yes, reference copy | Not started | Disabled by default, empty, populated, editing |
| Brand | AuthForm | App stylesheet implementation | Yes, reference copy | Feature-local | Centered light/dark production wordmark, sign in, sign up, loading, error |

“Shared primitive” means both the app and catalog consume the same production CSS. “Reference copy” identifies the next components to extract; do not add new copies.

## Adding or changing a component

1. Confirm that an existing component or variant cannot meet the need.
2. Define semantic anatomy, variants, interactive states, accessibility, and content rules here.
3. Implement web behavior/style in `assets/design-system/` and native iOS behavior in SwiftUI when needed.
4. Render the real implementation in `styleguide.html` and/or an Xcode preview.
5. Update this status table and run the design-system checks.
