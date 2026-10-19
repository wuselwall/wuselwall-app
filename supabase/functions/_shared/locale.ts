// Shared language negotiation for non-mail, family-facing server output.
export type Lang = "de" | "en" | "fr" | "es";

/** Explicit language, then the highest-quality supported header language, then the household.
 * Regional tags use their primary language; unsupported input falls back to German (NFR-14).
 */
export function pickLang(
  param: unknown,
  acceptLanguage: string | null,
  householdLocale: string | null,
): Lang {
  const of = (tag: string): Lang | null => {
    const primary = tag.trim().toLowerCase().split(/[-_;]/)[0];
    return primary === "de" || primary === "en" || primary === "fr" ||
        primary === "es"
      ? primary
      : null;
  };
  if (typeof param === "string" && of(param)) return of(param)!;
  // Highest quality first; stable sorting preserves header order for ties. Ignore q=0.
  const preferences = (acceptLanguage ?? "").split(",").map((part) => {
    const [tag, ...parameters] = part.split(";");
    const q = parameters.find((p) => /^\s*q\s*=/i.test(p));
    const value = q?.split("=")[1].trim();
    const quality = value === undefined
      ? 1
      : /^(?:0(?:\.\d{0,3})?|1(?:\.0{0,3})?)$/.test(value)
      ? Number(value)
      : 0;
    return { lang: of(tag), quality };
  }).filter((p) => p.lang !== null && p.quality > 0).sort((a, b) =>
    b.quality - a.quality
  );
  if (preferences.length > 0) return preferences[0].lang!;
  return (householdLocale && of(householdLocale)) || "de";
}
