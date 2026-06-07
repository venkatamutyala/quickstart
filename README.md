# quickstart

A FOSS quickstart for standing up the local **data backends** a new app needs — so you
can start building in minutes instead of wiring up infrastructure. One command brings up
each service with a UI and ready-to-paste connection details; point your app at it and go.

- **Postgres** (+ pgAdmin GUI)
- **Garage** — S3-compatible object storage (+ a web UI)
- **Valkey** — Redis-compatible cache/store (+ a redis-commander web UI)
- **RabbitMQ** — AMQP message broker (+ the built-in management UI)
- **Kafka** — event-streaming broker, single-node KRaft (+ the kafbat web UI)
- **OpenSearch** — search / analytics engine (+ OpenSearch Dashboards)
- _more backends planned (pgvector, …)_

> Local development only — not for production.

**How it compares:** *real* services you point an app at — not an AWS-API emulator
(LocalStack), not ephemeral per-test containers (Testcontainers), and not tied to one
language/SDK (.NET Aspire). Deliberately **FOSS and data-backends-only**, not a cloud emulator.

## Quick start

```bash
git clone https://github.com/venkatamutyala/quickstart && cd quickstart
make init    # create .env from .env.example
make up      # start everything, wait until healthy, init the S3 bucket (+ any Kafka topics)
make conn    # print full connection details for every service
```

`make up` prints a summary (example output, with the default `.env`):

```
Postgres  : postgresql://postgres:postgres@localhost:5432/appdb?sslmode=disable
pgAdmin   : http://localhost:8080  (opens straight in — no login, Postgres pre-connected)
S3 (Garage): http://localhost:3900  (region garage, bucket appbucket)
Garage UI : http://localhost:3909  (opens straight in — no login)
Valkey    : redis://default:valkey@localhost:6379/0  (UI http://localhost:8081 — no login)
RabbitMQ  : amqp://rabbit:rabbit@localhost:5672/  (UI http://localhost:15672 — log in: rabbit / rabbit)
Kafka     : localhost:9092  (PLAINTEXT, no auth; UI http://localhost:8082 — no login)
OpenSearch: http://localhost:9200  (no auth; Dashboards http://localhost:5601 — no login)
```

## Connection details

Everything lives in `.env` (the single source of truth — change a value there and
everything follows). `make conn` prints the details broken out per service, with your
live values, so you can map them to whatever language/framework you use:

