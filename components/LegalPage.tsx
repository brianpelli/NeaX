import Link from "next/link";
import type { ReactNode } from "react";

export function LegalPage({
  title,
  children,
}: {
  title: string;
  children: ReactNode;
}) {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]">
      <h1 className="text-3xl font-bold">{title}</h1>
      <p className="rounded-xl bg-[#fff4d6] p-3 text-sm text-[#5c4300]">
        Borrador en revisión. Última actualización: octubre de 2026.
      </p>
      <div className="flex flex-col gap-6 text-[15px] leading-relaxed">
        {children}
      </div>
      <Link href="/" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver al inicio
      </Link>
    </main>
  );
}

export function Seccion({
  titulo,
  children,
}: {
  titulo: string;
  children: ReactNode;
}) {
  return (
    <section className="flex flex-col gap-2">
      <h2 className="text-lg font-bold">{titulo}</h2>
      {children}
    </section>
  );
}