"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Certificate = {
  id: string;
  title: string;
  file_path: string;
  status: string;
};

const ESTADOS: Record<string, string> = {
  pendiente: "En revisión",
  verificado: "Verificado",
  rechazado: "Rechazado",
};

const MAX_BYTES = 5 * 1024 * 1024;
const TIPOS = ["application/pdf", "image/jpeg", "image/png", "image/webp"];

export default function CertificadosPage() {
  const router = useRouter();
  const [userId, setUserId] = useState<string | null>(null);
  const [professionalId, setProfessionalId] = useState<string | null>(null);
  const [items, setItems] = useState<Certificate[]>([]);
  const [title, setTitle] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [fileKey, setFileKey] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadItems = useCallback(async (proId: string) => {
    const supabase = createClient();
    const { data } = await supabase
      .from("certificates")
      .select("id, title, file_path, status")
      .eq("professional_id", proId)
      .order("created_at", { ascending: false });
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
      setUserId(user.id);

      const { data: pro } = await supabase
        .from("professionals")
        .select("id")
        .eq("user_id", user.id)
        .maybeSingle();
      if (pro) {
        setProfessionalId(pro.id);
        await loadItems(pro.id);
      }
      setLoading(false);
    }
    load();
  }, [router, loadItems]);

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);

    if (!file || !userId || !professionalId) return;
    if (!TIPOS.includes(file.type)) {
      setError("El archivo tiene que ser PDF, JPG, PNG o WEBP.");
      return;
    }
    if (file.size > MAX_BYTES) {
      setError("El archivo supera los 5 MB.");
      return;
    }

    setSaving(true);
    const supabase = createClient();
    const safeName = file.name.replace(/[^a-zA-Z0-9._-]/g, "_");
    const path = `${userId}/${crypto.randomUUID()}-${safeName}`;

    const { error: upError } = await supabase.storage
      .from("certificates")
      .upload(path, file);
    if (upError) {
      setError(upError.message);
      setSaving(false);
      return;
    }

    const { error: insError } = await supabase
      .from("certificates")
      .insert({ professional_id: professionalId, title, file_path: path });
    if (insError) {
      await supabase.storage.from("certificates").remove([path]);
      setError(insError.message);
      setSaving(false);
      return;
    }

    setTitle("");
    setFile(null);
    setFileKey((k) => k + 1);
    await loadItems(professionalId);
    setSaving(false);
  }

  async function handleView(path: string) {
    const supabase = createClient();
    const { data, error: urlError } = await supabase.storage
      .from("certificates")
      .createSignedUrl(path, 60);
    if (urlError || !data) {
      setError("No se pudo abrir el archivo.");
      return;
    }
    window.open(data.signedUrl, "_blank");
  }

  async function handleDelete(item: Certificate) {
    if (!confirm("¿Eliminar este certificado?")) return;
    const supabase = createClient();
    const { error: delError } = await supabase
      .from("certificates")
      .delete()
      .eq("id", item.id);
    if (delError) {
      setError(delError.message);
      return;
    }
    await supabase.storage.from("certificates").remove([item.file_path]);
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
        <h1 className="text-3xl font-bold">Certificados y estudios</h1>
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

  return (
    <main className={mainClass}>
      <h1 className="text-3xl font-bold">Certificados y estudios</h1>
      <p className="text-sm text-[#55666a]">
        Subí tu matrícula, certificados o estudios (PDF o foto, hasta 5 MB).
        Los revisamos antes de mostrarlos con la insignia de verificado.
      </p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Nombre del documento (ej: Matrícula de gasista)
          <input
            className={inputClass}
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            required
          />
        </label>
          <div className="flex flex-col gap-2">
          <span className="text-sm font-medium">Archivo</span>
          <input
            id="archivo"
            key={fileKey}
            type="file"
            accept="application/pdf,image/jpeg,image/png,image/webp"
            className="sr-only"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
          <label
            htmlFor="archivo"
            className="flex h-12 cursor-pointer items-center justify-center rounded-xl border border-[#0f5c5c] bg-white font-bold text-[#0f5c5c]"
          >
            {file ? "Cambiar archivo" : "Elegir archivo"}
          </label>
          {file && <p className="text-sm text-[#55666a]">{file.name}</p>}
        </div>

        {error && <p className="text-sm text-red-700">{error}</p>}

        <button
          type="submit"
          disabled={saving || !file}
          className="h-13 rounded-2xl bg-[#0f5c5c] text-lg font-bold text-white disabled:cursor-not-allowed disabled:opacity-50"
        >
          {saving ? "Subiendo..." : "Subir documento"}
        </button>
      </form>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-bold">Mis documentos</h2>
        {items.length === 0 && (
          <p className="text-sm text-[#55666a]">Todavía no subiste ninguno.</p>
        )}
        {items.map((item) => (
          <div
            key={item.id}
            className="flex flex-col gap-2 rounded-2xl border border-[#dde4e4] bg-white p-4"
          >
            <div className="font-bold">{item.title}</div>
            <div className="text-sm text-[#55666a]">
              Estado: {ESTADOS[item.status] ?? item.status}
            </div>
            <div className="flex gap-4 text-sm font-bold">
              <button
                onClick={() => handleView(item.file_path)}
                className="text-[#0f5c5c] underline"
              >
                Ver
              </button>
              {item.status !== "verificado" && (
                <button
                  onClick={() => handleDelete(item)}
                  className="text-red-700 underline"
                >
                  Eliminar
                </button>
              )}
            </div>
          </div>
        ))}
      </section>

      <Link href="/" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver al inicio
      </Link>
    </main>
  );
}