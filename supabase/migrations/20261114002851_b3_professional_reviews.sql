-- B.3.1: authenticated professional reviews, reputation, and protected edit history.
-- This migration is additive. It does not convert legacy ratings or purge data.

-- Stop before applying constraints if existing rows cannot be preserved as-is.
DO $preflight$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_catalog.pg_policy pol
    JOIN pg_catalog.pg_class rel ON rel.oid = pol.polrelid
    JOIN pg_catalog.pg_namespace nsp ON nsp.oid = rel.relnamespace
    WHERE nsp.nspname = 'public'
      AND rel.relname = 'reviews'
      AND NOT (
        (
          pol.polname = 'resenas visibles'
          AND pol.polcmd = 'r'
          AND pol.polpermissive
          AND pol.polroles = ARRAY[0::oid]
        )
        OR
        (
          pol.polname = 'calificar mi contratacion'
          AND pol.polcmd = 'a'
          AND pol.polpermissive
          AND pol.polroles = ARRAY[
            (SELECT oid FROM pg_catalog.pg_authid WHERE rolname = 'authenticated')
          ]
        )
      )
  ) THEN
    RAISE EXCEPTION
      'B.3.1 preflight failed: unexpected or altered RLS policies exist on public.reviews; inspect them before continuing';
  END IF;

  IF EXISTS (
    WITH expected (view_name, ordinal_position, column_name, formatted_type) AS (
      VALUES
        ('professional_ratings', 1, 'professional_id', 'uuid'),
        ('professional_ratings', 2, 'total', 'bigint'),
        ('professional_ratings', 3, 'avg_price', 'numeric'),
        ('professional_ratings', 4, 'avg_reliability', 'numeric'),
        ('professional_ratings', 5, 'avg_quality', 'numeric'),
        ('professional_ratings', 6, 'avg_overall', 'numeric'),
        ('professional_search', 1, 'id', 'uuid'),
        ('professional_search', 2, 'headline', 'text'),
        ('professional_search', 3, 'is_verified', 'boolean'),
        ('professional_search', 4, 'category_id', 'bigint'),
        ('professional_search', 5, 'category_name', 'text'),
        ('professional_search', 6, 'full_name', 'text'),
        ('professional_search', 7, 'province', 'text'),
        ('professional_search', 8, 'city', 'text'),
        ('professional_search', 9, 'total_reviews', 'bigint'),
        ('professional_search', 10, 'avg_overall', 'numeric'),
        ('professional_search', 11, 'score', 'numeric'),
        ('professional_search', 12, 'avatar_path', 'text')
    ), actual AS (
      SELECT
        rel.relname AS view_name,
        att.attnum::integer AS ordinal_position,
        att.attname AS column_name,
        pg_catalog.format_type(att.atttypid, att.atttypmod) AS formatted_type
      FROM pg_catalog.pg_class rel
      JOIN pg_catalog.pg_namespace nsp ON nsp.oid = rel.relnamespace
      JOIN pg_catalog.pg_attribute att ON att.attrelid = rel.oid
      WHERE nsp.nspname = 'public'
        AND rel.relkind = 'v'
        AND rel.relname IN ('professional_ratings', 'professional_search')
        AND att.attnum > 0
        AND NOT att.attisdropped
    )
    SELECT 1
    FROM expected e
    FULL OUTER JOIN actual a
      ON a.view_name = e.view_name
     AND a.ordinal_position = e.ordinal_position
    WHERE e.view_name IS NULL
       OR a.view_name IS NULL
       OR e.column_name IS DISTINCT FROM a.column_name
       OR e.formatted_type IS DISTINCT FROM a.formatted_type
  ) THEN
    RAISE EXCEPTION
      'B.3.1 preflight failed: professional_ratings or professional_search does not match the baseline signature';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.reviews r
    JOIN public.hirings h ON h.id = r.hiring_id
    WHERE h.client_id IS DISTINCT FROM r.client_id
       OR h.professional_id IS DISTINCT FROM r.professional_id
  ) THEN
    RAISE EXCEPTION
      'B.3.1 preflight failed: a legacy review does not match its hiring';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.reviews
    GROUP BY client_id, professional_id
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION
      'B.3.1 preflight failed: duplicate legacy reviews exist for a client-professional pair';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.reviews
    WHERE hiring_id IS NULL
       OR price IS NULL
       OR reliability IS NULL
       OR quality IS NULL
  ) THEN
    RAISE EXCEPTION
      'B.3.1 preflight failed: a review is not in the expected legacy format';
  END IF;
