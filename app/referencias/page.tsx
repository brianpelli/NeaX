"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Referencia = {
  id: string;
  name: string;
  relationship: string | null;
  phone: string;
};

const MAX_REFERENCIAS = 5;

export default function ReferenciasPage() {
  const router = useRouter();
  const [professionalId, setProfessionalId] = useState<string | null>(null);
  const [grupo, setGrupo] = useState<string | null>(null);
  const [items, setItems] = useState<Referencia[]>([]);
  const [name, setName] = useState("");
  const [relationship, setRelationship] = useState("");
  const [phone, setPhone] = useState("");
  const [consent, setConsent] = useState(false);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadItems = useCallback(async (proId: string) => {
    const { data } = await createClient()
      .from("professional_references")
      .select("id, name, relationship, phone")
      .eq("professional_id", proId)
      .order("created_at", { ascending: true });
    setItems(data ?? []);
  }, []);

  useEffect(() => {
    async function load() {
      const supabase = createClient();
      const { data: userData } = await supabase.auth.getUser();
      const user = userData.user;
      if (!user) {
        router.push("/login");
        return;
      }

      const { data: pro } = await supabase
        .from("professionals")
        .select("id, categories(grupo)")
        .eq("user_id", user.id)
        .maybeSingle();
      if (pro) {
        setProfessionalId(pro.id);
        const categoria = pro.categories as unknown as { grupo: string } | null;
        setGrupo(categoria?.grupo ?? null);
        await loadItems(pro.id);
      }
      setLoading(false);
    }
    load();
  }, [router, loadItems]);

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    if (!professionalId) return;

    setSaving(true);
    const { error: insError } = await createClient()
      .from("professional_references")
      .insert({
        professional_id: professionalId,
        name: name.trim(),
        relationship: relationship.trim() || null,
        phone: phone.trim(),
        consent: true,
      });
    setSaving(false);

    if (insError) {
      setError(insError.message);
      return;
    }
    setName("");
    setRelationship("");
    setPhone("");
    setConsent(false);
    await loadItems(professionalId);
  }

  async function handleDelete(id: string) {
    if (!confirm("¿Eliminar esta referencia?")) return;
    const { error: delError } = await createClient()
      .from("professional_references")
      .delete()
      .eq("id", id);
    if (delError) {
      setError(delError.message);
      return;
    }
    if (professionalId) await loadItems(professionalId);
  }

  const inputClass =
    "h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base text-[#14272b]";
  const mainClass =
    "mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]";

  if (loading) return <main className={mainClass}>Cargando...</main>;

  if (!professionalId) {
    return (
      <main className={mainClass}>
        <h1 className="text-3xl font-bold">Referencias</h1>
        <p>Primero tenés que completar tu perfil profesional.</p>
        <Link
          href="/ofrecer"
          className="flex h-12 items-center justify-center rounded-2xl bg-[#0f5c5c] font-bold text-white"
        >
          Completar mi perfil
        </Link>
      </main>
    );
  }

  if (grupo !== "cuidado" && grupo !== "seguridad") {
    return (
      <main className={mainClass}>
        <h1 className="text-3xl font-bold">Referencias</h1>
        <p className="text-sm text-[#55666a]">
          Las referencias están disponibles para los rubros de cuidado de
          personas y seguridad. Si elegiste uno de esos rubros, guardá primero
          tu perfil.
        </p>
        <Link href="/ofrecer" className="font-bold text-[#0f5c5c] underline">
          Volver a mi perfil
        </Link>
      </main>
    );
  }

  const llegoAlLimite = items.length >= MAX_REFERENCIAS;

  return (
    <main className={mainClass}>
      <h1 className="text-3xl font-bold">Referencias</h1>
      <p className="text-sm text-[#55666a]">
        Cargá contactos de personas para las que trabajaste antes (hasta{" "}
        {MAX_REFERENCIAS}). Las ven los usuarios con sesión iniciada, como
        referencias declaradas por vos: la plataforma no las verifica.
      </p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Nombre de la persona
          <input
            className={inputClass}
            maxLength={80}
            value={name}
            onChange={(e) => setName(e.target.value)}
          />
        </label>
        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Detalle (opcional)
          <input
            className={inputClass}
            maxLength={120}
            value={relationship}
            onChange={(e) => setRelationship(e.target.value)}
            placeholder="Ej: Cuidé a su mamá durante 2 años"
          />
        </label>
        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Teléfono
          <input
            type="tel"
            className={inputClass}
            maxLength={30}
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
          />
        </label>
        <label className="flex items-start gap-3 text-sm">
          <input
            type="checkbox"
            className="mt-1 h-5 w-5"
            checked={consent}
            onChange={(e) => setConsent(e.target.checked)}
          />
          Confirmo que esta persona aceptó que se publique su contacto como
          referencia.
        </label>

        {llegoAlLimite && (
          <p className="text-sm text-[#55666a]">
            Llegaste al máximo de referencias. Eliminá alguna para agregar otra.
          </p>
        )}
        {error && <p className="text-sm text-red-700">{error}</p>}

        <button
          type="submit"
          disabled={
            saving || !name.trim() || !phone.trim() || !consent || llegoAlLimite
          }
          className="h-13 rounded-2xl bg-[#0f5c5c] text-lg font-bold text-white disabled:cursor-not-allowed disabled:opacity-50"
        >
          {saving ? "Guardando..." : "Agregar referencia"}
        </button>
      </form>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-bold">
          Mis referencias ({items.length}/{MAX_REFERENCIAS})
        </h2>
        {items.length === 0 && (
          <p className="text-sm text-[#55666a]">
            Todavía no cargaste ninguna. Si no tenés, podés dejarlo vacío.
          </p>
        )}
        {items.map((item) => (
          <div
            key={item.id}
            className="flex flex-col gap-1 rounded-2xl border border-[#dde4e4] bg-white p-4"
          >
            <div className="font-bold">{item.name}</div>
            {item.relationship && (
              <div className="text-sm text-[#55666a]">{item.relationship}</div>
            )}
            <div className="text-sm text-[#55666a]">{item.phone}</div>
            <button
              onClick={() => handleDelete(item.id)}
              className="w-fit text-sm font-bold text-red-700 underline"
            >
              Eliminar
            </button>
          </div>
        ))}
      </section>

      <Link href="/ofrecer" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver a mi perfil
      </Link>
    </main>
  );
}