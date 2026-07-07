#!/usr/bin/env bash
# publish.sh — regenerate the OpenPolycom apt archive from a pool of .debs.
# Stateless: indexes are rebuilt from pool/ every run (no reprepro db).
#   ./publish.sh <repo-root>     # repo-root contains pool/ ; writes dists/
# Signing: uses the op-archive key from the default gpg keyring
# (CI imports it from the APT_GPG_KEY secret; locally it lives in ~/.gnupg).
set -euo pipefail
ROOT="${1:?usage: publish.sh <repo-root>}"
SUITE=stable COMP=main ARCH=arm64
KEYID="apt@openpolycom.cc"
cd "$ROOT"
[ -d pool ] || { echo "no pool/ under $ROOT" >&2; exit 1; }
BIN="dists/$SUITE/$COMP/binary-$ARCH"
rm -rf dists && mkdir -p "$BIN"
# One Packages index: arm64 + all (arch:all debs serve arm64 clients).
apt-ftparchive packages pool > "$BIN/Packages"
gzip -9kf "$BIN/Packages"
apt-ftparchive \
  -o APT::FTPArchive::Release::Origin=OpenPolycom \
  -o APT::FTPArchive::Release::Label=OpenPolycom \
  -o APT::FTPArchive::Release::Suite=$SUITE \
  -o APT::FTPArchive::Release::Codename=$SUITE \
  -o APT::FTPArchive::Release::Components=$COMP \
  -o APT::FTPArchive::Release::Architectures="$ARCH all" \
  release "dists/$SUITE" > "dists/$SUITE/Release"
gpg --batch --yes -u "$KEYID" -abs -o "dists/$SUITE/Release.gpg" "dists/$SUITE/Release"
gpg --batch --yes -u "$KEYID" --clearsign -o "dists/$SUITE/InRelease" "dists/$SUITE/Release"
echo "published: $(find pool -name '*.deb' | wc -l) debs, suite=$SUITE"
