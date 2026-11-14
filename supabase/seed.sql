BEGIN;

DO $seed_preflight$
BEGIN
  -- Reject any row whose ID or slug collides with the canonical catalog but
  -- whose identity/name/group differs. is_active is intentionally refreshed.
  IF EXISTS (
    WITH canonical(id, slug, name, grupo, is_active) AS (VALUES
      (1::bigint,'plomero','Plomero','oficios',true),
      (2,'electricista','Electricista','oficios',true),
      (3,'gasista','Gasista','oficios',true),
      (4,'abogado','Abogado/a','profesiones',false),
      (5,'dentista','Dentista','profesiones',false),
      (6,'ninera','Niñero/a','cuidado',false),
      (7,'cuidador-mayores','Cuidador/a de adultos mayores','cuidado',false),
      (8,'guardia','Sereno / Guardia de seguridad','seguridad',true),
      (9,'albanil','Albañil','oficios',true),
      (10,'pintor','Pintor/a','oficios',true),
      (11,'carpintero','Carpintero/a','oficios',true),
      (12,'herrero','Herrero/a','oficios',true),
      (13,'cerrajero','Cerrajero/a','oficios',true),
      (14,'refrigeracion','Refrigeración y aire acondicionado','oficios',true),
      (15,'tecnico-electrodomesticos','Reparación de electrodomésticos','oficios',true),
      (16,'mecanico','Mecánico/a','oficios',true),
      (17,'chapista','Chapista y pintura automotor','oficios',true),
      (18,'gomeria','Gomería','oficios',true),
      (19,'soldador','Soldador/a','oficios',true),
      (20,'techista','Techista','oficios',true),
      (21,'durlock','Yesero / Durlock','oficios',true),
      (22,'colocador-pisos','Colocador de pisos y cerámicos','oficios',true),
      (23,'vidriero','Vidriero/a','oficios',true),
      (24,'jardinero','Jardinero/a','oficios',true),
      (25,'piletero','Piletero/a','oficios',true),
      (26,'fumigador','Fumigador/a','oficios',true),
      (27,'limpieza','Limpieza','oficios',true),
      (28,'fletes','Fletes y mudanzas','oficios',true),
      (29,'tapicero','Tapicero/a','oficios',true),
      (30,'costurera','Costura y arreglos','oficios',true),
      (31,'peluquero','Peluquero/a','oficios',true),
      (32,'barbero','Barbero/a','oficios',true),
      (33,'manicura','Manicura y uñas','oficios',true),
      (34,'panadero','Panadería','comida',true),
      (35,'pastelero','Pastelería','comida',true),
      (36,'cocinero','Cocina y catering','comida',true),
      (37,'tecnico-pc','Técnico en computadoras y celulares','oficios',true),
      (38,'fotografo','Fotografía y video','oficios',true),
      (39,'otro-oficio','Otro oficio','oficios',true),
      (40,'viandas','Viandas y comidas caseras','comida',true),
      (41,'tortas','Tortas y dulces caseros','comida',true),
      (42,'empanadas','Empanadas y rotisería casera','comida',true),
      (43,'otro-comida','Otro producto casero','comida',true)
    )
    SELECT 1
    FROM public.categories c
    JOIN canonical x ON c.id = x.id OR c.slug = x.slug
    WHERE c.id <> x.id
       OR c.slug <> x.slug
       OR c.name <> x.name
       OR c.grupo <> x.grupo
  ) THEN
    RAISE EXCEPTION 'Seed aborted: category ID/slug/name/group conflict; inspect existing rows';
  END IF;

  -- Refuse to silently preserve unrelated categories in a supposedly fresh DB.
  IF EXISTS (
    WITH canonical(id, slug) AS (VALUES
      (1::bigint,'plomero'),(2,'electricista'),(3,'gasista'),(4,'abogado'),
      (5,'dentista'),(6,'ninera'),(7,'cuidador-mayores'),(8,'guardia'),
      (9,'albanil'),(10,'pintor'),(11,'carpintero'),(12,'herrero'),
      (13,'cerrajero'),(14,'refrigeracion'),(15,'tecnico-electrodomesticos'),
      (16,'mecanico'),(17,'chapista'),(18,'gomeria'),(19,'soldador'),
      (20,'techista'),(21,'durlock'),(22,'colocador-pisos'),(23,'vidriero'),
      (24,'jardinero'),(25,'piletero'),(26,'fumigador'),(27,'limpieza'),
      (28,'fletes'),(29,'tapicero'),(30,'costurera'),(31,'peluquero'),
      (32,'barbero'),(33,'manicura'),(34,'panadero'),(35,'pastelero'),
      (36,'cocinero'),(37,'tecnico-pc'),(38,'fotografo'),(39,'otro-oficio'),
      (40,'viandas'),(41,'tortas'),(42,'empanadas'),(43,'otro-comida')
    )
    SELECT 1 FROM public.categories c
    WHERE NOT EXISTS (SELECT 1 FROM canonical x WHERE x.id=c.id AND x.slug=c.slug)
  ) THEN
    RAISE EXCEPTION 'Seed aborted: unexpected categories exist; inspect public.categories';
  END IF;
