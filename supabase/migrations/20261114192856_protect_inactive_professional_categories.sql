-- Reject new or changed professional category assignments unless the category
-- is active. Unchanged legacy inactive/NULL values remain editable.
CREATE OR REPLACE FUNCTION public.enforce_professional_active_category()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
  v_is_active boolean;
BEGIN
  IF TG_OP = 'UPDATE' THEN
    IF NEW.category_id IS NOT DISTINCT FROM OLD.category_id THEN
      RETURN NEW;
    END IF;
  END IF;

  IF NEW.category_id IS NULL THEN
    RAISE EXCEPTION 'A professional must be assigned an active category.'
      USING ERRCODE = '23514',
            CONSTRAINT = 'professionals_category_must_be_active';
  END IF;

  SELECT c.is_active
    INTO v_is_active
    FROM public.categories AS c
   WHERE c.id = NEW.category_id
   FOR SHARE;

  IF NOT FOUND OR v_is_active IS NOT TRUE THEN
    RAISE EXCEPTION 'The selected professional category does not exist or is inactive.'
      USING ERRCODE = '23514',
            CONSTRAINT = 'professionals_category_must_be_active';
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE ALL ON FUNCTION public.enforce_professional_active_category()
  FROM PUBLIC, anon, authenticated, service_role;

CREATE TRIGGER professionals_active_category_guard
BEFORE INSERT OR UPDATE OF category_id
ON public.professionals
FOR EACH ROW
EXECUTE FUNCTION public.enforce_professional_active_category();

COMMENT ON FUNCTION public.enforce_professional_active_category() IS
  'Rejects new or changed category assignments unless the category is active; preserves unchanged historical values.';
