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

## Publishing

This repo is the single writer to the R2 bucket: the `packages` repo builds
its debs and hands them off, and the publish job here regenerates and signs
the indexes. The full pipeline — the three publish paths, the secret matrix,
and how to add a package — is in **[PUBLISHING.md](PUBLISHING.md)**.

Local one-off publish (regenerate indexes over a pool by hand):

```sh
mkdir -p repo/pool && cp *.deb repo/pool/
./publish.sh repo
# then wrangler r2 object put the repo/ tree (maintainers only)
```
