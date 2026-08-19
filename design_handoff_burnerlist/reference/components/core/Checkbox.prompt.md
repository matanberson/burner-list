A 16px circular checkbox used on every task row. Unchecked is a hollow ring (`--text-faint`); checked fills solid `--text-mid` with a white check mark.

```jsx
<Checkbox checked={task.done} onChange={() => toggle(task.id)} />
```

Never square, never a brand-color fill — stays in the neutral text scale so it doesn't compete with the task text.
