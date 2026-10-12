import type { APIRoute } from 'astro';

// Rendered per request (not prerendered): proves the Node server is up. Used by the
// container healthcheck and the uptime monitor.
export const prerender = false;

export const GET: APIRoute = () =>
  new Response('ok', { headers: { 'content-type': 'text/plain', 'cache-control': 'no-store' } });
