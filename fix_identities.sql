-- ═══════════════════════════════════════════════════════════════════
-- PARTRIDG3 — Fix test user authentication
-- Run in Supabase SQL editor (project: ukwvmnddeacixfslkfsa)
-- ═══════════════════════════════════════════════════════════════════

-- STEP 1: Check current state — run this first to see what exists
select
  u.email,
  u.email_confirmed_at is not null as email_confirmed,
  u.encrypted_password is not null as has_password,
  u.raw_app_meta_data,
  i.provider,
  i.id as identity_id
from auth.users u
left join auth.identities i on i.user_id = u.id
where u.email in (
  'client@test.partridg3.co.za',
  'adviser@test.partridg3.co.za',
  'collab@test.partridg3.co.za'
);

-- ═══════════════════════════════════════════════════════════════════
-- STEP 2: Insert missing identity rows
-- Supabase email/password auth requires a row in auth.identities
-- Raw SQL inserts into auth.users do NOT create this automatically
-- ═══════════════════════════════════════════════════════════════════
insert into auth.identities (
  id,
  user_id,
  identity_data,
  provider,
  provider_id,
  last_sign_in_at,
  created_at,
  updated_at
)
select
  gen_random_uuid(),
  u.id,
  json_build_object('sub', u.id::text, 'email', u.email)::jsonb,
  'email',
  u.email,
  now(),
  now(),
  now()
from auth.users u
where u.email in (
  'client@test.partridg3.co.za',
  'adviser@test.partridg3.co.za',
  'collab@test.partridg3.co.za'
)
and not exists (
  select 1 from auth.identities i where i.user_id = u.id
);

-- ═══════════════════════════════════════════════════════════════════
-- STEP 3: Verify — should now show provider = 'email' for all 3
-- ═══════════════════════════════════════════════════════════════════
select
  u.email,
  u.email_confirmed_at is not null as email_confirmed,
  i.provider,
  i.identity_data ->> 'sub' as identity_sub
from auth.users u
join auth.identities i on i.user_id = u.id
where u.email in (
  'client@test.partridg3.co.za',
  'adviser@test.partridg3.co.za',
  'collab@test.partridg3.co.za'
)
order by u.email;
