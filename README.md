# Poly apt repository

The publication channel for `poly-*` packages (profiles, apps, base plumbing,
and eventually a cortex-a53 Chromium) consumed by the TC8/C60 image builders
and by devices in `tc8-rw` maintenance mode.
Architecture and conventions: `polycom_dev/PROFILES-PLAN.md` in the
workspace (milestone M1).

## Client setup

```sh
apt install poly-archive-keyring   # or copy the key on first bootstrap
echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/poly-archive-keyring.gpg] \
  https://pub-1d222577af244182a265fc4d6a35b994.r2.dev stable main' > /etc/apt/sources.list.d/openpolycom.list
```

Archive signing key: ed25519 `7A27D57B0045457E4C51A11EFAABA6E245033620`
(`apt@openpolycom.cc`). Private key: GitHub Actions secret `APT_GPG_KEY`
on this repo + an offline copy held by Alex. Rotation = new key, new
keyring package revision, re-publish.

## How publishing works (single-writer)

Only this repo's CI writes to the R2 bucket. Package repos
(`packages`, `c60-kodi-portrait`, `chromium-a53`, …) build their debs and
send a `repository_dispatch` (`event_type: publish-packages`) with an
artifact URL; the workflow here downloads the debs into `pool/`, runs
`publish.sh` (stateless apt-ftparchive + GPG), and syncs `pool/` + `dists/`
to R2. Concurrency group = one publish at a time — no index races.

## Local / manual publish

```sh
mkdir -p repo/pool && cp *.deb repo/pool/
./publish.sh repo
# rclone or wrangler r2 object put the repo/ tree
```
