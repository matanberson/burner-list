# iOS and sync engineering audit

Date: 2026-08-19

## Summary

The web and iOS clients authenticate against the same Supabase project and user,
but the live database is on a partially deployed v2 schema. The web client has
therefore continued writing recent changes to the legacy `burner_lists` JSON
table, while the first iOS client read `burner_lists_v2` and
`burner_tasks_v2`. This split store was the primary reason the same account
showed different lists.

## Corrected in this pass

- Web row-sync detection now recognizes missing v2 columns and intentionally
  falls back to legacy sync instead of treating the failure as transient.
- iOS Today loading compares the current row snapshot with the legacy JSON
  snapshot and uses the newer state.
- iOS task mutations are dual-written while compatibility mode is necessary.
- New lists created on iOS are represented in both stores during compatibility
  mode.
- Custom list keys are resolved through their calendar `date_key`.
- iOS now loads the full list index, chooses Today when available, falls back
  to the newest list, and exposes list switching from the header menu.
- iOS now exposes Today's List, All Tasks, Upcoming, and Previous through a
  native `TabView`, with the same titles and contextual subtitles as the web
  app.
- The native task detail flow supports editing, completing, scheduling,
  rescheduling, moving between sections, and deleting tasks.
- Burner, Kanban, and general List layouts are available from the native
  navigation menu.
- The shared SwiftUI design system now owns the date header and scope-tab label,
  and text fields use the generated semantic field-surface token.
- The Xcode test target has a valid product name and Debug builds enable
  testability.
- Xcode user state, DerivedData, test results, and `.DS_Store` files are ignored.
- Local editor settings, generated review files, iOS client configuration, and
  archive artifacts are excluded from the public repository. The repository
  contains a safe iOS configuration template and no Apple development-team ID.
- The shared design-system page now inventories authentication, system states,
  aggregate views, and web/iOS component mappings.

## Required database action

Deploy `20260807190000_reconcile_legacy_sync.sql`. It:

1. Ensures every required v2 task column exists.
2. Copies newer legacy list and task values into v2 without overwriting newer
   v2 rows.
3. Restores the scheduling index.

After production verification, remove dual writes and make v2 the only source
of truth. Keeping two writable stores indefinitely would create recurring
conflict and deletion hazards.

## Remaining high-priority work

1. Add a durable SwiftData cache and mutation outbox before claiming offline
   support.
2. Add drag reordering and editable Front/Back Burner project names to the
   native repository contract.
3. Add explicit timeout, retry, cancellation, and offline error categories.
4. Add password reset, account deletion, and Sign in with Apple before App Store
   submission.
5. Verify the reconciliation migration in production, then remove compatibility
   dual writes and make v2 the only source of truth.
6. Test timezone changes, midnight rollover, simultaneous edits, deletions, and
   list-key/date-key divergence on two clients.
7. Add repository tests using a mocked URL protocol and fixture responses for
   both schema generations.

## Verification performed

- iOS application target builds successfully for the iOS Simulator SDK.
- Four XCTest cases run successfully in an iPhone simulator, including scope
  order and date-filtering coverage.
- Web inline JavaScript parses successfully.
- Xcode project and Info plist parse successfully.
- Design-system document structure and internal section links were inspected.
- Repository diff whitespace checks pass.

Signed-in visual testing and live database migration verification still require
the user's Supabase environment.
