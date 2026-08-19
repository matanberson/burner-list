Button renders Burner List's four button treatments: primary (solid, for the main commit action), secondary (outlined), ghost (text-only, low emphasis), and icon (compact row action).

```jsx
<Button variant="primary">+ New List</Button>
<Button variant="secondary">Export</Button>
<Button variant="ghost">+ Add task</Button>
<Button variant="icon"><Pencil size={15}/></Button>
```

Primary dims to 88% opacity on hover (never darkens). Secondary/ghost/icon pick up `--hover-tint` or a color shift. Pass `disabled` to fade to 50% opacity.
