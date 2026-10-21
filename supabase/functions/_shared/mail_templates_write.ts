// Writes single-language GoTrue fallback templates (supabase/templates/) from the renderer
// the send-email hook uses, so the two never drift apart. mail_render_test.ts fails when a
// committed template differs from this output. From the repository root:
//
//   deno run --allow-write supabase/functions/_shared/mail_templates_write.ts
import {
  FALLBACK_TEMPLATES,
  type FallbackTemplateKind,
  MAIL_LOCALES,
  renderFallbackTemplate,
} from "./mail_render.ts";

// Root files preserve the German default for existing config.toml installations.
for (const prefix of ["", ...MAIL_LOCALES] as const) {
  const directory = new URL(
    `../../templates/${prefix ? `${prefix}/` : ""}`,
    import.meta.url,
  );
  await Deno.mkdir(directory, { recursive: true });
  for (const [kind, file] of Object.entries(FALLBACK_TEMPLATES)) {
    await Deno.writeTextFile(
      new URL(file, directory),
      renderFallbackTemplate(kind as FallbackTemplateKind, prefix || "de"),
    );
    console.log(
      `wrote supabase/templates/${prefix ? `${prefix}/` : ""}${file}`,
    );
  }
}
