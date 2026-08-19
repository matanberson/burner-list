-- First-class task scheduling for Inbox and aggregate task views.
alter table public.burner_tasks_v2
  add column if not exists scheduled_date date,
  add column if not exists completed_at timestamptz;

-- Existing tasks were created inside dated Burner Lists, including the old
-- per-list "unscheduled" staging zone, so preserve that date during migration.
update public.burner_tasks_v2 as task
set scheduled_date = list.date_key::date
from public.burner_lists_v2 as list
where task.user_id = list.user_id
  and task.list_key = list.key
  and task.list_key <> '__inbox__'
  and task.scheduled_date is null
  and list.date_key ~ '^\d{4}-\d{2}-\d{2}$';

update public.burner_tasks_v2
set completed_at = updated_at
where done is true and completed_at is null;

create index if not exists burner_tasks_v2_user_open_schedule_idx
  on public.burner_tasks_v2 (user_id, scheduled_date, updated_at desc)
  where done is false and deleted_at is null;
