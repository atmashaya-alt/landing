-- ═══════════════════════════════════════════════════════════════════
-- PARTRIDG3 — adviser_profiles table + appointment booking policy
-- Run in Supabase SQL editor (project: aebsqfrfqovyfztmdnkw)
-- ═══════════════════════════════════════════════════════════════════

-- 1. ADVISER PROFILES — public-facing adviser cards
create table if not exists public.adviser_profiles (
  id                  uuid primary key default gen_random_uuid(),
  adviser_user_id     uuid unique references auth.users(id) on delete cascade,
  full_name           text,
  bio                 text,
  qualifications      text[],          -- e.g. {'CFP®','RE5','BCom Finance'}
  re_number           text,            -- RE5 license reference number
  fsp_number          text,            -- FAIS FSP registration number
  phone               text,
  email               text,
  whatsapp_number     text,            -- international format e.g. 27821234567
  calendly_url        text,            -- booking link (Calendly, Cal.com, etc.)
  photo_url           text,            -- public URL for headshot
  years_experience    integer,
  specialisations     text[],          -- e.g. {'Life Insurance','Retirement Planning'}
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

create trigger adviser_profiles_updated_at
  before update on public.adviser_profiles
  for each row execute function public.handle_updated_at();

alter table public.adviser_profiles enable row level security;

-- Any authenticated user can read adviser profiles (clients see their adviser card)
create policy "Authenticated users can view adviser profiles"
  on public.adviser_profiles for select
  using (auth.role() = 'authenticated');

-- Advisers can upsert their own profile
create policy "Adviser manages own profile"
  on public.adviser_profiles for all
  using (auth.uid() = adviser_user_id)
  with check (auth.uid() = adviser_user_id);

-- 2. Allow authenticated clients to insert appointment requests
--    The adviser confirms via Scrap3. Status starts as 'scheduled'.
create policy "Client can request appointment"
  on public.appointments for insert
  with check (auth.role() = 'authenticated');

-- Clients can read their own appointments
create policy "Client sees own appointments"
  on public.appointments for select
  using (
    auth.uid() = (select portal_user_id from public.clients where id = client_id limit 1)
    or auth.uid() = adviser_id
    or public.is_owner()
  );

-- Index for fast lookup by adviser
create index if not exists idx_adviser_profiles_user
  on public.adviser_profiles(adviser_user_id);
