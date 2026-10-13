import type { APIRoute } from 'astro';
import { site } from '../config/site';

// The web app is on its own host (web.wuselwall.app) with its own robots.txt (app/web/).
export const GET: APIRoute = () =>
  new Response(
    `User-agent: *\nAllow: /\n\nSitemap: ${site.url}/sitemap-index.xml\n`,
    { headers: { 'content-type': 'text/plain; charset=utf-8' } },
  );
