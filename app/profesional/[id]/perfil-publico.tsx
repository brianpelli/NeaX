"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Profesional = {
  id: string;
  user_id: string;
  headline: string | null;
  description: string | null;
  is_verified: boolean;
  categories: { name: string } | null;
  profiles: {
    full_name: string | null;
    country: string | null;
    province: string | null;
    city: string | null;
  } | null;
};

type Contacto = { phone: string | null; whatsapp: string | null };
type Certificado = { id: string; title: string };
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
  const [contact, setContact] = useState<Contacto | null>(null);
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
          "id, user_id, headline, description, is_verified, categories(name), profiles(full_name, country, province, city)"
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

        const { data: contactData } = await supabase
          .from("professional_contacts")
          .select("phone, whatsapp")
          .eq("professional_id", id)
          .maybeSingle();
        setContact(contactData);

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

  async function handleHire() {
    if (!userId) return;
    setError(null);
    setSending(true);
    const { error: hireError } = await createClient()
      .from("hirings")
      .insert({ professional_id: id, client_id: userId });
    setSending(false);
    if (hireError) {
      setError(hireError.message);
      return;
    }
    setVersion((v) => v + 1);
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
    setReportSending(true);
    const { error: insertError } = await createClient()
      .from("reports")
      .insert({
        reporter_id: userId,
        professional_id: id,
        reason,
        details: details.trim() || null,
      });
    setReportSending(false);
    if (insertError) {
      setReportError(insertError.message);
      return;
    }
    setShowReport(false);
    setDetails("");
    setVersion((v) => v + 1);
  }

  const loggedIn = userId !== null;
  const isOwner = pro !== null && pro.user_id === userId;

  const mainClass =
    "mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]";
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
  const initials = name
    .split(" ")
    .map((p) => p[0])
    .slice(0, 2)
    .join("")
    .toUpperCase();

  return (
    <main className={mainClass}>
      <div className="flex flex-col items-center gap-1.5 text-center">
        <div className="flex h-22 w-22 items-center justify-center rounded-full bg-[#d5e8e6] text-3xl font-bold text-[#0b4a4a]">
          {initials}
        </div>
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

      {loggedIn && !isOwner && (
        <div className={cardClass}>
          {!hiringId && (
            <>
              <h2 className="font-bold">¿Trabajaste con esta persona?</h2>
              <p className="text-sm text-[#55666a]">
                Marcá que la contrataste para poder calificar su trabajo.
              </p>
              <button
                onClick={handleHire}
                disabled={sending}
                className="h-12 rounded-2xl bg-[#0f5c5c] font-bold text-white disabled:opacity-60"
              >
                {sending ? "Guardando..." : "Contraté a esta persona"}
              </button>
            </>
          )}

          {hiringId && !reviewed && (
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
          )}

          {hiringId && reviewed && (
            <p className="text-sm font-medium text-[#0f5c5c]">
              Ya calificaste este trabajo. ¡Gracias por tu opinión!
            </p>
          )}

          {error && <p className="text-sm text-red-700">{error}</p>}
        </div>
      )}

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

      <div className={cardClass}>
        <h2 className="font-bold">Contacto</h2>
        {!loggedIn && (
          <p className="text-sm text-[#55666a]">
            Para ver el teléfono y el WhatsApp,{" "}
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
        {loggedIn && !contact?.phone && !contact?.whatsapp && (
          <p className="text-sm text-[#55666a]">
            Esta persona todavía no cargó datos de contacto.
          </p>
        )}
        {loggedIn && contact?.whatsapp && (
          <a
            href={`https://wa.me/${contact.whatsapp.replace(/\D/g, "")}`}
            target="_blank"
            rel="noopener noreferrer"
            className="flex h-12 items-center justify-center rounded-2xl bg-[#0f5c5c] font-bold text-white"
          >
            Escribir por WhatsApp
          </a>
        )}
        {loggedIn && contact?.phone && (
          <a
            href={`tel:${contact.phone}`}
            className="flex h-12 items-center justify-center rounded-2xl border border-[#0f5c5c] font-bold text-[#0f5c5c]"
          >
            Llamar: {contact.phone}
          </a>
        )}
      </div>

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