"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { createClient } from "@/lib/supabase/client";
import Avatar from "@/components/Avatar";

type Category = { id: number; name: string; grupo: string; is_active: boolean };

type Resultado = {
  id: string;
  headline: string | null;
  is_verified: boolean;
  category_name: string | null;
  full_name: string | null;
  province: string | null;
  city: string | null;
  total_reviews: number;
  avg_overall: number | null;
  avatar_path: string | null;
};

const GRUPOS: Record<string, string> = {
  oficios: "Oficios",
  cuidado: "Cuidado de personas",
  seguridad: "Seguridad",
  comida: "Comida y productos caseros",
  profesiones: "Profesiones",
};

export default function BuscarPage() {
  const [categories, setCategories] = useState<Category[]>([]);
  const [categoriesLoading, setCategoriesLoading] = useState(true);
  const [categoriesError, setCategoriesError] = useState<string | null>(null);
  const [group, setGroup] = useState("");
  const [categoryId, setCategoryId] = useState("");
  const [city, setCity] = useState("");
  const [results, setResults] = useState<Resultado[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const availableGroups = Object.entries(GRUPOS).filter(([groupKey]) =>
    categories.some((category) => category.is_active && category.grupo === groupKey)
  );
  const selectedGroup = availableGroups.some(([groupKey]) => groupKey === group)
    ? group
    : "";
  const selectedCategoryId = categories.some(
    (category) =>
      category.is_active &&
      String(category.id) === categoryId &&
      (!selectedGroup || category.grupo === selectedGroup)
  )
    ? categoryId
    : "";

  useEffect(() => {
    let cancelled = false;

    async function loadCategories() {
      const { data, error: categoriesError } = await createClient()
        .from("categories")
        .select("id, name, grupo, is_active")
        .eq("is_active", true)
        .order("name");

      if (cancelled) return;
      if (categoriesError) {
        setCategoriesError("No pudimos cargar los rubros y especialidades.");
      } else {
        setCategories(data ?? []);
      }
      setCategoriesLoading(false);
    }

    void loadCategories();
    return () => {
      cancelled = true;
    };
  }, []);

  useEffect(() => {
    let cancelled = false;

    async function search() {
      setLoading(true);
      setError(null);

      if (categoriesLoading) return;

      let query = createClient()
        .from("professional_search")
        .select(
          "id, headline, is_verified, category_name, full_name, province, city, total_reviews, avg_overall, avatar_path"
        )
        .order("score", { ascending: false })
        .order("total_reviews", { ascending: false })
        .limit(50);

      if (selectedCategoryId) {
        query = query.eq("category_id", Number(selectedCategoryId));
      } else if (selectedGroup) {
        const groupCategoryIds = categories
          .filter((category) => category.grupo === selectedGroup && category.is_active)
          .map((category) => category.id);

        if (groupCategoryIds.length === 0) {
          if (cancelled) return;
          setResults([]);
          setLoading(false);
          return;
        }

        query = query.in("category_id", groupCategoryIds);
      }
      if (city.trim()) query = query.ilike("city", `%${city.trim()}%`);

      const { data, error: searchError } = await query;
      if (cancelled) return;

      if (searchError) {
        setError(searchError.message);
      } else {
        setResults((data ?? []) as unknown as Resultado[]);
      }
      setLoading(false);
    }

    const timer = setTimeout(search, 300);
    return () => {
      cancelled = true;
      clearTimeout(timer);
    };
  }, [selectedCategoryId, categories, categoriesLoading, city, selectedGroup]);

  const inputClass =
    "h-12 rounded-xl border border-[#b9c7c7] bg-white px-4 text-base text-[#14272b] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c]";
  const groupCategories = categories.filter(
    (category) => category.is_active && (!selectedGroup || category.grupo === selectedGroup)
  );
  const specialtyPlaceholder = categoriesLoading
    ? "Cargando especialidades..."
    : categoriesError
      ? "Especialidades no disponibles"
      : groupCategories.length === 0
        ? "No hay especialidades activas"
        : group
          ? "Todas las especialidades del rubro"
          : "Todas las especialidades";

  return (
    <main className="mx-auto flex min-h-screen max-w-md md:max-w-3xl flex-col gap-4 bg-[#f4f6f6] p-6 text-[#14272b]">
      <h1 className="text-3xl font-bold">¿Qué necesitás?</h1>

      <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Rubro
          <select
            aria-label="Rubro"
            className={inputClass}
            value={selectedGroup}
            disabled={categoriesLoading || Boolean(categoriesError)}
            onChange={(event) => {
              setGroup(event.target.value);
              setCategoryId("");
            }}
          >
            <option value="">Todos los rubros</option>
            {availableGroups.map(([value, label]) => (
              <option key={value} value={value}>
                {label}
              </option>
            ))}
          </select>
        </label>

        <label className="flex flex-col gap-1.5 text-sm font-medium">
          Oficio o especialidad
          <select
            aria-label="Oficio o especialidad"
            className={inputClass}
            value={selectedCategoryId}
            disabled={categoriesLoading || Boolean(categoriesError) || groupCategories.length === 0}
            onChange={(event) => setCategoryId(event.target.value)}
          >
            <option value="">{specialtyPlaceholder}</option>
            {groupCategories.map((category) => (
              <option key={category.id} value={category.id}>
                {group
                  ? category.name
                  : `${category.name} (${GRUPOS[category.grupo] ?? category.grupo})`}
              </option>
            ))}
          </select>
        </label>
      </div>

      {categoriesError && (
        <p role="alert" className="text-sm text-red-700">
          {categoriesError}
        </p>
      )}
      {categoriesLoading && (
        <p role="status" className="text-sm text-[#55666a]">
          Cargando rubros y especialidades...
        </p>
      )}
      {!categoriesLoading && !categoriesError && selectedGroup && groupCategories.length === 0 && (
        <p role="status" className="text-sm text-[#55666a]">
          Este rubro todavía no tiene especialidades activas.
        </p>
      )}

      <input
        aria-label="Ciudad"
        className={inputClass}
        placeholder="Ciudad"
        value={city}
        onChange={(e) => setCity(e.target.value)}
      />

      <p className="text-sm text-[#55666a]">Ordenados por mejor calificación</p>

      {error && <p className="text-sm text-red-700">{error}</p>}
      {loading && <p className="text-sm text-[#55666a]">Buscando...</p>}
      {!loading && !error && results.length === 0 && !(selectedGroup && groupCategories.length === 0) && (
        <p className="text-sm text-[#55666a]">
          No encontramos profesionales con esos filtros.
        </p>
      )}

      {results.map((r) => (
        <Link
          key={r.id}
          href={`/profesional/${r.id}`}
          className="flex items-center gap-3 rounded-2xl border border-[#dde4e4] bg-white p-4"
        >
          <Avatar path={r.avatar_path} name={r.full_name ?? ""} size={56} />
          <div className="flex min-w-0 flex-col gap-1">
            <span className="text-lg font-bold">
              {r.full_name ?? "Sin nombre"}
            </span>
            <span className="text-sm text-[#55666a]">
              {r.headline ?? r.category_name}
            </span>
            <span className="text-sm text-[#55666a]">
              {[r.city, r.province].filter(Boolean).join(", ")}
            </span>
            {r.total_reviews > 0 && r.avg_overall !== null && (
              <span className="text-sm">
                <span className="text-[#e9a23b]">★</span>{" "}
                {Number(r.avg_overall).toFixed(1).replace(".", ",")} (
                {r.total_reviews})
              </span>
            )}
            {r.is_verified && (
              <span className="w-fit rounded-lg bg-[#dff0ec] px-2 py-0.5 text-sm font-medium text-[#0b4a4a]">
                Verificado
              </span>
            )}
          </div>
        </Link>
      ))}

      <Link href="/" className="text-sm font-bold text-[#0f5c5c] underline">
        Volver al inicio
      </Link>
    </main>
  );
}
