# 🍳 Burner List

A daily task planner built around the Burner List method from [**Make Time**](https://maketime.blog) by Jake Knapp and John Zeratsky.

## The idea

Divide your day into three zones:

- **Front Burner** — your single most important project right now
- **Back Burner** — your second priority
- **Kitchen Sink** — everything else

The constraint is the point. By limiting what fits on the paper, you're forced to decide what actually matters today — and let the rest go.

> *"The Burner List won't have room for everything, and that means you'll have to let go of things that aren't as important. But again, that's exactly the point."*
> — Make Time

## Features

- One opinionated Burner List with three focused zones per day
- All Tasks for scheduled and unscheduled work
- Direct navigation to Today, Upcoming, and Previous Burner Lists
- Global quick add (`Q`) with today, tomorrow, and weekday date parsing
- Inline scheduling that moves tasks between undated work and dated Burner Lists
- Drag and drop tasks between zones
- Postpone tasks to tomorrow
- Reschedule unfinished tasks without duplicating or completing them
- 5 color themes
- Optional advanced Kanban, general list, and quote-of-the-day views
- Syncs across devices via Supabase (Google or email login)

## Stack

Framework-free HTML, CSS, and JavaScript with a small design-token generation step. Hosted on Cloudflare Pages and backed by Supabase for auth and storage.

## Design system

[`design/tokens.json`](design/tokens.json) is the source of truth for shared
colors, spacing, and radii. It uses the Design Tokens Community Group `$type`
and `$value` conventions. Do not edit generated CSS or Swift token files.

After changing tokens, regenerate both platform outputs:

```bash
node scripts/generate-design-tokens.mjs
```

Verify that checked-in generated files are current:

```bash
node scripts/generate-design-tokens.mjs --check
```

The outputs are:

- `assets/generated/design-tokens.css`, consumed by the web app and style guide.
- `ios/BurnerList/DesignSystem/BurnerTokens.generated.swift`, consumed by SwiftUI through `BurnerTheme`.

Keep component structure and interaction code platform-native. Add shared visual
decisions to the token source only when they have the same semantic meaning on
both platforms.

The browsable component catalog is `styleguide.html`. It imports the same web
primitives used by the product from `assets/design-system/`; catalog examples
must not recreate production components. See
`design-system/component-inventory.md` for ownership, extraction status, and the
required workflow for adding components.

Web styles are layered in this order:

- `assets/generated/design-tokens.css` for generated semantic tokens.
- `assets/design-system/components.css` for reusable component primitives.
- `assets/app.css` for application layout and feature-specific styles.

Keep styles out of `index.html`; promote a rule from `assets/app.css` to the
design-system stylesheet when it becomes a reusable component contract.

Validate the component contract with:

```bash
node scripts/check-design-system.mjs
```

## Deploy

Deploys run automatically from GitHub Actions on pushes to `main`, using the repository secret `CLOUDFLARE_API_TOKEN`.

For local deploys, store a scoped Cloudflare token once in macOS Keychain:

```bash
security add-generic-password -a "$USER" -s burner-list-cloudflare-api-token -w "PASTE_TOKEN_HERE" -U
```

Then deploy without printing or committing the token:

```bash
./scripts/deploy.sh
```

## Credit

The Burner List method was created by Jake Knapp and published in [Make Time: How to Focus on What Matters Every Day](https://maketime.blog) by Jake Knapp & John Zeratsky (2018). This is an independent, unofficial app inspired by the original paper method; it is not affiliated with or endorsed by the authors.
