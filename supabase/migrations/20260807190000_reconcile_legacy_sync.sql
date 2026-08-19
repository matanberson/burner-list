-- Make the row schema complete, then reconcile any newer edits that were
-- written to the legacy JSON table while a partially deployed v2 schema made
-- row sync unavailable. This migration is safe to rerun.

alter table public.burner_tasks_v2
  add column if not exists in_progress boolean not null default false,
  add column if not exists board_order double precision not null default 0,
  add column if not exists scheduled_date date,
  add column if not exists completed_at timestamptz;

insert into public.burner_lists_v2 (
  user_id, key, date_key, front_name, back_name, quote,
  created_at, updated_at, deleted_at
)
select
  legacy.user_id,
  legacy.date_key,
  case
    when legacy.state->>'date' ~ '^\d{4}-\d{2}-\d{2}$' then legacy.state->>'date'
    when legacy.date_key ~ '^\d{4}-\d{2}-\d{2}$' then legacy.date_key
    else to_char(current_date, 'YYYY-MM-DD')
  end,
  coalesce(legacy.state->'front-burner'->>'name', ''),
  coalesce(legacy.state->'back-burner'->>'name', ''),
  coalesce(legacy.state->>'quote', ''),
  now(),
  coalesce(nullif(legacy.state->'_meta'->>'updatedAt', '')::timestamptz, now()),
  case
    when coalesce((legacy.state->>'_deleted')::boolean, false)
      then coalesce(nullif(legacy.state->'_meta'->>'deletedAt', '')::timestamptz, now())
    else null
  end
from public.burner_lists legacy
where legacy.state is not null
on conflict (user_id, key) do update set
  date_key = excluded.date_key,
  front_name = excluded.front_name,
  back_name = excluded.back_name,
  quote = excluded.quote,
  updated_at = excluded.updated_at,
  deleted_at = excluded.deleted_at
where excluded.updated_at > public.burner_lists_v2.updated_at;

with legacy_tasks as (
  select
    legacy.user_id,
    legacy.date_key as list_key,
    zone.zone,
    item.task,
    item.ordinality,
    case
      when legacy.state->>'date' ~ '^\d{4}-\d{2}-\d{2}$' then (legacy.state->>'date')::date
      when legacy.date_key ~ '^\d{4}-\d{2}-\d{2}$' then legacy.date_key::date
      else null
    end as list_date,
    coalesce(nullif(legacy.state->'_meta'->>'updatedAt', '')::timestamptz, now()) as list_updated_at
  from public.burner_lists legacy
  cross join lateral (
    values
      ('front-burner'::text, coalesce(legacy.state->'front-burner'->'tasks', '[]'::jsonb)),
      ('back-burner'::text, coalesce(legacy.state->'back-burner'->'tasks', '[]'::jsonb)),
      ('kitchen-sink'::text, coalesce(legacy.state->'kitchen-sink'->'tasks', '[]'::jsonb)),
      ('unscheduled'::text, coalesce(legacy.state->'unscheduled', '[]'::jsonb))
  ) as zone(zone, tasks)
  cross join lateral jsonb_array_elements(zone.tasks) with ordinality as item(task, ordinality)
  where legacy.state is not null
    and coalesce((legacy.state->>'_deleted')::boolean, false) is false
    and coalesce(item.task->>'text', '') <> ''
)
insert into public.burner_tasks_v2 (
  user_id, id, list_key, zone, text, done, sort_order,
  in_progress, board_order, scheduled_date, completed_at,
  created_at, updated_at, deleted_at
)
select
  user_id,
  coalesce(nullif(task->>'id', ''), gen_random_uuid()::text),
  list_key,
  zone,
  coalesce(task->>'text', ''),
  coalesce(nullif(task->>'done', '')::boolean, false),
  coalesce(nullif(task->'_meta'->>'order', '')::double precision, ordinality - 1),
  coalesce(nullif(task->'_meta'->>'doing', '')::boolean, false),
  coalesce(nullif(task->'_meta'->>'boardOrder', '')::double precision, ordinality - 1),
  case when list_key = '__inbox__' then null else list_date end,
  case
    when coalesce(nullif(task->>'done', '')::boolean, false)
      then coalesce(nullif(task->'_meta'->>'completedAt', '')::timestamptz,
                    nullif(task->'_meta'->>'updatedAt', '')::timestamptz,
                    list_updated_at)
    else null
  end,
  now(),
  coalesce(nullif(task->'_meta'->>'updatedAt', '')::timestamptz, list_updated_at),
  null
from legacy_tasks
on conflict (user_id, id) do update set
  list_key = excluded.list_key,
  zone = excluded.zone,
  text = excluded.text,
  done = excluded.done,
  sort_order = excluded.sort_order,
  in_progress = excluded.in_progress,
  board_order = excluded.board_order,
  scheduled_date = excluded.scheduled_date,
  completed_at = excluded.completed_at,
  updated_at = excluded.updated_at,
  deleted_at = null
where excluded.updated_at > public.burner_tasks_v2.updated_at;

create index if not exists burner_tasks_v2_user_open_schedule_idx
  on public.burner_tasks_v2 (user_id, scheduled_date, updated_at desc)
  where done is false and deleted_at is null;
