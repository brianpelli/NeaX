export default function Avatar({
  path,
  name,
  size = 56,
}: {
  path: string | null;
  name: string;
  size?: number;
}) {
  const initials =
    name
      .split(" ")
      .filter(Boolean)
      .map((p) => p[0])
      .slice(0, 2)
      .join("")
      .toUpperCase() || "?";

  if (path) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={`${process.env.NEXT_PUBLIC_SUPABASE_URL}/storage/v1/object/public/avatars/${path}`}
        alt={name}
        style={{ width: size, height: size }}
        className="shrink-0 rounded-full object-cover"
      />
    );
  }

  return (
    <div
      style={{ width: size, height: size, fontSize: size * 0.36 }}
      className="flex shrink-0 items-center justify-center rounded-full bg-[#d5e8e6] font-bold text-[#0b4a4a]"
    >
      {initials}
    </div>
  );
}