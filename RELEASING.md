# Releasing

Versioning and releases are automated with
[release-please](https://github.com/googleapis/release-please), driven by the
[Conventional Commits](https://www.conventionalcommits.org/) this repo enforces.

## What a version means

There's no public API here, so SemVer maps to the stack / developer experience:

- **MAJOR** — breaking change to how you use it (a service removed or renamed, incompatible
  `.env`/config, changed commands).
- **MINOR** — a new backend or feature (`feat:` commits).
- **PATCH** — fixes, image/digest bumps, docs (`fix:` / `chore:` commits).

A release is a **tested, known-good set of pinned images + config** — clone the tag and it
works.

## Cutting a release

1. Merge PRs to `main` as usual (Conventional Commits, CI green).
2. release-please keeps a **`chore(main): release X.Y.Z`** PR open, updating `CHANGELOG.md`
   and the version from your commit history.
3. **Merge that release PR.** release-please then tags `vX.Y.Z`, finalizes the changelog,
   and publishes the GitHub Release.

> Note: PRs opened by the default `GITHUB_TOKEN` don't re-trigger CI. The release PR only
> reorganizes the changelog/version (the commits were already CI'd), so that's fine. If you
> want CI to run on the release PR too, add a PAT secret and pass it to the action's `token`.

## Keeping releases current (Renovate)

[Renovate](https://docs.renovatebot.com/) runs **self-hosted in GitHub Actions**
(`.github/workflows/renovate.yml`) on a weekly schedule and on demand (workflow_dispatch),
using the built-in `GITHUB_TOKEN` — no external App or PAT to install. Config is
`renovate.json`. It opens PRs that bump the pinned image digests; merging them flows into the
next PATCH release.

For supply-chain safety, **every update waits `minimumReleaseAge: "30 days"`** (with
`internalChecksFilter: "strict"`) — Renovate won't open a PR until a release is 30 days old,
giving researchers/tools time to catch a malicious release.

Two `GITHUB_TOKEN` caveats (by design, since we avoid a PAT):

- PRs it opens won't auto-trigger CI (GITHUB_TOKEN-created PRs don't). Push to the branch to
  run CI, or wire a PAT/App if you want it automatic.
- It can't modify workflow files, so GitHub Actions version bumps aren't proposed. Bump those
  manually, or use a PAT/App with `workflow` scope.

## Version at a glance

`make version` prints the current release (`git describe --tags`); it's also shown by
`make info`.
