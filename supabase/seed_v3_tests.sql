-- Polyticks V3 Phase 0.2 test seed (idempotent)
BEGIN;

INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password, email_confirmed_at, created_at, updated_at, raw_app_meta_data, raw_user_meta_data)
VALUES
 ('00000000-0000-0000-0000-000000000000','11111111-1111-1111-1111-111111111111','authenticated','authenticated','u1@test.polyticks.app','x',now(),now(),now(),'{"provider":"phone","providers":["phone"]}','{}'),
 ('00000000-0000-0000-0000-000000000000','22222222-2222-2222-2222-222222222222','authenticated','authenticated','u2@test.polyticks.app','x',now(),now(),now(),'{"provider":"phone","providers":["phone"]}','{}'),
 ('00000000-0000-0000-0000-000000000000','33333333-3333-3333-3333-333333333333','authenticated','authenticated','u3@test.polyticks.app','x',now(),now(),now(),'{"provider":"phone","providers":["phone"]}','{}')
ON CONFLICT (id) DO NOTHING;

-- GoTrue requires email identities + non-NULL token columns for password login.
-- Password for all three test users: Polyticks#Test2026
INSERT INTO auth.identities (id, user_id, provider, provider_id, identity_data, last_sign_in_at, created_at, updated_at)
SELECT gen_random_uuid(), u.id, 'email', u.email,
       jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true),
       now(), now(), now()
FROM auth.users u
WHERE u.id::text IN ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333')
ON CONFLICT DO NOTHING;

UPDATE auth.users u SET
    encrypted_password = extensions.crypt('Polyticks#Test2026', extensions.gen_salt('bf')),
    confirmation_token = '', recovery_token = '',
    email_change = '', email_change_token_new = '', email_change_token_current = '',
    reauthentication_token = '', phone_change_token = '',
    raw_app_meta_data  = jsonb_build_object('provider','email','providers',jsonb_build_array('email')),
    raw_user_meta_data = jsonb_build_object('sub', u.id::text, 'email', u.email, 'email_verified', true)
WHERE u.id::text IN ('11111111-1111-1111-1111-111111111111','22222222-2222-2222-2222-222222222222','33333333-3333-3333-3333-333333333333');

INSERT INTO public.communities (id, name, state) VALUES
 ('a0000000-0000-0000-0000-000000000001','Community A','Test State'),
 ('b0000000-0000-0000-0000-000000000002','Community B','Test State')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.wards (id, community_id, name, ward_number) VALUES
 ('a0000000-0000-0000-0000-00000000a0a1','a0000000-0000-0000-0000-000000000001','Ward A1',1),
 ('b0000000-0000-0000-0000-00000000b0b1','b0000000-0000-0000-0000-000000000002','Ward B1',1)
ON CONFLICT (id) DO NOTHING;

UPDATE public.profiles SET username='U1', is_verified=false, verification_status='unverified' WHERE id='11111111-1111-1111-1111-111111111111';
UPDATE public.profiles SET username='U2', is_verified=true,  verification_status='approved',  community_id='a0000000-0000-0000-0000-000000000001', ward_id='a0000000-0000-0000-0000-00000000a0a1' WHERE id='22222222-2222-2222-2222-222222222222';
UPDATE public.profiles SET username='U3', is_verified=true,  verification_status='approved',  community_id='b0000000-0000-0000-0000-000000000002', ward_id='b0000000-0000-0000-0000-00000000b0b1' WHERE id='33333333-3333-3333-3333-333333333333';

INSERT INTO public.posts (id, author_id, channel_type, community_id, content, fact_check_status) VALUES
 ('aa000000-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222','local','a0000000-0000-0000-0000-000000000001','Poll post: which ward project first?', 'none'),
 ('aa000000-0000-0000-0000-000000000002','22222222-2222-2222-2222-222222222222','local','a0000000-0000-0000-0000-000000000001','Regular Community A post', 'verified_context'),
 ('bb000000-0000-0000-0000-000000000001','33333333-3333-3333-3333-333333333333','local','b0000000-0000-0000-0000-000000000002','Regular Community B post', 'none'),
 ('cc000000-0000-0000-0000-000000000001','22222222-2222-2222-2222-222222222222','broader',NULL,'National post one', 'none'),
 ('cc000000-0000-0000-0000-000000000002','33333333-3333-3333-3333-333333333333','broader',NULL,'National post two', 'none')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.polls (id, post_id, question) VALUES
 ('dd000000-0000-0000-0000-000000000001','aa000000-0000-0000-0000-000000000001','Which project should be prioritized?')
ON CONFLICT (id) DO NOTHING;

INSERT INTO public.poll_options (id, poll_id, option_text, vote_count) VALUES
 ('ee000000-0000-0000-0000-000000000001','dd000000-0000-0000-0000-000000000001','Road repair',0),
 ('ee000000-0000-0000-0000-000000000002','dd000000-0000-0000-0000-000000000001','Street lighting',0),
 ('ee000000-0000-0000-0000-000000000003','dd000000-0000-0000-0000-000000000001','Park cleanup',0)
ON CONFLICT (id) DO NOTHING;

COMMIT;
