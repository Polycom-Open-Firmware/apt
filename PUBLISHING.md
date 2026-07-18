# Publishing pipeline

How a Debian package becomes an installable entry in the OpenPolycom apt
archive. This repo is the **single writer** to the archive; nothing else
touches the R2 pool or indexes.

## Architecture

```
┌ packages repo ────────────┐        ┌ apt repo (this repo) ──────────────┐
│ push to main              │        │ publish.yml                        │
│  build.yml:               │        │  1. import GPG signing key         │
│   dpkg-buildpackage every │        │  2. pull current pool/ from R2     │
│   package → out/*.deb      │        │  3. fetch the dispatched debs      │
│   upload artifact "debs"  │        │     (or fold in incoming/*.deb)    │
│   repository_dispatch ────┼──────► │  4. apt-ftparchive + sign          │
│     to apt with run_id     │ event  │     (Packages, Release, InRelease) │
└───────────────────────────┘        │  5. wrangler sync pool/ + dists/   │
                                      │     → R2 bucket openpolycom-apt    │
                                      └────────────────────────────────────┘
                                                     │
                              devices + image builds │ apt update / install
                                                     ▼
                        https://pub-1d222577af244182a265fc4d6a35b994.r2.dev
```

## The three publish paths

All three converge on the same publish job (pull pool → add debs → sign →
sync); they differ only in where the new debs come from.

1. **Automatic (`repository_dispatch`).** A push to `packages` builds every
   deb and sends a dispatch carrying its CI `run_id`. This repo downloads
   that run's `debs` artifact and publishes. No manual step.
2. **Manual (`workflow_dispatch`).** Trigger *Publish apt archive* by hand
   (`gh workflow run publish.yml -R Polycom-Open-Firmware/apt`). Publishes
   the current pool plus anything in `incoming/`. Used when the automatic
   hop is unavailable or to re-sign without new debs.
3. **`incoming/` inbox (credential-free).** Commit built `*.deb` files under
   `incoming/` and push, then trigger the workflow. The publish job folds
   `incoming/*.deb` into the pool alongside what it pulled from R2. This is
   how debs from repos without dispatch wiring (or a local build) reach the
   archive without any GitHub-to-GitHub token.

## Secrets and variables

| Name | Where | Purpose |
|---|---|---|
| `DISPATCH_TOKEN` | `packages` + `apt` | Cross-repo hand-off: `packages` uses it to POST the dispatch; `apt` uses it to download the dispatched run's `debs` artifact. Needs **Contents: write** on `apt` (POST the dispatch) and **Actions: read** on `packages` (download the artifact) — a fine-grained PAT over both repos, or a classic `repo`-scoped token. |
| `APT_GPG_KEY` | `apt` | ASCII-armored private signing key, imported at publish time. |
| `CLOUDFLARE_API_TOKEN` | `apt` | R2 write access for the `wrangler` sync. |
| `CLOUDFLARE_ACCOUNT_ID` | `apt` (variable) | Cloudflare account for `wrangler`. |

Archive signing key: ed25519 `7A27D57B0045457E4C51A11EFAABA6E245033620`
(`OpenPolycom Archive Signing Key <apt@openpolycom.cc>`). The public half
ships in the `poly-archive-keyring` package; the private half is the
`APT_GPG_KEY` secret with an offline copy held by the maintainers. Rotating
it means a new key, a new `poly-archive-keyring` revision, and a re-publish.

## Archive facts

- Bucket: Cloudflare R2 `openpolycom-apt`, public over the `*.r2.dev` URL
  above (no per-request auth for clients).
- Suite `stable`, component `main`, architectures `arm64 all`.
- Layout: `pool/` holds every `.deb`; `dists/stable/` holds the generated,
  signed `Packages`/`Release`/`InRelease`. `publish.sh <repo-root>`
  regenerates `dists/` from `pool/` statelessly (no reprepro database).
- Single-writer invariant: the publish job runs under a concurrency group,
  one publish at a time, so indexes never race. Only this repo holds the R2
  credentials.

## Adding and publishing a package

1. Add the `debian/` tree in the `packages` repo (see that repo's
   `DEVELOPING.md`). Bump `debian/changelog` for every rebuild — apt serves
   the highest version, so a stale version number silently wins.
2. Push to `packages` main. `build.yml` builds it and dispatches here.
3. Confirm the *Publish apt archive* run went green, then verify:
   ```sh
   curl -s https://pub-1d222577af244182a265fc4d6a35b994.r2.dev/dists/stable/main/binary-arm64/Packages \
     | grep -A1 '^Package: <name>'
   ```
4. On a device in maintenance mode (`tc8-rw`): `apt update && apt install <name>`.
