# CI / GHCR

`.github/workflows/build.yml` builds and pushes container images to GitHub Container Registry.

## How it works
- **`discover` job:** finds every `services/*/` that has a `Dockerfile` and emits a matrix. The empty
  template (only `services/app/Dockerfile.example`) discovers nothing → the build is a clean no-op.
- **`build` job (matrix):** for each service, `docker/metadata-action` computes tags
  (`type=sha`, branch, and `latest` on the default branch), then `docker/build-push-action` builds with
  GHA layer cache and pushes to `ghcr.io/<owner>/<repo>-<service>`.
- Auth uses the built-in `GITHUB_TOKEN` with `permissions: packages: write`.

## One-time gotcha: package visibility
New GHCR packages default to **private even in a public repo**. After the first push, open the
package settings and flip visibility (and link it to the repo) so others/CI can pull. This is a
manual step the workflow can't do for you.

## Tips
- Pull by immutable SHA tag for reproducible deploys/rollbacks.
- For tighter scope than `GITHUB_TOKEN`, use a fine-grained PAT or OIDC (see `docs/production-hardening.md`).
