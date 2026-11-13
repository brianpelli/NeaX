"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import Avatar from "@/components/Avatar";

type Profesional = {
  id: string;
  user_id: string;
  headline: string | null;
  description: string | null;
  is_verified: boolean;
  categories: { name: string; grupo: string } | null;
  profiles: {
    full_name: string | null;
    country: string | null;
    province: string | null;
    city: string | null;
    avatar_path: string | null;
  } | null;
};

type Contacto = { phone: string | null; whatsapp: string | null };
type IntentoContacto = {
  id: string;
  attempted_at: string;
  confirmed_at: string | null;
};
type Certificado = { id: string; title: string };
type Foto = { id: string; file_path: string; caption: string | null };
type Referencia = {
  id: string;
  name: string;
  relationship: string | null;
  phone: string;
};
type Resumen = {
  total: number;
  avg_price: number;
  avg_reliability: number;
  avg_quality: number;
  avg_overall: number;
};
type Resena = {
  id: string;
  price: number;
  reliability: number;
  quality: number;
  comment: string | null;
  created_at: string;
  profiles: { full_name: string | null } | null;
};

function fmt(n: number) {
  return Number(n).toFixed(1).replace(".", ",");
}

const MOTIVOS: Record<string, string> = {
  perfil_falso: "Perfil falso o datos inventados",
  suplantacion: "Suplanta a otra persona",
  estafa: "Intento de estafa o cobro indebido",
  contenido_inapropiado: "Contenido inapropiado u ofensivo",
  otro: "Otro motivo",
};

const TIPOS_EVIDENCIA = [
  "image/jpeg",
  "image/png",
  "image/webp",
  "application/pdf",
];
const MAX_EVIDENCIA = 5;
const MAX_BYTES_EVIDENCIA = 5 * 1024 * 1024;

function Barra({ label, value }: { label: string; value: number }) {
  return (
    <div className="flex items-center gap-3 text-[15px]">
      <span className="w-28">{label}</span>
      <div className="h-2 flex-1 rounded bg-[#dde4e4]">
        <div
          className="h-2 rounded bg-[#0f5c5c]"
          style={{ width: `${(Number(value) / 5) * 100}%` }}
        />
      </div>
      <span className="w-8 text-right font-bold">{fmt(value)}</span>
    </div>
  );
}

function StarInput({
  label,
  hint,
  value,
  onChange,
}: {
  label: string;
  hint: string;
  value: number;
  onChange: (n: number) => void;
}) {
  return (
    <div className="flex flex-col gap-1">
      <div className="font-bold">{label}</div>
      <div className="text-sm text-[#55666a]">{hint}</div>
      <div className="flex gap-1">
        {[1, 2, 3, 4, 5].map((n) => (
          <button
            type="button"
            key={n}
            aria-label={`${n} de 5`}
            aria-pressed={value >= n}
            onClick={() => onChange(n)}
            className={`h-11 w-11 text-3xl leading-none ${
              value >= n ? "text-[#e9a23b]" : "text-[#8a9a9c]"
            }`}
          >
            {value >= n ? "★" : "☆"}
          </button>
        ))}
      </div>
    </div>
  );
}

