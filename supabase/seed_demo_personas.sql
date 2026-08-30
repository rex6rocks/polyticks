-- ─────────────────────────────────────────────────────────────────────────────
--  Polyticks – Seed: live backend accounts for the Quick Demo Personas
--
--  Creates one auth.user per mockAccounts entry in lib/data/mock_data.dart
--  (same email + password), so tapping a demo persona in LIVE mode performs a
--  real signInWithPassword and the app enters with a genuine session.
--
--  Run once in Dashboard → SQL Editor (runs as postgres, can write auth.*).
--  Idempotent: safe to re-run.
--
--  NOTE: the handle_new_user trigger fires on auth.users INSERT and creates a
--  basic profiles row; we then upsert the correct role/details on top.
-- ─────────────────────────────────────────────────────────────────────────────

-- Provides crypt() / gen_salt() for password hashing (needed by auth.users).
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Helper to create-or-get an auth user by email.
CREATE OR REPLACE FUNCTION public.seed_demo_user(
  p_email text, p_password text, p_phone text
) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public, extensions AS $$
DECLARE
  v_id uuid;
BEGIN
  SELECT id INTO v_id FROM auth.users WHERE email = p_email LIMIT 1;
  IF v_id IS NULL THEN
    INSERT INTO auth.users (
      instance_id, id, aud, role, email,
      encrypted_password, email_confirmed_at,
      raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, recovery_token,
      email_change_token_new, email_change
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', gen_random_uuid(),
      'authenticated', 'authenticated', p_email,
      crypt(p_password, gen_salt('bf')), now(),
      '{"provider":"email","providers":["email"]}', '{}',
      now(), now(),
      '', '', '', ''
    ) RETURNING id INTO v_id;
  END IF;
  RETURN v_id;
END;
$$;

DO $$
DECLARE
  r record;
  u uuid;
BEGIN
  FOR r IN
    SELECT * FROM (VALUES
      -- email,                 password,     phone,              username,                    role,               vstatus
      ('arjun@janta.in',        'janta123',   '+919876543210',    'Arjun Sharma',              'basic',            'approved'),
      ('priya@janta.in',        'janta123',   '+919876543211',    'Priya Menon',               'basic',            'approved'),
      -- Ravi is intentionally REJECTED so the verification status screen and
      -- re-apply flow can be exercised end-to-end with this persona.
      ('ravi@janta.in',         'janta123',   '+919876543212',    'Ravi Kumar',                'basic',            'rejected'),
      ('aad@party.in',          'party123',   '+919876500001',    'Aam Aadmi Dal Official',    'org_placeholder',  'approved'),
      ('brm@party.in',          'party123',   '+919876500002',    'Bharatiya Rashtriya Morcha Official', 'org_placeholder', 'approved'),
      ('jsp@party.in',          'party123',   '+919876500003',    'Janshakti Party Official',  'org_placeholder',  'approved'),
      ('sneha@member.in',       'member123',  '+919876511111',    'Sneha Patel',               'verified_user',    'approved'),
      ('vikram@member.in',      'member123',  '+919876522222',    'Vikram Singh',              'verified_user',    'approved'),
      ('nandini@member.in',     'member123',  '+919876533333',    'Nandini Rao',               'verified_user',    'approved'),
      ('admin@polyticks.gov',   'admin',      '+919876599999',    'Admin Officer',             'admin',            'approved')
    ) AS t(email, password, phone, username, role, vstatus)
  LOOP
    u := public.seed_demo_user(r.email, r.password, r.phone);

    -- Upsert the profile with persona details (trigger already made a basic row).
    INSERT INTO public.profiles (id, phone_number, username, role, is_verified, verification_status)
    VALUES (u, r.phone, r.username, r.role::public.user_role,
            r.vstatus = 'approved', r.vstatus::public.verification_status)
    ON CONFLICT (id) DO UPDATE
      SET phone_number       = EXCLUDED.phone_number,
          username           = EXCLUDED.username,
          role               = EXCLUDED.role,
          is_verified        = EXCLUDED.is_verified,
          verification_status= EXCLUDED.verification_status;
  END LOOP;
END;
$$;

DROP FUNCTION IF EXISTS public.seed_demo_user(text, text, text);