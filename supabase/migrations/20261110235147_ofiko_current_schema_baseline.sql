-- OFIKO CURRENT SCHEMA BASELINE DRAFT
-- Generated from read-only PostgreSQL catalog queries on 2026-11-10.
-- DO NOT EXECUTE until reviewed and approved. No application data or auth/storage object rows are included.
-- Managed Supabase schemas, roles, extensions internals, and platform triggers are provided by Supabase local.
-- Bucket metadata below contains only bucket configuration, not file records.
-- Column-level grants represented; global/default ACLs are not copied.

BEGIN;
SET LOCAL search_path = public, auth, extensions, storage, pg_catalog;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
REVOKE CREATE ON SCHEMA public FROM PUBLIC, anon, authenticated, service_role;

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA extensions;

-- TABLES
CREATE TABLE public.admins (
  user_id uuid NOT NULL
);

CREATE TABLE public.categories (
  id bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
  slug text NOT NULL,
  name text NOT NULL,
  grupo text NOT NULL,
  is_active boolean DEFAULT true NOT NULL
);

CREATE TABLE public.certificates (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  professional_id uuid NOT NULL,
  title text NOT NULL,
  file_path text NOT NULL,
  status text DEFAULT 'pendiente'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.hirings (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  professional_id uuid NOT NULL,
  client_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.professional_contacts (
  professional_id uuid NOT NULL,
  phone text,
  whatsapp text
);

CREATE TABLE public.professional_references (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  professional_id uuid NOT NULL,
  name text NOT NULL,
  relationship text,
  phone text NOT NULL,
  consent boolean NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.professionals (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  user_id uuid NOT NULL,
  category_id bigint,
  headline text,
  description text,
  is_verified boolean DEFAULT false NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  is_suspended boolean DEFAULT false NOT NULL
);

CREATE TABLE public.profiles (
  id uuid NOT NULL,
  full_name text,
  country text,
  province text,
  city text,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  avatar_path text
);

CREATE TABLE public.reports (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  reporter_id uuid NOT NULL,
  professional_id uuid NOT NULL,
  reason text NOT NULL,
  details text,
  status text DEFAULT 'abierta'::text NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  evidence text[] DEFAULT '{}'::text[] NOT NULL
);

CREATE TABLE public.reviews (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  hiring_id uuid NOT NULL,
  professional_id uuid NOT NULL,
  client_id uuid NOT NULL,
  price smallint NOT NULL,
  reliability smallint NOT NULL,
  quality smallint NOT NULL,
  comment text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE public.work_photos (
  id uuid DEFAULT gen_random_uuid() NOT NULL,
  professional_id uuid NOT NULL,
  file_path text NOT NULL,
  caption text,
  created_at timestamp with time zone DEFAULT now() NOT NULL
);

-- CONSTRAINTS
ALTER TABLE admins ADD CONSTRAINT admins_pkey PRIMARY KEY (user_id);
ALTER TABLE admins ADD CONSTRAINT admins_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE categories ADD CONSTRAINT categories_grupo_check CHECK (grupo = ANY (ARRAY['oficios'::text, 'profesiones'::text, 'cuidado'::text, 'seguridad'::text, 'comida'::text]));
ALTER TABLE categories ADD CONSTRAINT categories_pkey PRIMARY KEY (id);
ALTER TABLE categories ADD CONSTRAINT categories_slug_key UNIQUE (slug);
ALTER TABLE certificates ADD CONSTRAINT certificates_pkey PRIMARY KEY (id);
ALTER TABLE certificates ADD CONSTRAINT certificates_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES professionals(id) ON DELETE CASCADE;
ALTER TABLE certificates ADD CONSTRAINT certificates_status_check CHECK (status = ANY (ARRAY['pendiente'::text, 'verificado'::text, 'rechazado'::text]));
ALTER TABLE hirings ADD CONSTRAINT hirings_client_id_fkey FOREIGN KEY (client_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE hirings ADD CONSTRAINT hirings_pkey PRIMARY KEY (id);
ALTER TABLE hirings ADD CONSTRAINT hirings_professional_id_client_id_key UNIQUE (professional_id, client_id);
ALTER TABLE hirings ADD CONSTRAINT hirings_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES professionals(id) ON DELETE CASCADE;
ALTER TABLE professional_contacts ADD CONSTRAINT professional_contacts_pkey PRIMARY KEY (professional_id);
ALTER TABLE professional_contacts ADD CONSTRAINT professional_contacts_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES professionals(id) ON DELETE CASCADE;
ALTER TABLE professional_references ADD CONSTRAINT professional_references_consent_check CHECK (consent = true);
ALTER TABLE professional_references ADD CONSTRAINT professional_references_name_check CHECK (char_length(name) >= 2 AND char_length(name) <= 80);
ALTER TABLE professional_references ADD CONSTRAINT professional_references_phone_check CHECK (char_length(phone) >= 6 AND char_length(phone) <= 30);
ALTER TABLE professional_references ADD CONSTRAINT professional_references_pkey PRIMARY KEY (id);
ALTER TABLE professional_references ADD CONSTRAINT professional_references_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES professionals(id) ON DELETE CASCADE;
ALTER TABLE professional_references ADD CONSTRAINT professional_references_relationship_check CHECK (char_length(relationship) <= 120);
ALTER TABLE professionals ADD CONSTRAINT professionals_category_id_fkey FOREIGN KEY (category_id) REFERENCES categories(id);
ALTER TABLE professionals ADD CONSTRAINT professionals_pkey PRIMARY KEY (id);
ALTER TABLE professionals ADD CONSTRAINT professionals_user_id_fkey FOREIGN KEY (user_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE professionals ADD CONSTRAINT professionals_user_id_key UNIQUE (user_id);
ALTER TABLE profiles ADD CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE profiles ADD CONSTRAINT profiles_pkey PRIMARY KEY (id);
ALTER TABLE reports ADD CONSTRAINT reports_details_check CHECK (char_length(details) <= 500);
ALTER TABLE reports ADD CONSTRAINT reports_evidence_max CHECK (cardinality(evidence) <= 5);
ALTER TABLE reports ADD CONSTRAINT reports_pkey PRIMARY KEY (id);
ALTER TABLE reports ADD CONSTRAINT reports_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES professionals(id) ON DELETE CASCADE;
ALTER TABLE reports ADD CONSTRAINT reports_reason_check CHECK (reason = ANY (ARRAY['perfil_falso'::text, 'suplantacion'::text, 'estafa'::text, 'contenido_inapropiado'::text, 'otro'::text]));
ALTER TABLE reports ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE reports ADD CONSTRAINT reports_reporter_id_professional_id_key UNIQUE (reporter_id, professional_id);
ALTER TABLE reports ADD CONSTRAINT reports_status_check CHECK (status = ANY (ARRAY['abierta'::text, 'revisada'::text, 'descartada'::text]));
ALTER TABLE reviews ADD CONSTRAINT reviews_client_id_fkey FOREIGN KEY (client_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE reviews ADD CONSTRAINT reviews_comment_check CHECK (char_length(comment) <= 500);
ALTER TABLE reviews ADD CONSTRAINT reviews_hiring_id_fkey FOREIGN KEY (hiring_id) REFERENCES hirings(id) ON DELETE CASCADE;
ALTER TABLE reviews ADD CONSTRAINT reviews_hiring_id_key UNIQUE (hiring_id);
ALTER TABLE reviews ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);
ALTER TABLE reviews ADD CONSTRAINT reviews_price_check CHECK (price >= 1 AND price <= 5);
ALTER TABLE reviews ADD CONSTRAINT reviews_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES professionals(id) ON DELETE CASCADE;
ALTER TABLE reviews ADD CONSTRAINT reviews_quality_check CHECK (quality >= 1 AND quality <= 5);
ALTER TABLE reviews ADD CONSTRAINT reviews_reliability_check CHECK (reliability >= 1 AND reliability <= 5);
ALTER TABLE work_photos ADD CONSTRAINT work_photos_caption_check CHECK (char_length(caption) <= 120);
ALTER TABLE work_photos ADD CONSTRAINT work_photos_pkey PRIMARY KEY (id);
ALTER TABLE work_photos ADD CONSTRAINT work_photos_professional_id_fkey FOREIGN KEY (professional_id) REFERENCES professionals(id) ON DELETE CASCADE;

-- FUNCTIONS
CREATE OR REPLACE FUNCTION public.admin_set_certificate_status(p_certificate_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  v_professional uuid;
begin
  if not public.is_admin() then
    raise exception 'No autorizado';
  end if;
  if p_status not in ('pendiente', 'verificado', 'rechazado') then
    raise exception 'Estado inválido';
  end if;

  update public.certificates
  set status = p_status
  where id = p_certificate_id
  returning professional_id into v_professional;

  if v_professional is null then
    raise exception 'Certificado no encontrado';
  end if;

  update public.professionals
  set is_verified = exists (
    select 1 from public.certificates c
    where c.professional_id = v_professional and c.status = 'verificado'
  )
  where id = v_professional;
end;
$function$

CREATE OR REPLACE FUNCTION public.admin_set_report_status(p_report_id uuid, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  if p_status not in ('abierta','revisada','descartada') then
    raise exception 'Estado inválido';
  end if;
  update public.reports set status = p_status where id = p_report_id;
end;
$function$

CREATE OR REPLACE FUNCTION public.admin_set_suspended(p_professional_id uuid, p_suspended boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if not public.is_admin() then raise exception 'No autorizado'; end if;
  update public.professionals set is_suspended = p_suspended
  where id = p_professional_id;
end;
$function$

CREATE OR REPLACE FUNCTION public.handle_new_user()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  insert into public.profiles (id, full_name)
  values (new.id, new.raw_user_meta_data->>'full_name');
  return new;
end;
$function$

CREATE OR REPLACE FUNCTION public.is_admin()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
  select exists (select 1 from public.admins where user_id = auth.uid());
$function$

CREATE OR REPLACE FUNCTION public.limit_references()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (select count(*) from public.professional_references
      where professional_id = new.professional_id) >= 5 then
    raise exception 'Llegaste al máximo de 5 referencias';
  end if;
  return new;
end;
$function$

CREATE OR REPLACE FUNCTION public.limit_work_photos()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
  if (select count(*) from public.work_photos
      where professional_id = new.professional_id) >= 12 then
    raise exception 'Llegaste al máximo de 12 fotos';
  end if;
  return new;
end;
$function$


-- VIEWS
CREATE OR REPLACE VIEW public.professional_ratings WITH (security_invoker=true) AS  SELECT professional_id,
    count(*) AS total,
    round(avg(price), 1) AS avg_price,
    round(avg(reliability), 1) AS avg_reliability,
    round(avg(quality), 1) AS avg_quality,
    round(avg((price + reliability + quality)::numeric / 3.0), 1) AS avg_overall
   FROM reviews
  GROUP BY professional_id;

CREATE OR REPLACE VIEW public.professional_search WITH (security_invoker=true) AS  SELECT p.id,
    p.headline,
    p.is_verified,
    p.category_id,
    c.name AS category_name,
    pr.full_name,
    pr.province,
    pr.city,
    COALESCE(r.total, 0::bigint) AS total_reviews,
    r.avg_overall,
    round((3::numeric * 3.5 + COALESCE(r.total, 0::bigint)::numeric * COALESCE(r.avg_overall, 0::numeric)) / (3 + COALESCE(r.total, 0::bigint))::numeric, 2) AS score,
    pr.avatar_path
   FROM professionals p
     JOIN profiles pr ON pr.id = p.user_id
     LEFT JOIN categories c ON c.id = p.category_id
     LEFT JOIN professional_ratings r ON r.professional_id = p.id;

-- ROW LEVEL SECURITY
ALTER TABLE public.admins ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.certificates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.hirings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.professional_contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.professional_references ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.professionals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.work_photos ENABLE ROW LEVEL SECURITY;

-- POLICIES
CREATE POLICY "rubros visibles" ON public.categories AS permissive FOR SELECT TO public
  USING (is_active);
CREATE POLICY "admin ve todos los certificados" ON public.certificates AS permissive FOR SELECT TO authenticated
  USING (is_admin());
CREATE POLICY "borrar mis certificados no verificados" ON public.certificates AS permissive FOR DELETE TO authenticated
  USING (((status <> 'verificado'::text) AND (EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = certificates.professional_id) AND (p.user_id = auth.uid()))))));
CREATE POLICY "subir mis certificados" ON public.certificates AS permissive FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = certificates.professional_id) AND (p.user_id = auth.uid())))));
CREATE POLICY "ver certificados verificados o propios" ON public.certificates AS permissive FOR SELECT TO authenticated
  USING (((status = 'verificado'::text) OR (EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = certificates.professional_id) AND (p.user_id = auth.uid()))))));