export default function PerfilPublicoPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;

  const [pro, setPro] = useState<Profesional | null>(null);
  const [certs, setCerts] = useState<Certificado[]>([]);
  const [photos, setPhotos] = useState<Foto[]>([]);
  const [refs, setRefs] = useState<Referencia[]>([]);
  const [contact, setContact] = useState<Contacto | null>(null);
  const [contactAttempt, setContactAttempt] = useState<IntentoContacto | null>(null);
  const [contactReused, setContactReused] = useState(false);
  const [contactBusy, setContactBusy] = useState(false);
  const [confirmBusy, setConfirmBusy] = useState(false);
  const [contactError, setContactError] = useState<string | null>(null);
  const [contactUnavailable, setContactUnavailable] = useState(false);
  const [contactUnavailableMessage, setContactUnavailableMessage] = useState<string | null>(null);
  const [contactActionUrl, setContactActionUrl] = useState<string | null>(null);
  const [contactActionLabel, setContactActionLabel] = useState("Abrir contacto");
  const [summary, setSummary] = useState<Resumen | null>(null);
  const [reviews, setReviews] = useState<Resena[]>([]);
  const [userId, setUserId] = useState<string | null>(null);
  const [hiringId, setHiringId] = useState<string | null>(null);
  const [reviewed, setReviewed] = useState(false);
  const [loading, setLoading] = useState(true);
  const [version, setVersion] = useState(0);

  const [reported, setReported] = useState(false);
  const [showReport, setShowReport] = useState(false);
  const [reason, setReason] = useState("perfil_falso");
  const [details, setDetails] = useState("");
  const [files, setFiles] = useState<File[]>([]);
  const [fileKey, setFileKey] = useState(0);
  const [reportSending, setReportSending] = useState(false);
  const [reportError, setReportError] = useState<string | null>(null);

  const [price, setPrice] = useState(0);
  const [reliability, setReliability] = useState(0);
  const [quality, setQuality] = useState(0);
  const [comment, setComment] = useState("");
  const [sending, setSending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      const supabase = createClient();

      const { data } = await supabase
        .from("professionals")
        .select(
          "id, user_id, headline, description, is_verified, categories(name, grupo), profiles(full_name, country, province, city, avatar_path)"
        )
        .eq("id", id)
        .maybeSingle();

      if (!data) {
        setLoading(false);
        return;
      }
      setPro(data as unknown as Profesional);

      const { data: sum } = await supabase
        .from("professional_ratings")
        .select("total, avg_price, avg_reliability, avg_quality, avg_overall")
        .eq("professional_id", id)
        .maybeSingle();
      setSummary(sum as Resumen | null);

      const { data: revs } = await supabase
        .from("reviews")
        .select(
          "id, price, reliability, quality, comment, created_at, profiles(full_name)"
        )
        .eq("professional_id", id)
        .order("created_at", { ascending: false })
        .limit(10);
      setReviews((revs ?? []) as unknown as Resena[]);

      const { data: photoData } = await supabase
        .from("work_photos")
        .select("id, file_path, caption")
        .eq("professional_id", id)
        .order("created_at", { ascending: false });
      setPhotos(photoData ?? []);

      const { data: userData } = await supabase.auth.getUser();
      const user = userData.user;
      if (user) {
        setUserId(user.id);

        const { data: certData } = await supabase
          .from("certificates")
          .select("id, title")
          .eq("professional_id", id)
          .eq("status", "verificado");
        setCerts(certData ?? []);

        const { data: refData } = await supabase
          .from("professional_references")
          .select("id, name, relationship, phone")
          .eq("professional_id", id)
          .order("created_at", { ascending: true });
        setRefs(refData ?? []);

        const { data: attemptData } = await supabase
          .from("professional_contact_attempts")
          .select("id, attempted_at, confirmed_at")
          .eq("professional_id", id)
          .maybeSingle();
        setContactAttempt(attemptData as IntentoContacto | null);
        setContactReused(!!attemptData);

        const { data: hiring } = await supabase
          .from("hirings")
          .select("id")
          .eq("professional_id", id)
          .maybeSingle();
        setHiringId(hiring?.id ?? null);

        const { data: mine } = await supabase
          .from("reviews")
          .select("id")
          .eq("professional_id", id)
          .eq("client_id", user.id)
          .maybeSingle();
        setReviewed(!!mine);

        const { data: myReport } = await supabase
          .from("reports")
          .select("id")
          .eq("professional_id", id)
          .eq("reporter_id", user.id)
          .maybeSingle();
        setReported(!!myReport);
      }
      setLoading(false);
    }
    load();
  }, [id, version]);

  async function handleStartContact() {
    if (!userId || contactBusy) return;

    setContactError(null);
    setContactUnavailable(false);
    setContactUnavailableMessage(null);
    setContactActionUrl(null);
    setContactBusy(true);

    const popup = window.open("about:blank", "_blank");
    if (popup) popup.opener = null;
    try {
      const { data, error: startError } = await createClient().rpc(
        "start_professional_contact",
        { p_professional_id: id }
      );

      if (startError) {
        popup?.close();
        if (startError.code === "P0001") {
          setContactError(
            "Alcanzaste el máximo de 10 profesionales nuevos en las últimas 24 horas. Podrás contactar a otros cuando se libere un cupo."
          );
        } else {
          const unavailable = startError.code === "P0002";
          setContactUnavailable(unavailable);
          setContactUnavailableMessage(
            unavailable ? "Este perfil profesional no está disponible." : null
          );
          setContactError(unavailable ? null : startError.message);
        }
        return;
      }

      const result = data as {
        status: "created" | "reused" | "no_contact";
        attempt_id: string | null;
        attempted_at: string | null;
        confirmed_at: string | null;
        phone: string | null;
        whatsapp: string | null;
        contact_method: "whatsapp" | "phone" | null;
        reused: boolean;
      } | null;

      if (!result) {
        popup?.close();
        setContactError("No pudimos obtener los datos de contacto.");
        return;
      }

      if (result.status === "no_contact") {
        popup?.close();
        setContactUnavailable(true);
        setContactUnavailableMessage(
          "Esta persona todavía no cargó un teléfono ni un WhatsApp."
        );
        return;
      }

      if (!result.attempt_id || !result.attempted_at || !result.contact_method) {
        popup?.close();
        setContactError("No pudimos obtener los datos de contacto.");
        return;
      }

      setContact({ phone: result.phone, whatsapp: result.whatsapp });
      setContactAttempt({
        id: result.attempt_id,
        attempted_at: result.attempted_at,
        confirmed_at: result.confirmed_at,
      });
      setContactReused(result.reused);

      const url = result.contact_method === "whatsapp"
        ? `https://wa.me/${result.whatsapp}`
        : `tel:${(result.phone ?? "").replace(/[^\d+*#,;]/g, "")}`;
      const actionLabel = result.contact_method === "whatsapp"
        ? "Abrir WhatsApp"
        : "Llamar por teléfono";
      setContactActionLabel(actionLabel);
      if (popup && !popup.closed) {
        popup.location.replace(url);
      } else {
        setContactActionUrl(url);
        setContactError(
          `El contacto quedó registrado. Tu navegador bloqueó la pestaña; usá el enlace para ${result.contact_method === "whatsapp" ? "abrir WhatsApp" : "llamar"}.`
        );
      }
    } catch {
      popup?.close();
      setContactError("No pudimos registrar el intento. Probá nuevamente.");
    } finally {
      setContactBusy(false);
    }
  }

  async function handleConfirmContact() {
    if (!userId || !contactAttempt || confirmBusy) return;

    setContactError(null);
    setConfirmBusy(true);
    try {
      const { data, error: confirmError } = await createClient().rpc(
        "confirm_professional_contact",
        { p_attempt_id: contactAttempt.id }
      );

      if (confirmError || !data) {
        setContactError(
          confirmError?.message ?? "No pudimos confirmar el contacto."
        );
        return;
      }

      setContactAttempt({ ...contactAttempt, confirmed_at: data as string });
    } catch {
      setContactError("No pudimos confirmar el contacto. Probá nuevamente.");
    } finally {
      setConfirmBusy(false);
    }
  }

  async function handleReview(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!userId || !hiringId) return;
    if (!price || !reliability || !quality) {
      setError("Elegí una calificación en los tres criterios.");
      return;
    }
    setError(null);
    setSending(true);
    const { error: reviewError } = await createClient()
      .from("reviews")
      .insert({
        hiring_id: hiringId,
        professional_id: id,
        client_id: userId,
        price,
        reliability,
        quality,
        comment: comment.trim() || null,
      });
    setSending(false);
    if (reviewError) {
      setError(reviewError.message);
      return;
    }
    setPrice(0);
    setReliability(0);
    setQuality(0);
    setComment("");
    setVersion((v) => v + 1);
  }

  async function handleReport(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (!userId) return;
    setReportError(null);

    for (const f of files) {
      if (!TIPOS_EVIDENCIA.includes(f.type)) {
        setReportError(
          "La evidencia tiene que ser una imagen (JPG, PNG, WEBP) o un PDF."
        );
        return;
      }
      if (f.size > MAX_BYTES_EVIDENCIA) {
        setReportError("Cada archivo puede pesar hasta 5 MB.");
        return;
      }
    }

    setReportSending(true);
    const supabase = createClient();
    const reportId = crypto.randomUUID();
    const paths: string[] = [];

    try {
      for (const f of files) {
        const safeName = f.name.replace(/[^a-zA-Z0-9._-]/g, "_");
        const path = `${userId}/${reportId}/${crypto.randomUUID()}-${safeName}`;
        const { error: upError } = await supabase.storage
          .from("report-evidence")
          .upload(path, f);
        if (upError) throw new Error(upError.message);
        paths.push(path);
      }

      const { error: insertError } = await supabase.from("reports").insert({
        id: reportId,
        reporter_id: userId,
        professional_id: id,
        reason,
        details: details.trim() || null,
        evidence: paths,
      });
      if (insertError) throw new Error(insertError.message);
    } catch (err) {
      setReportError(
        err instanceof Error ? err.message : "No se pudo enviar la denuncia."
      );
      setReportSending(false);
      return;
    }

    setReportSending(false);
    setShowReport(false);
    setDetails("");
    setFiles([]);
    setFileKey((k) => k + 1);
    setVersion((v) => v + 1);
  }

  const loggedIn = userId !== null;
  const isOwner = pro !== null && pro.user_id === userId;

  const mainClass =
    "mx-auto flex min-h-screen max-w-md md:max-w-3xl flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]";
  const cardClass =
    "flex flex-col gap-2 rounded-2xl border border-[#dde4e4] bg-white p-4";
  const linkClass = "font-bold text-[#0f5c5c] underline";

  if (loading) return <main className={mainClass}>Cargando...</main>;

  if (!pro) {
    return (
      <main className={mainClass}>
        <h1 className="text-2xl font-bold">No encontramos este perfil</h1>
        <Link href="/buscar" className={linkClass}>
          Volver a buscar
        </Link>
      </main>
    );
  }

  const name = pro.profiles?.full_name ?? "Sin nombre";
  const location = [
    pro.profiles?.city,
    pro.profiles?.province,
    pro.profiles?.country,
  ]
    .filter(Boolean)
    .join(", ");
  const pideReferencias =
    pro.categories?.grupo === "cuidado" || pro.categories?.grupo === "seguridad";
  const esComida = pro.categories?.grupo === "comida";

  return (
    <main className={mainClass}>
      <div className="flex flex-col items-center gap-1.5 text-center">
        <Avatar path={pro.profiles?.avatar_path ?? null} name={name} size={88} />
        <h1 className="text-2xl font-bold">{name}</h1>
        <p className="text-[#55666a]">{pro.headline ?? pro.categories?.name}</p>
        <p className="text-sm text-[#55666a]">{location}</p>
        {pro.is_verified && (
          <span className="rounded-lg bg-[#dff0ec] px-2 py-0.5 text-sm font-medium text-[#0b4a4a]">
            Verificado
          </span>
        )}
        {summary && (
          <p className="text-lg font-bold">
            <span className="text-[#e9a23b]">★</span> {fmt(summary.avg_overall)}{" "}
            <span className="text-sm font-normal text-[#55666a]">
              ({summary.total}{" "}
              {summary.total === 1 ? "calificación" : "calificaciones"})
            </span>
          </p>
        )}
      </div>

      {pro.description && (
        <div className={cardClass}>
          <h2 className="font-bold">Sobre mí</h2>
          <p className="whitespace-pre-line text-[15px]">{pro.description}</p>
        </div>
      )}

      {esComida && (
        <p className="text-xs text-[#55666a]">
          Quien vende alimentos es responsable de contar con la habilitación que
          corresponda.
        </p>
      )}

      {photos.length > 0 && (
        <div className={cardClass}>
          <h2 className="font-bold">
            {esComida ? "Mis productos" : "Trabajos realizados"}
          </h2>
          <div className="grid grid-cols-2 gap-3">
            {photos.map((f) => (
              <div key={f.id} className="flex flex-col gap-1">
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img
                  src={
                    createClient().storage
                      .from("work-photos")
                      .getPublicUrl(f.file_path).data.publicUrl
                  }
                  alt={f.caption ?? "Foto"}
                  className="aspect-square w-full rounded-xl object-cover"
                />
                {f.caption && (
                  <p className="text-sm text-[#55666a]">{f.caption}</p>
                )}
              </div>
            ))}
          </div>
        </div>
      )}

      <div className={cardClass}>
        <h2 className="font-bold">Calificaciones</h2>
        {!summary ? (
          <p className="text-sm text-[#55666a]">Todavía no tiene calificaciones.</p>
        ) : (
          <>
            <Barra label="Precio" value={summary.avg_price} />
            <Barra label="Confiabilidad" value={summary.avg_reliability} />
            <Barra label="Calidad" value={summary.avg_quality} />
          </>
        )}
        {reviews
          .filter((r) => r.comment)
          .map((r) => (
            <div key={r.id} className="mt-2 border-t border-[#dde4e4] pt-3">
              <p className="text-[15px]">“{r.comment}”</p>
              <p className="mt-1 text-sm text-[#55666a]">
                {r.profiles?.full_name?.split(" ")[0] ?? "Cliente"} ·{" "}
                {new Date(r.created_at).toLocaleDateString("es-AR")}
              </p>
            </div>
          ))}
      </div>

      {loggedIn && !isOwner && hiringId && !reviewed && (
        <div className={cardClass}>
          <form onSubmit={handleReview} className="flex flex-col gap-4">
              <h2 className="font-bold">Calificá el trabajo</h2>
              <StarInput
                label="Precio"
                hint="¿Cobró un precio justo?"
                value={price}
                onChange={setPrice}
              />
              <StarInput
                label="Confiabilidad"
                hint="¿Cumplió y fue puntual?"
                value={reliability}
                onChange={setReliability}
              />
              <StarInput
                label="Calidad"
                hint="¿El trabajo quedó bien hecho?"
                value={quality}
                onChange={setQuality}
              />
              <label className="flex flex-col gap-1.5 text-sm font-medium">
                Comentario (opcional)
                <textarea
                  className="h-24 rounded-xl border border-[#b9c7c7] bg-white px-4 py-3 text-base"
                  maxLength={500}
                  value={comment}
                  onChange={(e) => setComment(e.target.value)}
                  placeholder="Contá cómo fue el trabajo"
                />
              </label>
              <button
                type="submit"
                disabled={sending}
                className="h-12 rounded-2xl bg-[#0f5c5c] font-bold text-white disabled:opacity-60"
              >
                {sending ? "Enviando..." : "Enviar calificación"}
              </button>
          </form>
          {error && <p className="text-sm text-red-700">{error}</p>}
        </div>
      )}

      {loggedIn && !isOwner && hiringId && reviewed && (
        <div className={cardClass}>
          <p className="text-sm font-medium text-[#0f5c5c]">
            Ya calificaste este trabajo. ¡Gracias por tu opinión!
          </p>
        </div>
      )}

      <div className={cardClass}>
        <h2 className="font-bold">Contacto</h2>
        {!loggedIn && (
          <p className="text-sm text-[#55666a]">
            Para contactar a esta persona,{" "}
            <Link href="/login" className={linkClass}>
              iniciá sesión
            </Link>{" "}
            o{" "}
            <Link href="/registro" className={linkClass}>
              creá tu cuenta
            </Link>
            .
          </p>
        )}
        {loggedIn && isOwner && (
          <p className="text-sm text-[#55666a]">Este es tu perfil profesional.</p>
        )}
        {loggedIn && !isOwner && !contactAttempt && !contactUnavailable && (
          <>
            <p className="text-sm text-[#55666a]">
              Al continuar, registraremos que intentaste contactar a esta persona.
              Esto no confirma que el mensaje se haya enviado.
            </p>
            <button
              type="button"
              onClick={handleStartContact}
              disabled={contactBusy}
              className="flex h-12 items-center justify-center rounded-2xl bg-[#0f5c5c] font-bold text-white disabled:opacity-60"
            >
              {contactBusy ? "Preparando contacto..." : "Contactar"}
            </button>
          </>
        )}
        {loggedIn && !isOwner && !contactAttempt && contactUnavailable && (
          <p className="text-sm text-[#55666a]">
            {contactUnavailableMessage ?? "Este perfil no está disponible para contactar."}
          </p>
        )}
        {loggedIn && !isOwner && contactAttempt && (
          <>
            <p className="text-sm text-[#55666a]">
              {contactReused ? "Contacto ya registrado el " : "Contacto registrado el "}{" "}
              {new Date(contactAttempt.attempted_at).toLocaleDateString("es-AR")}.
              {contactReused && " Reutilizarlo no consume otro cupo."}{" "}
              El registro no confirma el envío del mensaje ni que se haya realizado
              un trabajo.
            </p>
            {!contactAttempt.confirmed_at ? (
              <button
                type="button"
                onClick={handleConfirmContact}
                disabled={confirmBusy}
                className="h-12 rounded-2xl border border-[#0f5c5c] font-bold text-[#0f5c5c] disabled:opacity-60"
              >
                {confirmBusy ? "Guardando..." : "Contacté a esta persona"}
              </button>
            ) : (
              <p className="text-sm font-medium text-[#0f5c5c]">
                Confirmaste manualmente el contacto. La calificación estará
                disponible en una fase posterior.
              </p>
            )}
            <button
              type="button"
              onClick={handleStartContact}
              disabled={contactBusy}
              className="h-12 rounded-2xl bg-[#0f5c5c] font-bold text-white disabled:opacity-60"
            >
              {contactBusy ? "Abriendo contacto..." : "Volver a contactar"}
            </button>
          </>
        )}
        {contactActionUrl && (
          <a
            href={contactActionUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="flex h-12 items-center justify-center rounded-2xl border border-[#0f5c5c] font-bold text-[#0f5c5c]"
          >
            {contactActionLabel}
          </a>
        )}
        {contact?.phone && (
          <a
            href={`tel:${contact.phone}`}
            className="flex h-12 items-center justify-center rounded-2xl border border-[#0f5c5c] font-bold text-[#0f5c5c]"
          >
            Llamar: {contact.phone}
          </a>
        )}
        {contactError && <p className="text-sm text-red-700">{contactError}</p>}
      </div>

      <div className={cardClass}>
        <h2 className="font-bold">Certificados y estudios verificados</h2>
        {!loggedIn ? (
          <p className="text-sm text-[#55666a]">
            Para ver los certificados,{" "}
            <Link href="/login" className={linkClass}>
              iniciá sesión
            </Link>{" "}
            o{" "}
            <Link href="/registro" className={linkClass}>
              creá tu cuenta
            </Link>
            .
          </p>
        ) : certs.length === 0 ? (
          <p className="text-sm text-[#55666a]">
            Todavía no hay documentos verificados.
          </p>
        ) : (
          certs.map((c) => (
            <p key={c.id} className="text-[15px]">
              {c.title}
            </p>
          ))
        )}
      </div>

      {pideReferencias && (
        <div className={cardClass}>
          <h2 className="font-bold">Referencias de trabajos anteriores</h2>
          {!loggedIn ? (
            <p className="text-sm text-[#55666a]">
              Para ver las referencias,{" "}
              <Link href="/login" className={linkClass}>
                iniciá sesión
              </Link>{" "}
              o{" "}
              <Link href="/registro" className={linkClass}>
                creá tu cuenta
              </Link>
              .
            </p>
          ) : refs.length === 0 ? (
            <p className="text-sm text-[#55666a]">
              Todavía no cargó referencias.
            </p>
          ) : (
            <>
              {refs.map((r) => (
                <div
                  key={r.id}
                  className="flex flex-col gap-1 border-t border-[#dde4e4] pt-3 first:border-t-0 first:pt-0"
                >
                  <p className="font-bold">{r.name}</p>
                  {r.relationship && (
                    <p className="text-sm text-[#55666a]">{r.relationship}</p>
                  )}
                  <a
                    href={`tel:${r.phone}`}
                    className="w-fit text-sm font-bold text-[#0f5c5c] underline"
                  >
                    Llamar: {r.phone}
                  </a>
                </div>
              ))}
              <p className="text-xs text-[#55666a]">
                Referencias declaradas por el profesional. La plataforma no las
                verifica.
              </p>
            </>
          )}
        </div>
      )}

      {loggedIn && !isOwner && (
        <div className="flex flex-col gap-3">
          {reported ? (
            <p className="text-sm text-[#55666a]">
              Ya denunciaste este perfil. Lo vamos a revisar.
            </p>
          ) : !showReport ? (
            <button
              onClick={() => setShowReport(true)}
              className="w-fit text-sm font-bold text-red-700 underline"
            >
              Denunciar este perfil
            </button>
          ) : (
            <form onSubmit={handleReport} className={cardClass}>
              <h2 className="font-bold">Denunciar este perfil</h2>
              <select
                aria-label="Motivo"
                className="h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
              >
                {Object.entries(MOTIVOS).map(([value, label]) => (
                  <option key={value} value={value}>
                    {label}
                  </option>
                ))}
              </select>
              <textarea
                aria-label="Detalles"
                className="h-24 rounded-xl border border-[#b9c7c7] bg-white px-4 py-3 text-base"
                maxLength={500}
                value={details}
                onChange={(e) => setDetails(e.target.value)}
                placeholder="Contanos qué pasó (opcional)"
              />
              <div className="flex flex-col gap-2">
                <span className="text-sm font-medium">
                  Evidencia (capturas, fotos o PDF; hasta {MAX_EVIDENCIA})
                </span>
                <input
                  id="evidencia"
                  key={fileKey}
                  type="file"
                  multiple
                  accept="image/jpeg,image/png,image/webp,application/pdf"
                  className="sr-only"
                  onChange={(e) =>
                    setFiles(
                      Array.from(e.target.files ?? []).slice(0, MAX_EVIDENCIA)
                    )
                  }
                />
                <label
                  htmlFor="evidencia"
                  className="flex h-11 cursor-pointer items-center justify-center rounded-xl border border-[#0f5c5c] bg-white font-bold text-[#0f5c5c]"
                >
                  {files.length > 0 ? "Cambiar archivos" : "Agregar evidencia"}
                </label>
                {files.map((f) => (
                  <p key={f.name} className="text-sm text-[#55666a]">
                    {f.name}
                  </p>
                ))}
              </div>
              {reportError && (
                <p className="text-sm text-red-700">{reportError}</p>
              )}
              <div className="flex gap-2">
                <button
                  type="submit"
                  disabled={reportSending}
                  className="h-11 flex-1 rounded-xl bg-red-700 font-bold text-white disabled:opacity-60"
                >
                  {reportSending ? "Enviando..." : "Enviar denuncia"}
                </button>
                <button
                  type="button"
                  onClick={() => setShowReport(false)}
                  className="h-11 flex-1 rounded-xl border border-[#b9c7c7] font-bold"
                >
                  Cancelar
                </button>
              </div>
            </form>
          )}
        </div>
      )}

      <Link href="/buscar" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver a buscar
      </Link>
    </main>
  );
}
