# Example app (Python)

A ~30-line demo that connects to **Postgres** and **S3 (Garage)** using standard env vars
(`DATABASE_URL`, `AWS_*`) — the same values `make conn` / `make env` give you. It's a
reference for wiring your own app, and a quick proof the stack works end to end.

## Run it

Easiest (no host deps but Docker):

```bash
make up          # stack running
make example     # runs this in a throwaway python container on the stack's network
```

Or on your host (after `make up`):

```bash
eval "$(make env)"                 # exports DATABASE_URL / PG* / AWS_*
pip install -r examples/python/requirements.txt
python examples/python/main.py
```

It's deliberately one language — a *demo*, not a per-language scaffold. Map the same env
vars to whatever stack you actually build in.
