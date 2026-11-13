BEGIN;

CREATE TABLE public.professional_contact_attempts (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  professional_id uuid NOT NULL,
  client_id uuid NOT NULL,
  attempted_at timestamp with time zone DEFAULT now() NOT NULL,
  confirmed_at timestamp with time zone,
  CONSTRAINT professional_contact_attempts_pkey PRIMARY KEY (id),
  CONSTRAINT professional_contact_attempts_professional_id_fkey
    FOREIGN KEY (professional_id) REFERENCES public.professionals(id) ON DELETE CASCADE,
  CONSTRAINT professional_contact_attempts_client_id_fkey
    FOREIGN KEY (client_id) REFERENCES public.profiles(id) ON DELETE CASCADE,
  CONSTRAINT professional_contact_attempts_client_professional_key
    UNIQUE (client_id, professional_id),
  CONSTRAINT professional_contact_attempts_confirmation_check
    CHECK (confirmed_at IS NULL OR confirmed_at >= attempted_at)
);

ALTER TABLE public.professional_contact_attempts ENABLE ROW LEVEL SECURITY;

REVOKE ALL PRIVILEGES ON TABLE public.professional_contact_attempts
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.professional_contact_attempts TO authenticated;

CREATE POLICY "ver mis intentos de contacto"
  ON public.professional_contact_attempts
  FOR SELECT TO authenticated
  USING (client_id = (SELECT auth.uid()));

DROP POLICY IF EXISTS "registrar mi contratacion" ON public.hirings;
REVOKE INSERT ON TABLE public.hirings FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS "contactos visibles con sesion"
  ON public.professional_contacts;

CREATE POLICY "ver mis datos de contacto"
  ON public.professional_contacts
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.professionals p
      WHERE p.id = professional_contacts.professional_id
        AND p.user_id = (SELECT auth.uid())
    )
  );

REVOKE ALL PRIVILEGES ON TABLE public.professional_contacts
  FROM PUBLIC, anon, authenticated;
GRANT SELECT, INSERT, UPDATE ON TABLE public.professional_contacts TO authenticated;

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
BEGIN
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para contactar a esta persona'
      USING ERRCODE = '28000';
  END IF;

  SELECT p.user_id, p.is_suspended
    INTO v_professional_user_id, v_is_suspended
  FROM public.professionals p
  WHERE p.id = p_professional_id;

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

  v_whatsapp := pg_catalog.regexp_replace(
    COALESCE(v_whatsapp, ''), '\D', '', 'g'
  );
  IF v_whatsapp = '' THEN
    v_whatsapp := NULL;
  END IF;

  IF v_whatsapp IS NULL THEN
    RETURN pg_catalog.jsonb_build_object(
      'attempt_id', NULL,
      'attempted_at', NULL,
      'confirmed_at', NULL,
      'phone', v_phone,
      'whatsapp', NULL
    );
  END IF;

  INSERT INTO public.professional_contact_attempts (professional_id, client_id)
  VALUES (p_professional_id, v_client_id)
  ON CONFLICT (client_id, professional_id) DO NOTHING;

  SELECT a.id, a.attempted_at, a.confirmed_at
    INTO v_attempt_id, v_attempted_at, v_confirmed_at
  FROM public.professional_contact_attempts a
  WHERE a.professional_id = p_professional_id
    AND a.client_id = v_client_id;

  RETURN pg_catalog.jsonb_build_object(
    'attempt_id', v_attempt_id,
    'attempted_at', v_attempted_at,
    'confirmed_at', v_confirmed_at,
    'phone', v_phone,
    'whatsapp', v_whatsapp
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
  v_professional_suspended boolean;
  v_confirmed_at timestamp with time zone;
BEGIN
  IF v_client_id IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para confirmar el contacto'
      USING ERRCODE = '28000';
  END IF;

  -- Lock both rows so a concurrent suspension cannot race with confirmation.
  SELECT p.is_suspended
    INTO v_professional_suspended
  FROM public.professional_contact_attempts a
  JOIN public.professionals p ON p.id = a.professional_id
  WHERE a.id = p_attempt_id
    AND a.client_id = v_client_id
  FOR UPDATE OF a, p;

  IF NOT FOUND OR v_professional_suspended IS TRUE THEN
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

  RETURN v_confirmed_at;
END;
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION public.confirm_professional_contact(uuid)
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.confirm_professional_contact(uuid) TO authenticated;

COMMIT;
