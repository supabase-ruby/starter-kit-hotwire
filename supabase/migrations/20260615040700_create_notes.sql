-- US-010: minimal RLS-governed table used by the Rails `notes#index` view to
-- prove that one signed-in user cannot read another's rows. Owner is recorded
-- via `auth.uid()` on insert and locked down by RLS on every other operation.

create extension if not exists "pgcrypto";

create table public.notes (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  content    text not null,
  created_at timestamptz not null default now()
);

create index notes_user_id_created_at_idx on public.notes (user_id, created_at desc);

alter table public.notes enable row level security;

create policy "Users can read own notes"
  on public.notes for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can insert own notes"
  on public.notes for insert
  to authenticated
  with check ((select auth.uid()) = user_id);
