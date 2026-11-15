BEGIN;

CREATE OR REPLACE FUNCTION public.get_my_account_suspension_status()
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  v_user_id uuid := auth.uid();
  v_is_suspended boolean;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Iniciá sesión para consultar el estado de tu cuenta'
      USING ERRCODE = '28000';
  END IF;

  SELECT s.is_suspended
  INTO v_is_suspended
  FROM public.account_suspensions AS s
  WHERE s.user_id = v_user_id;

  RETURN COALESCE(v_is_suspended, false);
END;
$function$;

REVOKE ALL PRIVILEGES ON FUNCTION public.get_my_account_suspension_status()
  FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_my_account_suspension_status()
  TO authenticated;

COMMIT;