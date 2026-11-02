#!/bin/bash
# Teste l'archive complementaire de deps.sh dans les conditions d'un serveur SANS
# acces a Internet, dote seulement d'un miroir CentOS 7 :
#   1. (reseau) dans un centos:7 vierge, resolution complete puis constitution d'un
#      mini-miroir CentOS ne gardant QUE des paquets signes CentOS 7 (cle f4a80eb5) ;
#   2. (--network=none) dans un centos:7 vierge : mini-miroir + depot principal
#      (out/RPMS) seuls -> l'installation doit ECHOUER sur php74-runtime (cas client) ;
#      puis + archive des dependances -> installation de tous les paquets, gpgcheck=1,
#      rpm -K, chargement de toutes les extensions sans erreur, php-fpm -t.
# Rien n'est conserve hors d'un dossier temporaire efface en fin de script.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$HERE/out}
IMG=docker.io/library/centos:7@sha256:dead07b4d8ed7e29e98de0f4504d87e8880d4347859d839686a31da35a3b532f

DEPS=$(ls -d "$OUT"/deps/php74-el7-php2shell-deps-*/ 2>/dev/null | tail -1)
[ -n "$DEPS" ] || { echo "Archive des dependances absente : lancer ./deps.sh"; exit 1; }
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/main" "$WORK/mirror"
cp "$OUT"/RPMS/*.rpm "$HERE/RPM-GPG-KEY-php74-el7-php2shell" "$WORK/main/"
rm -f "$WORK"/main/*debuginfo*.rpm
# Depots vault CentOS seuls (ni Remi ni EPEL) pour la phase reseau
sed -n '/^\[base\]/,/^\[centos-sclo-sclo\]/p' "$HERE/container/el7-vault.repo" | grep -v '^\[centos-sclo-sclo\]' > "$WORK/vault.repo"

REPOS_IMG=localhost/php74-el7-repos:latest
podman build -q -t "$REPOS_IMG" -f "$HERE/container/Containerfile.repos" "$HERE/container" >/dev/null
mkrepo() { # repodata d'un dossier, dans un conteneur jetable distinct (createrepo n'y pollue rien)
  podman run --rm -v "$1:/r:Z" "$REPOS_IMG" bash -c 'yum -q -y install createrepo >/dev/null && createrepo -q /r'
}
mkrepo "$WORK/main"

echo "######## Phase 1 (reseau) : mini-miroir CentOS 7"
podman run --rm -v "$WORK:/w:Z" -v "$DEPS:/deps:ro,Z" "$IMG" bash -c '
set -euo pipefail
rm -f /etc/yum.repos.d/*.repo; cp /w/vault.repo /etc/yum.repos.d/
echo mddownloadpolicy=xml >> /etc/yum.conf
cat > /etc/yum.repos.d/tmp.repo <<R
[local-main]
name=main
baseurl=file:///w/main
gpgcheck=0
[local-deps]
name=deps
baseurl=file:///deps
gpgcheck=0
R
PKGS=$(cd /w/main && rpm -qp --qf "%{NAME}\n" *.rpm | sort -u | tr "\n" " ")
mkdir /dl && yum -q -y install --downloadonly --downloaddir=/dl $PKGS >/dev/null
for f in /dl/*.rpm; do
  rpm -qp --qf "%|RSAHEADER?{%{RSAHEADER:pgpsig}}:{%|SIGPGP?{%{SIGPGP:pgpsig}}:{(none)}|}|\n" "$f" 2>/dev/null \
    | grep -q "f4a80eb5" && cp "$f" /w/mirror/
done
echo "mini-miroir : $(ls /w/mirror/*.rpm | wc -l) paquets CentOS"
'
mkrepo "$WORK/mirror"

cat > "$WORK/in.sh" <<'EOF'
set -uo pipefail
FAIL=0
check() { if "${@:2}"; then echo "PASS: $1"; else echo "FAIL: $1"; FAIL=$((FAIL+1)); fi; }
rm -f /etc/yum.repos.d/*.repo
cat > /etc/yum.repos.d/offline.repo <<R
[mirror]
name=CentOS 7 (mini-miroir local)
baseurl=file:///w/mirror
gpgcheck=1
gpgkey=file:///etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
[php74-php2shell]
name=php74 EL7 PHP2Shell
baseurl=file:///w/main
gpgcheck=1
gpgkey=file:///w/main/RPM-GPG-KEY-php74-el7-php2shell
R
PKGS=$(cd /w/main && rpm -qp --qf "%{NAME}\n" *.rpm | sort -u | tr "\n" " ")
check "sans reseau" bash -c '! curl -s -m 5 -o /dev/null https://vault.centos.org/'
yum -y install $PKGS >/tmp/neg.log 2>&1
check "sans l'archive des dependances : echec attendu sur php74-runtime" \
  bash -c "grep -q 'Requires: php74-runtime' /tmp/neg.log && ! rpm -q php74-php-common >/dev/null"
cat >> /etc/yum.repos.d/offline.repo <<R
[php74-php2shell-deps]
name=php74 EL7 PHP2Shell, dependances Remi et EPEL
baseurl=file:///deps
gpgcheck=1
gpgkey=file:///deps/RPM-GPG-KEY-remi
       file:///deps/RPM-GPG-KEY-EPEL-7
R
yum clean metadata -q
check "SHA256SUMS de l'archive des dependances" bash -c 'cd /deps && sha256sum -c --quiet SHA256SUMS'
check "installation hors ligne des $(echo $PKGS | wc -w) paquets (gpgcheck=1)" bash -c "yum -y install $PKGS >/tmp/inst.log 2>&1"
grep -E "^Error|Requires:|Install  |Complete" /tmp/inst.log | sort -u

check "rpm -K des paquets Remi/EPEL" bash -c '! rpm -K /deps/*.rpm | grep -v -E "(pgp|gpg).*OK"'
for p in $PKGS; do rpm -q "$p" >/dev/null || { echo "absent : $p"; FAIL=$((FAIL+1)); }; done
check "aucune dependance cassee" bash -c '[ -z "$(rpm -Va --nofiles --nodigest 2>&1)" ]'
P=/opt/remi/php74/root/usr/bin/php
php74 -v | head -1
check "extensions chargees sans erreur" bash -c "! $P -m 2>&1 | grep -iE 'warning|error|unable'"
for m in gd intl mbstring sodium tidy imap pdo_dblib pdo_firebird dba; do
  check "extension $m" bash -c "$P -m | grep -qix $m"
done
check "php-fpm -t" /opt/remi/php74/root/usr/sbin/php-fpm -t
echo "Echecs : $FAIL"
exit $FAIL
EOF

echo "######## Phase 2 (--network=none) : installation hors ligne"
set +e
podman run --rm --network=none -v "$WORK:/w:ro,Z" -v "$DEPS:/deps:ro,Z" "$IMG" bash /w/in.sh
RC=$?
[ "$RC" -eq 0 ] && echo "RESULTAT : OK" || echo "RESULTAT : $RC controle(s) en echec"
exit "$RC"
