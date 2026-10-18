"use client";

import { useEffect, useState } from "react";
import { useParams } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Profesional = {
  id: string;
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

export default function PerfilPublicoPage() {
  const params = useParams<{ id: string }>();
  const id = params.id;

  const [pro, setPro] = useState<Profesional | null>(null);
  const [certs, setCerts] = useState<Certificado[]>([]);
  const [contact, setContact] = useState<Contacto | null>(null);
  const [loggedIn, setLoggedIn] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    async function load() {
      const supabase = createClient();

      const { data } = await supabase
        .from("professionals")
        .select(
          "id, headline, description, is_verified, categories(name), profiles(full_name, country, province, city)"
        )
        .eq("id", id)
        .maybeSingle();

      if (!data) {
        setLoading(false);
        return;
      }
      setPro(data as unknown as Profesional);

      const { data: userData } = await supabase.auth.getUser();
      if (userData.user) {
        setLoggedIn(true);

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
      }
      setLoading(false);
    }
    load();
  }, [id]);

  const mainClass =
    "mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]";
  const cardClass =
    "flex flex-col gap-2 rounded-2xl border border-[#dde4e4] bg-white p-4";

  if (loading) return <main className={mainClass}>Cargando...</main>;

  if (!pro) {
    return (
      <main className={mainClass}>
        <h1 className="text-2xl font-bold">No encontramos este perfil</h1>
        <Link href="/buscar" className="font-bold text-[#0f5c5c] underline">
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
      </div>

      {pro.description && (
        <div className={cardClass}>
          <h2 className="font-bold">Sobre mí</h2>
          <p className="whitespace-pre-line text-[15px]">{pro.description}</p>
        </div>
      )}

      <div className={cardClass}>
        <h2 className="font-bold">Certificados y estudios verificados</h2>
        {!loggedIn ? (
          <p className="text-sm text-[#55666a]">
            Para ver los certificados,{" "}
            <Link href="/login" className="font-bold text-[#0f5c5c] underline">
              iniciá sesión
            </Link>{" "}
            o{" "}
            <Link href="/registro" className="font-bold text-[#0f5c5c] underline">
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
            <Link href="/login" className="font-bold text-[#0f5c5c] underline">
              iniciá sesión
            </Link>{" "}
            o{" "}
            <Link href="/registro" className="font-bold text-[#0f5c5c] underline">
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

      <Link href="/buscar" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver a buscar
      </Link>
    </main>
  );
}