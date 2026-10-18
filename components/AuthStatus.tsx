"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import type { User } from "@supabase/supabase-js";
import { createClient } from "@/lib/supabase/client";

export default function AuthStatus() {
  const [user, setUser] = useState<User | null>(null);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    const supabase = createClient();

    supabase.auth.getUser().then(({ data }) => {
      setUser(data.user);
      setReady(true);
    });

    const {
      data: { subscription },
    } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
    });

    return () => subscription.unsubscribe();
  }, []);

  if (!ready) return null;

  if (user) {
    const name = user.user_metadata?.full_name ?? user.email;
    return (
      <div className="flex flex-col gap-3">
        <p className="text-lg">Hola, {name}</p>
        <button
          onClick={() => createClient().auth.signOut()}
          className="h-12 rounded-2xl border border-[#0f5c5c] font-bold text-[#0f5c5c]"
        >
          Cerrar sesión
        </button>
      </div>
    );
  }

  return (
    <div className="flex flex-col gap-3">
      <Link
        href="/registro"
        className="flex h-12 items-center justify-center rounded-2xl bg-[#0f5c5c] font-bold text-white"
      >
        Registrarme
      </Link>
      <Link
        href="/login"
        className="flex h-12 items-center justify-center rounded-2xl border border-[#0f5c5c] font-bold text-[#0f5c5c]"
      >
        Iniciar sesión
      </Link>
    </div>
  );
}