"use client";

import { useRef, useState } from "react";
import { createClient } from "@/lib/supabase/client";

export type EditableProfessionalReview = {
  id: string;
  overall_rating: number;
  comment: string | null;
  created_at: string;
  edit_count: number;
};

export function StarRatingInput({
  label,
  hint,
  value,
  onChange,
  disabled = false,
}: {
  label: string;
  hint: string;
  value: number;
  onChange: (rating: number) => void;
  disabled?: boolean;
}) {
  return (
    <div className="flex flex-col gap-1">
      <div className="font-bold">{label}</div>
      <div className="text-sm text-[#55666a]">{hint}</div>
      <div role="group" aria-label={label} className="flex gap-1">
        {[1, 2, 3, 4, 5].map((rating) => (
          <button
            type="button"
            key={rating}
            aria-label={`${rating} de 5`}
            aria-pressed={value === rating}
            disabled={disabled}
            onClick={() => onChange(rating)}
            className={`h-11 w-11 text-3xl leading-none focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c] disabled:opacity-60 ${
              value >= rating ? "text-[#e9a23b]" : "text-[#8a9a9c]"
            }`}
          >
            {value >= rating ? "★" : "☆"}
          </button>
        ))}
      </div>
    </div>
  );
}

export default function ProfessionalReviewEditor({
  review,
  onSaved,
  onRefresh,
}: {
  review: EditableProfessionalReview;
  onSaved?: () => void | Promise<void>;
  onRefresh?: () => void | Promise<void>;
}) {
  const [editing, setEditing] = useState(false);
  const [rating, setRating] = useState(review.overall_rating);
  const [comment, setComment] = useState(review.comment ?? "");
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [editBlocked, setEditBlocked] = useState(false);
  const saveLock = useRef(false);
  const normalizedComment = comment.trim();
  const dirty =
    rating !== review.overall_rating ||
    (normalizedComment || null) !== (review.comment || null);
  const editsRemaining = Math.max(0, 3 - review.edit_count);

  function beginEdit() {
    if (review.edit_count >= 3 || editBlocked || saving) return;
    setRating(review.overall_rating);
    setComment(review.comment ?? "");
    setError(null);
    setSuccess(null);
    setEditing(true);
  }

  function cancelEdit() {
    if (saving) return;
    setEditing(false);
    setRating(review.overall_rating);
    setComment(review.comment ?? "");
    setError(null);
  }

  async function refreshAfterRejection() {
    try {
      await onRefresh?.();
    } catch {
      // Keep editing blocked if the parent cannot refresh the review state.
    }
  }

  async function saveEdit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (
      saveLock.current ||
      saving ||
      editBlocked ||
      review.edit_count >= 3 ||
      !editing
    ) {
      return;
    }

    if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
      setError("Elegí una calificación de una a cinco estrellas.");
      return;
    }
    if (Array.from(normalizedComment).length > 500) {
      setError("El comentario no puede superar los 500 caracteres.");
      return;
    }
    if (!dirty) {
      setError("No hay cambios para guardar.");
      return;
    }

    saveLock.current = true;
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      const { error: rpcError } = await createClient().rpc(
        "edit_professional_review",
        {
          p_review_id: review.id,
          p_overall_rating: rating,
          p_comment: normalizedComment || null,
        }
      );

      if (rpcError) {
        if (rpcError.code === "23514") {
          setError("Esta calificación alcanzó el máximo de tres ediciones.");
          setEditing(false);
          setEditBlocked(true);
          await refreshAfterRejection();
        } else if (rpcError.code === "42501") {
          setError("No se pudo editar. La calificación puede no estar disponible para cambios.");
          setEditing(false);
          setEditBlocked(true);
          await refreshAfterRejection();
        } else if (rpcError.code === "28000") {
          setError("Tu sesión venció. Iniciá sesión nuevamente para editar.");
          setEditing(false);
          setEditBlocked(true);
          await refreshAfterRejection();
        } else if (rpcError.code === "22023") {
          setError(rpcError.message);
        } else {
          setError("No pudimos guardar los cambios. Probá nuevamente.");
        }
        return;
      }

      setEditing(false);
      setRating(review.overall_rating);
      setComment(review.comment ?? "");
      setSuccess("Tu calificación se actualizó correctamente.");
      await onSaved?.();
    } catch {
      setError(
        "No pudimos confirmar el cambio. Actualizamos la calificación antes de que vuelvas a intentar."
      );
      setEditing(false);
      setEditBlocked(true);
      await refreshAfterRejection();
    } finally {
      saveLock.current = false;
      setSaving(false);
    }
  }

  return (
    <section className="flex flex-col gap-3" aria-label="Mi calificación">
      <div className="flex flex-wrap items-center gap-2">
        <span
          className="whitespace-nowrap text-[#e9a23b]"
          role="img"
          aria-label={`${review.overall_rating} de 5 estrellas`}
        >
          {"★".repeat(review.overall_rating)}
          {"☆".repeat(5 - review.overall_rating)}
        </span>
        <span className="font-semibold">{review.overall_rating}/5</span>
        <span className="text-sm text-[#55666a]">
          {editsRemaining} {editsRemaining === 1 ? "edición disponible" : "ediciones disponibles"}
        </span>
      </div>
      <p className="text-xs text-[#55666a]">
        Calificación del {new Date(review.created_at).toLocaleDateString("es-AR")}
      </p>
      {review.comment && (
        <p className="whitespace-pre-line break-words text-sm text-[#34494d]">
          “{review.comment}”
        </p>
      )}
      {success && <p role="status" className="text-sm font-medium text-[#0f5c5c]">{success}</p>}
      {review.edit_count >= 3 ? (
        <p role="status" className="text-sm text-[#55666a]">
          Esta calificación ya alcanzó el máximo de tres ediciones.
        </p>
      ) : (
        <>
          {!editing && (
            <button
              type="button"
              onClick={beginEdit}
              disabled={editBlocked || saving}
              className="min-h-11 self-start rounded-xl border border-[#0f5c5c] px-4 font-bold text-[#0f5c5c] focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c] disabled:opacity-60"
            >
              Editar mi calificación
            </button>
          )}
          {editing && (
            <form onSubmit={saveEdit} className="flex flex-col gap-4">
              <StarRatingInput
                label="Calificación general"
                hint="Elegí de una a cinco estrellas."
                value={rating}
                disabled={saving}
                onChange={(value) => {
                  setRating(value);
                  setError(null);
                }}
              />
              <label className="flex w-full flex-col gap-1.5 text-sm font-medium">
                Comentario (opcional)
                <textarea
                  className="min-h-24 w-full rounded-xl border border-[#b9c7c7] bg-white px-4 py-3 text-base focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c]"
                  maxLength={1000}
                  value={comment}
                  onChange={(event) => {
                    const nextComment = event.target.value;
                    if (Array.from(nextComment).length <= 500) {
                      setComment(nextComment);
                      setError(null);
                    }
                  }}
                  aria-describedby={`review-edit-count-${review.id}`}
                  disabled={saving}
                />
                <span
                  id={`review-edit-count-${review.id}`}
                  aria-live="polite"
                  className="text-right text-xs text-[#55666a]"
                >
                  {Array.from(comment).length}/500 caracteres
                </span>
              </label>
              <div className="flex flex-wrap gap-3">
                <button
                  type="submit"
                  disabled={saving || !dirty || rating < 1}
                  className="min-h-12 rounded-2xl bg-[#0f5c5c] px-4 font-bold text-white focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c] disabled:opacity-60"
                >
                  {saving ? "Guardando..." : "Guardar cambios"}
                </button>
                <button
                  type="button"
                  onClick={cancelEdit}
                  disabled={saving}
                  className="min-h-12 rounded-2xl border border-[#b9c7c7] px-4 font-bold focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-[#0f5c5c] disabled:opacity-60"
                >
                  Cancelar
                </button>
              </div>
              {error && <p role="alert" className="text-sm text-red-700">{error}</p>}
            </form>
          )}
        </>
      )}
      {!editing && error && <p role="alert" className="text-sm text-red-700">{error}</p>}
    </section>
  );
}