```bash
make conn                 # all services
make conn ONLY=postgres   # just Postgres
make conn ONLY=s3         # just S3 / Garage
make conn ONLY=valkey     # just Valkey
make conn ONLY=rabbitmq   # just RabbitMQ
make conn ONLY=kafka      # just Kafka
make conn ONLY=opensearch # just OpenSearch
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

**Kafka** — `bootstrap.servers` for both contexts, plus the kafbat web UI. PLAINTEXT, no
auth. It's a **single node**, so:

- **Replication factor is 1** (one broker — RF>1 needs more brokers). Treat replication factor
  and `min.insync.replicas` as *config*, not constants: `1` locally, `3`+ in prod. Everything
  else — multiple topics, partitions, consumer groups, and transactions / exactly-once — works
  exactly as on a real cluster (the internal topics are configured RF=1 so EOS starts cleanly).
- **Topics** auto-create on first use (broker `auto.create.topics.enable=true`), so producing to
  a new topic name brings it into being at RF=1. Apps can also declare topics explicitly via the
  AdminClient. To *guarantee* specific topics exist up front, list them in `KAFKA_TOPICS` (in
  `.env`) and they're pre-created on every `make up`, idempotently (existing topics untouched);
  it's empty by default.

**OpenSearch** — REST endpoint for both contexts, plus OpenSearch Dashboards. The security
plugin is **disabled** (plain `http://`, no auth) for local dev — don't send credentials or
use `https`. Use an **OpenSearch** client (opensearch-py/-js/-java/-go), not the Elasticsearch
8+ client (it refuses to talk to an OpenSearch server). The cluster is `green` on boot (system
indices use 0 replicas); it turns `yellow` once you create an index with the default 1 replica
(which can't be assigned on a single node) — set `number_of_replicas: 0` to keep it `green`.

`make conn` prints **two fully-assembled forms** for every service:

- **From your host** — app runs on your machine: host `localhost`, the published port.
- **From inside Docker** — app runs as a container on the compose network (named after the
  directory, e.g. `quickstart_default`): the service name and internal port
  (`db-postgres:5432`, `http://s3-garage:3900`).

So whether you run your app on the host or dockerize it, copy the matching block. To use the
in-Docker form, put your app container on that network (`make conn` prints its exact name for
your checkout), or add your app as a service in `docker-compose.yaml`.

**Wire it up fast:** `eval "$(make env)"` exports `DATABASE_URL` / `PG*` / `AWS_*` into your
shell so your app picks them up against the running stack.

## Debugging from the CLI

Want to poke a backend with its native CLI without installing anything on your host?
`make debug` drops you into an on-demand container that's joined to the compose network with
every backend's CLI preloaded **and pre-wired** to the stack — so they connect with no
flags:

```bash
make up         # start the stack first
make debug      # interactive shell; type `help` for a copy-paste cheatsheet
```

Inside the box: `psql` / `pg_dump` (Postgres), `aws` + `mc` (S3/Garage), `redis-cli`
(Valkey), `kcat` + the official `kafka-*.sh` tools (Kafka), `amqp-tools` + `curl` (RabbitMQ),
`curl` + `jq` (OpenSearch), plus `dig`/`nc` for network checks. The connection details come
from `.env` and the in-Docker hostnames at runtime — nothing is baked into the image.

```bash
make debug                      # interactive shell
make debug CMD='aws s3 ls'      # run one command and exit
make debug CMD='psql -c "\l"'   # one-off query
make debug-build                # rebuild the image after editing debug/Dockerfile
```

It's ephemeral (removed on exit) and **not** part of `make up` — it won't show in
`make status`. The image is built locally (the stack's only built image); first launch
builds it (it's large — bundles a JRE for the Kafka tools).

## Hand the running stack to an AI assistant

Bringing this stack up, then handing it to a separate AI coding session (e.g. another
Claude Code session working on your app) to build or debug against? `make ai` prints a
compact, **paste-into-a-prompt** briefing: a menu of every backend with its live up/down
status, host **and** in-Docker connection strings, a one-line debug command, and the
guardrails (it's a disposable local stack — use, write, and reset freely; never treat it as
production). It's generated from `.env`, so it always matches your live values.

```bash
make ai      # print the handoff + write it to AI-HANDOFF-PROMPT.md (gitignored)
```

Hand it off by either appending the text to your prompt, attaching the generated
`AI-HANDOFF-PROMPT.md`, or just telling the other session: *"the data stack lives at
`<this dir>` and is running — run `make ai` there."* The briefing points the assistant at
`make debug CMD='…'` for poking the backends, so it needs no host CLIs of its own.

## Remote / headless: expose the GUIs with a dev tunnel

Running this on a remote or headless box and want to reach the GUIs from your laptop's
browser? The bundled [Dev Tunnels](https://aka.ms/devtunnels/docs) integration exposes the
**GUIs** (pgAdmin, Garage UI, Valkey UI, RabbitMQ management UI, Kafka UI, OpenSearch
Dashboards) over public HTTPS URLs (the database/S3/cache/broker/stream/search data ports
are **not** exposed):

```bash
make tunnel-login   # one-time: GitHub login (device-code flow, works headless)
make tunnel         # host the GUIs; opens https://*.devtunnels.ms URLs (Ctrl-C to stop)
```

- Access requires authentication by default (GitHub login on the tunnel). Add `ANON=1`
  (`make tunnel ANON=1`) to drop that and allow anyone with the URL. Be careful: most bundled
  GUIs have **no login of their own** — pgAdmin opens straight into a pre-connected Postgres,
  and the Garage, Valkey, Kafka, and OpenSearch UIs open straight in too — so `ANON=1` exposes
  them fully to anyone with the URL. Only RabbitMQ prompts for credentials. Keep tunnels
  authenticated unless you mean to share them.
- `./scripts/tunnel.sh <port> [<port>...]` tunnels specific ports, so any GUI added later
  exposes the same way.
- Needs the `devtunnel` CLI; `make tunnel` prints install instructions if it's missing.

## Commands

**`make help`** lists every target (always current — it's generated from the Makefile). The
ones you'll use most:

```
make init   make up   make conn   make env
make info   make status   make logs   make down   make reset
make debug  (shell with all backend CLIs preloaded)
make ai     (handoff briefing for a separate AI session)
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

Want to add another backend (pgvector, …)? There's one repeatable pattern —
see **[docs/adding-a-backend.md](docs/adding-a-backend.md)**. For workflow, commit
conventions (Conventional Commits), and the changelog process, see
**[CONTRIBUTING.md](CONTRIBUTING.md)**; for versioning/tags, **[RELEASING.md](RELEASING.md)**.
AI agents: start at **[AGENTS.md](AGENTS.md)**.

CI runs on every PR — it lints commit messages and runs a smoke test that boots the whole
stack and runs every `tests/smoke-*.sh` round-trip (one per bundled backend).

## Notes

- All credentials in `.env.example` are throwaway local-dev defaults — change them for
  anything real. They're committed for convenience; your working `.env` is gitignored.
- Secrets are **enforced**: Compose uses `${VAR:?...}` for passwords/tokens/keys, so the
  stack refuses to start (with a clear message) if a secret is missing or empty — no
  silent fallback to a guessable default. `make init` writes them all from `.env.example`.
- Postgres only honors `POSTGRES_*` when its data volume is empty. To change DB
  credentials after first boot: `make reset` (destroys data), edit `.env`, then `make up`.
- Garage is initialized automatically on `make up` (idempotent): it applies a single-node
  layout, imports the S3 key from `.env`, and creates the bucket.
- Kafka auto-creates topics on first use (RF=1); to guarantee specific topics, list them in
  `KAFKA_TOPICS` and they're pre-created on `make up` (idempotent, RF=1). It's empty by default.
- OpenSearch runs in single-node discovery mode, which skips the production bootstrap checks —
  so no host `vm.max_map_count` sysctl tuning is needed (unlike a multi-node cluster).
- Data lives in named Docker volumes (`pgdata`, `garagemeta`, `garagedata`, `valkeydata`,
  `rabbitmqdata`, `kafkadata`, `opensearchdata`); it survives `make down` but `make reset`
  wipes all of them.

## License

[MIT](LICENSE) © Venkata Mutyala. Referenced images keep their own upstream licenses (e.g.
**Garage is AGPL-3.0**); they're pulled at runtime, not redistributed here, so this repo's
own files stay MIT.
