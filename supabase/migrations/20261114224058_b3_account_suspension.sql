BEGIN;

-- Account-level suspension is distinct from professionals.is_suspended.
-- No existing professional suspension is copied or rewritten.
CREATE TABLE public.account_suspensions (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  is_suspended boolean NOT NULL DEFAULT true,
  reason text,
  suspended_at timestamptz NOT NULL,
  suspended_by uuid NOT NULL,
  ended_at timestamptz,
  ended_by uuid,
  CONSTRAINT account_suspensions_reason_length CHECK (reason IS NULL OR char_length(reason) <= 500),
  CONSTRAINT account_suspensions_state_check CHECK (
    (is_suspended AND ended_at IS NULL AND ended_by IS NULL)
    OR (NOT is_suspended AND ended_at IS NOT NULL AND ended_by IS NOT NULL)
  )
);

ALTER TABLE public.account_suspensions ENABLE ROW LEVEL SECURITY;
REVOKE ALL PRIVILEGES ON TABLE public.account_suspensions FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.is_account_suspended(p_user_id uuid)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT COALESCE((
    SELECT s.is_suspended
    FROM public.account_suspensions AS s
    WHERE s.user_id = p_user_id
  ), false);
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.is_account_suspended(uuid)
  FROM PUBLIC, anon, authenticated, service_role;

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
  SELECT auth.uid() IS NOT NULL
    AND NOT public.is_account_suspended(auth.uid())
    AND EXISTS (
      SELECT 1 FROM public.admins AS a WHERE a.user_id = auth.uid()
    );
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.is_admin() FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.is_admin() TO anon, authenticated;

