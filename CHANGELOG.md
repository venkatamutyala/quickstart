# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning
aims for [Semantic Versioning](https://semver.org/), and commits follow
[Conventional Commits](https://www.conventionalcommits.org/). Add your change under
`## [Unreleased]`; maintainers cut a dated, versioned section at release time.

## [Unreleased]


### Added
- **Postgres** backend (`db-postgres`) with a **pgAdmin** GUI and auto-login.
- **Garage** S3-compatible object storage (`s3-garage`) with a **web UI**
  (`s3-garage-ui`) and an idempotent `garage-init` (layout + key + bucket).
- One-command `make up` (waits for health, initializes S3); `make conn` prints per-service
  connection details for both host and in-Docker contexts; `make status` / `make logs`.
- Single `.env` source of truth with **enforced secrets** (`${VAR:?}`); all images pinned
  by `tag@sha256:` digest.
- Dev-tunnel exposure of the GUIs for remote/headless use (`make tunnel`).
- Contributor docs: `CONTRIBUTING.md` (incl. a review checklist), `docs/adding-a-backend.md`,
  this changelog, and agent docs (`AGENTS.md` / `CLAUDE.md`).
- Smoke tests in `tests/` (one `smoke-<service>.sh` per backend) with a `make test` runner.
- CI (`.github/workflows/ci.yml`): enforces Conventional Commits on every PR and runs
  `make test` (boots the stack and verifies Postgres + S3).
- MIT `LICENSE`.
- Automated releases via `release-please` (tags + GitHub Release from Conventional Commits),
  documented in `RELEASING.md`; `make version` surfaces the current tag.
- Self-hosted **Renovate** workflow (`.github/workflows/renovate.yml`, built-in
  `GITHUB_TOKEN`) + `renovate.json`, with a 30-day `minimumReleaseAge` on all updates to
  reduce supply-chain risk.
- A pull-request template tied to the review checklist.
- DCO sign-off enforcement in CI (`DCO` file): every commit needs a human `Signed-off-by`;
  AI is allowed only as a `Co-authored-by`, never the author.
- Documented contribution licensing: inbound = outbound (MIT), no CLA.
- `make env` (eval-able `DATABASE_URL`/`PG*`/`AWS_*` exports) and a Python example app
  (`examples/python/`, run via `make example`).
- pgAdmin `servers.json` and `garage.toml` are now rendered from `.env` (via `.tmpl` files),
  so changing `POSTGRES_USER`/`GARAGE_REGION` no longer drifts — `.env` is truly the source.
- GitHub Actions pinned by commit SHA; CI commit checks now also run on pushes to `main` and
  exempt trusted automation (Renovate/release-please) so their PRs don't fail.
- README: positioning vs LocalStack/Testcontainers/Aspire; trimmed the command list to point
  at `make help`.
- Documented "never commit secrets or generated files" in AGENTS.md and CONTRIBUTING.md.
