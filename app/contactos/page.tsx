"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { User } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";
import ProfessionalReviewEditor, {
  type AccountSuspensionStatus,
  type EditableProfessionalReview,
} from "@/components/reviews/ProfessionalReviewEditor";

type Intento = {
  id: string;
  professional_id: string;
  attempted_at: string;
  confirmed_at: string | null;
};

type Profesional = {
  id: string;
  headline: string | null;
  categories: { name: string } | null;
  profiles: { full_name: string | null } | null;
};

type Contacto = Intento & {
  profesional: Profesional | null;
  calificacion: EditableProfessionalReview | null;
};

function fecha(value: string) {
  return new Date(value).toLocaleDateString("es-AR", {
    day: "numeric",
    month: "long",
    year: "numeric",
  });
}

export default function ContactosPage() {
  const router = useRouter();
  const [items, setItems] = useState<Contacto[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [profileWarning, setProfileWarning] = useState<string | null>(null);
  const [ratingWarning, setRatingWarning] = useState<string | null>(null);
  const [suspensionStatus, setSuspensionStatus] = useState<AccountSuspensionStatus>("checking");
  const [confirmingId, setConfirmingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const loadContacts = useCallback(async (user: User, isCurrent: () => boolean) => {
    const supabase = createClient();
    setLoading(true);
    setError(null);
    setProfileWarning(null);
    setRatingWarning(null);
    setSuspensionStatus("checking");

    const suspensionCheck = (async () => {
      try {
        const { data, error } = await supabase.rpc(
          "get_my_account_suspension_status"
        );
        return error || typeof data !== "boolean"
          ? "error" as const
          : data
            ? "suspended" as const
            : "active" as const;
      } catch {
        return "error" as const;
      }
    })();
    const [attemptsResult, checkedSuspensionStatus] = await Promise.all([
      supabase
        .from("professional_contact_attempts")
        .select("id, professional_id, attempted_at, confirmed_at")
        .eq("client_id", user.id)
        .order("attempted_at", { ascending: false }),
      suspensionCheck,
    ]);

    if (!isCurrent()) return;
    setSuspensionStatus(checkedSuspensionStatus);
    const { data: attempts, error: attemptsError } = attemptsResult;
    if (attemptsError) {
      setItems([]);
      setError("No pudimos cargar tus contactos. Probá nuevamente.");
      setLoading(false);
      return;
    }

    const ownAttempts = (attempts ?? []) as Intento[];
    if (ownAttempts.length === 0) {
      setItems([]);
      setLoading(false);
      return;
    }

    const professionalIds = [...new Set(ownAttempts.map((item) => item.professional_id))];
    const attemptIds = ownAttempts.map((item) => item.id);
    const [professionalResult, reviewResult] = await Promise.all([
      supabase
        .from("professionals")
        .select(
          "id, headline, categories(name), profiles!professionals_user_id_fkey(full_name)"
        )
        .in("id", professionalIds),
      supabase.rpc("get_my_reviews_for_contacts", {
        p_contact_attempt_ids: attemptIds,
      }),
    ]);
    if (!isCurrent()) return;
    const byId = new Map(
      ((professionalResult.data ?? []) as unknown as Profesional[]).map((pro) => [pro.id, pro])
    );
    const reviewByAttemptId = new Map<string, EditableProfessionalReview>();
    for (const row of reviewResult.data ?? []) {
      if (
        row.contact_attempt_id &&
        row.overall_rating !== null &&
        row.edit_count !== null
      ) {
        reviewByAttemptId.set(row.contact_attempt_id, {
          id: row.id,
          overall_rating: row.overall_rating,
          comment: row.comment,
          created_at: row.created_at,
          edit_count: row.edit_count,
          removed_at: row.removed_at,
        });
      }
    }
    setItems(ownAttempts.map((item) => ({
      ...item,
      profesional: byId.get(item.professional_id) ?? null,
      calificacion: reviewResult.error
        ? null
        : reviewByAttemptId.get(item.id) ?? null,
    })));
    if (professionalResult.error) {
      setProfileWarning(
        "No pudimos cargar la disponibilidad de algunos perfiles. Es posible que no estén disponibles."
      );
    }
    if (reviewResult.error) {
      setRatingWarning(
        "No pudimos cargar tus calificaciones. La edición está deshabilitada hasta poder verificarlas."
      );
    }
    setLoading(false);
  }, []);

  async function retrySuspensionCheck(): Promise<AccountSuspensionStatus> {
    setSuspensionStatus("checking");
    try {
      const supabase = createClient();
      const { data: authData, error: authError } = await supabase.auth.getUser();
      if (authError || !authData.user) {
        setSuspensionStatus("error");
        return "error";
      }
      const { data, error: statusError } = await supabase.rpc(
        "get_my_account_suspension_status"
      );
      const { data: currentAuth } = await supabase.auth.getUser();
      if (currentAuth.user?.id !== authData.user.id) {
        setSuspensionStatus("error");
        return "error";
      }
      const status: AccountSuspensionStatus =
        statusError || typeof data !== "boolean"
          ? "error"
          : data
            ? "suspended"
            : "active";
      setSuspensionStatus(status);
      return status;
    } catch {
      setSuspensionStatus("error");
      return "error";
    }
  }

  useEffect(() => {
    const supabase = createClient();
    let active = true;
    let loadVersion = 0;
    const isCurrent = (version: number) => active && version === loadVersion;

    async function loadSession() {
      const version = ++loadVersion;
      const { data, error: authError } = await supabase.auth.getUser();
      if (!isCurrent(version)) return;
      if (authError || !data.user) {
        setItems([]);
        router.replace("/login");
        return;
      }
      await loadContacts(data.user, () => isCurrent(version));
    }

    void loadSession();
    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      const version = ++loadVersion;
      setItems([]);
      setError(null);
      setProfileWarning(null);
      setRatingWarning(null);
      setSuspensionStatus("checking");
      setActionError(null);
      if (!session?.user) {
        setLoading(true);
        router.replace("/login");
        return;
      }
      void loadContacts(session.user, () => isCurrent(version));
    });

    return () => {
      active = false;
      subscription.unsubscribe();
    };
  }, [loadContacts, router]);

  async function confirmContact(attempt: Contacto) {
    if (confirmingId) return;
    setActionError(null);
    setConfirmingId(attempt.id);
    try {
      const { data, error: confirmError } = await createClient().rpc(
        "confirm_professional_contact",
        { p_attempt_id: attempt.id }
      );

      if (confirmError || !data) {
        setActionError(
          confirmError?.code === "42501"
            ? "No pudimos confirmar el contacto. El perfil puede no estar disponible o el intento no pertenecer a tu cuenta."
            : confirmError?.message ?? "No pudimos confirmar el contacto. Probá nuevamente."
        );
        return;
      }

      setItems((current) => current.map((item) =>
        item.id === attempt.id ? { ...item, confirmed_at: data as string } : item
      ));
    } catch {
      setActionError("No pudimos confirmar el contacto. Revisá tu conexión y probá nuevamente.");
    } finally {
      setConfirmingId(null);
    }
  }

  async function refreshOwnReview(attemptId: string) {
    const supabase = createClient();
    const { data: authData, error: authError } = await supabase.auth.getUser();
    if (authError || !authData.user) {
      setRatingWarning("Iniciá sesión nuevamente para consultar tu calificación.");
      return;
    }

    const { data, error: reviewError } = await supabase.rpc(
      "get_my_reviews_for_contacts",
      { p_contact_attempt_ids: [attemptId] }
    );
    const ownRow = (data ?? [])[0];
    if (reviewError) {
      setRatingWarning(
        "No pudimos actualizar tu calificación. La edición está deshabilitada hasta poder verificarla."
      );
      return;
    }

    setRatingWarning(null);
    const ownReview = ownRow && ownRow.overall_rating !== null
      ? {
          id: ownRow.id,
          overall_rating: ownRow.overall_rating,
          comment: ownRow.comment,
          created_at: ownRow.created_at,
          edit_count: ownRow.edit_count,
          removed_at: ownRow.removed_at,
        }
      : null;
    setItems((current) => current.map((item) =>
      item.id === attemptId ? { ...item, calificacion: ownReview } : item
    ));
  }

  const mainClass =
    "mx-auto flex min-h-screen w-full max-w-5xl flex-col gap-5 bg-[#f4f6f6] p-4 text-[#14272b] sm:p-6";
  const linkClass = "font-bold text-[#0f5c5c] underline";

  return (
    <main className={mainClass}>
      <header className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <h1 className="text-3xl font-bold">Mis contactos</h1>
          <p className="mt-1 text-sm text-[#55666a]">
            Personas que iniciaste contacto. El registro no confirma un trabajo ni el envío de un mensaje.
          </p>
        </div>
        <Link href="/buscar" className={`${linkClass} w-fit`}>
          Buscar profesionales
        </Link>
      </header>

      {loading && <p role="status">Cargando tus contactos...</p>}
      {error && (
        <div role="alert" className="rounded-xl bg-white p-4 text-sm text-red-700">
          {error}
        </div>
      )}
      {profileWarning && (
        <p role="status" className="rounded-xl bg-white p-4 text-sm text-[#55666a]">
          {profileWarning}
        </p>
      )}
      {ratingWarning && (
        <p role="alert" className="rounded-xl bg-white p-4 text-sm text-red-700">
          {ratingWarning}
        </p>
      )}
      {actionError && (
        <p role="alert" className="rounded-xl bg-white p-4 text-sm text-red-700">
          {actionError}
        </p>
      )}

      {!loading && !error && items.length === 0 && (
        <section className="rounded-2xl border border-[#dde4e4] bg-white p-5">
          <h2 className="text-lg font-bold">Todavía no tenés contactos</h2>
          <p className="mt-1 text-sm text-[#55666a]">
            Cuando inicies contacto con un profesional, aparecerá en esta lista.
          </p>
          <Link href="/buscar" className={`${linkClass} mt-4 inline-block`}>
            Buscar profesionales
          </Link>
        </section>
      )}

      {!loading && items.length > 0 && (
        <ul className="grid grid-cols-1 gap-4 md:grid-cols-2">
          {items.map((item) => {
            const professional = item.profesional;
            const available = professional !== null;
            const name = professional?.profiles?.full_name?.trim() || "Profesional";
            const occupation = professional?.headline?.trim() || professional?.categories?.name;
            const confirmed = item.confirmed_at !== null;

            return (
              <li key={item.id} className="flex flex-col gap-4 rounded-2xl border border-[#dde4e4] bg-white p-4 sm:p-5">
                <div className="flex flex-col gap-2 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0">
                    <h2 className="break-words text-lg font-bold">
                      {available ? name : "Perfil no disponible"}
                    </h2>
                    {available && occupation && (
                      <p className="break-words text-sm text-[#55666a]">{occupation}</p>
                    )}
                    <p className="mt-2 text-sm text-[#55666a]">
                      Primer contacto: {fecha(item.attempted_at)}
                    </p>
                  </div>
                  <span className={`w-fit rounded-full px-3 py-1 text-sm font-semibold ${confirmed ? "bg-[#dff0ec] text-[#0b4a4a]" : "bg-[#fff4d6] text-[#5c4300]"}`}>
                    {confirmed ? "Confirmado" : "Contacto iniciado"}
                  </span>
                </div>

                {!available && (
                  <p className="text-sm text-[#55666a]">
                    Este perfil no está disponible en este momento.
                  </p>
                )}

                {ratingWarning ? (
                  <p role="status" className="text-sm text-[#55666a]">
                    No se puede editar hasta cargar correctamente tu calificación.
                  </p>
                ) : item.calificacion ? (
                  <div className="rounded-xl border border-[#dde4e4] p-3">
                    <h3 className="mb-2 font-bold">Mi calificación</h3>
                    <ProfessionalReviewEditor
                      review={item.calificacion}
                      suspensionStatus={suspensionStatus}
                      onRetrySuspensionCheck={retrySuspensionCheck}
                      onSaved={() => refreshOwnReview(item.id)}
                      onRefresh={() => refreshOwnReview(item.id)}
                    />
                  </div>
                ) : confirmed ? (
                  <p role="status" className="text-sm text-[#55666a]">
                    No hay una calificación activa para este contacto.
                  </p>
                ) : null}

                <div className="mt-auto flex flex-col gap-2 sm:flex-row sm:flex-wrap">
                  {available ? (
                    <>
                      <Link
                        href={`/profesional/${item.professional_id}`}
                        className="flex min-h-11 items-center justify-center rounded-xl border border-[#0f5c5c] px-4 text-center font-bold text-[#0f5c5c] sm:flex-1"
                      >
                        Ver perfil
                      </Link>
                      <Link
                        href={`/profesional/${item.professional_id}`}
                        className="flex min-h-11 items-center justify-center rounded-xl bg-[#0f5c5c] px-4 text-center font-bold text-white sm:flex-1"
                      >
                        Volver a contactar
                      </Link>
                      {!confirmed && (
                        <button
                          type="button"
                          onClick={() => void confirmContact(item)}
                          disabled={confirmingId !== null}
                          className="flex min-h-11 items-center justify-center rounded-xl border border-[#b9c7c7] px-4 text-center font-bold disabled:opacity-60 sm:w-full"
                        >
                          {confirmingId === item.id ? "Confirmando..." : "Contacté a esta persona"}
                        </button>
                      )}
                    </>
                  ) : (
                    <button
                      type="button"
                      disabled
                      className="min-h-11 rounded-xl border border-[#b9c7c7] px-4 font-bold text-[#55666a] opacity-60"
                    >
                      Perfil no disponible
                    </button>
                  )}
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </main>
  );
}
