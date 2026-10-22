"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

export default function RegistroPage() {
  const router = useRouter();
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [message, setMessage] = useState<string | null>(null);
  const [accepted, setAccepted] = useState(false);

  async function handleSubmit(e: React.FormEvent<HTMLFormElement>) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    const supabase = createClient();
    const { error } = await supabase.auth.signUp({
      email,
      password,
      options: {
        data: {
          full_name: fullName,
          terms_accepted_at: new Date().toISOString(),
        },
      },
    });

    setLoading(false);
    if (error) {
      setError(error.message);
      return;
    }
    router.push("/");
    router.refresh();
  }

  const inputClass =
    "h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base text-[#14272b]";

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col gap-5 bg-[#f4f6f6] p-6 text-[#14272b]">
      <h1 className="text-3xl font-bold">Creá tu cuenta</h1>

      <form onSubmit={handleSubmit} className="flex flex-col gap-4">
        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Nombre y apellido
          <input
            className={inputClass}
            value={fullName}
            onChange={(e) => setFullName(e.target.value)}
            required
          />
        </label>
        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Correo electrónico
          <input
            type="email"
            className={inputClass}
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            required
          />
        </label>
        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Contraseña (mínimo 8 caracteres)
          <input
            type="password"
            minLength={8}
            className={inputClass}
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            required
          />
        </label>

        <label className="flex items-start gap-3 text-sm">
          <input
            type="checkbox"
            className="mt-1 h-5 w-5"
            checked={accepted}
            onChange={(e) => setAccepted(e.target.checked)}
          />
          <span>
            Acepto los{" "}
            <Link href="/terminos" className="font-bold text-[#0f5c5c] underline">
              Términos y condiciones
            </Link>{" "}
            y la{" "}
            <Link href="/privacidad" className="font-bold text-[#0f5c5c] underline">
              Política de privacidad
            </Link>
            .
          </span>
        </label>

        {error && <p className="text-sm text-red-700">{error}</p>}

        <button
          type="submit"
          disabled={loading || !accepted}
          className="h-13 rounded-2xl bg-[#0f5c5c] text-lg font-bold text-white disabled:opacity-60"
        >
          {loading ? "Creando cuenta..." : "Registrarme"}
        </button>
      </form>

      <p className="text-sm text-[#55666a]">
        ¿Ya tenés cuenta?{" "}
        <Link href="/login" className="font-bold text-[#0f5c5c] underline">
          Iniciá sesión
        </Link>
      </p>
    </main>
  );
}