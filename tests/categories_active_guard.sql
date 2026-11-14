\set ON_ERROR_STOP on
\set QUIET 1

-- Synthetic fixtures only. The companion runner compares persistent row
-- counts before/after; errors also leave the transaction uncommitted.
BEGIN;

SELECT set_config('ofiko_test.run_id', replace(gen_random_uuid()::text, '-', ''), true);
SELECT set_config('ofiko_test.owner_id', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.active_user_id', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.inactive_user_id', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.null_user_id', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.other_id', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.admin_id', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.owner_active_pro', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.owner_inactive_pro', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.owner_null_pro', gen_random_uuid()::text, true);
SELECT set_config('ofiko_test.other_pro', gen_random_uuid()::text, true);
SELECT set_config(
  'ofiko_test.active_category_id',
  (SELECT id::text FROM public.categories WHERE is_active IS TRUE ORDER BY id LIMIT 1),
  true
);
SELECT set_config(
  'ofiko_test.inactive_category_id',
  (SELECT id::text FROM public.categories WHERE is_active IS FALSE ORDER BY id LIMIT 1),
  true
);

DO $setup$
BEGIN
  IF current_setting('ofiko_test.active_category_id', true) IS NULL
     OR current_setting('ofiko_test.inactive_category_id', true) IS NULL THEN
    RAISE EXCEPTION 'FALLO: active and inactive category fixtures are required';
  END IF;
END;
$setup$;

INSERT INTO auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data
)
SELECT
  current_setting('ofiko_test.' || f.user_key)::uuid,
  'authenticated', 'authenticated',
  'category-guard+' || current_setting('ofiko_test.run_id') || '+' || f.label || '@example.invalid',
  '', pg_catalog.clock_timestamp(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Synthetic category guard test"}'::jsonb
FROM (VALUES
  ('owner_id', 'owner'), ('active_user_id', 'active'),
  ('inactive_user_id', 'inactive'), ('null_user_id', 'null'),
  ('other_id', 'other'), ('admin_id', 'admin')
) AS f(user_key, label);

INSERT INTO public.admins (user_id)
VALUES (current_setting('ofiko_test.admin_id')::uuid);

-- Create test-only legacy rows while bypassing just the guard, inside this
-- transaction. ROLLBACK restores trigger state as well as the synthetic rows.
ALTER TABLE public.professionals
  DISABLE TRIGGER professionals_active_category_guard;

INSERT INTO public.professionals (id, user_id, category_id, headline, description)
VALUES
  (current_setting('ofiko_test.owner_active_pro')::uuid,
   current_setting('ofiko_test.active_user_id')::uuid,
   current_setting('ofiko_test.active_category_id')::bigint,
   'Synthetic active profile', 'Original description'),
  (current_setting('ofiko_test.owner_inactive_pro')::uuid,
   current_setting('ofiko_test.inactive_user_id')::uuid,
   current_setting('ofiko_test.inactive_category_id')::bigint,
   'Synthetic historical inactive profile', 'Legacy description'),
  (current_setting('ofiko_test.owner_null_pro')::uuid,
   current_setting('ofiko_test.null_user_id')::uuid,
   NULL, 'Synthetic historical NULL profile', 'Legacy description'),
  (current_setting('ofiko_test.other_pro')::uuid,
   current_setting('ofiko_test.other_id')::uuid,
   current_setting('ofiko_test.active_category_id')::bigint,
   'Synthetic other profile', 'Other description');

ALTER TABLE public.professionals
  ENABLE TRIGGER professionals_active_category_guard;

-- Client-path tests: these run as authenticated under existing RLS policies.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('ofiko_test.owner_id'), true);

DO $authenticated_tests$
DECLARE
  v_new_professional uuid;
  v_rejected boolean;
  v_rows integer;
