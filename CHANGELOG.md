# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versioning
aims for [Semantic Versioning](https://semver.org/), and commits follow
[Conventional Commits](https://www.conventionalcommits.org/). Add your change under
`## [Unreleased]`; maintainers cut a dated, versioned section at release time.

## 1.0.0 (2026-06-06)


### Features

* add initial project setup with PostgreSQL and pgAdmin using Docker Compose ([f9ac0e1](https://github.com/venkatamutyala/quickstart/commit/f9ac0e1b00a70b15f3b88cdeb854b8c0be0fb6eb))
* adding example of flyway usage ([6e54a4f](https://github.com/venkatamutyala/quickstart/commit/6e54a4fcdd252c6c8e9d0c3d3bf1950344d36ff3))
* local FOSS data-backends quickstart (Postgres + Garage S3) ([77d2bbd](https://github.com/venkatamutyala/quickstart/commit/77d2bbd4283872712572a62fa6b5098c31e0a24c))
* local FOSS data-backends quickstart (Postgres + Garage S3) ([261bc5e](https://github.com/venkatamutyala/quickstart/commit/261bc5e61c83f6956f927cebba8350e63d7b1944))
* update PostgreSQL and pgAdmin configurations with new credentials and init scripts ([8211c86](https://github.com/venkatamutyala/quickstart/commit/8211c86ef78590dfeb89e710802878addcbe433c))


### Bug Fixes

* drop inline comment on GARAGE_REGION (trailing-space bug) ([628a8ea](https://github.com/venkatamutyala/quickstart/commit/628a8ead085f2d358d422853c0de57b6ed59f008))

## [Unreleased]


### Added
- **Valkey** cache backend (`cache-valkey`, Redis-compatible) with a **redis-commander**
  web UI (`cache-valkey-ui`) and a `smoke-valkey.sh` set/get round-trip test.
- **RabbitMQ** message broker (`queue-rabbitmq`, AMQP 0-9-1) with the bundled **management
  UI** and a `smoke-rabbitmq.sh` publish/get round-trip test via the management API. Both
  new GUIs are exposed by `make tunnel` and shown in `make conn` / `make info`.
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

### Fixed
- `.env.example`: an inline comment after `GARAGE_REGION` leaked trailing whitespace into the
  value under Make/Compose parsing, corrupting the rendered Garage region and failing CI's
  smoke test. Comments now live on their own lines.
