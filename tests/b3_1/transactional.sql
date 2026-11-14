\set ON_ERROR_STOP on
\set QUIET 1

-- All fixtures and destructive checks are contained by this transaction.
-- Any failure makes psql exit; closing the connection rolls the transaction back.
BEGIN;

DO $test$
DECLARE
  v_columns text[];
  v_types text[];
  v_security_invoker boolean;
BEGIN
  SELECT
    pg_catalog.array_agg(att.attname::text ORDER BY att.attnum),
    pg_catalog.array_agg(
      pg_catalog.format_type(att.atttypid, att.atttypmod)
      ORDER BY att.attnum
    ),
    COALESCE(rel.reloptions @> ARRAY['security_invoker=true'], false)
  INTO v_columns, v_types, v_security_invoker
  FROM pg_catalog.pg_class rel
  JOIN pg_catalog.pg_namespace nsp ON nsp.oid = rel.relnamespace
  JOIN pg_catalog.pg_attribute att ON att.attrelid = rel.oid
  WHERE nsp.nspname = 'public'
    AND rel.relname = 'professional_ratings'
    AND rel.relkind = 'v'
    AND att.attnum > 0
    AND NOT att.attisdropped
  GROUP BY rel.reloptions;

  IF v_columns IS DISTINCT FROM ARRAY[
       'professional_id', 'total', 'avg_price', 'avg_reliability',
       'avg_quality', 'avg_overall'
     ]::text[]
     OR v_types IS DISTINCT FROM ARRAY[
       'uuid', 'bigint', 'numeric', 'numeric', 'numeric', 'numeric'
     ]::text[]
     OR NOT v_security_invoker THEN
    RAISE EXCEPTION 'FALLIDO B3-E00: professional_ratings signature/options';
  END IF;

  SELECT
    pg_catalog.array_agg(att.attname::text ORDER BY att.attnum),
    pg_catalog.array_agg(
      pg_catalog.format_type(att.atttypid, att.atttypmod)
      ORDER BY att.attnum
    ),
    COALESCE(rel.reloptions @> ARRAY['security_invoker=true'], false)
  INTO v_columns, v_types, v_security_invoker
  FROM pg_catalog.pg_class rel
  JOIN pg_catalog.pg_namespace nsp ON nsp.oid = rel.relnamespace
  JOIN pg_catalog.pg_attribute att ON att.attrelid = rel.oid
  WHERE nsp.nspname = 'public'
    AND rel.relname = 'professional_search'
    AND rel.relkind = 'v'
    AND att.attnum > 0
    AND NOT att.attisdropped
  GROUP BY rel.reloptions;

  IF v_columns IS DISTINCT FROM ARRAY[
       'id', 'headline', 'is_verified', 'category_id', 'category_name',
       'full_name', 'province', 'city', 'total_reviews', 'avg_overall',
       'score', 'avatar_path'
     ]::text[]
     OR v_types IS DISTINCT FROM ARRAY[
       'uuid', 'text', 'boolean', 'bigint', 'text', 'text', 'text', 'text',
       'bigint', 'numeric', 'numeric', 'text'
     ]::text[]
     OR NOT v_security_invoker THEN
    RAISE EXCEPTION 'FALLIDO B3-E00: professional_search signature/options';
  END IF;

  RAISE NOTICE 'APROBADO B3-E00 view signatures, order, types and security_invoker';
END;
$test$;