END;
$preflight$;

ALTER TABLE public.reviews
  ADD COLUMN overall_rating smallint,
  ADD COLUMN contact_attempt_id uuid,
  ADD COLUMN edit_count smallint NOT NULL DEFAULT 0,
  ADD COLUMN edited_at timestamp with time zone,
  ADD COLUMN removed_at timestamp with time zone;

ALTER TABLE public.reviews
  ALTER COLUMN hiring_id DROP NOT NULL,
  ALTER COLUMN price DROP NOT NULL,
  ALTER COLUMN reliability DROP NOT NULL,
  ALTER COLUMN quality DROP NOT NULL;

ALTER TABLE public.professional_contact_attempts
  ADD CONSTRAINT professional_contact_attempts_identity_key
    UNIQUE (id, client_id, professional_id);

ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_format_check CHECK (
    (
      hiring_id IS NOT NULL
      AND contact_attempt_id IS NULL
      AND overall_rating IS NULL
      AND price IS NOT NULL
      AND reliability IS NOT NULL
      AND quality IS NOT NULL
    )
    OR
    (
      hiring_id IS NULL
      AND contact_attempt_id IS NOT NULL
      AND overall_rating IS NOT NULL
      AND price IS NULL
      AND reliability IS NULL
      AND quality IS NULL
    )
  ),
  ADD CONSTRAINT reviews_overall_rating_check
    CHECK (overall_rating BETWEEN 1 AND 5),
  ADD CONSTRAINT reviews_edit_count_check
    CHECK (edit_count BETWEEN 0 AND 3),
  ADD CONSTRAINT reviews_client_professional_key
    UNIQUE (client_id, professional_id),
  ADD CONSTRAINT reviews_contact_attempt_id_key
    UNIQUE (contact_attempt_id),
  ADD CONSTRAINT reviews_contact_attempt_owner_key
    FOREIGN KEY (contact_attempt_id, client_id, professional_id)
    REFERENCES public.professional_contact_attempts (id, client_id, professional_id)
    ON DELETE CASCADE;

COMMENT ON COLUMN public.reviews.overall_rating IS
  'B.3 rating; populated only for contact-attempt reviews. Legacy component scores remain unchanged.';
COMMENT ON COLUMN public.reviews.removed_at IS
  'Public removal timestamp. A removed review remains stored until an approved retention action.';

CREATE TABLE public.review_edit_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid,
  review_ref uuid,
  editor_id uuid,
  edit_ordinal smallint NOT NULL,
  old_overall_rating smallint NOT NULL,
  new_overall_rating smallint NOT NULL,
  old_comment text,
  new_comment text,
  edited_at timestamp with time zone NOT NULL,
  CONSTRAINT review_edit_history_review_fkey
    FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE SET NULL,
  CONSTRAINT review_edit_history_editor_fkey
    FOREIGN KEY (editor_id) REFERENCES public.profiles(id) ON DELETE SET NULL,
  CONSTRAINT review_edit_history_ordinal_check
    CHECK (edit_ordinal BETWEEN 1 AND 3),
  CONSTRAINT review_edit_history_old_rating_check
    CHECK (old_overall_rating BETWEEN 1 AND 5),
  CONSTRAINT review_edit_history_new_rating_check
    CHECK (new_overall_rating BETWEEN 1 AND 5),
  CONSTRAINT review_edit_history_old_comment_check
    CHECK (old_comment IS NULL OR char_length(old_comment) <= 500),
  CONSTRAINT review_edit_history_new_comment_check
    CHECK (new_comment IS NULL OR char_length(new_comment) <= 500),
  CONSTRAINT review_edit_history_review_ref_check
    CHECK (
      review_id IS NULL
      OR (review_ref IS NOT NULL AND review_ref = review_id)
    ),
  CONSTRAINT review_edit_history_real_change_check
    CHECK (
      old_overall_rating IS DISTINCT FROM new_overall_rating
      OR old_comment IS DISTINCT FROM new_comment
    ),
  CONSTRAINT review_edit_history_review_ordinal_key
    UNIQUE (review_id, edit_ordinal)
);

CREATE UNIQUE INDEX review_edit_history_review_ref_ordinal_key
  ON public.review_edit_history (review_ref, edit_ordinal)
  WHERE review_ref IS NOT NULL;

CREATE INDEX review_edit_history_review_id_idx
  ON public.review_edit_history (review_id)
  WHERE review_id IS NOT NULL;

COMMENT ON TABLE public.review_edit_history IS
  'Private append-only snapshots for B.3 edits. No automatic retention or purge policy is enabled.';
