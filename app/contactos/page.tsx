"use client";

import { useCallback, useEffect, useState } from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import type { User } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";

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
  const [confirmingId, setConfirmingId] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);

  const loadContacts = useCallback(async (user: User, isCurrent: () => boolean) => {
    const supabase = createClient();
    setLoading(true);
    setError(null);
    setProfileWarning(null);

    const { data: attempts, error: attemptsError } = await supabase
      .from("professional_contact_attempts")
      .select("id, professional_id, attempted_at, confirmed_at")
      .eq("client_id", user.id)
      .order("attempted_at", { ascending: false });

    if (!isCurrent()) return;
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
    const { data: professionals, error: professionalsError } = await supabase
      .from("professionals")
      .select(
        "id, headline, categories(name), profiles!professionals_user_id_fkey(full_name)"
      )
      .in("id", professionalIds);

    if (!isCurrent()) return;
    const byId = new Map(
      ((professionals ?? []) as unknown as Profesional[]).map((pro) => [pro.id, pro])
    );
    setItems(ownAttempts.map((item) => ({
      ...item,
      profesional: byId.get(item.professional_id) ?? null,
    })));
    if (professionalsError) {
      setProfileWarning(
        "No pudimos cargar la disponibilidad de algunos perfiles. Es posible que no estén disponibles."
      );
    }
    setLoading(false);
  }, []);

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
