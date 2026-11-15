\set ON_ERROR_STOP on
\set QUIET 1
BEGIN;

SELECT set_config('b3sec.run_id', gen_random_uuid()::text, true);
SELECT set_config('b3sec.client', gen_random_uuid()::text, true);
SELECT set_config('b3sec.professional_user', gen_random_uuid()::text, true);
SELECT set_config('b3sec.admin_one', gen_random_uuid()::text, true);
SELECT set_config('b3sec.admin_two', gen_random_uuid()::text, true);
SELECT set_config('b3sec.professional', gen_random_uuid()::text, true);
SELECT set_config('b3sec.attempt', gen_random_uuid()::text, true);

INSERT INTO auth.users (id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data)
SELECT current_setting('b3sec.' || x.key)::uuid, 'authenticated', 'authenticated',
       'b3sec+' || current_setting('b3sec.run_id') || '+' || x.key || '@example.invalid', '',
       pg_catalog.clock_timestamp(), '{"provider":"email","providers":["email"]}'::jsonb,
       pg_catalog.jsonb_build_object('full_name', x.name)
FROM (VALUES
  ('client', 'B.3 Privacy Client'),
  ('professional_user', 'B.3 Professional'),
  ('admin_one', 'B.3 Admin One'),
  ('admin_two', 'B.3 Admin Two')
) AS x(key, name);
INSERT INTO public.professionals (id, user_id, category_id, is_suspended)
VALUES (current_setting('b3sec.professional')::uuid,
        current_setting('b3sec.professional_user')::uuid, 1, false);
INSERT INTO public.admins (user_id)
VALUES (current_setting('b3sec.admin_one')::uuid), (current_setting('b3sec.admin_two')::uuid);
INSERT INTO public.professional_contacts (professional_id, phone, whatsapp)
VALUES (current_setting('b3sec.professional')::uuid, '5551112222', '549115551112222');
INSERT INTO public.professional_contact_attempts (id, professional_id, client_id, attempted_at, confirmed_at)
VALUES (current_setting('b3sec.attempt')::uuid, current_setting('b3sec.professional')::uuid,
        current_setting('b3sec.client')::uuid, pg_catalog.clock_timestamp() - interval '1 minute', pg_catalog.clock_timestamp());

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.client'), true);
DO $test$
DECLARE v_args integer; v_returns text; v_security_definer boolean; v_config text[];
BEGIN
  SELECT p.pronargs, pg_catalog.format_type(p.prorettype, NULL), p.prosecdef,
         p.proconfig
    INTO v_args, v_returns, v_security_definer, v_config
  FROM pg_catalog.pg_proc AS p
  JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public'
    AND p.proname = 'get_my_account_suspension_status';
  IF v_args IS DISTINCT FROM 0 OR v_returns IS DISTINCT FROM 'boolean'
     OR v_security_definer IS DISTINCT FROM true
     OR NOT (v_config @> ARRAY['search_path=""']::text[])
     OR pg_catalog.has_function_privilege('service_role',
          'public.get_my_account_suspension_status()', 'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: own-suspension RPC signature or security mode is unexpected';
  END IF;
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_proc AS p
    CROSS JOIN LATERAL pg_catalog.aclexplode(p.proacl) AS acl
    WHERE p.oid = 'public.get_my_account_suspension_status()'::regprocedure
      AND acl.grantee = 0
      AND acl.privilege_type = 'EXECUTE'
  ) THEN
    RAISE EXCEPTION 'FAIL: PUBLIC can execute own-suspension RPC';
  END IF;
  IF public.get_my_account_suspension_status() IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'FAIL: active account status did not return false';
  END IF;
END;
$test$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $test$
BEGIN
  IF pg_catalog.has_function_privilege('anon',
       'public.get_my_account_suspension_status()', 'EXECUTE') THEN
    RAISE EXCEPTION 'FAIL: anon can execute own-suspension RPC';
  END IF;
  BEGIN
    PERFORM public.get_my_account_suspension_status();
    RAISE EXCEPTION 'FAIL: anonymous RPC call unexpectedly succeeded';
  EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE 'APROBADO SUSP-STATUS-ANON anonymous execution is denied';
  END;
