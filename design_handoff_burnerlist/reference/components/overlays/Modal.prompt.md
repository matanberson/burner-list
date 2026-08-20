Centered dialog over a 25%-black scrim, no blur. Used for the quote editor and the "paste tasks" choice (single vs. multiple). Actions right-align: cancel (outlined) then primary (solid).

```jsx
<Modal title="Paste tasks" actions={<><Button variant="secondary">Cancel</Button><Button variant="primary">Multiple tasks</Button></>}>
  This paste has 3 lines. Add each line as its own task, or keep everything in one task?
</Modal>
```
