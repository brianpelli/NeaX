import Link from "next/link";
import AuthStatus from "@/components/AuthStatus";

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col gap-6 bg-[#f4f6f6] p-6 text-[#14272b]">
      <h1 className="text-center text-3xl font-bold">Nea-X</h1>
      <p className="text-center text-[#55666a]">
        Encontrá profesionales y oficios de confianza.
      </p>
      <Link
        href="/buscar"
        className="flex h-12 items-center justify-center rounded-2xl bg-[#0f5c5c] font-bold text-white"
      >
        Buscar profesionales
      </Link>
      <AuthStatus />
    </main>
  );
}