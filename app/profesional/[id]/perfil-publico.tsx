"use client";

import { useEffect, useRef, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import Avatar from "@/components/Avatar";
import ProfessionalReviewEditor from "@/components/reviews/ProfessionalReviewEditor";
import { StarRatingInput } from "@/components/reviews/ProfessionalReviewEditor";

type Profesional = {
  id: string;
  user_id: string;
  headline: string | null;
  description: string | null;
  is_verified: boolean;
  is_suspended: boolean;
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
  avg_overall: number | null;
};
type Resena = {
  id: string;
  contact_attempt_id: string | null;
  overall_rating: number | null;
  edit_count?: number;
  price: number | null;
  reliability: number | null;
  quality: number | null;
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

function Estrellas({ value }: { value: number }) {
  const rating = Math.max(0, Math.min(5, Math.round(value)));
  return (
    <span
      className="whitespace-nowrap text-[#e9a23b]"
      role="img"
      aria-label={rating + " de 5 estrellas"}
    >
      {"★".repeat(rating)}
      {"☆".repeat(5 - rating)}
    </span>
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
  const [legacyReviews, setLegacyReviews] = useState<Resena[]>([]);
  const [ownReview, setOwnReview] = useState<Resena | null>(null);
  const [ratingsLoading, setRatingsLoading] = useState(true);
  const [contactLookupLoading, setContactLookupLoading] = useState(true);
  const [reviewLookupLoading, setReviewLookupLoading] = useState(true);
  const [summaryError, setSummaryError] = useState<string | null>(null);
  const [reviewsError, setReviewsError] = useState<string | null>(null);
  const [legacyReviewsError, setLegacyReviewsError] = useState<string | null>(null);
  const [contactLookupError, setContactLookupError] = useState<string | null>(null);
  const [reviewLookupError, setReviewLookupError] = useState<string | null>(null);
  const [userId, setUserId] = useState<string | null>(null);
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

  const [comment, setComment] = useState("");
  const [overallRating, setOverallRating] = useState(0);
  const [publishing, setPublishing] = useState(false);
  const [publishError, setPublishError] = useState<string | null>(null);
  const [publishSuccess, setPublishSuccess] = useState<string | null>(null);
  const [duplicateBlocked, setDuplicateBlocked] = useState(false);
  const [authorizationBlocked, setAuthorizationBlocked] = useState(false);
  const publishLock = useRef(false);
  const [editSuccess, setEditSuccess] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      const supabase = createClient();

      const { data } = await supabase
        .from("professionals")
        .select(
          "id, user_id, headline, description, is_verified, is_suspended, categories(name, grupo), profiles(full_name, country, province, city, avatar_path)"
        )
        .eq("id", id)
        .maybeSingle();

      if (!data) {
        setLoading(false);
        return;
      }
      setPro(data as unknown as Profesional);

      setRatingsLoading(true);
      setSummary(null);
      setReviews([]);
      setLegacyReviews([]);
      setSummaryError(null);
      setReviewsError(null);
      setLegacyReviewsError(null);
      setContactLookupLoading(true);
      setReviewLookupLoading(true);
      setContactLookupError(null);
      setReviewLookupError(null);
      setOwnReview(null);
      setContactAttempt(null);
      setContactReused(false);
      setUserId(null);

      const { data: sum, error: summaryLoadError } = await supabase
        .from("professional_ratings")
        .select("total, avg_overall")
        .eq("professional_id", id)
        .maybeSingle();
      if (summaryLoadError) {
        setSummaryError("No pudimos cargar el promedio de calificaciones.");
      } else {
        setSummary(sum as Resumen | null);
      }

      const reviewFields =
        "id, contact_attempt_id, overall_rating, price, reliability, quality, comment, created_at, profiles(full_name)";
      const { data: b3Reviews, error: b3ReviewsError } = await supabase
        .from("reviews")
        .select(reviewFields)
        .eq("professional_id", id)
        .not("contact_attempt_id", "is", null)
        .not("overall_rating", "is", null)
        .is("removed_at", null)
        .order("created_at", { ascending: false })
        .limit(10);
      if (b3ReviewsError) {
        setReviewsError("No pudimos cargar las calificaciones recientes.");
      } else {
        setReviews((b3Reviews ?? []) as unknown as Resena[]);
      }

      const { data: historicalReviews, error: historicalReviewsError } =
        await supabase
          .from("reviews")
          .select(reviewFields)
          .eq("professional_id", id)
          .is("contact_attempt_id", null)
          .is("removed_at", null)
          .order("created_at", { ascending: false })
          .limit(10);
      if (historicalReviewsError) {
        setLegacyReviewsError("No pudimos cargar las opiniones anteriores.");
      } else {
        setLegacyReviews((historicalReviews ?? []) as unknown as Resena[]);
      }
      setRatingsLoading(false);

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

        const { data: attemptData, error: attemptError } = await supabase
          .from("professional_contact_attempts")
          .select("id, attempted_at, confirmed_at")
          .eq("professional_id", id)
          .maybeSingle();
        if (attemptError) {
          setContactLookupError("No pudimos verificar tu contacto con este profesional.");
        } else {
          setContactAttempt(attemptData as IntentoContacto | null);
        }
        setContactReused(!!attemptData);
        setContactLookupLoading(false);

        const { data: mine, error: mineError } = await supabase
          .from("reviews")
          .select(`${reviewFields}, edit_count`)
          .eq("professional_id", id)
          .eq("client_id", user.id)
          .is("removed_at", null)
          .maybeSingle();
        if (mineError) {
          setReviewLookupError("No pudimos comprobar si ya existe una reseña tuya.");
        } else {
          setOwnReview(mine as unknown as Resena | null);
        }
        setReviewLookupLoading(false);

        const { data: myReport } = await supabase
          .from("reports")
          .select("id")
          .eq("professional_id", id)
          .eq("reporter_id", user.id)
          .maybeSingle();
        setReported(!!myReport);
      } else {
        setUserId(null);
        setContactAttempt(null);
        setContactLookupLoading(false);
        setOwnReview(null);
        setReviewLookupLoading(false);
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
      setContactLookupError(null);
      setContactLookupLoading(false);
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

      setContactLookupError(null);
      setContactAttempt({ ...contactAttempt, confirmed_at: data as string });
    } catch {
      setContactError("No pudimos confirmar el contacto. Probá nuevamente.");
    } finally {
      setConfirmBusy(false);
    }
  }

  async function handlePublishReview(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (
      publishLock.current ||
      !userId ||
      !pro ||
      pro.user_id === userId ||
      pro.is_suspended ||
      ratingsLoading ||
      summaryError ||
      !contactAttempt?.confirmed_at ||
      contactLookupLoading ||
      contactLookupError ||
      reviewLookupLoading ||
      reviewLookupError ||
      reviewsError ||
      legacyReviewsError ||
      ownReview ||
      duplicateBlocked ||
      authorizationBlocked ||
      publishSuccess
    ) {
      return;
    }

    const normalizedComment = comment.trim();
    if (!Number.isInteger(overallRating) || overallRating < 1 || overallRating > 5) {
      setPublishError("Elegí una calificación de una a cinco estrellas.");
      return;
    }
    if (Array.from(normalizedComment).length > 500) {
      setPublishError("El comentario no puede superar los 500 caracteres.");
      return;
    }

    publishLock.current = true;
    setPublishing(true);
    setPublishError(null);
    try {
      const { data: reviewId, error: reviewError } = await createClient().rpc(
        "create_professional_review",
        {
          p_contact_attempt_id: contactAttempt.id,
          p_overall_rating: overallRating,
          p_comment: normalizedComment || null,
        }
      );

      if (reviewError) {
        if (reviewError.code === "23505") {
          setDuplicateBlocked(true);
          setPublishError(
            "Ya existe una reseña para este profesional. No se puede publicar otra."
          );
        } else if (reviewError.code === "42501") {
          setAuthorizationBlocked(true);
          setPublishError(
            "No pudimos autorizar la publicación. Verificá que el contacto esté confirmado y el perfil disponible."
          );
        } else if (reviewError.code === "28000") {
          setPublishError("Tu sesión venció. Iniciá sesión nuevamente para publicar.");
        } else if (reviewError.code === "22023") {
          setPublishError(reviewError.message);
        } else if (reviewError.code === "P0002") {
          setAuthorizationBlocked(true);
          setPublishError("Este perfil profesional ya no está disponible.");
        } else {
          setPublishError("No pudimos publicar la calificación. Probá nuevamente.");
        }
        setReviewLookupLoading(true);
        setRatingsLoading(true);
        setSummary(null);
        setReviews([]);
        setLegacyReviews([]);
        setOwnReview(null);
        setVersion((current) => current + 1);
        return;
      }

      if (!reviewId) {
        setPublishError("No recibimos la confirmación de publicación. Actualizaremos el perfil.");
        setReviewLookupLoading(true);
        setRatingsLoading(true);
        setSummary(null);
        setReviews([]);
        setLegacyReviews([]);
        setOwnReview(null);
        setVersion((current) => current + 1);
        return;
      }

      setPublishSuccess("Tu calificación se publicó correctamente.");
      setOverallRating(0);
      setComment("");
      setReviewLookupLoading(true);
      setRatingsLoading(true);
      setSummary(null);
      setReviews([]);
      setLegacyReviews([]);
      setOwnReview(null);
      setVersion((current) => current + 1);
    } catch {
      setPublishError("No pudimos confirmar la publicación. Estamos actualizando el perfil.");
      setReviewLookupLoading(true);
      setRatingsLoading(true);
      setSummary(null);
      setReviews([]);
      setLegacyReviews([]);
      setOwnReview(null);
      setVersion((current) => current + 1);
    } finally {
      publishLock.current = false;
      setPublishing(false);
    }
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
  const visibleReviews =
    ownReview?.contact_attempt_id && !reviews.some((review) => review.id === ownReview.id)
      ? [ownReview, ...reviews]
      : reviews;
  const visibleLegacyReviews =
    ownReview && ownReview.contact_attempt_id === null &&
    !legacyReviews.some((review) => review.id === ownReview.id)
      ? [ownReview, ...legacyReviews]
      : legacyReviews;
  const eligibilityLoading =
    ratingsLoading || contactLookupLoading || reviewLookupLoading;
  const eligibilityError =
    summaryError ||
    reviewsError ||
    legacyReviewsError ||
    contactLookupError ||
    reviewLookupError;
  function refreshProfileRatings() {
    setReviewLookupLoading(true);
    setRatingsLoading(true);
    setSummary(null);
    setReviews([]);
    setLegacyReviews([]);
    setOwnReview(null);
    setVersion((current) => current + 1);
  }

  const canPublishRating =
    loggedIn &&
    !isOwner &&
    pro !== null &&
    !pro.is_suspended &&
    Boolean(contactAttempt?.confirmed_at) &&
    !eligibilityLoading &&
    !eligibilityError &&
    !ownReview &&
    !duplicateBlocked &&
    !authorizationBlocked &&
    !publishSuccess &&
    !publishing;

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
        {!ratingsLoading &&
          !summaryError &&
          summary &&
          summary.total > 0 &&
          summary.avg_overall !== null && (
            <p className="flex flex-wrap items-center justify-center gap-2 text-lg font-bold">
              <Estrellas value={summary.avg_overall} />
              <span>{Math.round(summary.avg_overall)}/5</span>
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
        <p className="text-sm text-[#55666a]">
          Promedio de clientes que confirmaron su contacto.
        </p>
        {ratingsLoading && (
          <p role="status" className="text-sm text-[#55666a]">
            Cargando calificaciones...
          </p>
        )}
        {!ratingsLoading && summaryError && (
          <p role="alert" className="text-sm text-red-700">{summaryError}</p>
        )}
        {!ratingsLoading && !summaryError && (summary?.total ?? 0) === 0 && (
          <p className="text-sm text-[#55666a]">
            Este profesional todavía no recibió calificaciones.
          </p>
        )}
        {!ratingsLoading && !summaryError && (summary?.total ?? 0) > 0 &&
          summary?.avg_overall === null && (
            <p role="status" className="text-sm text-[#55666a]">
              El promedio todavía no está disponible.
            </p>
          )}
        {!ratingsLoading && !reviewsError && reviews.length === 0 &&
          (summary?.total ?? 0) > 0 && (
            <p className="text-sm text-[#55666a]">
              Todavía no hay comentarios para mostrar.
            </p>
          )}
        {!ratingsLoading && reviewsError && (
          <p role="alert" className="text-sm text-red-700">{reviewsError}</p>
        )}
        {visibleReviews.map((review) => (
          <article key={review.id} className="mt-2 flex flex-col gap-2 border-t border-[#dde4e4] pt-3">
            <div className="flex flex-wrap items-center gap-2">
              {review.overall_rating !== null && (
                <>
                  <Estrellas value={review.overall_rating} />
                  <span className="text-sm font-semibold">
                    {review.overall_rating}/5
                  </span>
                </>
              )}
              {review.id === ownReview?.id && (
                <span className="rounded-full bg-[#dff0ec] px-2 py-1 text-xs text-[#0b4a4a]">
                  Tu calificación
                </span>
              )}
              <span className="text-sm text-[#55666a]">
                {review.profiles?.full_name?.split(" ")[0] ?? "Cliente"} ·{" "}
                {new Date(review.created_at).toLocaleDateString("es-AR")}
              </span>
            </div>
            {review.comment && (
              <p className="whitespace-pre-line break-words text-[15px]">
                “{review.comment}”
              </p>
            )}
          </article>
        ))}
      </div>

      <div className={cardClass}>
        <h2 className="font-bold">Opiniones anteriores</h2>
        <p className="text-sm text-[#55666a]">
          Estas opiniones conservan sus criterios originales y se muestran por
          separado del promedio actual.
        </p>
        {ratingsLoading && (
          <p role="status" className="text-sm text-[#55666a]">
            Cargando opiniones anteriores...
          </p>
        )}
        {!ratingsLoading && legacyReviewsError && (
          <p role="alert" className="text-sm text-red-700">
            {legacyReviewsError}
          </p>
        )}
        {!ratingsLoading && !legacyReviewsError && legacyReviews.length === 0 && (
          <p className="text-sm text-[#55666a]">
            Todavía no hay opiniones anteriores para mostrar.
          </p>
        )}
        {visibleLegacyReviews.map((review) => (
          <article key={review.id} className="mt-2 flex flex-col gap-3 border-t border-[#dde4e4] pt-3">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <p className="text-sm font-medium">
                {review.profiles?.full_name?.split(" ")[0] ?? "Cliente"} ·{" "}
                {new Date(review.created_at).toLocaleDateString("es-AR")}
              </p>
              <span className="rounded-full bg-[#edf1f1] px-2 py-1 text-xs text-[#55666a]">
                Anterior
              </span>
            </div>
            <div className="grid grid-cols-1 gap-2 sm:grid-cols-3">
              {review.price !== null && (
                <Barra label="Precio" value={review.price} />
              )}
              {review.reliability !== null && (
                <Barra label="Confiabilidad" value={review.reliability} />
              )}
              {review.quality !== null && (
                <Barra label="Calidad" value={review.quality} />
              )}
            </div>
            {review.comment && (
              <p className="whitespace-pre-line break-words text-[15px]">
                “{review.comment}”
              </p>
            )}
          </article>
        ))}
      </div>

      {loggedIn && !isOwner && ownReview?.contact_attempt_id === null && (
        <div className={cardClass}>
          <p role="status" className="text-sm text-[#55666a]">
            Ya dejaste una opinión anterior para este profesional. Como solo se
            permite una reseña por persona y profesional, no podés publicar otra.
          </p>
        </div>
      )}

      {loggedIn &&
        !isOwner &&
        (contactAttempt?.confirmed_at ||
          (ownReview?.contact_attempt_id && ownReview.overall_rating !== null)) && (
        <div className={cardClass}>
          <h2 className="font-bold">
            {ownReview?.contact_attempt_id ? "Tu calificación" : "Calificá tu experiencia"}
          </h2>

          {publishSuccess && (
            <p role="status" className="text-sm font-medium text-[#0f5c5c]">
              {publishSuccess}
            </p>
          )}
          {editSuccess && (
            <p role="status" className="text-sm font-medium text-[#0f5c5c]">
              {editSuccess}
            </p>
          )}
          {pro.is_suspended && !ownReview?.contact_attempt_id && (
            <p role="status" className="text-sm text-[#55666a]">
              Este perfil no está recibiendo nuevas calificaciones.
            </p>
          )}
          {!pro.is_suspended && eligibilityLoading && !ownReview && (
            <p role="status" className="text-sm text-[#55666a]">
              Verificando que puedas publicar...
            </p>
          )}
          {!pro.is_suspended && eligibilityError && (
            <p role="alert" className="text-sm text-red-700">
              No pudimos comprobar si ya existe una calificación. Actualizá la
              página antes de intentar publicar.
            </p>
          )}
          {ownReview?.contact_attempt_id && (
            ownReview.overall_rating !== null &&
            ownReview.edit_count !== undefined && (
              <ProfessionalReviewEditor
                review={{
                  id: ownReview.id,
                  overall_rating: ownReview.overall_rating,
                  comment: ownReview.comment,
                  created_at: ownReview.created_at,
                  edit_count: ownReview.edit_count,
                }}
                onSaved={() => {
                  setEditSuccess("Tu calificación se actualizó correctamente.");
                  refreshProfileRatings();
                }}
                onRefresh={refreshProfileRatings}
              />
            )
          )}
          {duplicateBlocked && (
            <p role="alert" className="text-sm text-red-700">
              Ya existe una reseña para este profesional. No se puede publicar otra.
            </p>
          )}
          {canPublishRating && (
            <form onSubmit={handlePublishReview} className="flex flex-col gap-4">
              <StarRatingInput
                label="Calificación general"
                hint="Elegí de una a cinco estrellas."
                value={overallRating}
                disabled={publishing}
                onChange={(value) => {
                  setOverallRating(value);
                  setPublishError(null);
                }}
              />
              <label className="flex w-full flex-col gap-1.5 text-sm font-medium">
                Comentario (opcional)
                <textarea
                  className="min-h-24 w-full rounded-xl border border-[#b9c7c7] bg-white px-4 py-3 text-base focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c]"
                  maxLength={1000}
                  value={comment}
                  onChange={(event) => {
                    const nextComment = event.target.value;
                    if (Array.from(nextComment).length <= 500) {
                      setComment(nextComment);
                      setPublishError(null);
                    }
                  }}
                  placeholder="Contá cómo fue tu experiencia"
                  aria-describedby="review-comment-count"
                  disabled={publishing}
                />
                <span id="review-comment-count" aria-live="polite" className="text-right text-xs text-[#55666a]">
                  {Array.from(comment).length}/500 caracteres
                </span>
              </label>
              <button
                type="submit"
                disabled={publishing || overallRating === 0}
                className="min-h-12 rounded-2xl bg-[#0f5c5c] px-4 font-bold text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c] disabled:opacity-60"
              >
                {publishing ? "Publicando..." : "Publicar calificación"}
              </button>
            </form>
          )}
          {publishError && !duplicateBlocked && (
            <p role="alert" className="text-sm text-red-700">
              {publishError}
            </p>
          )}
        </div>
      )}

      <div className={cardClass}>
        <h2 className="font-bold">Contacto</h2>
        {contactLookupError && (
          <p role="alert" className="text-sm text-red-700">
            No pudimos comprobar tu contacto anterior con este profesional.
          </p>
        )}
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
                Confirmaste manualmente que contactaste a esta persona.
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
