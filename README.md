# quickstart

A FOSS quickstart for standing up the local **data backends** a new app needs — so you
can start building in minutes instead of wiring up infrastructure. One command brings up
each service with a UI and ready-to-paste connection details; point your app at it and go.

- **Postgres** (+ pgAdmin GUI)
- **Garage** — S3-compatible object storage (+ a web UI)
- **Valkey** — Redis-compatible cache/store (+ a redis-commander web UI)
- **RabbitMQ** — AMQP message broker (+ the built-in management UI)
- _more backends planned (Kafka, OpenSearch, pgvector, …)_

> Local development only — not for production.

**How it compares:** *real* services you point an app at — not an AWS-API emulator
(LocalStack), not ephemeral per-test containers (Testcontainers), and not tied to one
language/SDK (.NET Aspire). Deliberately **FOSS and data-backends-only**, not a cloud emulator.

## Quick start

```bash
git clone https://github.com/venkatamutyala/quickstart && cd quickstart
make init    # create .env from .env.example
make up      # start everything, wait until healthy, init the S3 bucket
make conn    # print full connection details for every service
```

`make up` prints a summary (example output, with the default `.env`):

```
Postgres  : postgresql://postgres:postgres@localhost:5432/appdb?sslmode=disable
pgAdmin   : http://localhost:8080  (admin@example.com / admin)
S3 (Garage): http://localhost:3900  (region garage, bucket appbucket)
Garage UI : http://localhost:3909
Valkey    : redis://default:valkey@localhost:6379/0  (UI http://localhost:8081)
RabbitMQ  : amqp://rabbit:rabbit@localhost:5672/  (UI http://localhost:15672)
```

## Connection details

Everything lives in `.env` (the single source of truth — change a value there and
everything follows). `make conn` prints the details broken out per service, with your
live values, so you can map them to whatever language/framework you use:

```bash
make conn               # all services
make conn ONLY=postgres # just Postgres
make conn ONLY=s3       # just S3 / Garage
make conn ONLY=valkey   # just Valkey
make conn ONLY=rabbitmq # just RabbitMQ
```

**Postgres** — host, port, db, user, password, SSL mode, plus assembled libpq URL,
key=value DSN, JDBC URL, and the standard `PG*` env vars.

**S3 / Garage** — endpoint URL, region, access key ID, secret, bucket, the AWS-style
env vars, and an `aws` CLI example. Note two things:

- **Path-style addressing is required** (set "force path style" / disable virtual-host
  addressing in your S3 client).
- `sslmode=disable` for Postgres and plain `http://` for S3 are intentional — these are
  local, TLS-free services.

**Valkey** — host, port, password, and an assembled `redis://default:…` URL (Valkey speaks
the Redis protocol, so any `redis://` client works). The default DB index is `0`; auth is the
password only (user `default`). Plain connection — use `redis://`, not `rediss://`.

**RabbitMQ** — user, password, the default vhost `/`, and an assembled `amqp://` URL
(AMQP 0-9-1). The bundled management UI doubles as an HTTP API on the same port under `/api`.

`make conn` prints **two fully-assembled forms** for every service:

- **From your host** — app runs on your machine: host `localhost`, the published port.
- **From inside Docker** — app runs as a container on the compose network (named after the
  directory, e.g. `quickstart_default`): the service name and internal port
  (`db-postgres:5432`, `http://s3-garage:3900`).

So whether you run your app on the host or dockerize it, copy the matching block. To use the
in-Docker form, put your app container on that network (`make conn` prints its exact name for
your checkout), or add your app as a service in `docker-compose.yaml`.

**Wire it up fast:** `eval "$(make env)"` exports `DATABASE_URL` / `PG*` / `AWS_*` into your
shell, and `make example` runs a tiny Python app (`examples/python/`) that connects to
Postgres + S3 against the running stack — a copy-me starting point.

## Remote / headless: expose the GUIs with a dev tunnel

Running this on a remote or headless box and want to reach the GUIs from your laptop's
browser? The bundled [Dev Tunnels](https://aka.ms/devtunnels/docs) integration exposes the
**GUIs** (pgAdmin, Garage UI, Valkey UI, RabbitMQ management UI) over public HTTPS URLs (the
database/S3/cache/broker data ports are **not** exposed):

```bash
make tunnel-login   # one-time: GitHub login (device-code flow, works headless)
make tunnel         # host the GUIs; opens https://*.devtunnels.ms URLs (Ctrl-C to stop)
```

- Access requires authentication by default. Add `ANON=1` (`make tunnel ANON=1`) to allow
  anyone with the URL — convenient, but each GUI's own login is then your only gate.
- `./scripts/tunnel.sh <port> [<port>...]` tunnels specific ports, so any GUI added later
  exposes the same way.
- Needs the `devtunnel` CLI; `make tunnel` prints install instructions if it's missing.

## Commands

**`make help`** lists every target (always current — it's generated from the Makefile). The
ones you'll use most:

```
make init   make up   make conn   make env   make example
make test   make status   make logs   make psql   make down   make reset
```

## Schema & migrations

This stack just gives you a database — managing schema is your app's job. Point your
ORM / migration tool (Alembic, Prisma, Drizzle, golang-migrate, …) at the connection
string from `make conn`.

If you want first-boot SQL (e.g. `CREATE EXTENSION`), add your own `.sql` to the
`db-postgres` service — anything under `/docker-entrypoint-initdb.d` runs once, when the
data volume is first created:

```yaml
# docker-compose.yaml, under services: db-postgres: volumes:
      - ./my-init.sql:/docker-entrypoint-initdb.d/my-init.sql:ro
```

## Contributing & extending

Want to add another backend (Kafka, OpenSearch, pgvector, …)? There's one repeatable pattern —
see **[docs/adding-a-backend.md](docs/adding-a-backend.md)**. For workflow, commit
conventions (Conventional Commits), and the changelog process, see
**[CONTRIBUTING.md](CONTRIBUTING.md)**; for versioning/tags, **[RELEASING.md](RELEASING.md)**.
AI agents: start at **[AGENTS.md](AGENTS.md)**.

CI runs on every PR — it lints commit messages and runs a smoke test that boots the whole
stack and verifies Postgres + S3.

## Notes

- All credentials in `.env.example` are throwaway local-dev defaults — change them for
  anything real. They're committed for convenience; your working `.env` is gitignored.
- Secrets are **enforced**: Compose uses `${VAR:?...}` for passwords/tokens/keys, so the
  stack refuses to start (with a clear message) if a secret is missing or empty — no
  silent fallback to a guessable default. `make init` writes them all from `.env.example`.
- Postgres only honors `POSTGRES_*` when its data volume is empty. To change DB
  credentials after first boot: `make reset` (destroys data), edit `.env`, then `make up`.
- Garage is initialized automatically on `make up` (`make garage-init` is idempotent): it
  applies a single-node layout, imports the S3 key from `.env`, and creates the bucket.
- Data lives in named Docker volumes (`pgdata`, `garagemeta`, `garagedata`); it survives
  `make down` but `make reset` wipes all of them.

## License

[MIT](LICENSE) © Venkata Mutyala. Referenced images keep their own upstream licenses (e.g.
**Garage is AGPL-3.0**); they're pulled at runtime, not redistributed here, so this repo's
own files stay MIT.
