import type { APIRoute } from 'astro';
import { site, href } from '../data/site';

export const GET: APIRoute = () =>
  new Response(
    JSON.stringify({
      name: site.name,
      short_name: site.name,
      description: site.description,
      start_url: href('/'),
      display: 'browser',
      background_color: '#0d0d0c',
      theme_color: '#0d0d0c',
      icons: [
        { src: href('/icon-192.png'), sizes: '192x192', type: 'image/png' },
        { src: href('/icon-512.png'), sizes: '512x512', type: 'image/png' },
      ],
    }),
    { headers: { 'Content-Type': 'application/manifest+json; charset=utf-8' } },
  );
