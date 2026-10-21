"use client";

import { useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Foto = { id: string; file_path: string; caption: string | null };

const MAX_FOTOS = 12;
const MAX_LADO = 1280;

async function comprimir(file: File): Promise<Blob> {
  const bitmap = await createImageBitmap(file);
  const escala = Math.min(1, MAX_LADO / Math.max(bitmap.width, bitmap.height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.round(bitmap.width * escala);
  canvas.height = Math.round(bitmap.height * escala);
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("No se pudo procesar la imagen.");
  ctx.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
  bitmap.close();
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) =>
        blob ? resolve(blob) : reject(new Error("No se pudo procesar la imagen.")),
      "image/jpeg",
      0.8
    );
  });
}

export default function FotosPage() {
  const router = useRouter();
  const [userId, setUserId] = useState<string | null>(null);
  const [professionalId, setProfessionalId] = useState<string | null>(null);
  const [items, setItems] = useState<Foto[]>([]);
  const [caption, setCaption] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [fileKey, setFileKey] = useState(0);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const loadItems = useCallback(async (proId: string) => {
    const { data } = await createClient()
      .from("work_photos")
      .select("id, file_path, caption")
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

  function urlDe(path: string) {
    return createClient().storage.from("work-photos").getPublicUrl(path).data
      .publicUrl;
  }

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    if (!file || !userId || !professionalId) return;
    if (!file.type.startsWith("image/")) {
      setError("El archivo tiene que ser una imagen.");
      return;
    }

    setSaving(true);
    const supabase = createClient();
    try {
      const blob = await comprimir(file);
      const path = `${userId}/${crypto.randomUUID()}.jpg`;

      const { error: upError } = await supabase.storage
        .from("work-photos")
        .upload(path, blob, { contentType: "image/jpeg" });
      if (upError) throw new Error(upError.message);

      const { error: insError } = await supabase.from("work_photos").insert({
        professional_id: professionalId,
        file_path: path,
        caption: caption.trim() || null,
      });
      if (insError) {
        await supabase.storage.from("work-photos").remove([path]);
        throw new Error(insError.message);
      }

      setCaption("");
      setFile(null);
      setFileKey((k) => k + 1);
      await loadItems(professionalId);
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo subir la foto.");
    }
    setSaving(false);
  }

  async function handleDelete(item: Foto) {
    if (!confirm("¿Eliminar esta foto?")) return;
    const supabase = createClient();
    const { error: delError } = await supabase
      .from("work_photos")
      .delete()
      .eq("id", item.id);
    if (delError) {
      setError(delError.message);
      return;
    }
    await supabase.storage.from("work-photos").remove([item.file_path]);
    if (professionalId) await loadItems(professionalId);
  }

  const mainClass =
    "mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]";

  if (loading) return <main className={mainClass}>Cargando...</main>;

  if (!professionalId) {
    return (
      <main className={mainClass}>
        <h1 className="text-3xl font-bold">Fotos de mis trabajos</h1>
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

  const llegoAlLimite = items.length >= MAX_FOTOS;

  return (
    <main className={mainClass}>
      <h1 className="text-3xl font-bold">Fotos de mis trabajos</h1>
      <p className="text-sm text-[#55666a]">
        Mostrá trabajos que hayas hecho (hasta {MAX_FOTOS} fotos). Las ve
        cualquier persona que abra tu perfil, así que evitá fotos donde se vean
        personas, patentes o direcciones.
      </p>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <div className="flex flex-col gap-2">
          <span className="text-sm font-medium">Foto</span>
          <input
            id="foto"
            key={fileKey}
            type="file"
            accept="image/*"
            className="sr-only"
            onChange={(e) => setFile(e.target.files?.[0] ?? null)}
          />
          <label
            htmlFor="foto"
            className="flex h-12 cursor-pointer items-center justify-center rounded-xl border border-[#0f5c5c] bg-white font-bold text-[#0f5c5c]"
          >
            {file ? "Cambiar foto" : "Elegir foto"}
          </label>
          {file && <p className="text-sm text-[#55666a]">{file.name}</p>}
        </div>

        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Descripción (opcional)
          <input
            className="h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base"
            maxLength={120}
            value={caption}
            onChange={(e) => setCaption(e.target.value)}
            placeholder="Ej: Instalación de cañerías en baño"
          />
        </label>

        {llegoAlLimite && (
          <p className="text-sm text-[#55666a]">
            Llegaste al máximo de fotos. Eliminá alguna para subir otra.
          </p>
        )}
        {error && <p className="text-sm text-red-700">{error}</p>}

        <button
          type="submit"
          disabled={saving || !file || llegoAlLimite}
          className="h-13 rounded-2xl bg-[#0f5c5c] text-lg font-bold text-white disabled:cursor-not-allowed disabled:opacity-50"
        >
          {saving ? "Subiendo..." : "Subir foto"}
        </button>
      </form>

      <section className="flex flex-col gap-3">
        <h2 className="text-lg font-bold">
          Mis fotos ({items.length}/{MAX_FOTOS})
        </h2>
        {items.length === 0 && (
          <p className="text-sm text-[#55666a]">Todavía no subiste ninguna.</p>
        )}
        <div className="grid grid-cols-2 gap-3">
          {items.map((item) => (
            <div key={item.id} className="flex flex-col gap-1.5">
              {/* eslint-disable-next-line @next/next/no-img-element */}
              <img
                src={urlDe(item.file_path)}
                alt={item.caption ?? "Trabajo realizado"}
                className="aspect-square w-full rounded-xl object-cover"
              />
              {item.caption && (
                <p className="text-sm text-[#55666a]">{item.caption}</p>
              )}
              <button
                onClick={() => handleDelete(item)}
                className="w-fit text-sm font-bold text-red-700 underline"
              >
                Eliminar
              </button>
            </div>
          ))}
        </div>
      </section>

      <Link href="/ofrecer" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver a mi perfil
      </Link>
    </main>
  );
}