BEGIN;

CREATE INDEX professional_contact_attempts_client_attempted_idx
  ON public.professional_contact_attempts (client_id, attempted_at DESC);

COMMENT ON COLUMN public.professional_contact_attempts.attempted_at IS
  'Primera autorización de acceso a los datos de contacto; define la ventana móvil de 24 horas y no cambia al reutilizar el contacto.';

CREATE OR REPLACE FUNCTION public.start_professional_contact(p_professional_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_client_id uuid := auth.uid();
  v_professional_user_id uuid;
  v_is_suspended boolean;
  v_phone text;
  v_whatsapp text;
  v_attempt_id uuid;
  v_attempted_at timestamp with time zone;
  v_confirmed_at timestamp with time zone;
  v_recent_contacts bigint;
  v_now timestamp with time zone;
BEGIN
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para contactar a esta persona'
      USING ERRCODE = '28000';
  END IF;

  SELECT p.user_id, p.is_suspended
    INTO v_professional_user_id, v_is_suspended
  FROM public.professionals p
  WHERE p.id = p_professional_id
  FOR SHARE;

  IF NOT FOUND OR v_is_suspended IS TRUE THEN
    RAISE EXCEPTION 'Este perfil no está disponible'
      USING ERRCODE = 'P0002';
  END IF;

  IF v_professional_user_id = v_client_id THEN
    RAISE EXCEPTION 'No podés contactarte a vos mismo'
      USING ERRCODE = '42501';
  END IF;

  SELECT pc.phone, pc.whatsapp
    INTO v_phone, v_whatsapp
  FROM public.professional_contacts pc
  WHERE pc.professional_id = p_professional_id;

  v_phone := NULLIF(pg_catalog.btrim(v_phone), '');
  v_whatsapp := NULLIF(
    pg_catalog.regexp_replace(COALESCE(v_whatsapp, ''), '\D', '', 'g'),
    ''
  );

  IF v_phone IS NULL AND v_whatsapp IS NULL THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', 'no_contact',
      'attempt_id', NULL,
      'attempted_at', NULL,
      'confirmed_at', NULL,
      'phone', NULL,
      'whatsapp', NULL,
      'contact_method', NULL,
      'reused', false
    );
  END IF;

  -- Serialize new contacts for this client. This lock is released when the RPC
  -- transaction ends, before the browser opens WhatsApp or the phone dialer.
  PERFORM 1
  FROM public.profiles p
  WHERE p.id = v_client_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos el perfil del cliente autenticado'
      USING ERRCODE = '42501';
  END IF;

  SELECT a.id, a.attempted_at, a.confirmed_at
    INTO v_attempt_id, v_attempted_at, v_confirmed_at
  FROM public.professional_contact_attempts a
  WHERE a.client_id = v_client_id
    AND a.professional_id = p_professional_id;

  IF FOUND THEN
    RETURN pg_catalog.jsonb_build_object(
      'status', 'reused',
      'attempt_id', v_attempt_id,
      'attempted_at', v_attempted_at,
      'confirmed_at', v_confirmed_at,
      'phone', v_phone,
      'whatsapp', v_whatsapp,
      'contact_method', CASE WHEN v_whatsapp IS NOT NULL THEN 'whatsapp' ELSE 'phone' END,
      'reused', true
    );
  END IF;

  v_now := pg_catalog.clock_timestamp();

  SELECT pg_catalog.count(*)
    INTO v_recent_contacts
  FROM public.professional_contact_attempts a
  WHERE a.client_id = v_client_id
    AND a.attempted_at > v_now - INTERVAL '24 hours';

  IF v_recent_contacts >= 10 THEN
    RAISE EXCEPTION 'Alcanzaste el máximo de 10 profesionales nuevos en las últimas 24 horas'
      USING ERRCODE = 'P0001';
  END IF;

  INSERT INTO public.professional_contact_attempts (
    professional_id, client_id, attempted_at
  )
  VALUES (p_professional_id, v_client_id, v_now)
  ON CONFLICT (client_id, professional_id) DO NOTHING;

  SELECT a.id, a.attempted_at, a.confirmed_at
    INTO v_attempt_id, v_attempted_at, v_confirmed_at
  FROM public.professional_contact_attempts a
  WHERE a.client_id = v_client_id
    AND a.professional_id = p_professional_id;

  RETURN pg_catalog.jsonb_build_object(
    'status', 'created',
    'attempt_id', v_attempt_id,
    'attempted_at', v_attempted_at,
    'confirmed_at', v_confirmed_at,
    'phone', v_phone,
    'whatsapp', v_whatsapp,
    'contact_method', CASE WHEN v_whatsapp IS NOT NULL THEN 'whatsapp' ELSE 'phone' END,
    'reused', false
  );
END;
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION public.start_professional_contact(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.start_professional_contact(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.confirm_professional_contact(p_attempt_id uuid)
RETURNS timestamp with time zone
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  v_client_id uuid := auth.uid();
  v_professional_id uuid;
  v_is_suspended boolean;
  v_confirmed_at timestamp with time zone;
BEGIN
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para confirmar el contacto'
      USING ERRCODE = '28000';
  END IF;

  -- Keep confirmation lock order aligned with start_professional_contact.
  PERFORM 1
  FROM public.profiles p
  WHERE p.id = v_client_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos el perfil del cliente autenticado'
      USING ERRCODE = '42501';
  END IF;

  SELECT a.professional_id
    INTO v_professional_id
  FROM public.professional_contact_attempts a
  WHERE a.id = p_attempt_id
    AND a.client_id = v_client_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos un contacto disponible para confirmar'
      USING ERRCODE = '42501';
  END IF;

  SELECT p.is_suspended
    INTO v_is_suspended
  FROM public.professionals p
  WHERE p.id = v_professional_id
  FOR SHARE;

  IF NOT FOUND OR v_is_suspended IS TRUE THEN
    RAISE EXCEPTION 'No encontramos un contacto disponible para confirmar'
      USING ERRCODE = '42501';
  END IF;

  UPDATE public.professional_contact_attempts a
  SET confirmed_at = COALESCE(
    a.confirmed_at, pg_catalog.clock_timestamp()
  )
  WHERE a.id = p_attempt_id
    AND a.client_id = v_client_id
  RETURNING a.confirmed_at INTO v_confirmed_at;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No encontramos un contacto disponible para confirmar'
      USING ERRCODE = '42501';
  END IF;

  RETURN v_confirmed_at;
END;
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION public.confirm_professional_contact(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_professional_contact(uuid) TO authenticated;

COMMIT;
