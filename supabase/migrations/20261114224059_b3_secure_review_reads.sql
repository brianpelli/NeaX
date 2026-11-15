BEGIN;

DROP POLICY IF EXISTS reviews_public_active_read ON public.reviews;
DROP POLICY IF EXISTS reviews_admin_read_all ON public.reviews;
CREATE POLICY reviews_author_read_own
  ON public.reviews FOR SELECT TO authenticated
  USING (client_id = (SELECT auth.uid()));
CREATE POLICY reviews_admin_read_all
  ON public.reviews FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()));

-- Raw review rows are no longer a Data API resource. Public and private reads
-- use the narrow RPCs below; do not expose nested joins to private columns.
REVOKE ALL PRIVILEGES ON TABLE public.reviews FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE VIEW public.professional_ratings
  WITH (security_invoker = false, security_barrier = true)
AS
SELECT
  r.professional_id,
  count(*) AS total,
  NULL::numeric AS avg_price,
  NULL::numeric AS avg_reliability,
  NULL::numeric AS avg_quality,
  pg_catalog.round(pg_catalog.avg(r.overall_rating)) AS avg_overall
FROM public.reviews AS r
JOIN public.professionals AS p ON p.id = r.professional_id
WHERE r.contact_attempt_id IS NOT NULL
  AND r.removed_at IS NULL
  AND p.is_suspended IS FALSE
  AND NOT EXISTS (
    SELECT 1 FROM public.account_suspensions AS s
    WHERE s.user_id = r.client_id AND s.is_suspended
  )
GROUP BY r.professional_id;

CREATE OR REPLACE VIEW public.professional_search
  WITH (security_invoker = false, security_barrier = true)
AS
WITH b3_ratings AS (
  SELECT
    r.professional_id,
    count(*) AS total,
    pg_catalog.avg(r.overall_rating)::numeric AS average_exact
  FROM public.reviews AS r
  JOIN public.professionals AS rp ON rp.id = r.professional_id
  WHERE r.contact_attempt_id IS NOT NULL
    AND r.removed_at IS NULL
    AND rp.is_suspended IS FALSE
    AND NOT EXISTS (
    SELECT 1 FROM public.account_suspensions AS s
    WHERE s.user_id = r.client_id AND s.is_suspended
  )
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
  CASE WHEN r.total IS NULL THEN NULL::numeric
       ELSE pg_catalog.round(r.average_exact) END AS avg_overall,
  pg_catalog.round(
    (5::numeric * 3.5::numeric
      + COALESCE(r.total, 0::bigint)::numeric * COALESCE(r.average_exact, 0::numeric))
    / (COALESCE(r.total, 0::bigint)::numeric + 5::numeric),
    2
  ) AS score,
  pr.avatar_path
FROM public.professionals AS p
JOIN public.profiles AS pr ON pr.id = p.user_id
LEFT JOIN public.categories AS c ON c.id = p.category_id
LEFT JOIN b3_ratings AS r ON r.professional_id = p.id
WHERE p.is_suspended IS FALSE;

REVOKE ALL PRIVILEGES ON TABLE public.professional_ratings, public.professional_search
  FROM PUBLIC, anon, authenticated, service_role;
GRANT SELECT ON TABLE public.professional_ratings, public.professional_search TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_public_professional_reviews(
  p_professional_id uuid,
  p_contact_based boolean,
  p_limit integer DEFAULT 10
)
RETURNS TABLE (
  full_name text,
  overall_rating smallint,
  price smallint,
  reliability smallint,
  quality smallint,
  comment text,
  created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT
    COALESCE(NULLIF(pg_catalog.btrim(pr.full_name), ''), 'Cliente de OFIKO') AS full_name,
    r.overall_rating,
    r.price,
    r.reliability,
    r.quality,
    r.comment,
    r.created_at
  FROM public.reviews AS r
  JOIN public.professionals AS p ON p.id = r.professional_id
  JOIN public.profiles AS pr ON pr.id = r.client_id
  WHERE r.professional_id = p_professional_id
    AND r.removed_at IS NULL
    AND p.is_suspended IS FALSE
    AND NOT EXISTS (
    SELECT 1 FROM public.account_suspensions AS s
    WHERE s.user_id = r.client_id AND s.is_suspended
  )
    AND ((p_contact_based AND r.contact_attempt_id IS NOT NULL)
      OR (NOT p_contact_based AND r.contact_attempt_id IS NULL))
  ORDER BY r.created_at DESC, r.id DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 10), 1), 50);
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_public_professional_reviews(uuid, boolean, integer)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_public_professional_reviews(uuid, boolean, integer)
  TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.get_my_professional_review(p_professional_id uuid)
RETURNS TABLE (
  id uuid,
  author_name text,
  contact_attempt_id uuid,
  overall_rating smallint,
  price smallint,
  reliability smallint,
  quality smallint,
  comment text,
  created_at timestamptz,
  edit_count smallint,
  edited_at timestamptz,
  removed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para consultar tu calificación' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  SELECT r.id, COALESCE(NULLIF(pg_catalog.btrim(p.full_name), ''), 'Cliente de OFIKO'),
         r.contact_attempt_id, r.overall_rating, r.price, r.reliability,
         r.quality, r.comment, r.created_at, r.edit_count, r.edited_at, r.removed_at
  FROM public.reviews AS r
  JOIN public.profiles AS p ON p.id = r.client_id
  WHERE r.client_id = auth.uid()
    AND r.professional_id = p_professional_id;
END;
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_my_professional_review(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_professional_review(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.get_my_reviews_for_contacts(p_contact_attempt_ids uuid[])
RETURNS TABLE (
  id uuid,
  professional_id uuid,
  contact_attempt_id uuid,
  overall_rating smallint,
  comment text,
  created_at timestamptz,
  edit_count smallint,
  removed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para consultar tus calificaciones' USING ERRCODE = '28000';
  END IF;
  RETURN QUERY
  SELECT r.id, r.professional_id, r.contact_attempt_id, r.overall_rating,
         r.comment, r.created_at, r.edit_count, r.removed_at
  FROM public.reviews AS r
  WHERE r.client_id = auth.uid()
    AND r.contact_attempt_id = ANY(COALESCE(p_contact_attempt_ids, ARRAY[]::uuid[]));
END;
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.get_my_reviews_for_contacts(uuid[])
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_reviews_for_contacts(uuid[]) TO authenticated;

COMMIT;