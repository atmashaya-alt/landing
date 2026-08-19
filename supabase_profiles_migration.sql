-- ═══════════════════════════════════════════════════════════════════
-- PARTRIDG3 — PROFILES TABLE & ROLE ROUTING FOUNDATION
-- Run this in the Supabase SQL editor (project: ukwvmnddeacixfslkfsa)
-- ═══════════════════════════════════════════════════════════════════

-- 1. PROFILES TABLE
--    One row per user. Role drives which portal they see after sign-in.
create table if not exists public.profiles (
  id          uuid        primary key references auth.users(id) on delete cascade,
  full_name   text,
  role        text        not null default 'client'
                          check (role in ('client', 'adviser', 'collaborator', 'owner')),
  avatar_url  text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

comment on column public.profiles.role is
  'client = Wealth Shield portal | adviser = Scrap3 portal | collaborator = Content hub | owner = Master view';

-- 2. ROW LEVEL SECURITY
alter table public.profiles enable row level security;

-- Each user reads and updates only their own row
create policy "profiles: own row read"
  on public.profiles for select
  using (auth.uid() = id);

create policy "profiles: own row update"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id AND role = (select role from public.profiles where id = auth.uid()));
  -- ^ prevents users from promoting their own role

-- Owner can read every profile (needed for master view)
create policy "profiles: owner reads all"
  on public.profiles for select
  using (
    exists (
      select 1 from public.profiles p
      where p.id = auth.uid() and p.role = 'owner'
    )
  );

-- Service role (used by triggers) can insert
create policy "profiles: service insert"
  on public.profiles for insert
  with check (true);

-- 3. AUTO-CREATE PROFILE ON SIGNUP
--    Fires after every new row in auth.users — no manual step needed.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, role)
  values (
    new.id,
    new.raw_user_meta_data ->> 'full_name',
    coalesce(new.raw_user_meta_data ->> 'role', 'client')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- 4. UPDATED_AT TRIGGER
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at
  before update on public.profiles
  for each row execute procedure public.set_updated_at();

-- 5. BACKFILL: create profiles for any existing auth users
--    (safe to run even if profiles already exist — the ON CONFLICT skips them)
insert into public.profiles (id, full_name, role)
select
  u.id,
  u.raw_user_meta_data ->> 'full_name',
  coalesce(u.raw_user_meta_data ->> 'role', 'client')
from auth.users u
where not exists (select 1 from public.profiles p where p.id = u.id)
on conflict (id) do nothing;

-- 6. SET AKHONA AS OWNER
--    Replace the email below with your actual Partridg3 account email.
--    Run this separately after the above — or add your email directly.
--
-- update public.profiles
-- set role = 'owner'
-- where id = (select id from auth.users where email = 'YOUR_EMAIL_HERE');

-- ═══════════════════════════════════════════════════════════════════
-- DONE. Verify with:
--   select id, full_name, role, created_at from public.profiles;
-- ═══════════════════════════════════════════════════════════════════
