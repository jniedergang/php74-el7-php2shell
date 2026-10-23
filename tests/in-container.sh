#!/bin/bash
# Execute DANS un conteneur centos:7 propre (image php74-el7-repos), lance par test.sh.
# Volumes : /rpms (RPM construits, ro), /bt (arbre source patche, ro),
#           /t (ce dossier tests/, ro), /logs (sortie).
# Aucun exploit ni PoC public : uniquement des controles fonctionnels et les .phpt
# fournis par les correctifs eux-memes.
set -uo pipefail

PHPROOT=/opt/remi/php74/root
PHP=$PHPROOT/usr/bin/php
FPM=$PHPROOT/usr/sbin/php-fpm
FAIL=0
step() { echo; echo "######## $*"; }
check() { # check "description" commande...
  if "${@:2}"; then echo "PASS: $1"; else echo "FAIL: $1"; FAIL=$((FAIL+1)); fi
}

# Paquets typiques d'un serveur en production (base -15 remi) : large couverture des extensions
PKGS="php74-php php74-php-cli php74-php-common php74-php-fpm php74-php-mysqlnd php74-php-pdo
      php74-php-xml php74-php-soap php74-php-mbstring php74-php-gd php74-php-intl
      php74-php-opcache php74-php-json php74-php-process php74-php-pgsql php74-php-ldap
      php74-php-bcmath php74-php-sodium php74-php-pdo-dblib"
BASE=7.4.33-15.el7.remi

# Controle de comportement du correctif PHP2Shell (pas un exploit) :
# depuis le correctif, un depassement de memory_limit n'est plus traite par
# zend_error()+longjmp (etat de requete potentiellement corrompu) mais termine
# le processus proprement (_exit(1)) apres avoir ecrit "Fatal error" sur stderr.
oom_probe() {
  local rc
  $PHP -d memory_limit=8M -d display_errors=stderr -r '$a = str_repeat("x", 64*1024*1024);' >/tmp/oom.out 2>&1
  rc=$?
  echo "code de sortie OOM CLI = $rc ; message : $(grep -m1 -o 'Allowed memory size of [0-9]* bytes exhausted' /tmp/oom.out)"
  return $rc
}

fpm_probe() { # demarre un FPM a 1 worker, mesure le PID du worker avant/apres une requete OOM
  mkdir -p /srv/www
  echo '<?php echo getmypid();' > /srv/www/pid.php
  echo '<?php ini_set("memory_limit","8M"); $a = str_repeat("x", 64*1024*1024); echo "survived";' > /srv/www/oom.php
  cat > /tmp/fpm-test.conf <<'EOF'
[global]
error_log = /tmp/fpm-test.log
daemonize = yes
pid = /tmp/fpm-test.pid
[t]
user = nobody
group = nobody
listen = 127.0.0.1:9074
pm = static
pm.max_children = 1
catch_workers_output = yes
EOF
  $FPM -y /tmp/fpm-test.conf -R || return 1
  sleep 1
  req() { SCRIPT_FILENAME=/srv/www/$1 REQUEST_METHOD=GET cgi-fcgi -bind -connect 127.0.0.1:9074 2>/dev/null | sed '1,/^\r\?$/d'; }
  P1=$(req pid.php); OOMOUT=$(req oom.php | tr -d '\r' | grep -v '^$' | head -2); sleep 1; P2=$(req pid.php)
  echo "worker PID avant=$P1 apres=$P2 ; reponse OOM : ${OOMOUT:-<vide>}"
  echo "journal FPM :"; grep -i 'exited\|exhausted\|started' /tmp/fpm-test.log | tail -4
  kill "$(cat /tmp/fpm-test.pid)"; sleep 1
  [ -n "$P2" ]   # le service doit toujours repondre apres l'OOM
}

