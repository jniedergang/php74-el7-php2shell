#!/bin/bash
# Teste les RPM construits par build.sh dans un conteneur centos:7 PROPRE
# (depots vault + remi-safe, sans aucune dependance de build) :
# installation de la base remi 7.4.33-15, mise a jour vers nos RPM, controles
# fonctionnels et .phpt des correctifs. Rejouable, rien n'est conserve hors out/logs.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$HERE/out}
REPOS_IMG=localhost/php74-el7-repos:latest

[ -n "$(ls "$OUT"/RPMS/*.rpm 2>/dev/null)" ] || { echo "Pas de RPM dans $OUT/RPMS : lancer ./build.sh"; exit 1; }
[ -s "$OUT/buildtree/php-7.4.33-patched.tar" ] || { echo "Arbre de build absent : lancer ./build.sh"; exit 1; }

podman build -q -t "$REPOS_IMG" -f "$HERE/container/Containerfile.repos" "$HERE/container" >/dev/null

# Liste des .phpt touches par les correctifs ajoutes (Patch210 a Patch243)
mkdir -p "$OUT/logs"
TMPT=$(mktemp -d)
trap 'rm -rf "$TMPT"' EXIT
cp -a "$HERE/tests/." "$TMPT/"
for p in $(awk '/^Patch2(1[0-9]|2[0-9]|3[0-9]|4[0-3]):/{print $2}' "$HERE/SPECS/php.spec"); do
  grep -h '^+++ b/.*\.phpt' "$HERE/SOURCES/$p" | sed 's#^+++ b/##' || true
done | sort -u > "$TMPT/phpt-list.txt"

LOG=$OUT/logs/test-$(date +%Y%m%d-%H%M%S).log
set +e
podman run --rm \
  -v "$OUT/RPMS:/rpms:ro" -v "$OUT/buildtree:/bt:ro" -v "$TMPT:/t:ro" -v "$OUT/logs:/logs" \
  "$REPOS_IMG" bash /t/in-container.sh 2>&1 | tee "$LOG"
RC=${PIPESTATUS[0]}
echo "Journal : $LOG (sorties run-tests : $OUT/logs/run-tests-base15.out, $OUT/logs/run-tests-after.out)"
[ "$RC" -eq 0 ] && echo "RESULTAT : OK" || echo "RESULTAT : $RC controle(s) en echec"
exit "$RC"
