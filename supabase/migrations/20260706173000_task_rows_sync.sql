-- Burner List v2 sync schema
-- Moves sync from one JSON blob per list to row-level lists and tasks.

create extension if not exists pgcrypto;

create table if not exists public.burner_lists_v2 (
  user_id uuid not null references auth.users(id) on delete cascade,
  key text not null,
  date_key text not null,
  front_name text not null default '',
  back_name text not null default '',
  quote text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, key)
);

create table if not exists public.burner_tasks_v2 (
  user_id uuid not null references auth.users(id) on delete cascade,
  id text not null,
  list_key text not null,
  zone text not null check (zone in ('front-burner', 'back-burner', 'kitchen-sink', 'unscheduled')),
  text text not null default '',
  done boolean not null default false,
  sort_order double precision not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  primary key (user_id, id)
);

create index if not exists burner_lists_v2_user_updated_idx
  on public.burner_lists_v2 (user_id, updated_at desc);

create index if not exists burner_tasks_v2_user_list_idx
  on public.burner_tasks_v2 (user_id, list_key, zone, sort_order);

alter table public.burner_lists_v2 enable row level security;
alter table public.burner_tasks_v2 enable row level security;

drop policy if exists "Users can read own lists v2" on public.burner_lists_v2;
drop policy if exists "Users can insert own lists v2" on public.burner_lists_v2;
drop policy if exists "Users can update own lists v2" on public.burner_lists_v2;
drop policy if exists "Users can delete own lists v2" on public.burner_lists_v2;

create policy "Users can read own lists v2"
  on public.burner_lists_v2 for select
  using (auth.uid() = user_id);

create policy "Users can insert own lists v2"
  on public.burner_lists_v2 for insert
  with check (auth.uid() = user_id);

create policy "Users can update own lists v2"
  on public.burner_lists_v2 for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own lists v2"
  on public.burner_lists_v2 for delete
  using (auth.uid() = user_id);

drop policy if exists "Users can read own tasks v2" on public.burner_tasks_v2;
drop policy if exists "Users can insert own tasks v2" on public.burner_tasks_v2;
drop policy if exists "Users can update own tasks v2" on public.burner_tasks_v2;
drop policy if exists "Users can delete own tasks v2" on public.burner_tasks_v2;

create policy "Users can read own tasks v2"
  on public.burner_tasks_v2 for select
  using (auth.uid() = user_id);

create policy "Users can insert own tasks v2"
  on public.burner_tasks_v2 for insert
  with check (auth.uid() = user_id);

create policy "Users can update own tasks v2"
  on public.burner_tasks_v2 for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can delete own tasks v2"
  on public.burner_tasks_v2 for delete
  using (auth.uid() = user_id);

do $$
begin
  alter publication supabase_realtime add table public.burner_lists_v2;
exception
  when duplicate_object then null;
end $$;

do $$
begin
  alter publication supabase_realtime add table public.burner_tasks_v2;
exception
  when duplicate_object then null;
end $$;

insert into public.burner_lists_v2 (
  user_id,
  key,
  date_key,
  front_name,
  back_name,
  quote,
  created_at,
  updated_at
)
select
  user_id,
  date_key,
  coalesce(state->>'date', date_key),
  coalesce(state->'front-burner'->>'name', ''),
  coalesce(state->'back-burner'->>'name', ''),
  coalesce(state->>'quote', ''),
  now(),
  coalesce(nullif(state->'_meta'->>'updatedAt', '')::timestamptz, now())
from public.burner_lists
where state is not null
  and coalesce((state->>'_deleted')::boolean, false) is false
on conflict (user_id, key) do update set
  date_key = excluded.date_key,
  front_name = excluded.front_name,
  back_name = excluded.back_name,
  quote = excluded.quote,
  updated_at = greatest(public.burner_lists_v2.updated_at, excluded.updated_at),
  deleted_at = null;

insert into public.burner_tasks_v2 (
  user_id,
  id,
  list_key,
  zone,
  text,
  done,
  sort_order,
  created_at,
  updated_at
)
select
  b.user_id,
  coalesce(task->>'id', gen_random_uuid()::text),
  b.date_key,
  z.zone,
  coalesce(task->>'text', ''),
  coalesce((task->>'done')::boolean, false),
  z.ordinality - 1,
  now(),
  coalesce(nullif(task->'_meta'->>'updatedAt', '')::timestamptz, now())
from public.burner_lists b
cross join lateral (
  select 'front-burner'::text as zone, task, ordinality
  from jsonb_array_elements(coalesce(b.state->'front-burner'->'tasks', '[]'::jsonb)) with ordinality as t(task, ordinality)
  union all
  select 'back-burner'::text as zone, task, ordinality
  from jsonb_array_elements(coalesce(b.state->'back-burner'->'tasks', '[]'::jsonb)) with ordinality as t(task, ordinality)
  union all
  select 'kitchen-sink'::text as zone, task, ordinality
  from jsonb_array_elements(coalesce(b.state->'kitchen-sink'->'tasks', '[]'::jsonb)) with ordinality as t(task, ordinality)
  union all
  select 'unscheduled'::text as zone, task, ordinality
  from jsonb_array_elements(coalesce(b.state->'unscheduled', '[]'::jsonb)) with ordinality as t(task, ordinality)
) z
where b.state is not null
  and coalesce(task->>'text', '') <> ''
  and coalesce((b.state->>'_deleted')::boolean, false) is false
on conflict (user_id, id) do update set
  list_key = excluded.list_key,
  zone = excluded.zone,
  text = excluded.text,
  done = excluded.done,
  sort_order = excluded.sort_order,
  updated_at = greatest(public.burner_tasks_v2.updated_at, excluded.updated_at),
  deleted_at = null;
