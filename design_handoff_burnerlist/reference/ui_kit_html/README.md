# Burner App UI kit

Click-through recreation of `BurnerList/index.html`: sign in → the two-column Burner List board with sidebar, theme switching, quick add (press `Q`), quote of the day, and view toggle. Composes the `core`, `tasks`, `navigation`, `overlays`, and `brand` component families — see the root `readme.md` for the full inventory.

Files: `index.html` (shell + script loads), `AuthScreen.jsx`, `BoardScreen.jsx`, `App.jsx` (state + routing between the two).

Not recreated (out of scope for a click-through mock): Supabase sync, kanban/list view bodies (the toggle is visual only), drag-and-drop reordering, postpone menu wiring.
