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
  `mem_limit` — splash 32m, nginx-proxy 96m, acme-companion 64m — so the whole
  site runs in roughly 192 MB. New services are chosen to fit that: it is why
  the planned identity provider is Dex (~30 MB) and not Keycloak (~700 MB+).
- **The proxy routes by hostname.** `nginx-proxy` reads `VIRTUAL_HOST` off each
  container. Splitting one hostname by path needs `VIRTUAL_PATH`, which this
  stack has not used yet and which the board-game deployment depends on.
- **Each source repo owns one deployment unit.** board-game-api produces two
  images, board-game-ui one. Planned layout:
  `apps/board-games/` (postgres, migrate, api, mcp — 2 GHCR images),
  `apps/ludoteca/` (the UI — 1 image), `apps/auth/` (Dex, upstream image).
- **Hostnames**: `boardgames.chrispotter.io` (UI at `/`, API at `/api`),
  `auth.chrispotter.io` (Dex), `boardgames-mcp.chrispotter.io` (already live).

## Agent skills

### Issue tracker

Issues live in GitHub Issues on chrispotter/chrispotter.io-docker, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Default vocabulary: needs-triage, needs-info, ready-for-agent, ready-for-human, wontfix. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: `GLOSSARY.md` and `docs/adr/` at the repo root, created lazily. See `docs/agents/domain.md`.
