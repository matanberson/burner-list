Every data-driven surface needs an explicit non-happy-path row: loading, empty, offline, or error. Copy stays calm and reassuring even for errors ("Couldn't sync. Your local changes are safe.").

```jsx
<StateRow icon="⟳" text="Loading your lists…" />
<StateRow icon="!" text="Couldn't sync. Your local changes are safe." error />
```
