// Writes the bilingual GoTrue fallback templates (supabase/templates/) from the renderer
// the send-email hook uses, so the two never drift apart. mail_render_test.ts fails when a
// committed template differs from this output. From the repository root:
//
//   deno run --allow-write supabase/functions/_shared/mail_templates_write.ts
import {
  FALLBACK_TEMPLATES,
  type FallbackTemplateKind,
  renderFallbackTemplate,
} from "./mail_render.ts";

for (const [kind, file] of Object.entries(FALLBACK_TEMPLATES)) {
  const target = new URL(`../../templates/${file}`, import.meta.url);
  await Deno.writeTextFile(
    target,
    renderFallbackTemplate(kind as FallbackTemplateKind),
  );
  console.log(`wrote supabase/templates/${file}`);
}
