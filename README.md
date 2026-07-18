# Poly apt repository

The publication channel for `poly-*` packages (profiles, apps, base
plumbing) consumed by the TC8/C60 image builders and by devices in
`tc8-rw` maintenance mode.

## Client setup

```sh
apt install poly-archive-keyring   # or copy the key on first bootstrap
echo 'deb [arch=arm64 signed-by=/usr/share/keyrings/poly-archive-keyring.gpg] \
  https://pub-1d222577af244182a265fc4d6a35b994.r2.dev stable main' > /etc/apt/sources.list.d/poly.list
```

Archive signing key: ed25519 `7A27D57B0045457E4C51A11EFAABA6E245033620`
(`apt@openpolycom.cc`). Private key: GitHub Actions secret `APT_GPG_KEY`
on this repo + an offline copy held by the maintainers. Rotation = new key, new
keyring package revision, re-publish.

## How publishing works (single-writer)

Only this repo's CI writes to the R2 bucket. The `packages` repo builds
its debs and sends a `repository_dispatch` (`event_type:
publish-packages`) whose payload carries the sender's CI `run_id` (and
repo); the workflow here downloads that run's `debs` artifact into
`pool/`, runs `publish.sh` (stateless apt-ftparchive + GPG), and syncs
`pool/` + `dists/` to R2. Concurrency group = one publish at a time —
no index races.

## Local / manual publish

```sh
mkdir -p repo/pool && cp *.deb repo/pool/
./publish.sh repo
# rclone or wrangler r2 object put the repo/ tree
```

## Manual publish without DISPATCH_TOKEN

Commit debs under `incoming/` and run the workflow (`gh workflow run` or the
Actions UI). The publish job folds `incoming/*.deb` into the pool alongside
whatever is already in R2. Remove them from `incoming/` after they land
(they persist in the R2 pool).