COMMENT ON COLUMN public.review_edit_history.review_ref IS
  'Private historical UUID reference without a foreign key; pseudonymous, not anonymous.';

ALTER TABLE public.review_edit_history ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.review_edit_history
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.review_edit_history TO authenticated;

CREATE POLICY review_edit_history_admin_read
  ON public.review_edit_history
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()));

-- Replace the baseline's unrestricted public SELECT and legacy direct INSERT policy.
DROP POLICY IF EXISTS "resenas visibles" ON public.reviews;
DROP POLICY IF EXISTS "calificar mi contratacion" ON public.reviews;

CREATE POLICY reviews_public_active_read
  ON public.reviews
  FOR SELECT TO anon, authenticated
  USING (removed_at IS NULL);

CREATE POLICY reviews_admin_read_all
  ON public.reviews
  FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()));

REVOKE ALL PRIVILEGES ON TABLE public.reviews
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.reviews TO anon, authenticated;

-- Both public views remain security-invoker views and keep their existing
-- output names, order, and types. Historical rows are deliberately excluded.
CREATE OR REPLACE VIEW public.professional_ratings
  WITH (security_invoker = true)
AS
SELECT
  r.professional_id,
  count(*) AS total,
  NULL::numeric AS avg_price,
  NULL::numeric AS avg_reliability,
  NULL::numeric AS avg_quality,
  pg_catalog.round(pg_catalog.avg(r.overall_rating)) AS avg_overall
FROM public.reviews r
WHERE r.contact_attempt_id IS NOT NULL
  AND r.removed_at IS NULL
GROUP BY r.professional_id;

CREATE OR REPLACE VIEW public.professional_search
  WITH (security_invoker = true)
AS
WITH b3_ratings AS (
  SELECT
    r.professional_id,
    count(*) AS total,
    pg_catalog.avg(r.overall_rating)::numeric AS average_exact
  FROM public.reviews r
  WHERE r.contact_attempt_id IS NOT NULL
    AND r.removed_at IS NULL
  GROUP BY r.professional_id
)
SELECT
  p.id,
  p.headline,
  p.is_verified,
  p.category_id,
  c.name AS category_name,
  pr.full_name,
  pr.province,
  pr.city,
  COALESCE(r.total, 0::bigint) AS total_reviews,
  CASE
    WHEN r.total IS NULL THEN NULL::numeric
    ELSE pg_catalog.round(r.average_exact)
  END AS avg_overall,
  pg_catalog.round(
    (
      5::numeric * 3.5::numeric
      + COALESCE(r.total, 0::bigint)::numeric
        * COALESCE(r.average_exact, 0::numeric)
    )
    / (COALESCE(r.total, 0::bigint)::numeric + 5::numeric),
    2
  ) AS score,
  pr.avatar_path
FROM public.professionals p
JOIN public.profiles pr ON pr.id = p.user_id
LEFT JOIN public.categories c ON c.id = p.category_id
LEFT JOIN b3_ratings r ON r.professional_id = p.id;

