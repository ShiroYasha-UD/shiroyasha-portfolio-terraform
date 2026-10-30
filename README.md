# David Bali's portfolio

A static portfolio built with Astro. The stack diagram is a small React island; the rest of the site is rendered as HTML at build time. The SSO case study lives in `src/pages/work/sso-and-permissions.md` and can be edited as Markdown.

## Local development

Requires Node.js 22.22.0 or later.

```sh
npm install
npm run dev
```

Build and preview the production site:

```sh
npm run build
npm run preview
```

The generated static files are in `dist/`. Serve that directory with Caddy on EC2 or upload its contents to static hosting. For example, a Caddy site block can use `root * /path/to/dist` and `file_server`.

## Content

- Home page and project links: `src/pages/index.astro`
- Case study: `src/pages/work/sso-and-permissions.md`
- Stack diagram content: `src/components/StackDiagram.tsx`
- Shared styling: `src/styles/global.css`

Set the `contact` object near the top of `src/pages/index.astro` to add your email. The displayed address can be copied even before the contact form recipient is configured. The GitHub, LinkedIn and Discord links can also be edited on that page. The Copy button uses the browser Clipboard API, which requires HTTPS or localhost.

## Contact API

The contact form sends JSON to `/api/contact`. Run the supplied Express service separately from Astro:

```sh
AWS_REGION=eu-central-1 CONTACT_FROM=contact@your-verified-domain.example CONTACT_TO=you@example.com npm run contact-api
```

Set `CONTACT_FROM` to an SES-verified sender and `CONTACT_TO` to your real inbox. The values in `src/backend/server.js` are examples, so override both for deployment. Set the AWS region to the one containing your SES identity, and provide SES sending permission through the EC2 instance role (or a local AWS profile). SES sandbox accounts also require a verified recipient. Do not put AWS credentials in the repository.

For local development, run `npm run dev` in another terminal; Astro proxies `/api/contact` to the API at `127.0.0.1:3001`. The API must remain running separately. Production builds are still static; Caddy serves `dist/` and proxies the contact endpoint to the Node process:

```caddyfile
example.com {
    handle /api/contact {
        reverse_proxy 127.0.0.1:3001
    }
    handle {
        root * /path/to/dist
        file_server
    }
}
```

Replace the domain and path, and run the API as a service with the environment settings above. A static-only host such as S3 cannot run this Node service by itself; it needs an API backend at the same `/api/contact` URL. The form includes a hidden honeypot and displays the API's errors. The rate limits in the supplied service are in-memory and apply per process, resetting on restart.
