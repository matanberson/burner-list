The main nav surface — a fixed-position drawer opened via the top-bar hamburger. Smart views (All Tasks / Today / Upcoming / Previous) sit above a scrolling history of past Burner Lists. Active/selected rows use `--hover-tint-strong`, matching hover at a stronger intensity rather than a distinct "selected" color.

```jsx
<Sidebar lists={[{date:'5 Jul · Sunday', preview:'4 tasks'}]} activeIndex={0} />
```
