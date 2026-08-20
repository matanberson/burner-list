# Burner List shared data contract

This document defines the contract shared by the web and iOS clients. Supabase's
`burner_lists_v2` and `burner_tasks_v2` tables are the canonical remote store.

## List rows

`burner_lists_v2` is keyed by `(user_id, key)`.

- A dated list uses `YYYY-MM-DD` for both `key` and `date_key`.
- The inbox uses `__inbox__` as its key.
- `front_name`, `back_name`, and `quote` belong to the list.
- `updated_at` is the last client mutation time in UTC.
- A non-null `deleted_at` is a tombstone. Clients must not revive it unless the
  user explicitly recreates that list after the tombstone time.

## Task rows

`burner_tasks_v2` is keyed by `(user_id, id)`. IDs are UUID strings generated
on the client and remain stable when a task moves between lists or zones.

- `list_key` identifies the owning list.
- `zone` is one of `front-burner`, `back-burner`, `kitchen-sink`, or
  `unscheduled`.
- `sort_order` orders tasks within a zone; lower values appear first.
- `in_progress` and `board_order` control the Kanban projection.
- `scheduled_date` is null for inbox work and a calendar date for scheduled work.
- `completed_at` is set when `done` becomes true and cleared when reopened.
- `updated_at` is the last client mutation time in UTC.
- A non-null `deleted_at` is a tombstone and wins over an older live row.

## Dates and time

- Calendar keys are produced in the user's current calendar and time zone.
- Database timestamps are ISO-8601 UTC instants.
- A list's calendar date does not change if the device later changes time zone.

## Merge rules

1. Compare rows with the same primary key.
2. The row with the latest `updated_at` wins.
3. If timestamps are equal, a tombstone wins over a live row.
4. Reordering updates the moved task and any siblings whose order changed.
5. Clients keep failed mutations locally and retry; a successful pull must not
   discard a newer pending local mutation.

The first iOS milestone reads and writes online. Durable SwiftData outbox support
will be layered behind the repository protocol before offline mode is declared
complete.

## Shared interaction contract

The web and iOS clients expose the same concepts even when controls are native
to each platform:

- The checkbox is the only row control that completes a task.
- Activating the task text opens task details; it never changes completion.
- Task details edit the title, scheduled date (or Inbox), and burner section.
- A task's context menu/long press always offers Edit, Reschedule, and Delete.
- Navigation uses the same scopes: All Tasks, Today, Upcoming, and Previous.
- Layout uses the same modes: Burner List, Kanban, and List.
- Moving or rescheduling preserves the task ID and updates both `list_key` and
  `scheduled_date`. Removing a date moves the task to `__inbox__` and the
  `unscheduled` zone.

New task fields or navigation concepts should be added to this contract and the
canonical v2 rows first, then implemented by both clients. Platform-specific UI
may differ, but labels, mutation semantics, and resulting sync data must match.