BEGIN
  INSERT INTO public.professionals (user_id, category_id, headline, description)
  VALUES (auth.uid(), current_setting('ofiko_test.active_category_id')::bigint,
          'Synthetic client insert', 'Active category accepted')
  RETURNING id INTO v_new_professional;
  PERFORM set_config('ofiko_test.inserted_pro', v_new_professional::text, true);
  RAISE NOTICE 'APROBADO CATEGORIA-01: authenticated INSERT with active category';

  v_rejected := false;
  BEGIN
    INSERT INTO public.professionals (user_id, category_id, headline, description)
    VALUES (auth.uid(), current_setting('ofiko_test.inactive_category_id')::bigint,
            'Rejected inactive insert', 'Must roll back');
  EXCEPTION WHEN SQLSTATE '23514' THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-02: inactive INSERT was accepted';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-02: authenticated inactive INSERT rejected';

  v_rejected := false;
  BEGIN
    INSERT INTO public.professionals (user_id, category_id, headline, description)
    VALUES (auth.uid(), NULL, 'Rejected NULL insert', 'Must roll back');
  EXCEPTION WHEN SQLSTATE '23514' THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-03: NULL INSERT was accepted';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-03: authenticated NULL INSERT rejected';

  PERFORM set_config('request.jwt.claim.sub', current_setting('ofiko_test.active_user_id'), true);
  v_rejected := false;
  BEGIN
    UPDATE public.professionals
       SET category_id = current_setting('ofiko_test.inactive_category_id')::bigint
     WHERE id = current_setting('ofiko_test.owner_active_pro')::uuid;
  EXCEPTION WHEN SQLSTATE '23514' THEN v_rejected := true;
  END;
  IF NOT v_rejected OR NOT EXISTS (
    SELECT 1 FROM public.professionals
     WHERE id = current_setting('ofiko_test.owner_active_pro')::uuid
       AND category_id = current_setting('ofiko_test.active_category_id')::bigint
  ) THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-04: active-to-inactive UPDATE was accepted or persisted';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-04: active-to-inactive UPDATE rejected';

  v_rejected := false;
  BEGIN
    UPDATE public.professionals
       SET category_id = 9223372036854775807::bigint
     WHERE id = current_setting('ofiko_test.owner_active_pro')::uuid;
  EXCEPTION WHEN SQLSTATE '23514' THEN v_rejected := true;
  END;
  IF NOT v_rejected OR NOT EXISTS (
    SELECT 1 FROM public.professionals
     WHERE id = current_setting('ofiko_test.owner_active_pro')::uuid
       AND category_id = current_setting('ofiko_test.active_category_id')::bigint
  ) THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-11: nonexistent category UPDATE was accepted or persisted';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-11: nonexistent category UPDATE rejected';

  PERFORM set_config('request.jwt.claim.sub', current_setting('ofiko_test.inactive_user_id'), true);
  UPDATE public.professionals
     SET category_id = category_id,
         headline = 'Historical inactive profile edited',
         description = 'Legacy category preserved'
   WHERE id = current_setting('ofiko_test.owner_inactive_pro')::uuid;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 OR NOT EXISTS (
    SELECT 1 FROM public.professionals
     WHERE id = current_setting('ofiko_test.owner_inactive_pro')::uuid
       AND category_id = current_setting('ofiko_test.inactive_category_id')::bigint
       AND headline = 'Historical inactive profile edited'
       AND description = 'Legacy category preserved'
  ) THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-05: unchanged historical inactive category was not editable';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-05: historical inactive category preserved while editing';

  UPDATE public.professionals
     SET category_id = current_setting('ofiko_test.active_category_id')::bigint
   WHERE id = current_setting('ofiko_test.owner_inactive_pro')::uuid;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-06: inactive-to-active UPDATE did not affect own row';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-06: inactive-to-active UPDATE accepted';

  PERFORM set_config('request.jwt.claim.sub', current_setting('ofiko_test.active_user_id'), true);
  v_rejected := false;
  BEGIN
    UPDATE public.professionals SET category_id = NULL
     WHERE id = current_setting('ofiko_test.owner_active_pro')::uuid;
  EXCEPTION WHEN SQLSTATE '23514' THEN v_rejected := true;
  END;
  IF NOT v_rejected THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-08: explicit change to NULL was accepted';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-08: explicit change to NULL rejected';

  PERFORM set_config('request.jwt.claim.sub', current_setting('ofiko_test.null_user_id'), true);
  UPDATE public.professionals
     SET category_id = category_id, headline = 'Historical NULL profile edited'
   WHERE id = current_setting('ofiko_test.owner_null_pro')::uuid;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 1 OR NOT EXISTS (
    SELECT 1 FROM public.professionals
     WHERE id = current_setting('ofiko_test.owner_null_pro')::uuid
       AND category_id IS NULL
       AND headline = 'Historical NULL profile edited'
  ) THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-07: unchanged historical NULL category was not editable';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-07: historical NULL category preserved while editing';

  UPDATE public.professionals
     SET category_id = current_setting('ofiko_test.active_category_id')::bigint
   WHERE id = current_setting('ofiko_test.other_pro')::uuid;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows <> 0 THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-09: RLS allowed update to another professional';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-09: RLS blocked update to another professional';
END;
$authenticated_tests$;

RESET ROLE;

-- Verify the existing administrative suspension RPC remains available and
-- does not alter category_id. This tests its established path, not a bypass.
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('ofiko_test.admin_id'), true);
SELECT public.admin_set_suspended(current_setting('ofiko_test.owner_active_pro')::uuid, true);
RESET ROLE;

DO $admin_test$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.professionals
     WHERE id = current_setting('ofiko_test.owner_active_pro')::uuid
       AND is_suspended IS TRUE
       AND category_id = current_setting('ofiko_test.active_category_id')::bigint
  ) THEN
    RAISE EXCEPTION 'FALLO CATEGORIA-10: existing admin suspension operation changed';
  END IF;
  RAISE NOTICE 'APROBADO CATEGORIA-10: existing admin suspension operation unchanged';
END;
$admin_test$;

ROLLBACK;