REVOKE ALL PRIVILEGES ON TABLE public.professional_ratings,
  public.professional_search FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.professional_ratings,
  public.professional_search TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.create_professional_review(
  p_contact_attempt_id uuid,
  p_overall_rating smallint,
  p_comment text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_client_id uuid := auth.uid();
  v_professional_id uuid;
  v_professional_user_id uuid;
  v_is_suspended boolean;
  v_review_id uuid;
BEGIN
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para publicar una calificación'
      USING ERRCODE = '28000';
  END IF;

  IF p_overall_rating IS NULL OR p_overall_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'La calificación debe estar entre 1 y 5'
      USING ERRCODE = '22023';
  END IF;

  IF p_comment IS NOT NULL AND char_length(p_comment) > 500 THEN
    RAISE EXCEPTION 'El comentario no puede superar los 500 caracteres'
      USING ERRCODE = '22023';
  END IF;

  SELECT a.professional_id
    INTO v_professional_id
  FROM public.professional_contact_attempts a
  WHERE a.id = p_contact_attempt_id
    AND a.client_id = v_client_id
    AND a.confirmed_at IS NOT NULL
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos un contacto confirmado propio'
      USING ERRCODE = '42501';
  END IF;

  SELECT p.user_id, p.is_suspended
    INTO v_professional_user_id, v_is_suspended
  FROM public.professionals p
  WHERE p.id = v_professional_id
  FOR SHARE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Este perfil profesional ya no está disponible'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_professional_user_id = v_client_id THEN
    RAISE EXCEPTION 'No podés calificarte a vos mismo'
      USING ERRCODE = '42501';
  END IF;

  IF v_is_suspended THEN
    RAISE EXCEPTION 'No se aceptan calificaciones nuevas para este perfil'
      USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.reviews (
    contact_attempt_id,
    client_id,
    professional_id,
    overall_rating,
    comment
  )
  VALUES (
    p_contact_attempt_id,
    v_client_id,
    v_professional_id,
    p_overall_rating,
    p_comment
  )
  ON CONFLICT (client_id, professional_id) DO NOTHING
  RETURNING id INTO v_review_id;

  IF v_review_id IS NULL THEN
    RAISE EXCEPTION 'Ya existe una calificación para esta pareja'
      USING ERRCODE = '23505';
  END IF;

  RETURN v_review_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.edit_professional_review(
  p_review_id uuid,
  p_overall_rating smallint,
  p_comment text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_client_id uuid := auth.uid();
  v_review_client_id uuid;
  v_contact_attempt_id uuid;
  v_old_rating smallint;
  v_old_comment text;
  v_edit_count smallint;
  v_removed_at timestamp with time zone;
  v_edited_at timestamp with time zone := pg_catalog.clock_timestamp();
BEGIN
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para editar una calificación'
      USING ERRCODE = '28000';
  END IF;

  IF p_overall_rating IS NULL OR p_overall_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'La calificación debe estar entre 1 y 5'
      USING ERRCODE = '22023';
  END IF;

  IF p_comment IS NOT NULL AND char_length(p_comment) > 500 THEN
    RAISE EXCEPTION 'El comentario no puede superar los 500 caracteres'
      USING ERRCODE = '22023';
  END IF;

  SELECT
    r.client_id,
    r.contact_attempt_id,
    r.overall_rating,
    r.comment,
    r.edit_count,
    r.removed_at
  INTO
    v_review_client_id,
    v_contact_attempt_id,
    v_old_rating,
    v_old_comment,
    v_edit_count,
    v_removed_at
  FROM public.reviews r
  WHERE r.id = p_review_id
  FOR UPDATE;

  IF NOT FOUND OR v_review_client_id IS DISTINCT FROM v_client_id THEN
    RAISE EXCEPTION 'No encontramos una calificación propia para editar'
      USING ERRCODE = '42501';
  END IF;

  IF v_contact_attempt_id IS NULL THEN
    RAISE EXCEPTION 'Las calificaciones históricas no se editan con B.3'
      USING ERRCODE = '42501';
  END IF;

  IF v_removed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Una calificación retirada no se puede editar ni republicar'
      USING ERRCODE = '42501';
  END IF;

  IF v_edit_count >= 3 THEN
    RAISE EXCEPTION 'Esta calificación ya alcanzó el máximo de tres ediciones'
      USING ERRCODE = '23514';
  END IF;

  IF v_old_rating IS NOT DISTINCT FROM p_overall_rating
     AND v_old_comment IS NOT DISTINCT FROM p_comment THEN
    RAISE EXCEPTION 'La calificación no tiene cambios'
      USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.review_edit_history (
    review_id,
    review_ref,
    editor_id,
    edit_ordinal,
    old_overall_rating,
    new_overall_rating,
    old_comment,
    new_comment,
    edited_at
  )
  VALUES (
    p_review_id,
    p_review_id,
    v_client_id,
    v_edit_count + 1,
    v_old_rating,
    p_overall_rating,
    v_old_comment,
    p_comment,
    v_edited_at
  );

  UPDATE public.reviews r
  SET overall_rating = p_overall_rating,
      comment = p_comment,
      edit_count = v_edit_count + 1,
      edited_at = v_edited_at
  WHERE r.id = p_review_id
    AND r.client_id = v_client_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.admin_remove_professional_review(
  p_review_id uuid
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tenés permiso para retirar esta calificación'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.reviews r
  SET removed_at = COALESCE(r.removed_at, pg_catalog.clock_timestamp())
  WHERE r.id = p_review_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos la calificación'
      USING ERRCODE = 'P0002';
  END IF;
END;
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION public.create_professional_review(uuid, smallint, text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_professional_review(uuid, smallint, text)
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.edit_professional_review(uuid, smallint, text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.edit_professional_review(uuid, smallint, text)
  TO authenticated;

REVOKE ALL PRIVILEGES ON FUNCTION public.admin_remove_professional_review(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_remove_professional_review(uuid)
  TO authenticated;
