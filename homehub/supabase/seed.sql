-- LOCAL DEVELOPMENT ONLY. Runs on `supabase db reset`, never in production.
-- Creates a demo account (demo@homehub.test / homehub-demo) with a sample home.

insert into auth.users (
  instance_id, id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data, created_at, updated_at,
  confirmation_token, recovery_token, email_change, email_change_token_new
) values (
  '00000000-0000-0000-0000-000000000000',
  '11111111-1111-4111-8111-111111111111',
  'authenticated', 'authenticated', 'demo@homehub.test',
  extensions.crypt('homehub-demo', extensions.gen_salt('bf')),
  now(),
  '{"provider": "email", "providers": ["email"]}',
  '{"full_name": "Kai"}',
  now(), now(), '', '', '', ''
);

insert into auth.identities (id, user_id, provider_id, identity_data, provider, last_sign_in_at, created_at, updated_at)
values (
  gen_random_uuid(),
  '11111111-1111-4111-8111-111111111111',
  '11111111-1111-4111-8111-111111111111',
  '{"sub": "11111111-1111-4111-8111-111111111111", "email": "demo@homehub.test"}',
  'email', now(), now(), now()
);

select public.seed_sample_home('11111111-1111-4111-8111-111111111111');