prepare_tree() {
  rm -rf /tmp/bt && mkdir -p /tmp/bt && tar -xf /bt/php-7.4.33-patched.tar -C /tmp/bt
  cp /t/php2shell/*.phpt /tmp/bt/php-7.4.33/tests/basic/
}
run_phpt() { # run_phpt <etiquette> : lance les .phpt des correctifs + tests maison
  local label=$1 f
  ( cd /tmp/bt/php-7.4.33
    local list=()
    while read -r f; do [ -f "$f" ] && list+=("$f"); done < /t/phpt-list.txt
    list+=(tests/basic/php2shell_*.phpt)
    export TEST_PHP_EXECUTABLE=$PHP TEST_PHP_CGI_EXECUTABLE=$PHPROOT/usr/bin/php-cgi
    export TEST_FPM_EXECUTABLE=$FPM TEST_FPM_RUN_AS_ROOT=1
    export NO_INTERACTION=1 SKIP_ONLINE_TESTS=1 REPORT_EXIT_STATUS=1
    echo "${#list[@]} fichiers .phpt (correctifs : $(wc -l < /t/phpt-list.txt) touches, + tests maison)"
    $PHP run-tests.php -q --show-diff "${list[@]}" > /logs/run-tests-$label.out 2>&1 )
  sed -n '/^Number of tests/,/^Time taken/p' /logs/run-tests-$label.out
  grep -a '^FAIL ' /logs/run-tests-$label.out | sed 's/^FAIL //' | sort > /tmp/phpt-fail-$label.txt
}

step "0. Outils de test (fcgi pour interroger FPM)"
yum -y -q install fcgi file >/dev/null && echo "fcgi installe"

step "1. Installation de la base remi $BASE (etat de depart typique)"
yum -y -q install $(for p in $PKGS; do echo "$p-$BASE"; done) || { echo "FAIL: install base"; exit 1; }
rpm -q php74-php-cli php74-php-fpm
step "1b. Comportement OOM de la base -15 (reference)"
oom_probe; echo "(attendu sur -15 : 255, erreur fatale classique par longjmp)"
fpm_probe
step "1c. Tests .phpt des correctifs sur la base -15 (reference)"
prepare_tree; run_phpt base15

step "2. Mise a jour par les RPM construits (yum update de fichiers locaux)"
yum -y update $(ls /rpms/*.rpm | grep -v debuginfo) 2>&1 | grep -E '^ (Updating|Mise)|Updated|Complete|Error|^ php74' | head -60
echo "-- versions installees :"
rpm -qa 'php74-php*' | sort
check "aucun paquet php74-php restant en -15" bash -c '! rpm -qa "php74-php*" | grep -q "15.el7.remi"'
check "tous les paquets php74-php en 15.1.el7.php2shell" bash -c 'rpm -qa "php74-php*" | grep -v -q "15.1.el7.php2shell" && exit 1 || exit 0'
check "rpm -V des fichiers binaires" bash -c 'rpm -Va "php74-php*" | grep -v " c " | grep -q . && exit 1 || exit 0'

step "3. php74 -v / -m"
php74 -v
check "php74 -v = 7.4.33" bash -c "php74 -v | grep -q '^PHP 7.4.33'"
php74 -m | tr '\n' ' '; echo
for m in curl date dom filter gd intl json libxml mbstring mysqli mysqlnd openssl pcre PDO pdo_mysql pdo_pgsql pdo_dblib pgsql Phar session soap sodium standard xml zlib "Zend OPcache"; do
  check "extension $m chargee" bash -c "php74 -m | grep -qx '$m'"
done
check "aucun avertissement au demarrage (php -m sur stderr)" bash -c '[ -z "$(php74 -m 2>&1 >/dev/null)" ]'

step "4. php-fpm -t et module apache"
$FPM -t 2>&1; check "php-fpm -t" $FPM -t
check "configuration httpd + mod_php" bash -c 'httpd -t 2>&1 | grep -q "Syntax OK" && httpd -M 2>/dev/null | grep -q php7_module'

step "5. Changelog RPM"
rpm -q --changelog php74-php-common | head -8
for c in CVE-2026-109618 CVE-2026-109619 CVE-2026-93682 CVE-2026-91765 CVE-2026-91766 CVE-2026-91767 CVE-2026-91768 CVE-2026-91769 CVE-2025-1218 CVE-2026-6103 CVE-2025-14181 CVE-2026-92842 CVE-2026-14355 CVE-2026-17543 CVE-2026-7260 CVE-2024-4577; do
  check "changelog mentionne $c" bash -c "rpm -q --changelog php74-php-common | grep -q '$c'"
done

step "6. Presence du correctif PHP2Shell dans le binaire"
check "symbole zend_mm_safe_error_ex exporte par php" bash -c "nm -D $PHP | grep -q ' T zend_mm_safe_error_ex'"
check "symbole zend_new_array_singleton exporte par php" bash -c "nm -D $PHP | grep -q ' T zend_new_array_singleton'"
check "symbole zend_mm_safe_error_ex exporte par php-fpm" bash -c "nm -D $FPM | grep -q ' T zend_mm_safe_error_ex'"
check "symbole zend_mm_safe_error_ex dans libphp7.so (mod_php)" bash -c "nm -D /usr/lib64/httpd/modules/libphp74.so 2>/dev/null | grep -q ' T zend_mm_safe_error_ex' || nm -D $PHPROOT/usr/lib64/httpd/modules/libphp7.so | grep -q ' T zend_mm_safe_error_ex'"

step "7. Comportement OOM apres correctif"
oom_probe; RC=$?
check "OOM CLI : sortie propre code 1 (au lieu de 255) avec message Fatal error" bash -c "[ $RC -eq 1 ] && grep -q 'Allowed memory size of 8388608 bytes exhausted' /tmp/oom.out"
check "FPM continue de servir apres un OOM (worker remplace)" fpm_probe

step "7b. Tests .phpt des correctifs sur les RPM corriges"
prepare_tree; run_phpt after
comm -13 /tmp/phpt-fail-base15.txt /tmp/phpt-fail-after.txt > /tmp/phpt-regressions.txt
comm -23 /tmp/phpt-fail-base15.txt /tmp/phpt-fail-after.txt > /tmp/phpt-fixed.txt
{ echo "echecs sur -15 : $(wc -l < /tmp/phpt-fail-base15.txt), echecs apres : $(wc -l < /tmp/phpt-fail-after.txt)"
  echo "tests en echec sur -15 et qui passent apres (failles corrigees) : $(wc -l < /tmp/phpt-fixed.txt)"; sed 's/^/  + /' /tmp/phpt-fixed.txt; } > /tmp/phpt-compare.txt

step "8. Tests .phpt fournis par les correctifs, base -15 puis RPM corriges"
cat /tmp/phpt-compare.txt
if [ -s /tmp/phpt-regressions.txt ]; then
  echo "FAIL: regressions (passent en -15, echouent apres mise a jour) :"; cat /tmp/phpt-regressions.txt
  FAIL=$((FAIL+1))
else
  echo "PASS: aucune regression .phpt par rapport a la base -15"
fi
comm -12 /tmp/phpt-fail-base15.txt /tmp/phpt-fail-after.txt > /tmp/phpt-preexisting.txt
if [ -s /tmp/phpt-preexisting.txt ]; then
  echo "Echecs preexistants (identiques sur la base -15 de remi) :"; cat /tmp/phpt-preexisting.txt
fi

step "BILAN"
echo "controles en echec : $FAIL"
exit $FAIL
