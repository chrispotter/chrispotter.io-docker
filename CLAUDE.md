# chrispotter.io-docker

Deployment for the droplet: compose files per app behind a shared proxy.

## Shared plan

The board-game stack's deployment, auth and roles are planned in a living doc
shared by all three repos. Read it with the Docs tools (never web-fetch it):

https://claude.ai/code/artifact/8ba61ddf-091a-43b7-b70f-305d5da1baf9

## Things that are not obvious from the code

- **Nothing is built on the droplet.** It has neither the CPU nor the memory.
  Images are built in each source repo's Actions, pushed to GHCR, and pulled
  here. This repo only composes and routes.
- **Memory is budgeted, not incidental.** Every container carries a
  `mem_limit` — splash 32m, ludoteca 32m, nginx-proxy 96m, acme-companion
  64m, dex 192m, postgres 256m, api 96m, mcp 96m, migrate 64m. That is roughly
  930 MB of caps on a 1 GB box, deliberately over-subscribed: they are caps, not
  reservations, and provision.sh lays down 2 GB of swap. New services are
  chosen to fit: it is why the identity provider is Dex (~30 MB resident) and
  not Keycloak (~700 MB+).
- **The proxy routes by hostname, and only by hostname.** `nginx-proxy` reads
  `VIRTUAL_HOST` off each container. An earlier plan split one hostname by
  path with `VIRTUAL_PATH`; board-game-api#17 replaced it with one hostname
  per service, so `VIRTUAL_PATH` is not used anywhere here and the UI and API
  are different origins — which is what makes CORS load-bearing on the API.
- **Each source repo owns one deployment unit.** board-game-api produces two
  images, board-game-ui one. Layout:
  `apps/boardgames/` (postgres, migrate, api, mcp — 2 GHCR images, deployed),
  `apps/ludoteca/` (the UI — 1 GHCR image, deployed), `auth/` (Dex, upstream
  image, deployed).
- **Hostnames, one per service**: `boardgames.chrispotter.io` (UI),
  `boardgames-api.chrispotter.io` (API), `auth.chrispotter.io` (Dex),
  `boardgames-mcp.chrispotter.io` (MCP). All one label deep, so Cloudflare's
  free Universal SSL covers them. All DNS-only, not proxied: the MCP transport
  streams and Cloudflare's proxy buffers responses and caps an origin response
  at 100s.
- **Dex needs `web.allowedOrigins`, or no browser can sign in.** The UI reads
  the discovery document and then `/token` with `fetch`, from a different
  origin, so without that key the browser discards both responses and the app
  reports `Failed to fetch` before Dex is ever reached — which reads as Dex
  being down rather than a header being absent. The redirect legs need
  nothing: a browser navigating to `/auth` is not a fetch. The trap is that
  curl has no origin policy, so the whole flow can verify green from the
  command line and be broken in every browser; this cost a deploy to find.

- **Membership of the `chrispotter-sso` GitHub org is the login, for every
  service.** Dex's `orgs` check sits on the connector, not on a client, so it
  gates `boardgames-ui`, `boardgames-mcp-cli`, `claude-ai` and anything added
  later, with no per-client equivalent. That org exists only to be that gate:
  no repositories, one member, named for the identity service rather than for
  an app. Adding somebody to it grants them a login everywhere behind
  `auth.chrispotter.io` — and renaming it breaks sign-in until `auth/config.yaml`
  is changed too, because `GET /orgs/<old>/members` 404s where a browser would
  have been redirected.

- **A bind-mounted config is invisible to Compose.** Editing `auth/config.yaml`
  leaves the container spec identical, so `up -d` does nothing and Dex goes on
  serving what it read at startup — a deploy that reports success and changed
  nothing. `DEX_CONFIG_SHA` hashes the file into the container's environment so
  Compose recreates it when the config actually changed. Any future
  bind-mounted config read once at startup needs the same treatment.

## Agent skills

### Issue tracker

Issues live in GitHub Issues on chrispotter/chrispotter.io-docker, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily. See `docs/agents/domain.md`.
