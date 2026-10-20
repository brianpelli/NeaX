"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Estado = "abierta" | "revisada" | "descartada";

type Item = {
  id: string;
  reason: string;
  details: string | null;
  status: string;
  created_at: string;
  reporter: { full_name: string | null } | null;
  professionals: {
    id: string;
    headline: string | null;
    is_suspended: boolean;
    profiles: { full_name: string | null } | null;
  } | null;
};

const ESTADOS: Record<Estado, string> = {
  abierta: "Abiertas",
  revisada: "Revisadas",
  descartada: "Descartadas",
};

const MOTIVOS: Record<string, string> = {
  perfil_falso: "Perfil falso o datos inventados",
  suplantacion: "Suplanta a otra persona",
  estafa: "Intento de estafa o cobro indebido",
  contenido_inapropiado: "Contenido inapropiado u ofensivo",
  otro: "Otro motivo",
};

export default function DenunciasPage() {
  const [allowed, setAllowed] = useState<boolean | null>(null);
  const [estado, setEstado] = useState<Estado>("abierta");
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
      .from("reports")
      .select(
        "id, reason, details, status, created_at, reporter:profiles!reporter_id(full_name), professionals(id, headline, is_suspended, profiles(full_name))"
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

  async function setStatus(id: string, status: Estado) {
    setError(null);
    const { error: rpcError } = await createClient().rpc(
      "admin_set_report_status",
      { p_report_id: id, p_status: status }
    );
    if (rpcError) {
      setError(rpcError.message);
      return;
    }
    await load();
  }

  async function setSuspended(professionalId: string, suspended: boolean) {
    setError(null);
    const { error: rpcError } = await createClient().rpc(
      "admin_set_suspended",
      { p_professional_id: professionalId, p_suspended: suspended }
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
      <h1 className="text-3xl font-bold">Denuncias</h1>

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
        <p className="text-sm text-[#55666a]">No hay denuncias en este estado.</p>
      )}

      {items.map((item) => (
        <div
          key={item.id}
          className="flex flex-col gap-2 rounded-2xl border border-[#dde4e4] bg-white p-4"
        >
          <div className="font-bold">
            {MOTIVOS[item.reason] ?? item.reason}
          </div>
          {item.details && <p className="text-[15px]">“{item.details}”</p>}
          <div className="text-sm text-[#55666a]">
            Perfil: {item.professionals?.profiles?.full_name ?? "Sin nombre"} ·{" "}
            {item.professionals?.headline ?? "Sin título"}
            {item.professionals?.is_suspended && " (suspendido)"}
          </div>
          <div className="text-sm text-[#55666a]">
            Denunciado por {item.reporter?.full_name ?? "Sin nombre"} el{" "}
            {new Date(item.created_at).toLocaleDateString("es-AR")}
          </div>
          {item.professionals && (
            <Link
              href={`/profesional/${item.professionals.id}`}
              className="w-fit text-sm font-bold text-[#0f5c5c] underline"
            >
              Ver perfil
            </Link>
          )}
          <div className="flex flex-wrap gap-2">
            {item.professionals && (
              <button
                onClick={() =>
                  setSuspended(
                    item.professionals!.id,
                    !item.professionals!.is_suspended
                  )
                }
                className="h-11 flex-1 rounded-xl border border-red-700 px-3 font-bold text-red-700"
              >
                {item.professionals.is_suspended
                  ? "Reactivar perfil"
                  : "Suspender perfil"}
              </button>
            )}
          </div>
          <div className="flex gap-2">
            {item.status !== "revisada" && (
              <button
                onClick={() => setStatus(item.id, "revisada")}
                className="h-11 flex-1 rounded-xl bg-[#0f5c5c] font-bold text-white"
              >
                Marcar revisada
              </button>
            )}
            {item.status !== "descartada" && (
              <button
                onClick={() => setStatus(item.id, "descartada")}
                className="h-11 flex-1 rounded-xl border border-[#0f5c5c] font-bold text-[#0f5c5c]"
              >
                Descartar
              </button>
            )}
          </div>
        </div>
      ))}

      <Link href="/admin" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver a verificación
      </Link>
    </main>
  );
}