SELECT set_config('b3test.run_id', gen_random_uuid()::text, true);
SELECT set_config('b3test.client_a', gen_random_uuid()::text, true);
SELECT set_config('b3test.client_b', gen_random_uuid()::text, true);
SELECT set_config('b3test.legacy_client', gen_random_uuid()::text, true);
SELECT set_config('b3test.pro_user_a', gen_random_uuid()::text, true);
SELECT set_config('b3test.pro_user_b', gen_random_uuid()::text, true);
SELECT set_config('b3test.pro_user_c', gen_random_uuid()::text, true);
SELECT set_config('b3test.admin_user', gen_random_uuid()::text, true);
SELECT set_config('b3test.pro_a', gen_random_uuid()::text, true);
SELECT set_config('b3test.pro_b', gen_random_uuid()::text, true);
SELECT set_config('b3test.pro_c', gen_random_uuid()::text, true);
SELECT set_config('b3test.pro_self', gen_random_uuid()::text, true);
SELECT set_config('b3test.attempt_a', gen_random_uuid()::text, true);
SELECT set_config('b3test.attempt_b', gen_random_uuid()::text, true);
SELECT set_config('b3test.attempt_c', gen_random_uuid()::text, true);
SELECT set_config('b3test.attempt_self', gen_random_uuid()::text, true);
SELECT set_config('b3test.attempt_other_client', gen_random_uuid()::text, true);
SELECT set_config('b3test.hiring_legacy', gen_random_uuid()::text, true);

INSERT INTO auth.users (
  id, aud, role, email, encrypted_password, email_confirmed_at,
  raw_app_meta_data, raw_user_meta_data
)
SELECT
  current_setting('b3test.' || f.user_key)::uuid,
  'authenticated',
  'authenticated',
  'b3test+' || current_setting('b3test.run_id') || '+' || f.label || '@example.invalid',
  '',
  pg_catalog.clock_timestamp(),
  '{"provider":"email","providers":["email"]}'::jsonb,
  '{"full_name":"Synthetic B3.1 test"}'::jsonb
FROM (VALUES
  ('client_a', 'client-a'),
  ('client_b', 'client-b'),
  ('legacy_client', 'legacy-client'),
  ('pro_user_a', 'professional-a'),
  ('pro_user_b', 'professional-b'),
  ('pro_user_c', 'professional-c'),
  ('admin_user', 'admin')
) AS f(user_key, label);

INSERT INTO public.professionals (id, user_id, is_suspended)
VALUES
  (current_setting('b3test.pro_a')::uuid, current_setting('b3test.pro_user_a')::uuid, false),
  (current_setting('b3test.pro_b')::uuid, current_setting('b3test.pro_user_b')::uuid, false),
  (current_setting('b3test.pro_c')::uuid, current_setting('b3test.pro_user_c')::uuid, false),
  (current_setting('b3test.pro_self')::uuid, current_setting('b3test.client_a')::uuid, false);

INSERT INTO public.admins (user_id)
VALUES (current_setting('b3test.admin_user')::uuid);

INSERT INTO public.professional_contacts (professional_id, phone, whatsapp)
VALUES (
  current_setting('b3test.pro_a')::uuid,
  '5550100000',
  '5491155501000'
);

INSERT INTO public.professional_contact_attempts (
  id, professional_id, client_id, attempted_at, confirmed_at
)
VALUES
  (current_setting('b3test.attempt_a')::uuid,
   current_setting('b3test.pro_a')::uuid,
   current_setting('b3test.client_a')::uuid,
   pg_catalog.clock_timestamp() - interval '1 minute', pg_catalog.clock_timestamp()),
  (current_setting('b3test.attempt_b')::uuid,
   current_setting('b3test.pro_b')::uuid,
   current_setting('b3test.client_a')::uuid,
   pg_catalog.clock_timestamp() - interval '1 minute', pg_catalog.clock_timestamp()),
  (current_setting('b3test.attempt_c')::uuid,
   current_setting('b3test.pro_c')::uuid,
   current_setting('b3test.client_a')::uuid,
   pg_catalog.clock_timestamp() - interval '1 minute', NULL),
  (current_setting('b3test.attempt_self')::uuid,
   current_setting('b3test.pro_self')::uuid,
   current_setting('b3test.client_a')::uuid,
   pg_catalog.clock_timestamp() - interval '1 minute', pg_catalog.clock_timestamp()),
  (current_setting('b3test.attempt_other_client')::uuid,
   current_setting('b3test.pro_a')::uuid,
   current_setting('b3test.client_b')::uuid,
   pg_catalog.clock_timestamp() - interval '1 minute', pg_catalog.clock_timestamp());

