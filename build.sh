#!/bin/bash
# Reconstruit les RPM php74-php-* EL7 corriges (PHP2Shell + correctifs remi -16..-31)
# dans un conteneur podman rootless CentOS 7. Rejouable : chaque execution repart
# d'un conteneur neuf, seul out/ est ecrit sur l'hote.
#
# Usage : ./build.sh            (build complet, suite de tests PHP incluse)
#         RUNSELFTEST=0 ./build.sh   (sans la suite de tests du %check, plus rapide)
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${OUT:-$HERE/out}
RUNSELFTEST=${RUNSELFTEST:-1}
REPOS_IMG=localhost/php74-el7-repos:latest
BUILD_IMG=localhost/php74-el7-builder:latest

# Entrees amont epinglees (verifiees avant tout usage)
PHP_TARBALL=php-7.4.33.tar.xz
PHP_URL=https://www.php.net/distributions/$PHP_TARBALL
PHP_SHA256=924846abf93bc613815c55dd3f5809377813ac62a9ec4eb3778675b82a27b927

mkdir -p "$OUT/dl" "$OUT/logs"
STAMP=$(date +%Y%m%d-%H%M%S)
LOG=$OUT/logs/build-$STAMP.log

echo "== 1. Sources amont"
for f in "$PHP_TARBALL" "$PHP_TARBALL.asc"; do
  [ -s "$OUT/dl/$f" ] || curl -fsSL --max-time 600 -o "$OUT/dl/$f" "https://www.php.net/distributions/$f"
done
echo "$PHP_SHA256  $OUT/dl/$PHP_TARBALL" | sha256sum -c -

echo "== 2. Images conteneur"
podman build -q -t "$REPOS_IMG" -f "$HERE/container/Containerfile.repos" "$HERE/container"
podman build -q -t "$BUILD_IMG" --build-arg BASE="$REPOS_IMG" -f "$HERE/container/Containerfile.build" "$HERE/container"

echo "== 3. rpmbuild (journal : $LOG)"
rm -rf "$OUT/RPMS" "$OUT/SRPMS" "$OUT/buildtree"
mkdir -p "$OUT/RPMS" "$OUT/SRPMS" "$OUT/buildtree"

podman run --rm \
  -v "$HERE/SPECS:/in/SPECS:ro" \
  -v "$HERE/SOURCES:/in/SOURCES:ro" \
  -v "$OUT/dl:/in/dl:ro" \
  -v "$OUT:/out" \
  -e RUNSELFTEST="$RUNSELFTEST" \
  "$BUILD_IMG" bash -euxc '
    TOP=/work/rpmbuild
    mkdir -p $TOP/{SOURCES,SPECS,BUILD,RPMS,SRPMS}
    cp -a /in/SOURCES/. /in/dl/. $TOP/SOURCES/
    cp /in/SPECS/php.spec $TOP/SPECS/
    DEFS=(--define "_topdir $TOP" --define "scl php74" --define "runselftest $RUNSELFTEST")
    rpmbuild "${DEFS[@]}" -bs $TOP/SPECS/php.spec
    yum-builddep -y --enablerepo=remi-devel $TOP/SRPMS/*.src.rpm
    rpm -qa | sort > /out/logs/buildroot-packages.txt
    rpmbuild "${DEFS[@]}" -bb $TOP/SPECS/php.spec
    cp $TOP/SRPMS/*.src.rpm /out/SRPMS/
    find $TOP/RPMS -name "*.rpm" -exec cp {} /out/RPMS/ \;
    # Arbre source patche (sans les objets de compilation) pour test.sh / run-tests.php
    cd $TOP/BUILD
    tar --exclude="php-7.4.33/build-*" -cf /out/buildtree/php-7.4.33-patched.tar php-7.4.33
    # Resultats de la suite de tests du %check, si elle a tourne
    find php-7.4.33 -name "*.diff" -path "*/tests/*" | sort > /out/logs/selftest-failed-diffs.txt || true
  ' 2>&1 | tee "$LOG"

echo "== 4. Resultat"
ls -1 "$OUT/RPMS" "$OUT/SRPMS"
( cd "$OUT" && sha256sum RPMS/*.rpm SRPMS/*.rpm > SHA256SUMS )
echo "RPM dans $OUT/RPMS (sommes : $OUT/SHA256SUMS), journal $LOG"
