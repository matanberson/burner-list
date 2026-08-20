The atomic unit of the whole product. A checkbox, an editable text input (doubles as the click target), and hover-revealed drag handle / postpone / delete controls. Only the checkbox and text are visible at rest — everything else fades in on row hover.

```jsx
<ul>
  <TaskRow text="Write launch notes" done={false} onToggle={...} onTextChange={...} />
</ul>
```
