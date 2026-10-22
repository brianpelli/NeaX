"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Estado = "pendiente" | "verificado" | "rechazado";

type Item = {
  id: string;
  title: string;
  file_path: string;
  status: string;
  created_at: string;
  professionals: {
    headline: string | null;
    profiles: { full_name: string | null } | null;
  } | null;
};

const ESTADOS: Record<Estado, string> = {
  pendiente: "Pendientes",
  verificado: "Verificados",
  rechazado: "Rechazados",
};

export default function AdminPage() {
  const [allowed, setAllowed] = useState<boolean | null>(null);
  const [estado, setEstado] = useState<Estado>("pendiente");
  const [items, setItems] = useState<Item[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    createClient()
      .rpc("is_admin")
      .then(({ data }) => setAllowed(data === true));
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const { data, error: loadError } = await createClient()
      .from("certificates")
      .select(
        "id, title, file_path, status, created_at, professionals(headline, profiles(full_name))"
      )
      .eq("status", estado)
      .order("created_at", { ascending: true });
    if (loadError) {
      setError(loadError.message);
    } else {
      setItems((data ?? []) as unknown as Item[]);
    }
    setLoading(false);
  }, [estado]);

  useEffect(() => {
    if (allowed) load();
  }, [allowed, load]);

  async function handleView(path: string) {
    const { data, error: urlError } = await createClient()
      .storage.from("certificates")
      .createSignedUrl(path, 60);
    if (urlError || !data) {
      setError("No se pudo abrir el archivo.");
      return;
    }
    window.open(data.signedUrl, "_blank");
  }

  async function handleSet(id: string, status: Estado) {
    setError(null);
    const { error: rpcError } = await createClient().rpc(
      "admin_set_certificate_status",
      { p_certificate_id: id, p_status: status }
    );
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    await load();
  }

  const mainClass =
    "mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]";

  if (allowed === null) return <main className={mainClass}>Cargando...</main>;

  if (!allowed) {
    return (
      <main className={mainClass}>
        <h1 className="text-2xl font-bold">Sin acceso</h1>
        <p className="text-sm text-[#55666a]">
          Esta sección es solo para administradores.
        </p>
        <Link href="/" className="font-bold text-[#0f5c5c] underline">
          Volver al inicio
        </Link>
      </main>
    );
  }

  return (
    <main className={mainClass}>
      <h1 className="text-3xl font-bold">Verificación de certificados</h1>
      <Link
        href="/admin/denuncias"
        className="w-fit text-sm font-bold text-[#0f5c5c] underline"
      >
        Ver denuncias
      </Link>

      <select
        aria-label="Estado"
        className="h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base"
        value={estado}
        onChange={(e) => setEstado(e.target.value as Estado)}
      >
        {(Object.keys(ESTADOS) as Estado[]).map((e) => (
          <option key={e} value={e}>
            {ESTADOS[e]}
          </option>
        ))}
      </select>

      {error && <p className="text-sm text-red-700">{error}</p>}
      {loading && <p className="text-sm text-[#55666a]">Cargando...</p>}
      {!loading && items.length === 0 && (
        <p className="text-sm text-[#55666a]">No hay documentos en este estado.</p>
      )}

      {items.map((item) => (
        <div
          key={item.id}
          className="flex flex-col gap-2 rounded-2xl border border-[#dde4e4] bg-white p-4"
        >
          <div className="font-bold">{item.title}</div>
          <div className="text-sm text-[#55666a]">
            {item.professionals?.profiles?.full_name ?? "Sin nombre"} ·{" "}
            {item.professionals?.headline ?? "Sin título"}
          </div>
          <div className="text-sm text-[#55666a]">
            Subido el {new Date(item.created_at).toLocaleDateString("es-AR")}
          </div>
          <button
            onClick={() => handleView(item.file_path)}
            className="w-fit text-sm font-bold text-[#0f5c5c] underline"
          >
            Ver documento
          </button>
          <div className="flex gap-2">
            {item.status !== "verificado" && (
              <button
                onClick={() => handleSet(item.id, "verificado")}
                className="h-11 flex-1 rounded-xl bg-[#0f5c5c] font-bold text-white"
              >
                Aprobar
              </button>
            )}
            {item.status !== "rechazado" && (
              <button
                onClick={() => handleSet(item.id, "rechazado")}
                className="h-11 flex-1 rounded-xl border border-red-700 font-bold text-red-700"
              >
                Rechazar
              </button>
            )}
          </div>
        </div>
      ))}

      <Link href="/" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver al inicio
      </Link>
    </main>
  );
}