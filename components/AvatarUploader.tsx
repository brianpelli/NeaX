"use client";

import { useEffect, useState } from "react";
import { createClient } from "@/lib/supabase/client";
import Avatar from "@/components/Avatar";

const LADO = 400;

async function recortarCuadrado(file: File): Promise<Blob> {
  const bitmap = await createImageBitmap(file);
  const lado = Math.min(bitmap.width, bitmap.height);
  const sx = (bitmap.width - lado) / 2;
  const sy = (bitmap.height - lado) / 2;
  const canvas = document.createElement("canvas");
  canvas.width = LADO;
  canvas.height = LADO;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("No se pudo procesar la imagen.");
  ctx.drawImage(bitmap, sx, sy, lado, lado, 0, 0, LADO, LADO);
  bitmap.close();
  return new Promise((resolve, reject) => {
    canvas.toBlob(
      (blob) =>
        blob ? resolve(blob) : reject(new Error("No se pudo procesar la imagen.")),
      "image/jpeg",
      0.85
    );
  });
}

export default function AvatarUploader() {
  const [userId, setUserId] = useState<string | null>(null);
  const [name, setName] = useState("");
  const [path, setPath] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    async function load() {
      const supabase = createClient();
      const { data: userData } = await supabase.auth.getUser();
      const user = userData.user;
      if (!user) return;
      setUserId(user.id);

      const { data } = await supabase
        .from("profiles")
        .select("full_name, avatar_path")
        .eq("id", user.id)
        .maybeSingle();
      setName(data?.full_name ?? "");
      setPath(data?.avatar_path ?? null);
    }
    load();
  }, []);

  async function handleChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = "";
    if (!file || !userId) return;
    if (!file.type.startsWith("image/")) {
      setError("El archivo tiene que ser una imagen.");
      return;
    }

    setError(null);
    setBusy(true);
    const supabase = createClient();
    try {
      const blob = await recortarCuadrado(file);
      const newPath = `${userId}/${crypto.randomUUID()}.jpg`;

      const { error: upError } = await supabase.storage
        .from("avatars")
        .upload(newPath, blob, { contentType: "image/jpeg" });
      if (upError) throw new Error(upError.message);

      const { error: updError } = await supabase
        .from("profiles")
        .update({ avatar_path: newPath })
        .eq("id", userId);
      if (updError) {
        await supabase.storage.from("avatars").remove([newPath]);
        throw new Error(updError.message);
      }

      if (path) await supabase.storage.from("avatars").remove([path]);
      setPath(newPath);
    } catch (err) {
      setError(err instanceof Error ? err.message : "No se pudo subir la foto.");
    }
    setBusy(false);
  }

  return (
    <div className="flex items-center gap-4">
      <Avatar path={path} name={name} size={88} />
      <div className="flex flex-col gap-2">
        <input
          id="avatar"
          type="file"
          accept="image/*"
          className="sr-only"
          onChange={handleChange}
          disabled={busy}
        />
        <label
          htmlFor="avatar"
          className="flex h-11 cursor-pointer items-center justify-center rounded-xl border border-[#0f5c5c] bg-white px-4 font-bold text-[#0f5c5c]"
        >
          {busy ? "Subiendo..." : path ? "Cambiar foto de perfil" : "Subir foto de perfil"}
        </label>
        <p className="text-xs text-[#55666a]">
          Se ve en tu perfil y en las búsquedas.
        </p>
        {error && <p className="text-xs text-red-700">{error}</p>}
      </div>
    </div>
  );
}