"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";

type Category = { id: number; name: string; grupo: string };

type Resultado = {
  id: string;
  headline: string | null;
  is_verified: boolean;
  categories: { name: string } | null;
  profiles: {
    full_name: string | null;
    province: string | null;
    city: string | null;
  } | null;
};

type Resumen = { total: number; avg_overall: number };

const GRUPOS: Record<string, string> = {
  oficios: "Oficios",
  cuidado: "Cuidado de personas",
  seguridad: "Seguridad",
};

export default function BuscarPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [categoryId, setCategoryId] = useState("");
  const [city, setCity] = useState("");
  const [results, setResults] = useState<Resultado[]>([]);
  const [ratings, setRatings] = useState<Record<string, Resumen>>({});
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    createClient()
      .from("categories")
      .select("id, name, grupo")
      .order("name")
      .then(({ data }) => setCategories(data ?? []));
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function search() {
      setLoading(true);
      setError(null);

      const supabase = createClient();

      let query = supabase
        .from("professionals")
        .select(
          "id, headline, is_verified, categories(name), profiles!inner(full_name, province, city)"
        )
        .order("is_verified", { ascending: false })
        .limit(50);

      if (categoryId) query = query.eq("category_id", Number(categoryId));
      if (city.trim()) query = query.ilike("profiles.city", `%${city.trim()}%`);

      const { data, error: searchError } = await query;
      if (cancelled) return;

      if (searchError) {
        setError(searchError.message);
        setLoading(false);
        return;
      }

      const rows = (data ?? []) as unknown as Resultado[];
      setResults(rows);

      if (rows.length > 0) {
        const { data: rat } = await supabase
          .from("professional_ratings")
          .select("professional_id, total, avg_overall")
          .in(
            "professional_id",
            rows.map((r) => r.id)
          );
        if (cancelled) return;
        setRatings(
          Object.fromEntries(
            (rat ?? []).map((x) => [x.professional_id, x as Resumen])
          )
        );
      }

      setLoading(false);
    }

    const timer = setTimeout(search, 300);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [categoryId, city]);

  const inputClass =
    "h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base text-[#14272b]";

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col gap-4 bg-[#f4f6f6] p-6 text-[#14272b]">
      <h1 className="text-3xl font-bold">¿Qué necesitás?</h1>

      <select
        aria-label="Rubro"
        className={inputClass}
        value={categoryId}
        onChange={(e) => setCategoryId(e.target.value)}
      >
        <option value="">Todos los rubros</option>
        {Object.entries(GRUPOS).map(([grupo, titulo]) => (
          <optgroup key={grupo} label={titulo}>
            {categories
              .filter((c) => c.grupo === grupo)
              .map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                </option>
              ))}
          </optgroup>
        ))}
      </select>

      <input
        aria-label="Ciudad"
        className={inputClass}
        placeholder="Ciudad"
        value={city}
        onChange={(e) => setCity(e.target.value)}
      />

      {error && <p className="text-sm text-red-700">{error}</p>}
      {loading && <p className="text-sm text-[#55666a]">Buscando...</p>}
      {!loading && !error && results.length === 0 && (
        <p className="text-sm text-[#55666a]">
          No encontramos resultados con esos filtros.
        </p>
      )}

      {results.map((r) => (
        <Link
          key={r.id}
          href={`/profesional/${r.id}`}
          className="flex flex-col gap-1 rounded-2xl border border-[#dde4e4] bg-white p-4"
        >
          <span className="text-lg font-bold">
            {r.profiles?.full_name ?? "Sin nombre"}
          </span>
          <span className="text-sm text-[#55666a]">
            {r.headline ?? r.categories?.name}
          </span>
          <span className="text-sm text-[#55666a]">
            {[r.profiles?.city, r.profiles?.province].filter(Boolean).join(", ")}
          </span>
          {ratings[r.id] && (
            <span className="text-sm">
              <span className="text-[#e9a23b]">★</span>{" "}
              {Number(ratings[r.id].avg_overall).toFixed(1).replace(".", ",")} (
              {ratings[r.id].total})
            </span>
          )}
          {r.is_verified && (
            <span className="mt-1 w-fit rounded-lg bg-[#dff0ec] px-2 py-0.5 text-sm font-medium text-[#0b4a4a]">
              Verificado
            </span>
          )}
        </Link>
      ))}

      <Link href="/" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver al inicio
      </Link>
    </main>
  );
}