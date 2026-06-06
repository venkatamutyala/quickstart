<!-- Keep PRs focused. Commits must follow Conventional Commits (enforced by CI). -->

## What & why

<!-- Briefly: what does this change and why? -->

## Checklist

- [ ] Commits follow Conventional Commits (`feat:`, `fix:`, `docs:`, …).
- [ ] Commits are signed off by a human (`git commit -s` / DCO); any AI is a `Co-authored-by:`.
- [ ] `CHANGELOG.md` updated under `## [Unreleased]` (or N/A).
- [ ] Verified locally: `make reset && make up`, then `make test` passes and `make status` is healthy.
- [ ] For a new/changed backend: went through the [review checklist](../CONTRIBUTING.md#review-checklist)
      (FOSS digest-pinned image, enforced secrets, healthcheck, `conn.sh` both contexts,
      idempotent init, smoke test added, docs updated).
