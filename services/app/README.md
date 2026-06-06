# services/app — empty by design

This is the placeholder for your service. The stack is **language-agnostic**, so nothing
ships here by default. To fill it with a working service in one step:

```bash
make add-service LANG=python NAME=app   # or LANG=node / LANG=go
```

That copies a runnable hello-world from `recipes/<lang>/` into this directory. Then, in
`compose.yaml`, uncomment the `app:` block (it mirrors `recipes/<lang>/service.snippet.yml`)
and run `make up`.

See the repo root `AGENTS.md` → "Add a Service" for the full checklist.
