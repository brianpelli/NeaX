import { Suspense } from "react";
import PerfilPublico from "./perfil-publico";

export default function Page() {
  return (
    <Suspense
      fallback={
        <main className="mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]">
          Cargando...
        </main>
      }
    >
      <PerfilPublico />
    </Suspense>
  );
}