CREATE POLICY "registrar mi contratacion" ON public.hirings AS permissive FOR INSERT TO authenticated
  WITH CHECK (((client_id = auth.uid()) AND (NOT (EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = hirings.professional_id) AND (p.user_id = auth.uid())))))));
CREATE POLICY "ver mis contrataciones" ON public.hirings AS permissive FOR SELECT TO authenticated
  USING ((client_id = auth.uid()));
CREATE POLICY "cargar mis contactos" ON public.professional_contacts AS permissive FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = professional_contacts.professional_id) AND (p.user_id = auth.uid())))));
CREATE POLICY "contactos visibles con sesion" ON public.professional_contacts AS permissive FOR SELECT TO authenticated
  USING (true);
CREATE POLICY "editar mis contactos" ON public.professional_contacts AS permissive FOR UPDATE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = professional_contacts.professional_id) AND (p.user_id = auth.uid())))));
CREATE POLICY "borrar mis referencias" ON public.professional_references AS permissive FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = professional_references.professional_id) AND (p.user_id = auth.uid())))));
CREATE POLICY "cargar mis referencias" ON public.professional_references AS permissive FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = professional_references.professional_id) AND (p.user_id = auth.uid())))));
CREATE POLICY "ver referencias con sesion" ON public.professional_references AS permissive FOR SELECT TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE (p.id = professional_references.professional_id))));
CREATE POLICY "crear mi perfil profesional" ON public.professionals AS permissive FOR INSERT TO public
  WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "editar mi perfil profesional" ON public.professionals AS permissive FOR UPDATE TO public
  USING ((auth.uid() = user_id))
  WITH CHECK ((auth.uid() = user_id));