END;
$seed_preflight$;

INSERT INTO public.categories (id, slug, name, grupo, is_active)
OVERRIDING SYSTEM VALUE
VALUES
  (1,'plomero','Plomero','oficios',true),
  (2,'electricista','Electricista','oficios',true),
  (3,'gasista','Gasista','oficios',true),
  (4,'abogado','Abogado/a','profesiones',false),
  (5,'dentista','Dentista','profesiones',false),
  (6,'ninera','Niñero/a','cuidado',false),
  (7,'cuidador-mayores','Cuidador/a de adultos mayores','cuidado',false),
  (8,'guardia','Sereno / Guardia de seguridad','seguridad',true),
  (9,'albanil','Albañil','oficios',true),
  (10,'pintor','Pintor/a','oficios',true),
  (11,'carpintero','Carpintero/a','oficios',true),
  (12,'herrero','Herrero/a','oficios',true),
  (13,'cerrajero','Cerrajero/a','oficios',true),
  (14,'refrigeracion','Refrigeración y aire acondicionado','oficios',true),
  (15,'tecnico-electrodomesticos','Reparación de electrodomésticos','oficios',true),
  (16,'mecanico','Mecánico/a','oficios',true),
  (17,'chapista','Chapista y pintura automotor','oficios',true),
  (18,'gomeria','Gomería','oficios',true),
  (19,'soldador','Soldador/a','oficios',true),
  (20,'techista','Techista','oficios',true),
  (21,'durlock','Yesero / Durlock','oficios',true),
  (22,'colocador-pisos','Colocador de pisos y cerámicos','oficios',true),
  (23,'vidriero','Vidriero/a','oficios',true),
  (24,'jardinero','Jardinero/a','oficios',true),
  (25,'piletero','Piletero/a','oficios',true),
  (26,'fumigador','Fumigador/a','oficios',true),
  (27,'limpieza','Limpieza','oficios',true),
  (28,'fletes','Fletes y mudanzas','oficios',true),
  (29,'tapicero','Tapicero/a','oficios',true),
  (30,'costurera','Costura y arreglos','oficios',true),
  (31,'peluquero','Peluquero/a','oficios',true),
  (32,'barbero','Barbero/a','oficios',true),
  (33,'manicura','Manicura y uñas','oficios',true),
  (34,'panadero','Panadería','comida',true),
  (35,'pastelero','Pastelería','comida',true),
  (36,'cocinero','Cocina y catering','comida',true),
  (37,'tecnico-pc','Técnico en computadoras y celulares','oficios',true),
  (38,'fotografo','Fotografía y video','oficios',true),
  (39,'otro-oficio','Otro oficio','oficios',true),
  (40,'viandas','Viandas y comidas caseras','comida',true),
  (41,'tortas','Tortas y dulces caseros','comida',true),
  (42,'empanadas','Empanadas y rotisería casera','comida',true),
  (43,'otro-comida','Otro producto casero','comida',true)
ON CONFLICT (id) DO UPDATE
SET is_active = EXCLUDED.is_active;

DO $sequence_sync$
DECLARE
  seq_name text;
  max_id bigint;
BEGIN
  seq_name := pg_catalog.pg_get_serial_sequence('public.categories', 'id');
  SELECT pg_catalog.max(id) INTO max_id FROM public.categories;
  IF seq_name IS NOT NULL AND max_id IS NOT NULL THEN
    PERFORM pg_catalog.setval(seq_name::regclass, max_id, true);
  END IF;
END;
$sequence_sync$;

COMMIT;