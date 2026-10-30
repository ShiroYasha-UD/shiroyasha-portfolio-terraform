import { defineConfig } from 'astro/config';
import react from '@astrojs/react';

const contactProxy = { '/api/contact': { target: 'http://127.0.0.1:3001' } };

export default defineConfig({
  site: 'https://shiroyasha.dev',
  integrations: [react()],
  output: 'static',
  vite: { server: { proxy: contactProxy }, preview: { proxy: contactProxy } },
});
