BEGIN;

CREATE TABLE public.review_moderation_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_ref uuid NOT NULL,
  actor_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('removed', 'restored')),
  acted_at timestamptz NOT NULL DEFAULT pg_catalog.clock_timestamp()
);
ALTER TABLE public.review_moderation_audit ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.review_moderation_audit FROM PUBLIC, anon, authenticated, service_role;
CREATE POLICY review_moderation_audit_admin_read
  ON public.review_moderation_audit FOR SELECT TO authenticated
  USING ((SELECT public.is_admin()));

CREATE OR REPLACE FUNCTION public.prevent_review_moderation_audit_mutation()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = ''
AS $function$
BEGIN
  RAISE EXCEPTION 'El historial de moderación es de solo anexado'
    USING ERRCODE = '42501';
END;
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.prevent_review_moderation_audit_mutation()
  FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER review_moderation_audit_append_only
  BEFORE UPDATE OR DELETE ON public.review_moderation_audit
  FOR EACH ROW EXECUTE FUNCTION public.prevent_review_moderation_audit_mutation();

CREATE OR REPLACE FUNCTION public.admin_remove_professional_review(p_review_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_removed_at timestamptz;
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tenés permiso para retirar esta calificación' USING ERRCODE = '42501';
  END IF;
  SELECT r.removed_at INTO v_removed_at
  FROM public.reviews AS r
  WHERE r.id = p_review_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos la calificación' USING ERRCODE = 'P0002';
  END IF;
  IF v_removed_at IS NOT NULL THEN
    RAISE EXCEPTION 'La calificación ya está retirada' USING ERRCODE = '23514';
  END IF;
  UPDATE public.reviews AS r
  SET removed_at = pg_catalog.clock_timestamp()
  WHERE r.id = p_review_id;
  INSERT INTO public.review_moderation_audit (review_ref, actor_id, action)
  VALUES (p_review_id, v_actor, 'removed');
END;
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.admin_remove_professional_review(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_remove_professional_review(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_restore_professional_review(p_review_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_removed_at timestamptz;
  v_actor uuid := auth.uid();
BEGIN
  IF v_actor IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tenés permiso para restaurar esta calificación' USING ERRCODE = '42501';
  END IF;
  SELECT r.removed_at INTO v_removed_at
  FROM public.reviews AS r
  WHERE r.id = p_review_id
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos la calificación' USING ERRCODE = 'P0002';
  END IF;
  IF v_removed_at IS NULL THEN
    RAISE EXCEPTION 'La calificación no está retirada' USING ERRCODE = '23514';
  END IF;
  UPDATE public.reviews AS r SET removed_at = NULL WHERE r.id = p_review_id;
  INSERT INTO public.review_moderation_audit (review_ref, actor_id, action)
  VALUES (p_review_id, v_actor, 'restored');
END;
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.admin_restore_professional_review(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_restore_professional_review(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_list_professional_reviews(
  p_status text DEFAULT 'active',
  p_limit integer DEFAULT 20,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  review_id uuid,
  professional_id uuid,
  professional_name text,
  author_name text,
  overall_rating smallint,
  price smallint,
  reliability smallint,
  quality smallint,
  comment text,
  created_at timestamptz,
  removed_at timestamptz,
  edit_count smallint,
  has_removal_audit boolean
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tenés permiso para consultar la moderación' USING ERRCODE = '42501';
  END IF;
  IF p_status IS NULL OR p_status NOT IN ('active', 'removed') THEN
    RAISE EXCEPTION 'Estado de filtro inválido' USING ERRCODE = '22023';
  END IF;
  IF p_offset < 0 THEN
    RAISE EXCEPTION 'Desplazamiento inválido' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
  SELECT r.id, r.professional_id,
         COALESCE(NULLIF(pg_catalog.btrim(pp.full_name), ''), 'Profesional'),
         COALESCE(NULLIF(pg_catalog.btrim(cp.full_name), ''), 'Cliente de OFIKO'),
         r.overall_rating, r.price, r.reliability, r.quality, r.comment,
         r.created_at, r.removed_at, r.edit_count,
         EXISTS (
           SELECT 1 FROM public.review_moderation_audit AS a
           WHERE a.review_ref = r.id AND a.action = 'removed'
         )
  FROM public.reviews AS r
  JOIN public.professionals AS p ON p.id = r.professional_id
  JOIN public.profiles AS pp ON pp.id = p.user_id
  JOIN public.profiles AS cp ON cp.id = r.client_id
  WHERE (p_status = 'active' AND r.removed_at IS NULL)
     OR (p_status = 'removed' AND r.removed_at IS NOT NULL)
  ORDER BY r.created_at DESC, r.id DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 20), 1), 100)
  OFFSET p_offset;
END;
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.admin_list_professional_reviews(text, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_professional_reviews(text, integer, integer)
  TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_list_review_moderation_audit(
  p_review_id uuid,
  p_limit integer DEFAULT 50,
  p_offset integer DEFAULT 0
)
RETURNS TABLE (
  action text,
  actor_name text,
  acted_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tenés permiso para consultar la auditoría' USING ERRCODE = '42501';
  END IF;
  IF p_offset < 0 THEN
    RAISE EXCEPTION 'Desplazamiento inválido' USING ERRCODE = '22023';
  END IF;
  RETURN QUERY
  SELECT a.action,
         COALESCE(NULLIF(pg_catalog.btrim(p.full_name), ''), 'Administrador no disponible'),
         a.acted_at
  FROM public.review_moderation_audit AS a
  LEFT JOIN public.profiles AS p ON p.id = a.actor_id
  WHERE a.review_ref = p_review_id
  ORDER BY a.acted_at DESC, a.id DESC
  LIMIT LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100)
  OFFSET p_offset;
END;
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.admin_list_review_moderation_audit(uuid, integer, integer)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_list_review_moderation_audit(uuid, integer, integer)
  TO authenticated;

COMMIT;