CREATE POLICY "profesionales visibles" ON public.professionals AS permissive FOR SELECT TO public
  USING (((NOT is_suspended) OR (user_id = auth.uid()) OR is_admin()));
CREATE POLICY "editar mi perfil" ON public.profiles AS permissive FOR UPDATE TO public
  USING ((auth.uid() = id))
  WITH CHECK ((auth.uid() = id));
CREATE POLICY "perfiles visibles" ON public.profiles AS permissive FOR SELECT TO public
  USING (true);
CREATE POLICY "crear mi denuncia" ON public.reports AS permissive FOR INSERT TO authenticated
  WITH CHECK (((reporter_id = auth.uid()) AND (NOT (EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = reports.professional_id) AND (p.user_id = auth.uid()))))) AND (NOT (EXISTS ( SELECT 1
   FROM unnest(reports.evidence) t(path)
  WHERE (t.path !~~ ((auth.uid())::text || '/%'::text)))))));
CREATE POLICY "ver mis denuncias o admin" ON public.reports AS permissive FOR SELECT TO authenticated
  USING (((reporter_id = auth.uid()) OR is_admin()));
CREATE POLICY "calificar mi contratacion" ON public.reviews AS permissive FOR INSERT TO authenticated
  WITH CHECK (((client_id = auth.uid()) AND (EXISTS ( SELECT 1
   FROM hirings h
  WHERE ((h.id = reviews.hiring_id) AND (h.client_id = auth.uid()) AND (h.professional_id = reviews.professional_id))))));
