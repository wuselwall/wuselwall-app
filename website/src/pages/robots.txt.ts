import type { APIRoute } from 'astro';
import { site } from '../config/site';

// /app/ is the Flutter web app (a different program, behind a sign-in): keep it out of search.
export const GET: APIRoute = () =>
  new Response(
    `User-agent: *\nAllow: /\nDisallow: /app/\n\nSitemap: ${site.url}/sitemap-index.xml\n`,
    { headers: { 'content-type': 'text/plain; charset=utf-8' } },
  );
