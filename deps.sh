#!/bin/bash
# Construit l'archive complementaire des dependances non CentOS des RPM de out/RPMS :
# paquets du depot Remi "safe" et d'EPEL 7 (archive), avec leurs signatures d'origine,
# pour installer sur une machine CentOS 7 neuve SANS acces a Internet (seul un miroir
# CentOS 7 base/updates local est suppose).
#
# Selection : resolution yum complete dans un conteneur centos:7 (depots vault + Remi
# safe + EPEL archive), puis tri des paquets telecharges PAR CLE DE SIGNATURE (Remi
# 00f97f56, EPEL 7 352c64e5) : ne depend pas de l'affichage de yum. Un paquet signe par
# une autre cle (hors CentOS) fait echouer le script.
#
# Sortie : out/deps/php74-el7-php2shell-deps-<version>/ (RPM, repodata, cles, SHA256SUMS,
# LISEZMOI.txt) et l'archive .tar.gz a cote. Tester ensuite avec ./test-deps.sh.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$HERE/out}
REPOS_IMG=localhost/php74-el7-repos:latest

ls "$OUT"/RPMS/php74-php-common-*.rpm >/dev/null 2>&1 || { echo "Pas de RPM dans $OUT/RPMS : lancer ./build.sh"; exit 1; }
VER=$(basename "$OUT"/RPMS/php74-php-common-*.rpm | sed -E 's/^php74-php-common-([0-9.]+-[0-9.]+)\..*/\1/')
NAME=php74-el7-php2shell-deps-$VER
DEST=$OUT/deps/$NAME

podman build -q -t "$REPOS_IMG" -f "$HERE/container/Containerfile.repos" "$HERE/container" >/dev/null
rm -rf "$DEST" "$OUT/deps/$NAME.tar.gz"
mkdir -p "$DEST"

podman run --rm \
  -v "$OUT/RPMS:/rpms:ro,Z" -v "$DEST:/dest:Z" \
  -v "$HERE/container/keys:/keys:ro,Z" -v "$HERE/RPM-GPG-KEY-php74-el7-php2shell:/pub.asc:ro,Z" \
  "$REPOS_IMG" bash -c '
set -euo pipefail
yum -q -y install createrepo >/dev/null
rpm --import /pub.asc
mkdir /local && cp /rpms/*.rpm /local/ && rm -f /local/*debuginfo*.rpm
createrepo -q /local
cat > /etc/yum.repos.d/local.repo <<R
[php74-php2shell]
name=local
baseurl=file:///local
gpgcheck=1
R
PKGS=$(cd /local && rpm -qp --qf "%{NAME}\n" *.rpm | sort -u)
mkdir /dl
yum -q -y install --downloadonly --downloaddir=/dl $PKGS >/dev/null
UNEXPECTED=0
for f in /dl/*.rpm; do
  key=$(rpm -qp --qf "%|DSAHEADER?{%{DSAHEADER:pgpsig}}:{%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGGPG?{%{SIGGPG:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{(none)}|}|}|}|\n" "$f" 2>/dev/null | grep -o "Key ID [0-9a-f]*" | head -1 | awk "{print \$3}")
  case "$key" in
    *00f97f56) cp "$f" /dest/ ;;                 # Remi
    *352c64e5) cp "$f" /dest/ ;;                 # EPEL 7
    *24c6a8a7f4a80eb5|*f4a80eb5) ;;              # CentOS 7 : fourni par le miroir local
    *207c6d805f513eca|*5f513eca) ;;              # nos RPM (archive principale)
    *) echo "Signature inattendue ($key) : $f"; UNEXPECTED=1 ;;
  esac
done
[ "$UNEXPECTED" -eq 0 ]
cp /keys/RPM-GPG-KEY-remi /keys/RPM-GPG-KEY-EPEL-7 /dest/
createrepo -q /dest
cd /dest && sha256sum *.rpm RPM-GPG-KEY-* > SHA256SUMS
echo "Paquets retenus :"; rpm -qp --qf "  %{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n" /dest/*.rpm
'

# Liste des paquets pour le LISEZMOI (regeneree a chaque construction)
LIST=$(cd "$DEST" && for f in *.rpm; do echo "- $f"; done)
sed -e "s/@VERSION@/$VER/g" "$HERE/LISEZMOI-deps.txt.in" | awk -v list="$LIST" '{ if ($0 == "@LISTE@") print list; else print }' > "$DEST/LISEZMOI.txt"

tar -C "$OUT/deps" -czf "$OUT/deps/$NAME.tar.gz" "$NAME"
(cd "$OUT/deps" && sha256sum "$NAME.tar.gz" > "$NAME.tar.gz.sha256")
echo "Archive : $OUT/deps/$NAME.tar.gz"
cat "$OUT/deps/$NAME.tar.gz.sha256"
