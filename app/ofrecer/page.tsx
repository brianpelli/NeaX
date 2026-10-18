"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Category = { id: number; name: string; grupo: string };

const GRUPOS: Record<string, string> = {
  oficios: "Oficios",
  profesiones: "Profesiones",
  cuidado: "Cuidado de personas",
  seguridad: "Seguridad",
};

export default function OfrecerPage() {
  const router = useRouter();
  const [categories, setCategories] = useState<Category[]>([]);
  const [categoryId, setCategoryId] = useState("");
  const [headline, setHeadline] = useState("");
  const [description, setDescription] = useState("");
  const [country, setCountry] = useState("Argentina");
  const [province, setProvince] = useState("");
  const [city, setCity] = useState("");
  const [phone, setPhone] = useState("");
  const [whatsapp, setWhatsapp] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [saved, setSaved] = useState(false);
  const [myId, setMyId] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      const supabase = createClient();
      const { data: userData } = await supabase.auth.getUser();
      const user = userData.user;
      if (!user) {
        router.push("/login");
        return;
      }

      const { data: cats } = await supabase
        .from("categories")
        .select("id, name, grupo")
        .order("name");
      setCategories(cats ?? []);

      const { data: profile } = await supabase
        .from("profiles")
        .select("country, province, city")
        .eq("id", user.id)
        .maybeSingle();
      if (profile) {
        setCountry(profile.country ?? "Argentina");
        setProvince(profile.province ?? "");
        setCity(profile.city ?? "");
      }

      const { data: pro } = await supabase
        .from("professionals")
        .select("id, category_id, headline, description")
        .eq("user_id", user.id)
        .maybeSingle();
      if (pro) {
		setMyId(pro.id);
        setCategoryId(String(pro.category_id ?? ""));
        setHeadline(pro.headline ?? "");
        setDescription(pro.description ?? "");

        const { data: contact } = await supabase
          .from("professional_contacts")
          .select("phone, whatsapp")
          .eq("professional_id", pro.id)
          .maybeSingle();
        if (contact) {
          setPhone(contact.phone ?? "");
          setWhatsapp(contact.whatsapp ?? "");
        }
      }
      setLoading(false);
    }
    load();
  }, [router]);

  function fail(message: string) {
    setError(message);
    setSaving(false);
  }

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setSaved(false);
    setSaving(true);

    const supabase = createClient();
    const { data: userData } = await supabase.auth.getUser();
    const user = userData.user;
    if (!user) {
      router.push("/login");
      return;
    }

    const { error: profileError } = await supabase
      .from("profiles")
      .update({ country, province, city })
      .eq("id", user.id);
    if (profileError) return fail(profileError.message);

    const fields = { category_id: Number(categoryId), headline, description };

    const { data: existing } = await supabase
      .from("professionals")
      .select("id")
      .eq("user_id", user.id)
      .maybeSingle();

    let professionalId = existing?.id;
    if (professionalId) {
      const { error: updError } = await supabase
        .from("professionals")
        .update(fields)
        .eq("id", professionalId);
      if (updError) return fail(updError.message);
    } else {
      const { data: created, error: insError } = await supabase
        .from("professionals")
        .insert({ user_id: user.id, ...fields })
        .select("id")
        .single();
      if (insError) return fail(insError.message);
      professionalId = created.id;
    }

    const { error: contactError } = await supabase
      .from("professional_contacts")
      .upsert({
        professional_id: professionalId,
        phone,
        whatsapp: whatsapp.replace(/\D/g, ""),
      });
    if (contactError) return fail(contactError.message);

    setMyId(professionalId);
    setSaving(false);
    setSaved(true);
  }

  const inputClass =
    "h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base text-[#14272b]";
  const labelClass = "flex flex-col gap-1.5 text-sm font-medium";

  if (loading) {
    return (
      <main className="mx-auto min-h-screen max-w-md bg-[#f4f6f6] p-6 text-[#14272b]">
        Cargando...
      </main>
    );
  }

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]">
      <h1 className="text-3xl font-bold">Ofrecé tus servicios</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <label className={labelClass}>
          Rubro
          <select
            className={inputClass}
            value={categoryId}
            onChange={(e) => setCategoryId(e.target.value)}
            required
          >
            <option value="">Elegí un rubro</option>
            {Object.entries(GRUPOS).map(([grupo, titulo]) => (
              <optgroup key={grupo} label={titulo}>
                {categories
                  .filter((c) => c.grupo === grupo)
                  .map((c) => (
                    <option key={c.id} value={c.id}>
                      {c.name}
                    </option>
                  ))}
              </optgroup>
            ))}
          </select>
        </label>

        <label className={labelClass}>
          Título breve (ej: Plomero matriculado)
          <input
            className={inputClass}
            value={headline}
            onChange={(e) => setHeadline(e.target.value)}
            required
          />
        </label>

        <label className={labelClass}>
          Descripción
          <textarea
            className="h-28 rounded-xl border border-[#b9c7c7] bg-white px-4 py-3 text-base text-[#14272b]"
            value={description}
            onChange={(e) => setDescription(e.target.value)}
            placeholder="Contá qué hacés, tu experiencia y en qué zonas trabajás"
          />
        </label>

        <label className={labelClass}>
          País
          <input
            className={inputClass}
            value={country}
            onChange={(e) => setCountry(e.target.value)}
            required
          />
        </label>
        <label className={labelClass}>
          Provincia
          <input
            className={inputClass}
            value={province}
            onChange={(e) => setProvince(e.target.value)}
            required
          />
        </label>
        <label className={labelClass}>
          Ciudad
          <input
            className={inputClass}
            value={city}
            onChange={(e) => setCity(e.target.value)}
            required
          />
        </label>

        <label className={labelClass}>
          Teléfono
          <input
            type="tel"
            className={inputClass}
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
          />
        </label>
        <label className={labelClass}>
          WhatsApp
          <input
            type="tel"
            inputMode="numeric"
            pattern="[0-9 +()-]{10,20}"
            title="Escribí el número completo con código de país y de área"
            className={inputClass}
            value={whatsapp}
            onChange={(e) => setWhatsapp(e.target.value)}
          />
          <span className="text-xs font-normal text-[#55666a]">
            Con código de país y de área, sin 0 ni 15. Ejemplo para Argentina:
            5491123456789
          </span>
        </label>

        {error && <p className="text-sm text-red-700">{error}</p>}
        {saved && (
          <p className="text-sm font-medium text-[#0f5c5c]">
            Tu perfil se guardó correctamente.
          </p>
        )}

        <button
          type="submit"
          disabled={saving}
          className="h-13 rounded-2xl bg-[#0f5c5c] text-lg font-bold text-white disabled:opacity-60"
        >
          {saving ? "Guardando..." : "Guardar perfil"}
        </button>
      </form>
      <Link
        href="/certificados"
        className="flex h-12 items-center justify-center rounded-2xl border border-[#0f5c5c] font-bold text-[#0f5c5c]"
      >
	  {myId && (
        <Link
          href={`/profesional/${myId}`}
          className="flex h-12 items-center justify-center rounded-2xl border border-[#0f5c5c] font-bold text-[#0f5c5c]"
        >
          Ver mi perfil público
        </Link>
      )}
        Subir certificados y estudios
      </Link>
      <Link href="/" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver al inicio
      </Link>
    </main>
  );
}