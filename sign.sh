#!/bin/bash
# Signe les RPM et le SRPM de out/ avec la cle GPG de publication, dans le conteneur
# CentOS 7 (rpmsign d'EL7 : signature lisible par le rpm 4.11 des serveurs cibles),
# puis verifie chaque signature et regenere out/SHA256SUMS.
#
# Usage : SIGN_KEY_FILE=/chemin/cle-privee.asc ./sign.sh
#   La cle privee (armure ASCII, sans phrase secrete) n'est jamais copiee dans le depot :
#   elle est importee dans un trousseau temporaire, efface en fin de script.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$HERE/out}
BUILD_IMG=localhost/php74-el7-builder:latest
PUBKEY=$HERE/RPM-GPG-KEY-php74-el7-php2shell
: "${SIGN_KEY_FILE:?indiquer la cle privee dans SIGN_KEY_FILE}"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
chmod 700 "$WORK"
install -m 600 "$SIGN_KEY_FILE" "$WORK/private.asc"

podman run --rm \
  -v "$WORK:/k:Z" \
  -v "$OUT/RPMS:/r/RPMS:Z" -v "$OUT/SRPMS:/r/SRPMS:Z" \
  -v "$PUBKEY:/pub.asc:ro,Z" \
  "$BUILD_IMG" bash -c '
set -euo pipefail
command -v rpmsign >/dev/null || yum -q -y install rpm-sign >/dev/null
export GNUPGHOME=/k/gnupg; mkdir -m 700 -p "$GNUPGHOME"
gpg2 --batch --quiet --import /k/private.asc
FPR=$(gpg2 --with-colons --fingerprint | awk -F: "/^fpr/{print \$10; exit}")
# La cle publique du depot doit correspondre a la cle privee fournie
PUBFPR=$(GNUPGHOME=$(mktemp -d) sh -c "gpg2 --batch --quiet --import /pub.asc 2>/dev/null; gpg2 --with-colons --fingerprint" \
  | awk -F: "/^fpr/{print \$10; exit}")
[ "$PUBFPR" = "$FPR" ] || { echo "cle publique du depot ($PUBFPR) != cle privee fournie ($FPR)"; exit 1; }
echo "%_gpg_name $FPR" > ~/.rpmmacros
rpmsign --addsign /r/RPMS/*.rpm /r/SRPMS/*.rpm </dev/null >/dev/null
rpm --import /pub.asc
total=$(ls /r/RPMS/*.rpm /r/SRPMS/*.rpm | wc -l)
ok=$(rpm -K /r/RPMS/*.rpm /r/SRPMS/*.rpm | grep -c "pgp md5 OK" || true)
echo "signatures verifiees : $ok / $total (cle $FPR)"
[ "$ok" -eq "$total" ]
'

(cd "$OUT" && sha256sum RPMS/*.rpm SRPMS/*.rpm > SHA256SUMS)
echo "out/SHA256SUMS regenere"
