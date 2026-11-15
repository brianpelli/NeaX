"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Status = "active" | "removed";
type Review = {
  review_id: string;
  professional_id: string;
  professional_name: string;
  author_name: string;
  overall_rating: number | null;
  price: number | null;
  reliability: number | null;
  quality: number | null;
  comment: string | null;
  created_at: string;
  removed_at: string | null;
  edit_count: number;
  has_removal_audit: boolean;
};
type AuditEvent = { action: "removed" | "restored"; actor_name: string; acted_at: string };

const PAGE_SIZE = 20;
const shell = "mx-auto flex min-h-screen w-full max-w-4xl flex-col gap-5 bg-[#f4f6f6] p-4 text-[#14272b] sm:p-6";
const button = "min-h-11 rounded-xl px-4 font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c] disabled:opacity-60";

export default function AdminCalificacionesPage() {
  const [allowed, setAllowed] = useState<boolean | null>(null);
  const [accessError, setAccessError] = useState(false);
  const [status, setStatus] = useState<Status>("active");
  const [offset, setOffset] = useState(0);
  const [items, setItems] = useState<Review[]>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busyId, setBusyId] = useState<string | null>(null);
  const [auditReview, setAuditReview] = useState<Review | null>(null);
  const [audit, setAudit] = useState<AuditEvent[]>([]);
  const [auditLoading, setAuditLoading] = useState(false);
  const [auditError, setAuditError] = useState<string | null>(null);

  useEffect(() => {
    createClient().rpc("is_admin").then(({ data, error: authError }) => {
      setAllowed(data === true);
      setAccessError(Boolean(authError));
    });
  }, []);

  const load = useCallback(async () => {
    setLoading(true);
    setError(null);
    const { data, error: loadError } = await createClient().rpc(
      "admin_list_professional_reviews",
      { p_status: status, p_limit: PAGE_SIZE, p_offset: offset }
    );
    if (loadError) {
      setItems([]);
      setError(loadError.code === "42501"
        ? "Tu sesión no tiene permiso para consultar esta sección."
        : "No pudimos cargar las calificaciones. Probá nuevamente.");
    } else {
      setItems((data ?? []) as unknown as Review[]);
    }
    setLoading(false);
  }, [offset, status]);

  useEffect(() => {
    if (allowed) void Promise.resolve().then(load);
  }, [allowed, load]);

  async function changeStatus(review: Review, action: "remove" | "restore") {
    const label = action === "remove" ? "retirar" : "restaurar";
    if (!window.confirm(`¿Querés ${label} esta calificación?`)) return;
    setBusyId(review.review_id);
    setError(null);
    const { error: actionError } = await createClient().rpc(
      action === "remove" ? "admin_remove_professional_review" : "admin_restore_professional_review",
      { p_review_id: review.review_id }
    );
    if (actionError) {
      setError(actionError.code === "42501"
        ? "No tenés permiso para realizar esta operación."
        : "No se pudo completar la operación. Actualizá la lista e intentá nuevamente.");
    } else {
      await load();
      if (auditReview?.review_id === review.review_id) await loadAudit(review);
    }
    setBusyId(null);
  }

  async function loadAudit(review: Review) {
    setAuditReview(review);
    setAuditLoading(true);
    setAuditError(null);
    const { data, error: loadError } = await createClient().rpc(
      "admin_list_review_moderation_audit",
      { p_review_id: review.review_id, p_limit: 50, p_offset: 0 }
    );
    if (loadError) {
      setAudit([]);
      setAuditError(loadError.code === "42501"
        ? "No tenés permiso para consultar la auditoría."
        : "No pudimos cargar el historial de moderación.");
    } else {
      setAudit((data ?? []) as unknown as AuditEvent[]);
    }
    setAuditLoading(false);
  }

  if (allowed === null) return <main className={shell}><p role="status">Comprobando permisos...</p></main>;
  if (!allowed) {
    return (
      <main className={shell}>
        <h1 className="text-2xl font-bold">Sin acceso</h1>
        <p role={accessError ? "alert" : "status"} className="text-sm text-[#55666a]">
          {accessError ? "No pudimos comprobar tus permisos. Iniciá sesión nuevamente." : "Esta sección es solo para administradores activos."}
        </p>
        <Link href="/admin" className="font-bold text-[#0f5c5c] underline">Volver al panel</Link>
      </main>
    );
  }

  return (
    <main className={shell}>
      <header className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold">Moderación de calificaciones</h1>
          <p className="text-sm text-[#55666a]">Las estrellas y los comentarios no se editan desde esta sección.</p>
        </div>
        <Link href="/admin" className="font-bold text-[#0f5c5c] underline">Volver al panel</Link>
      </header>

      <label className="flex max-w-sm flex-col gap-1.5 text-sm font-semibold">
        Mostrar
        <select
          aria-label="Estado de las calificaciones"
          className="h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base"
          value={status}
          onChange={(event) => { setStatus(event.target.value as Status); setOffset(0); setAuditReview(null); }}
        >
          <option value="active">Activas</option>
          <option value="removed">Retiradas</option>
        </select>
      </label>

      {error && <p role="alert" className="rounded-xl bg-white p-4 text-sm text-red-700">{error}</p>}
      {loading && <p role="status" className="text-sm text-[#55666a]">Cargando calificaciones...</p>}
      {!loading && !error && items.length === 0 && <p className="rounded-xl bg-white p-4 text-sm text-[#55666a]">No hay calificaciones en este estado.</p>}

      <ul className="flex flex-col gap-4">
        {items.map((item) => (
          <li key={item.review_id} className="flex flex-col gap-3 rounded-2xl border border-[#dde4e4] bg-white p-4 sm:p-5">
            <div className="flex flex-col gap-1 sm:flex-row sm:justify-between">
              <h2 className="font-bold">{item.professional_name}</h2>
              <span className="text-sm text-[#55666a]">{new Date(item.created_at).toLocaleDateString("es-AR")}</span>
            </div>
            <p className="text-sm text-[#55666a]">Autor: {item.author_name}</p>
            <p className="font-semibold">{item.overall_rating ?? "Histórica"}{item.overall_rating !== null ? "/5" : ""}</p>
            {item.overall_rating === null && (
              <p className="text-sm text-[#55666a]">Precio {item.price ?? "—"}/5 · Confiabilidad {item.reliability ?? "—"}/5 · Calidad {item.quality ?? "—"}/5</p>
            )}
            {item.comment && <p className="whitespace-pre-line break-words text-sm">“{item.comment}”</p>}
            {item.removed_at && !item.has_removal_audit && (
              <p role="status" className="text-sm text-[#805b00]">Retirada antes de habilitar la auditoría; no hay actor ni fecha de moderación registrados.</p>
            )}
            <div className="flex flex-wrap gap-2">
              {status === "active" ? (
                <button type="button" className={`${button} bg-red-700 text-white`} disabled={busyId === item.review_id} onClick={() => void changeStatus(item, "remove")}>
                  {busyId === item.review_id ? "Procesando..." : "Retirar calificación"}
                </button>
              ) : (
                <button type="button" className={`${button} border border-[#0f5c5c] text-[#0f5c5c]`} disabled={busyId === item.review_id} onClick={() => void changeStatus(item, "restore")}>
                  {busyId === item.review_id ? "Procesando..." : "Restaurar calificación"}
                </button>
              )}
              <button type="button" className={`${button} border border-[#b9c7c7]`} onClick={() => void loadAudit(item)}>Ver auditoría</button>
            </div>
          </li>
        ))}
      </ul>

      <nav aria-label="Paginación de calificaciones" className="flex items-center justify-between">
        <button className={`${button} border border-[#b9c7c7]`} disabled={loading || offset === 0} onClick={() => setOffset((value) => Math.max(0, value - PAGE_SIZE))}>Anterior</button>
        <span className="text-sm text-[#55666a]">Página {Math.floor(offset / PAGE_SIZE) + 1}</span>
        <button className={`${button} border border-[#b9c7c7]`} disabled={loading || items.length < PAGE_SIZE} onClick={() => setOffset((value) => value + PAGE_SIZE)}>Siguiente</button>
      </nav>

      {auditReview && (
        <section className="flex flex-col gap-2 rounded-2xl border border-[#b9c7c7] bg-white p-4" aria-labelledby="review-audit-title">
          <div className="flex items-center justify-between gap-2">
            <h2 id="review-audit-title" className="font-bold">Historial de moderación</h2>
            <button type="button" className="text-sm font-bold underline" onClick={() => setAuditReview(null)}>Cerrar</button>
          </div>
          {auditLoading && <p role="status" className="text-sm text-[#55666a]">Cargando historial...</p>}
          {auditError && <p role="alert" className="text-sm text-red-700">{auditError}</p>}
          {!auditLoading && !auditError && audit.length === 0 && <p className="text-sm text-[#55666a]">Sin eventos registrados.</p>}
          {audit.map((event, index) => (
            <p key={`${event.acted_at}-${index}`} className="text-sm">
              {event.action === "removed" ? "Retirada" : "Restaurada"} por {event.actor_name} · {new Date(event.acted_at).toLocaleString("es-AR")}
            </p>
          ))}
        </section>
      )}
    </main>
  );
}