CREATE POLICY "resenas visibles" ON public.reviews AS permissive FOR SELECT TO public
  USING (true);
CREATE POLICY "borrar mis fotos" ON public.work_photos AS permissive FOR DELETE TO authenticated
  USING ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = work_photos.professional_id) AND (p.user_id = auth.uid())))));
CREATE POLICY "fotos visibles" ON public.work_photos AS permissive FOR SELECT TO public
  USING ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE (p.id = work_photos.professional_id))));
CREATE POLICY "subir mis fotos" ON public.work_photos AS permissive FOR INSERT TO authenticated
  WITH CHECK ((EXISTS ( SELECT 1
   FROM professionals p
  WHERE ((p.id = work_photos.professional_id) AND (p.user_id = auth.uid())))));
CREATE POLICY "admin ve todos los archivos" ON storage.objects AS permissive FOR SELECT TO authenticated
  USING (((bucket_id = 'certificates'::text) AND is_admin()));
CREATE POLICY avatar_borrar ON storage.objects AS permissive FOR DELETE TO authenticated
  USING (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY avatar_subir ON storage.objects AS permissive FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'avatars'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY cert_storage_borrar ON storage.objects AS permissive FOR DELETE TO authenticated
  USING (((bucket_id = 'certificates'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY cert_storage_subir ON storage.objects AS permissive FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'certificates'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY cert_storage_ver ON storage.objects AS permissive FOR SELECT TO authenticated
  USING (((bucket_id = 'certificates'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY evid_subir ON storage.objects AS permissive FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'report-evidence'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY evid_ver ON storage.objects AS permissive FOR SELECT TO authenticated
  USING (((bucket_id = 'report-evidence'::text) AND (((storage.foldername(name))[1] = (auth.uid())::text) OR is_admin())));
CREATE POLICY fotos_storage_borrar ON storage.objects AS permissive FOR DELETE TO authenticated
  USING (((bucket_id = 'work-photos'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));
CREATE POLICY fotos_storage_subir ON storage.objects AS permissive FOR INSERT TO authenticated
  WITH CHECK (((bucket_id = 'work-photos'::text) AND ((storage.foldername(name))[1] = (auth.uid())::text)));

-- TRIGGERS
CREATE TRIGGER on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user();
CREATE TRIGGER references_limit BEFORE INSERT ON professional_references FOR EACH ROW EXECUTE FUNCTION limit_references();
CREATE TRIGGER work_photos_limit BEFORE INSERT ON work_photos FOR EACH ROW EXECUTE FUNCTION limit_work_photos();

-- REVOKE LOCAL DEFAULT PRIVILEGES BEFORE REPLAYING EXPLICIT ACLS
REVOKE ALL PRIVILEGES ON TABLE public.admins FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.categories FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON SEQUENCE public.categories_id_seq FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.certificates FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.hirings FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.professional_contacts FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.professional_ratings FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.professional_references FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.professional_search FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.professionals FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.profiles FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.reports FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.reviews FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON TABLE public.work_photos FROM anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_certificate_status(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_certificate_status(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_certificate_status(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_report_status(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_report_status(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_report_status(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_suspended(uuid,boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_suspended(uuid,boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION admin_set_suspended(uuid,boolean) FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION handle_new_user() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION handle_new_user() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION handle_new_user() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION handle_new_user() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION handle_new_user() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION is_admin() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION is_admin() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION is_admin() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION is_admin() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION is_admin() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_references() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_references() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_references() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_references() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_references() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_work_photos() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_work_photos() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_work_photos() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_work_photos() FROM PUBLIC, anon, authenticated, service_role;
REVOKE ALL PRIVILEGES ON FUNCTION limit_work_photos() FROM PUBLIC, anon, authenticated, service_role;

-- TABLE, VIEW, AND SEQUENCE GRANTS
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.admins TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.admins TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.admins TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.categories TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.categories TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.categories TO service_role;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.categories_id_seq TO anon;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.categories_id_seq TO authenticated;
GRANT SELECT, UPDATE, USAGE ON SEQUENCE public.categories_id_seq TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.certificates TO anon;
GRANT DELETE, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE public.certificates TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.certificates TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hirings TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hirings TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.hirings TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_contacts TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_contacts TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_contacts TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_ratings TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_ratings TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_ratings TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_references TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_references TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_references TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_search TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_search TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professional_search TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professionals TO anon;
GRANT DELETE, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE public.professionals TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.professionals TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.profiles TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.profiles TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.profiles TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.reports TO anon;
GRANT MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE ON TABLE public.reports TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.reports TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.reviews TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.reviews TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.reviews TO service_role;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.work_photos TO anon;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.work_photos TO authenticated;
GRANT DELETE, INSERT, MAINTAIN, REFERENCES, SELECT, TRIGGER, TRUNCATE, UPDATE ON TABLE public.work_photos TO service_role;

-- COLUMN GRANTS
GRANT INSERT (file_path) ON TABLE public.certificates TO authenticated;
GRANT INSERT (professional_id) ON TABLE public.certificates TO authenticated;
GRANT INSERT (title) ON TABLE public.certificates TO authenticated;
GRANT INSERT (category_id) ON TABLE public.professionals TO authenticated;
GRANT UPDATE (category_id) ON TABLE public.professionals TO authenticated;
GRANT INSERT (description) ON TABLE public.professionals TO authenticated;
GRANT UPDATE (description) ON TABLE public.professionals TO authenticated;
GRANT INSERT (headline) ON TABLE public.professionals TO authenticated;
GRANT UPDATE (headline) ON TABLE public.professionals TO authenticated;
GRANT INSERT (user_id) ON TABLE public.professionals TO authenticated;
GRANT INSERT (details) ON TABLE public.reports TO authenticated;
GRANT INSERT (evidence) ON TABLE public.reports TO authenticated;
GRANT INSERT (id) ON TABLE public.reports TO authenticated;
GRANT INSERT (professional_id) ON TABLE public.reports TO authenticated;
GRANT INSERT (reason) ON TABLE public.reports TO authenticated;
GRANT INSERT (reporter_id) ON TABLE public.reports TO authenticated;

-- FUNCTION EXECUTE GRANTS
GRANT EXECUTE ON FUNCTION admin_set_certificate_status(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_set_certificate_status(uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION admin_set_report_status(uuid,text) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_set_report_status(uuid,text) TO service_role;
GRANT EXECUTE ON FUNCTION admin_set_suspended(uuid,boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION admin_set_suspended(uuid,boolean) TO service_role;
GRANT EXECUTE ON FUNCTION handle_new_user() TO PUBLIC;
GRANT EXECUTE ON FUNCTION handle_new_user() TO anon;
GRANT EXECUTE ON FUNCTION handle_new_user() TO authenticated;
GRANT EXECUTE ON FUNCTION handle_new_user() TO service_role;
GRANT EXECUTE ON FUNCTION is_admin() TO PUBLIC;
GRANT EXECUTE ON FUNCTION is_admin() TO anon;
GRANT EXECUTE ON FUNCTION is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION is_admin() TO service_role;
GRANT EXECUTE ON FUNCTION limit_references() TO PUBLIC;
GRANT EXECUTE ON FUNCTION limit_references() TO anon;
GRANT EXECUTE ON FUNCTION limit_references() TO authenticated;
GRANT EXECUTE ON FUNCTION limit_references() TO service_role;
GRANT EXECUTE ON FUNCTION limit_work_photos() TO PUBLIC;
GRANT EXECUTE ON FUNCTION limit_work_photos() TO anon;
GRANT EXECUTE ON FUNCTION limit_work_photos() TO authenticated;
GRANT EXECUTE ON FUNCTION limit_work_photos() TO service_role;

-- STORAGE BUCKET CONFIGURATION ONLY (no storage.objects rows)
INSERT INTO storage.buckets (id,name,public,file_size_limit,allowed_mime_types) VALUES ('avatars','avatars',true,307200,ARRAY['image/jpeg']::text[]),('certificates','certificates',false,5242880,ARRAY['application/pdf','image/jpeg','image/png','image/webp']::text[]),('report-evidence','report-evidence',false,5242880,ARRAY['image/jpeg','image/png','image/webp','application/pdf']::text[]),('work-photos','work-photos',true,1572864,ARRAY['image/jpeg']::text[]) ON CONFLICT(id) DO UPDATE SET name=EXCLUDED.name,public=EXCLUDED.public,file_size_limit=EXCLUDED.file_size_limit,allowed_mime_types=EXCLUDED.allowed_mime_types;

COMMIT;