CREATE OR REPLACE FUNCTION public.admin_set_account_suspension(
  p_user_id uuid,
  p_suspended boolean,
  p_reason text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_actor uuid := auth.uid();
  v_existing boolean;
BEGIN
  IF v_actor IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'No tenés permiso para administrar suspensiones de cuenta'
      USING ERRCODE = '42501';
  END IF;
  IF p_user_id IS NULL OR p_user_id = v_actor THEN
    RAISE EXCEPTION 'No podés modificar tu propia suspensión'
      USING ERRCODE = '42501';
  END IF;
  IF p_suspended IS NULL THEN
    RAISE EXCEPTION 'El estado de suspensión es obligatorio'
      USING ERRCODE = '22023';
  END IF;
  IF p_reason IS NOT NULL AND char_length(p_reason) > 500 THEN
    RAISE EXCEPTION 'El motivo no puede superar los 500 caracteres'
      USING ERRCODE = '22023';
  END IF;

  -- Serialize account status changes with B.3 create/edit operations.
  PERFORM 1 FROM public.profiles AS p WHERE p.id = p_user_id FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos la cuenta'
      USING ERRCODE = 'P0002';
  END IF;

  SELECT s.is_suspended INTO v_existing
  FROM public.account_suspensions AS s
  WHERE s.user_id = p_user_id
  FOR UPDATE;

  IF p_suspended THEN
    INSERT INTO public.account_suspensions (
      user_id, is_suspended, reason, suspended_at, suspended_by, ended_at, ended_by
    ) VALUES (
      p_user_id, true, p_reason, pg_catalog.clock_timestamp(), v_actor, NULL, NULL
    )
    ON CONFLICT (user_id) DO UPDATE SET
      is_suspended = true,
      reason = EXCLUDED.reason,
      suspended_at = EXCLUDED.suspended_at,
      suspended_by = EXCLUDED.suspended_by,
      ended_at = NULL,
      ended_by = NULL;
  ELSE
    IF v_existing IS DISTINCT FROM true THEN
      RAISE EXCEPTION 'La cuenta no está suspendida'
        USING ERRCODE = 'P0002';
    END IF;
    UPDATE public.account_suspensions
    SET is_suspended = false,
        ended_at = pg_catalog.clock_timestamp(),
        ended_by = v_actor
    WHERE user_id = p_user_id;
  END IF;
END;
$function$;
REVOKE ALL PRIVILEGES ON FUNCTION public.admin_set_account_suspension(uuid, boolean, text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.admin_set_account_suspension(uuid, boolean, text)
  TO authenticated;

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
    RAISE EXCEPTION 'Iniciá sesión para publicar una calificación' USING ERRCODE = '28000';
  END IF;
  PERFORM 1 FROM public.profiles AS p WHERE p.id = v_client_id FOR SHARE;
  IF NOT FOUND OR public.is_account_suspended(v_client_id) THEN
    RAISE EXCEPTION 'Tu cuenta no puede publicar calificaciones' USING ERRCODE = '42501';
  END IF;
  IF p_overall_rating IS NULL OR p_overall_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'La calificación debe estar entre 1 y 5' USING ERRCODE = '22023';
  END IF;
  IF p_comment IS NOT NULL AND char_length(p_comment) > 500 THEN
    RAISE EXCEPTION 'El comentario no puede superar los 500 caracteres' USING ERRCODE = '22023';
  END IF;

  SELECT a.professional_id INTO v_professional_id
  FROM public.professional_contact_attempts AS a
  WHERE a.id = p_contact_attempt_id
    AND a.client_id = v_client_id
    AND a.confirmed_at IS NOT NULL
  FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos un contacto confirmado propio' USING ERRCODE = '42501';
  END IF;

  SELECT p.user_id, p.is_suspended INTO v_professional_user_id, v_is_suspended
  FROM public.professionals AS p
  WHERE p.id = v_professional_id
  FOR SHARE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Este perfil profesional ya no está disponible' USING ERRCODE = 'P0002';
  END IF;
  PERFORM 1 FROM public.profiles AS pp WHERE pp.id = v_professional_user_id FOR SHARE;
  IF v_professional_user_id = v_client_id THEN
    RAISE EXCEPTION 'No podés calificarte a vos mismo' USING ERRCODE = '42501';
  END IF;
  IF v_is_suspended OR public.is_account_suspended(v_professional_user_id) THEN
    RAISE EXCEPTION 'No se aceptan calificaciones nuevas para este perfil' USING ERRCODE = '42501';
  END IF;

  INSERT INTO public.reviews (contact_attempt_id, client_id, professional_id, overall_rating, comment)
  VALUES (p_contact_attempt_id, v_client_id, v_professional_id, p_overall_rating, p_comment)
  ON CONFLICT (client_id, professional_id) DO NOTHING
  RETURNING id INTO v_review_id;
  IF v_review_id IS NULL THEN
    RAISE EXCEPTION 'Ya existe una calificación para esta pareja' USING ERRCODE = '23505';
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
  v_removed_at timestamptz;
  v_edited_at timestamptz := pg_catalog.clock_timestamp();
BEGIN
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para editar una calificación' USING ERRCODE = '28000';
  END IF;
  PERFORM 1 FROM public.profiles AS p WHERE p.id = v_client_id FOR SHARE;
  IF NOT FOUND OR public.is_account_suspended(v_client_id) THEN
    RAISE EXCEPTION 'Tu cuenta no puede editar calificaciones' USING ERRCODE = '42501';
  END IF;
  IF p_overall_rating IS NULL OR p_overall_rating NOT BETWEEN 1 AND 5 THEN
    RAISE EXCEPTION 'La calificación debe estar entre 1 y 5' USING ERRCODE = '22023';
  END IF;
  IF p_comment IS NOT NULL AND char_length(p_comment) > 500 THEN
    RAISE EXCEPTION 'El comentario no puede superar los 500 caracteres' USING ERRCODE = '22023';
  END IF;

  SELECT r.client_id, r.contact_attempt_id, r.overall_rating, r.comment, r.edit_count, r.removed_at
  INTO v_review_client_id, v_contact_attempt_id, v_old_rating, v_old_comment, v_edit_count, v_removed_at
  FROM public.reviews AS r
  WHERE r.id = p_review_id
  FOR UPDATE;
  IF NOT FOUND OR v_review_client_id IS DISTINCT FROM v_client_id THEN
    RAISE EXCEPTION 'No encontramos una calificación propia para editar' USING ERRCODE = '42501';
  END IF;
  IF v_contact_attempt_id IS NULL THEN
    RAISE EXCEPTION 'Las calificaciones históricas no se editan con B.3' USING ERRCODE = '42501';
  END IF;
  IF v_removed_at IS NOT NULL THEN
    RAISE EXCEPTION 'Una calificación retirada no se puede editar ni republicar' USING ERRCODE = '42501';
  END IF;
  IF v_edit_count >= 3 THEN
    RAISE EXCEPTION 'Esta calificación ya alcanzó el máximo de tres ediciones' USING ERRCODE = '23514';
  END IF;
  IF v_old_rating IS NOT DISTINCT FROM p_overall_rating
     AND v_old_comment IS NOT DISTINCT FROM p_comment THEN
    RAISE EXCEPTION 'La calificación no tiene cambios' USING ERRCODE = '22023';
  END IF;

  INSERT INTO public.review_edit_history (
    review_id, review_ref, editor_id, edit_ordinal,
    old_overall_rating, new_overall_rating, old_comment, new_comment, edited_at
  ) VALUES (
    p_review_id, p_review_id, v_client_id, v_edit_count + 1,
    v_old_rating, p_overall_rating, v_old_comment, p_comment, v_edited_at
  );

  UPDATE public.reviews AS r
  SET overall_rating = p_overall_rating,
      comment = p_comment,
      edit_count = v_edit_count + 1,
      edited_at = v_edited_at
  WHERE r.id = p_review_id AND r.client_id = v_client_id;
END;
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION public.create_professional_review(uuid, smallint, text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_professional_review(uuid, smallint, text) TO authenticated;
REVOKE ALL PRIVILEGES ON FUNCTION public.edit_professional_review(uuid, smallint, text)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.edit_professional_review(uuid, smallint, text) TO authenticated;

COMMIT;