END;
$test$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.client'), true);
SELECT set_config('b3sec.review', public.create_professional_review(current_setting('b3sec.attempt')::uuid, 4::smallint, 'Privacy test review')::text, true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.admin_one'), true);
DO $test$
BEGIN
  BEGIN
    PERFORM public.admin_set_account_suspension(current_setting('b3sec.admin_one')::uuid, true, 'self');
    RAISE EXCEPTION 'FAIL: administrator suspended itself';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$test$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $test$
DECLARE v_name text; v_rating smallint; v_comment text; v_names text[];
BEGIN
  SELECT full_name, overall_rating, comment INTO v_name, v_rating, v_comment
  FROM public.get_public_professional_reviews(current_setting('b3sec.professional')::uuid, true, 10);
  IF v_name IS DISTINCT FROM 'B.3 Privacy Client' OR v_rating IS DISTINCT FROM 4 OR v_comment IS DISTINCT FROM 'Privacy test review' THEN
    RAISE EXCEPTION 'FAIL: public projection missing approved name/review fields';
  END IF;
  SELECT p.proargnames INTO v_names
  FROM pg_catalog.pg_proc p JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
  WHERE n.nspname = 'public' AND p.proname = 'get_public_professional_reviews';
  IF v_names IS DISTINCT FROM ARRAY['p_professional_id','p_contact_based','p_limit','full_name','overall_rating','price','reliability','quality','comment','created_at']::text[] THEN
    RAISE EXCEPTION 'FAIL: public projection exposes unexpected columns';
  END IF;
  RAISE NOTICE 'APROBADO PRIV-01 public projection includes full name and only approved fields';
END;
$test$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.admin_one'), true);SELECT public.admin_set_account_suspension(current_setting('b3sec.client')::uuid, true, 'synthetic client test');
SELECT public.admin_set_account_suspension(current_setting('b3sec.admin_two')::uuid, true, 'synthetic admin test');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.client'), true);
DO $test$
DECLARE v_count integer; v_message text;
BEGIN
  IF public.get_my_account_suspension_status() IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'FAIL: suspended account status did not return true';
  END IF;
  SELECT count(*) INTO v_count FROM public.get_my_professional_review(current_setting('b3sec.professional')::uuid)
  WHERE id = current_setting('b3sec.review')::uuid;
  IF v_count <> 1 THEN RAISE EXCEPTION 'FAIL: suspended author lost own read'; END IF;
  BEGIN
    PERFORM public.edit_professional_review(current_setting('b3sec.review')::uuid, 5::smallint, 'blocked');
    RAISE EXCEPTION 'FAIL: suspended author edited';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    GET STACKED DIAGNOSTICS v_message = MESSAGE_TEXT;
    IF v_message IS DISTINCT FROM 'Tu cuenta no puede editar calificaciones' THEN
      RAISE EXCEPTION 'FAIL: suspended edit returned an unexpected rejection message';
    END IF;
  END;
  BEGIN
    PERFORM public.create_professional_review(current_setting('b3sec.attempt')::uuid, 5::smallint, 'blocked');
    RAISE EXCEPTION 'FAIL: suspended author published';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$test$;
RESET ROLE;
SET LOCAL ROLE anon;
DO $test$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.get_public_professional_reviews(current_setting('b3sec.professional')::uuid, true, 10);
  IF v_count <> 0 THEN RAISE EXCEPTION 'FAIL: suspended author review remained public'; END IF;
  IF EXISTS (SELECT 1 FROM public.professional_ratings WHERE professional_id = current_setting('b3sec.professional')::uuid) THEN
    RAISE EXCEPTION 'FAIL: suspended author remained in public ratings';
  END IF;
  IF pg_catalog.has_table_privilege('anon', 'public.reviews', 'SELECT') THEN RAISE EXCEPTION 'FAIL: anon can select reviews'; END IF;
END;
$test$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.admin_two'), true);
DO $test$
BEGIN
  IF public.is_admin() THEN RAISE EXCEPTION 'FAIL: suspended administrator retained is_admin'; END IF;
  BEGIN
    PERFORM * FROM public.admin_list_professional_reviews('active', 10, 0);
    RAISE EXCEPTION 'FAIL: suspended administrator queried moderation';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$test$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.admin_one'), true);
SELECT public.admin_set_account_suspension(current_setting('b3sec.admin_two')::uuid, true, 'synthetic admin test');
SELECT public.admin_set_account_suspension(current_setting('b3sec.client')::uuid, false, NULL);
SELECT public.admin_set_account_suspension(current_setting('b3sec.admin_two')::uuid, false, NULL);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.client'), true);
DO $test$
BEGIN
  IF public.get_my_account_suspension_status() IS DISTINCT FROM false THEN
    RAISE EXCEPTION 'FAIL: rehabilitated account status did not return false';
  END IF;
  RAISE NOTICE 'APROBADO SUSP-STATUS-REHABILITATED own status reflects rehabilitation';
END;
$test$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.admin_one'), true);
SELECT public.admin_set_account_suspension(current_setting('b3sec.professional_user')::uuid, true, 'synthetic professional account test');
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.client'), true);
DO $test$
BEGIN
  BEGIN
    PERFORM public.create_professional_review(current_setting('b3sec.attempt')::uuid, 3::smallint, 'blocked target');
    RAISE EXCEPTION 'FAIL: suspended professional account accepted a new review';
  EXCEPTION WHEN SQLSTATE '42501' THEN NULL;
  END;
END;
$test$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.admin_one'), true);
SELECT public.admin_set_account_suspension(current_setting('b3sec.professional_user')::uuid, false, NULL);
SELECT public.admin_set_suspended(current_setting('b3sec.professional')::uuid, true);
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.client'), true);
SELECT public.edit_professional_review(current_setting('b3sec.review')::uuid, 5::smallint, 'active author can edit suspended profile');
DO $test$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.get_my_professional_review(current_setting('b3sec.professional')::uuid)
  WHERE edit_count = 1;
  IF v_count <> 1 THEN RAISE EXCEPTION 'FAIL: active author could not edit review for suspended profile'; END IF;
END;
$test$;
RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3sec.admin_one'), true);
SELECT public.admin_remove_professional_review(current_setting('b3sec.review')::uuid);
SELECT public.admin_restore_professional_review(current_setting('b3sec.review')::uuid);
DO $test$
DECLARE v_count integer;
BEGIN
  SELECT count(*) INTO v_count FROM public.admin_list_review_moderation_audit(current_setting('b3sec.review')::uuid, 20, 0);
  IF v_count <> 2 THEN RAISE EXCEPTION 'FAIL: moderation audit did not record both actions'; END IF;
  IF pg_catalog.has_table_privilege('authenticated', 'public.reviews', 'SELECT') THEN RAISE EXCEPTION 'FAIL: authenticated has direct review SELECT'; END IF;
END;
$test$;

DO $test$
BEGIN
  RAISE NOTICE 'APROBADO SUSP-01 account suspension blocks B.3 publication and edits';
  RAISE NOTICE 'APROBADO SUSP-02 authors keep their own private read';
  RAISE NOTICE 'APROBADO SUSP-03 suspended accounts are hidden from public ratings';
  RAISE NOTICE 'APROBADO SUSP-04 suspended administrators lose admin access';
  RAISE NOTICE 'APROBADO SUSP-05 active author can edit a review of a suspended profile';
  RAISE NOTICE 'APROBADO SUSP-STATUS-OWN RPC exposes only own active/suspended boolean';
  RAISE NOTICE 'APROBADO MOD-01 moderator actions are audited and reversible';
END;
$test$;
ROLLBACK;
\set QUIET 0
\echo Account suspension and review privacy tests passed; all fixtures rolled back.