INSERT INTO public.hirings (id, professional_id, client_id)
VALUES (
  current_setting('b3test.hiring_legacy')::uuid,
  current_setting('b3test.pro_a')::uuid,
  current_setting('b3test.legacy_client')::uuid
);

INSERT INTO public.reviews (
  hiring_id, professional_id, client_id, price, reliability, quality, comment
)
VALUES (
  current_setting('b3test.hiring_legacy')::uuid,
  current_setting('b3test.pro_a')::uuid,
  current_setting('b3test.legacy_client')::uuid,
  1, 2, 3, 'Synthetic legacy review'
);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3test.client_a'), true);

DO $test$
BEGIN
  IF public.start_professional_contact(current_setting('b3test.pro_a')::uuid)->>'status'
       IS DISTINCT FROM 'reused' THEN
    RAISE EXCEPTION 'FALLIDO B3-R01: B.1 contact reuse';
  END IF;
  IF NOT EXISTS (
    SELECT 1 FROM public.professional_contact_attempts
    WHERE id = current_setting('b3test.attempt_a')::uuid
      AND client_id = auth.uid()
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-R02: B.2 own contact history';
  END IF;
  RAISE NOTICE 'APROBADO B3-R01 B.1 contact reuse';
  RAISE NOTICE 'APROBADO B3-R02 B.2 own contact history';
END;
$test$;

DO $test$
BEGIN
  BEGIN
    PERFORM public.create_professional_review(
      current_setting('b3test.attempt_c')::uuid, 4::smallint, 'Synthetic review'
    );
    RAISE EXCEPTION 'FALLIDO B3-A01: unconfirmed contact was accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-A01 unconfirmed contact rejected';
  END;

  PERFORM public.confirm_professional_contact(
    current_setting('b3test.attempt_c')::uuid
  );
  IF NOT EXISTS (
    SELECT 1 FROM public.professional_contact_attempts
    WHERE id = current_setting('b3test.attempt_c')::uuid
      AND confirmed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-R03: B.1 contact confirmation';
  END IF;
  RAISE NOTICE 'APROBADO B3-R03 B.1 contact confirmation';

  BEGIN
    PERFORM public.create_professional_review(gen_random_uuid(), 4::smallint, NULL);
    RAISE EXCEPTION 'FALLIDO B3-A02: unknown contact was accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-A02 unknown contact rejected';
  END;

  BEGIN
    PERFORM public.create_professional_review(
      current_setting('b3test.attempt_other_client')::uuid, 4::smallint, NULL
    );
    RAISE EXCEPTION 'FALLIDO B3-A03: another clients contact was accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-A03 another clients contact rejected';
  END;

  BEGIN
    PERFORM public.create_professional_review(
      current_setting('b3test.attempt_self')::uuid, 4::smallint, NULL
    );
    RAISE EXCEPTION 'FALLIDO B3-A04: self-review was accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-A04 self-review rejected';
  END;

  BEGIN
    PERFORM public.create_professional_review(
      current_setting('b3test.attempt_a')::uuid, 0::smallint, NULL
    );
    RAISE EXCEPTION 'FALLIDO B3-A05: rating zero was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    RAISE NOTICE 'APROBADO B3-A05 rating zero rejected';
  END;

  BEGIN
    PERFORM public.create_professional_review(
      current_setting('b3test.attempt_a')::uuid, 6::smallint, NULL
    );
    RAISE EXCEPTION 'FALLIDO B3-A06: rating six was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    RAISE NOTICE 'APROBADO B3-A06 rating six rejected';
  END;

  BEGIN
    PERFORM public.create_professional_review(
      current_setting('b3test.attempt_a')::uuid, 4::smallint, pg_catalog.repeat('x', 501)
    );
    RAISE EXCEPTION 'FALLIDO B3-A07: oversized comment was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    RAISE NOTICE 'APROBADO B3-A07 oversized comment rejected';
  END;
END;
$test$;

SELECT set_config(
  'b3test.review_a',
  public.create_professional_review(
    current_setting('b3test.attempt_a')::uuid, 4::smallint, 'Synthetic B3 review A'
  )::text,
  true
);

DO $test$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.reviews
    WHERE id = current_setting('b3test.review_a')::uuid
      AND client_id = auth.uid()
      AND professional_id = current_setting('b3test.pro_a')::uuid
      AND overall_rating = 4
      AND edit_count = 0
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-P01: initial publication state';
  END IF;
  RAISE NOTICE 'APROBADO B3-P01 initial publication state';
END;
$test$;

DO $test$
BEGIN
  BEGIN
    PERFORM public.create_professional_review(
      current_setting('b3test.attempt_a')::uuid, 5::smallint, NULL
    );
    RAISE EXCEPTION 'FALLIDO B3-P02: duplicate review was accepted';
  EXCEPTION WHEN SQLSTATE '23505' THEN
    RAISE NOTICE 'APROBADO B3-P02 duplicate review rejected';
  END;

  BEGIN
    INSERT INTO public.reviews (
      contact_attempt_id, client_id, professional_id, overall_rating
    ) VALUES (
      current_setting('b3test.attempt_b')::uuid,
      auth.uid(),
      current_setting('b3test.pro_b')::uuid,
      3
    );
    RAISE EXCEPTION 'FALLIDO B3-S01: direct review insert was accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-S01 direct review insert denied';
  END;

  BEGIN
    UPDATE public.reviews SET edit_count = 3
    WHERE id = current_setting('b3test.review_a')::uuid;
    RAISE EXCEPTION 'FALLIDO B3-S02: direct review update was accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-S02 direct review update denied';
  END;

  BEGIN
    INSERT INTO public.review_edit_history (
      review_id, review_ref, editor_id, edit_ordinal,
      old_overall_rating, new_overall_rating, edited_at
    ) VALUES (
      current_setting('b3test.review_a')::uuid,
      current_setting('b3test.review_a')::uuid,
      auth.uid(), 1, 4, 5, pg_catalog.clock_timestamp()
    );
    RAISE EXCEPTION 'FALLIDO B3-S03: direct audit insert was accepted';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-S03 direct audit insert denied';
  END;
END;
$test$;

SELECT set_config(
  'b3test.review_b',
  public.create_professional_review(
    current_setting('b3test.attempt_b')::uuid, 2::smallint, 'Synthetic B3 review B'
  )::text,
  true
);

RESET ROLE;
SET LOCAL ROLE anon;
DO $test$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.reviews
    WHERE id = current_setting('b3test.review_a')::uuid
      AND removed_at IS NULL
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-P03: public cannot read an active review';
  END IF;
  IF (SELECT total FROM public.professional_ratings
      WHERE professional_id = current_setting('b3test.pro_a')::uuid) <> 1 THEN
    RAISE EXCEPTION 'FALLIDO B3-P04: public B3 ratings view';
  END IF;
  RAISE NOTICE 'APROBADO B3-P03 active review is public';
  RAISE NOTICE 'APROBADO B3-P04 public B3 ratings view';
END;
$test$;

RESET ROLE;

DO $test$
BEGIN
  IF (SELECT total FROM public.professional_ratings
      WHERE professional_id = current_setting('b3test.pro_a')::uuid) <> 1
     OR (SELECT avg_overall FROM public.professional_ratings
         WHERE professional_id = current_setting('b3test.pro_a')::uuid) <> 4
     OR (SELECT avg_price FROM public.professional_ratings
         WHERE professional_id = current_setting('b3test.pro_a')::uuid) IS NOT NULL THEN
    RAISE EXCEPTION 'FALLIDO B3-E01: legacy score entered B3 reputation';
  END IF;

  IF (SELECT total_reviews FROM public.professional_search
      WHERE id = current_setting('b3test.pro_b')::uuid) <> 1
     OR (SELECT avg_overall FROM public.professional_search
         WHERE id = current_setting('b3test.pro_b')::uuid) <> 2
     OR (SELECT score FROM public.professional_search
         WHERE id = current_setting('b3test.pro_b')::uuid) <> 3.25 THEN
    RAISE EXCEPTION 'FALLIDO B3-E02: weighted reputation formula';
  END IF;

  IF (SELECT total_reviews FROM public.professional_search
      WHERE id = current_setting('b3test.pro_c')::uuid) <> 0
     OR (SELECT avg_overall FROM public.professional_search
         WHERE id = current_setting('b3test.pro_c')::uuid) IS NOT NULL
     OR (SELECT score FROM public.professional_search
         WHERE id = current_setting('b3test.pro_c')::uuid) <> 3.5 THEN
    RAISE EXCEPTION 'FALLIDO B3-E03: empty B3 reputation state';
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.reviews
    WHERE client_id = current_setting('b3test.legacy_client')::uuid
      AND hiring_id = current_setting('b3test.hiring_legacy')::uuid
      AND price = 1 AND reliability = 2 AND quality = 3
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-E04: legacy review was altered';
  END IF;

  RAISE NOTICE 'APROBADO B3-E01 legacy ratings excluded';
  RAISE NOTICE 'APROBADO B3-E02 weighted reputation';
  RAISE NOTICE 'APROBADO B3-E03 zero-review mean is NULL';
  RAISE NOTICE 'APROBADO B3-E04 legacy review preserved';
END;
$test$;

SELECT set_config(
  'b3test.pro_b_before',
  (
    SELECT pg_catalog.concat_ws('|', total_reviews, avg_overall, score)
    FROM public.professional_search
    WHERE id = current_setting('b3test.pro_b')::uuid
  ),
  true
);

UPDATE public.professionals
SET is_suspended = true
WHERE id = current_setting('b3test.pro_a')::uuid;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3test.client_b'), true);

DO $test$
BEGIN
  BEGIN
    PERFORM public.create_professional_review(
      current_setting('b3test.attempt_other_client')::uuid, 4::smallint, NULL
    );
    RAISE EXCEPTION 'FALLIDO B3-A08: suspended professional accepted a new review';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-A08 suspended professional rejected for new review';
  END;

  BEGIN
    PERFORM public.edit_professional_review(
      current_setting('b3test.review_a')::uuid, 3::smallint, 'Unauthorized edit'
    );
    RAISE EXCEPTION 'FALLIDO B3-S04: another client edited the review';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-S04 another client cannot edit';
  END;
END;
$test$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3test.client_a'), true);

DO $test$
BEGIN
  BEGIN
    PERFORM public.edit_professional_review(
      current_setting('b3test.review_a')::uuid, 4::smallint, 'Synthetic B3 review A'
    );
    RAISE EXCEPTION 'FALLIDO B3-A09: no-op edit was accepted';
  EXCEPTION WHEN SQLSTATE '22023' THEN
    RAISE NOTICE 'APROBADO B3-A09 no-op edit rejected';
  END;
END;
$test$;

SELECT public.edit_professional_review(
  current_setting('b3test.review_a')::uuid, 3::smallint, 'Synthetic edit one'
);
SELECT public.edit_professional_review(
  current_setting('b3test.review_a')::uuid, 4::smallint, 'Synthetic edit two'
);
SELECT public.edit_professional_review(
  current_setting('b3test.review_a')::uuid, 5::smallint, 'Synthetic edit three'
);

DO $test$
BEGIN
  IF (SELECT edit_count FROM public.reviews
      WHERE id = current_setting('b3test.review_a')::uuid) <> 3
     OR (SELECT overall_rating FROM public.reviews
         WHERE id = current_setting('b3test.review_a')::uuid) <> 5 THEN
    RAISE EXCEPTION 'FALLIDO B3-A10: review edit_count/rating state';
  END IF;
  RAISE NOTICE 'APROBADO B3-A10 review edit_count and rating updated';
END;
$test$;

RESET ROLE;
DO $test$
BEGIN
  IF (SELECT count(*) FROM public.review_edit_history
      WHERE review_ref = current_setting('b3test.review_a')::uuid) <> 3 THEN
    RAISE EXCEPTION 'FALLIDO B3-A10: expected three audit events as postgres';
  END IF;
  RAISE NOTICE 'APROBADO B3-A10 three audit events recorded';
END;
$test$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3test.client_a'), true);

DO $test$
BEGIN
  BEGIN
    PERFORM public.edit_professional_review(
      current_setting('b3test.review_a')::uuid, 1::smallint, 'Fourth edit'
    );
    RAISE EXCEPTION 'FALLIDO B3-A11: fourth edit was accepted';
  EXCEPTION WHEN SQLSTATE '23514' THEN
    RAISE NOTICE 'APROBADO B3-A11 fourth edit rejected';
  END;
END;
$test$;

RESET ROLE;
DO $test$
BEGIN
  IF (SELECT count(*) FROM public.review_edit_history
      WHERE review_ref = current_setting('b3test.review_a')::uuid) <> 3 THEN
    RAISE EXCEPTION 'FALLIDO B3-A12: rejected edit changed the audit history';
  END IF;
  RAISE NOTICE 'APROBADO B3-A12 rejected edit leaves exactly three audit events';
END;
$test$;

DO $test$
BEGIN
  IF NOT (SELECT is_suspended FROM public.professionals
          WHERE id = current_setting('b3test.pro_a')::uuid) THEN
    RAISE EXCEPTION 'FALLIDO B3-A13: edit changed suspension';
  END IF;
  IF (SELECT total_reviews FROM public.professional_search
      WHERE id = current_setting('b3test.pro_a')::uuid) <> 1
     OR (SELECT avg_overall FROM public.professional_search
         WHERE id = current_setting('b3test.pro_a')::uuid) <> 5 THEN
    RAISE EXCEPTION 'FALLIDO B3-E05: edited B3 reputation';
  END IF;
  RAISE NOTICE 'APROBADO B3-A13 suspension remains set';
  RAISE NOTICE 'APROBADO B3-E05 updated B3 score only';
END;
$test$;

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3test.client_a'), true);

DO $test$
BEGIN
  BEGIN
    PERFORM public.admin_remove_professional_review(
      current_setting('b3test.review_a')::uuid
    );
    RAISE EXCEPTION 'FALLIDO B3-B01: non-admin removed a review';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-B01 non-admin removal rejected';
  END;
END;
$test$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3test.admin_user'), true);
SELECT public.admin_remove_professional_review(
  current_setting('b3test.review_a')::uuid
);

DO $test$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.reviews
    WHERE id = current_setting('b3test.review_a')::uuid
      AND removed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-B02: admin removal did not hide the review';
  END IF;
  IF (SELECT pg_catalog.concat_ws('|', total_reviews, avg_overall, score)
      FROM public.professional_search
      WHERE id = current_setting('b3test.pro_b')::uuid)
     IS DISTINCT FROM current_setting('b3test.pro_b_before') THEN
    RAISE EXCEPTION 'FALLIDO B3-B03: removal changed another professional';
  END IF;
  IF (SELECT total_reviews FROM public.professional_search
      WHERE id = current_setting('b3test.pro_a')::uuid) <> 0
     OR (SELECT avg_overall FROM public.professional_search
         WHERE id = current_setting('b3test.pro_a')::uuid) IS NOT NULL
     OR (SELECT score FROM public.professional_search
         WHERE id = current_setting('b3test.pro_a')::uuid) <> 3.5 THEN
    RAISE EXCEPTION 'FALLIDO B3-B04: removed review remains in reputation';
  END IF;
  RAISE NOTICE 'APROBADO B3-B02 admin can remove a review';
  RAISE NOTICE 'APROBADO B3-B03 other professional reputation unchanged';
  RAISE NOTICE 'APROBADO B3-B04 removed review excluded from reputation';
END;
$test$;

SET LOCAL ROLE anon;
DO $test$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.reviews
    WHERE id = current_setting('b3test.review_a')::uuid
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-B05: anon can read a removed review';
  END IF;

  BEGIN
    PERFORM 1 FROM public.review_edit_history LIMIT 1;
    RAISE EXCEPTION 'FALLIDO B3-B06: anon can read audit history';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-B05 anon cannot read removed review';
    RAISE NOTICE 'APROBADO B3-B06 anon cannot read audit history';
  END;
END;
$test$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3test.client_b'), true);
DO $test$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.reviews
    WHERE id = current_setting('b3test.review_a')::uuid
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-B07: ordinary user can read removed review';
  END IF;
  IF EXISTS (
    SELECT 1 FROM public.review_edit_history
    WHERE review_ref = current_setting('b3test.review_a')::uuid
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-B08: ordinary user can read audit history';
  END IF;
  RAISE NOTICE 'APROBADO B3-B07 ordinary user cannot read removed review';
  RAISE NOTICE 'APROBADO B3-B08 ordinary user cannot read audit history';
END;
$test$;

RESET ROLE;
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claim.sub', current_setting('b3test.admin_user'), true);
DO $test$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM public.reviews
    WHERE id = current_setting('b3test.review_a')::uuid
      AND removed_at IS NOT NULL
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-B09: admin cannot inspect removed review';
  END IF;
  IF (SELECT count(*) FROM public.review_edit_history
      WHERE review_ref = current_setting('b3test.review_a')::uuid) <> 3 THEN
    RAISE EXCEPTION 'FALLIDO B3-B10: admin cannot inspect edit history';
  END IF;
  RAISE NOTICE 'APROBADO B3-B09 admin can inspect removed review';
  RAISE NOTICE 'APROBADO B3-B10 admin can inspect edit history';
END;
$test$;

RESET ROLE;
DELETE FROM public.reviews
WHERE id = current_setting('b3test.review_a')::uuid
  AND client_id = current_setting('b3test.client_a')::uuid;

DO $test$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.reviews
    WHERE id = current_setting('b3test.review_a')::uuid
  ) THEN
    RAISE EXCEPTION 'FALLIDO B3-D01: synthetic review delete did not occur';
  END IF;
  IF (SELECT count(*) FROM public.review_edit_history
      WHERE review_ref = current_setting('b3test.review_a')::uuid
        AND review_id IS NULL) <> 3 THEN
    RAISE EXCEPTION 'FALLIDO B3-D02: audit reference was not detached';
  END IF;
  RAISE NOTICE 'APROBADO B3-D01 synthetic review physically removed';
  RAISE NOTICE 'APROBADO B3-D02 history detached and reference retained';
END;
$test$;

SET LOCAL ROLE anon;
DO $test$
BEGIN
  BEGIN
    PERFORM 1 FROM public.review_edit_history
    WHERE review_ref = current_setting('b3test.review_a')::uuid;
    RAISE EXCEPTION 'FALLIDO B3-D03: anon can resolve detached history';
  EXCEPTION WHEN SQLSTATE '42501' THEN
    RAISE NOTICE 'APROBADO B3-D03 detached history remains private';
  END;
END;
$test$;

RESET ROLE;
ROLLBACK;

\set QUIET 0
\echo Transactional B.3.1 synthetic suite passed; all fixtures rolled back.
