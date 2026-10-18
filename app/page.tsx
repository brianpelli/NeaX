import AuthStatus from "@/components/AuthStatus";

export default function Home() {
  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col gap-6 bg-[#f4f6f6] p-6 text-[#14272b]">
      <h1 className="text-3xl font-bold">[Nombre de la app]</h1>
      <p className="text-[#55666a]">
        Encontrá profesionales y oficios de confianza.
      </p>
      <AuthStatus />
    </main>
  );
}