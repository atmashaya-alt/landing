-- Delete the broken test users and recreate with correct bcrypt cost
delete from auth.users
where email in (
  'client@test.partridg3.co.za',
  'adviser@test.partridg3.co.za',
  'collab@test.partridg3.co.za'
);

-- Recreate with full required fields (bcrypt cost 10 to match Supabase default)
insert into auth.users (
  id, instance_id, email, encrypted_password,
  email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data,
  role, aud, created_at, updated_at
)
select
  gen_random_uuid(),
  '00000000-0000-0000-0000-000000000000',
  v.email,
  crypt('Test1234!', gen_salt('bf', 10)),
  now(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  v.meta::jsonb,
  'authenticated', 'authenticated',
  now(), now()
from (values
  ('client@test.partridg3.co.za',  '{"full_name":"Test Client"}'),
  ('adviser@test.partridg3.co.za', '{"full_name":"Test Adviser"}'),
  ('collab@test.partridg3.co.za',  '{"full_name":"Test Collaborator"}')
) as v(email, meta);

-- Update roles (trigger auto-creates the profiles rows)
update public.profiles set role = 'adviser'
  where id = (select id from auth.users where email = 'adviser@test.partridg3.co.za');
update public.profiles set role = 'collaborator'
  where id = (select id from auth.users where email = 'collab@test.partridg3.co.za');

-- Verify
select u.email, u.email_confirmed_at is not null as confirmed, p.role
from auth.users u
join public.profiles p on p.id = u.id
order by p.role;
