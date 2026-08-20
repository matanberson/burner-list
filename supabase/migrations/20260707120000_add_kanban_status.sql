-- Kanban board view: adds workflow status columns to the task rows.
-- "done" is already tracked by burner_tasks_v2.done; this only adds the
-- intermediate "doing" flag plus a per-kanban-column sort order.

alter table public.burner_tasks_v2
  add column if not exists in_progress boolean not null default false,
  add column if not exists board_order double precision not null default 0;
