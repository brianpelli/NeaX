-- SELECT FOR SHARE is subject to category RLS. The existing authenticated
-- policy intentionally has no UPDATE policy, so row locking there hides even
-- active rows. Elevate only this trigger function: it has no arguments,
-- performs no writes, has an empty search_path, and has EXECUTE revoked.
ALTER FUNCTION public.enforce_professional_active_category() SECURITY DEFINER;
ALTER FUNCTION public.enforce_professional_active_category() SET search_path TO '';

COMMENT ON FUNCTION public.enforce_professional_active_category() IS
  'Trigger-only check for active professional categories; uses a row lock to serialize concurrent category deactivation.';
