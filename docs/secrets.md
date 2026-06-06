# Secrets & config

Three layers:

1. **`.env.example`** (committed) — documents every variable. Values that should be random are `__GEN__`.
2. **`.env`** (gitignored) — the real values. `make init` creates it: copies `.env.example`, replaces
   each `__GEN__` with `openssl rand -hex 16`, and writes `pgadmin/pgpass` (mode 600) from the same
   values so Postgres, pgAdmin, and your app all agree. `make init` is **idempotent** — it never
   clobbers an existing `.env`.
3. **Deployed** secrets come from **GitHub Actions / Environment secrets**, injected at deploy time —
   never committed, never baked into an image.

Notes:
- Keep comments on their own lines in `.env` (some tools fold a trailing `# ...` into the value).
- The SSH key for `make expose` is **not** a variable — it comes from your `ssh-agent`, forwarded
  into the `autossh` container. `.gitignore` also blocks `id_*`, `*.pem`, `*.key`, `acme.json`.
- To rotate local secrets: `rm .env && make init` (throwaway dev creds).
