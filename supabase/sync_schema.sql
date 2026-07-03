-- Evoly remote sync schema.
-- Run this in the Supabase SQL Editor for the Evoly project.

create table if not exists public.sync_changes (
  id uuid primary key default gen_random_uuid(),
  revision bigserial not null unique,
  account_id uuid not null references auth.users(id) on delete cascade,
  entity_type text not null,
  entity_id text not null,
  operation text not null check (operation in ('upsert', 'delete')),
  payload_json jsonb not null default '{}'::jsonb,
  base_remote_revision bigint not null default 0,
  device_id text not null,
  client_change_id text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists idx_sync_changes_account_revision
  on public.sync_changes(account_id, revision);

create index if not exists idx_sync_changes_account_entity
  on public.sync_changes(account_id, entity_type, entity_id, revision desc);

alter table public.sync_changes enable row level security;

drop policy if exists "sync_changes_select_own" on public.sync_changes;
create policy "sync_changes_select_own"
  on public.sync_changes
  for select
  to authenticated
  using (account_id = auth.uid());

drop policy if exists "sync_changes_insert_own" on public.sync_changes;
create policy "sync_changes_insert_own"
  on public.sync_changes
  for insert
  to authenticated
  with check (account_id = auth.uid());

grant select, insert on public.sync_changes to authenticated;
grant usage, select on sequence public.sync_changes_revision_seq to authenticated;
