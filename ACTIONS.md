# Journal : php74-el7-php2shell

## 2026-10-23 : premiere reconstruction EL7 corrigee PHP2Shell

**Quoi.** Reconstruction non officielle des paquets SCL `php74-php-*` de remi pour
CentOS 7.9 (base remi `7.4.33-15.el7.remi`, gelee depuis le 05/06/2024) avec le
correctif PHP2Shell (CVE-2026-109618, CVE-2026-109619, publie le 21/10/2026) et
l'ensemble des correctifs de securite que remi a ajoutes a sa branche EL8 entre
`-16` et `-31`. Version produite : `7.4.33-15.1.el7.php2shell`.

**Pourquoi.** Beaucoup de serveurs CentOS 7.9 font tourner `php74-php-*` remi ; aucun
editeur ne livre de correctif PHP 7.4 pour EL7 (remi a gele `enterprise/7/safe`,
Red Hat ne corrige que RHEL 8, CentOS 7 est en fin de vie).

**Comment.**
- Spec et sources remi `-15` (commit `3114644`) comme base, pour garder les
  particularites EL7 que remi a retirees ensuite (patch curl TLS, ICU 73, gd3php).
- Correctifs `Patch210` a `Patch243` repris tels quels du commit remi `b756db9`
  (`-31`), sans modification. `Patch7` (libxml212) retire comme remi l'a fait en
  `-24` : son contenu est inclus dans `php-cve-2025-1219.patch` (une premiere
  tentative de garder libxml212 en elaguant 1219 echouait au `%prep`).
- Comparaison avec la source Red Hat (SRPM Rocky/AlmaLinux 8.10
  `php-7.4.33-8.module+el8.10.0`, rebuild de RHSA-2026:87080, signatures verifiees) :
  correctif PHP2Shell identique hunk par hunk, paquet cumulatif 8.2.34 identique
  octet par octet (detail dans README.md).
- Pieges payes : vault.centos.org renvoie 403 sur les `*.sqlite.bz2` (contourne par
  `mddownloadpolicy=xml`) ; les `-devel` des bibliotheques remi (ICU 73, gd3php,
  oniguruma5php, libzip5) ne sont que dans le depot `remi`, pas `safe`.

**Verification.** `./build.sh` (35 RPM + SRPM, %check : 11 echecs tous expliques,
dont 7 dus a la desactivation voulue de session.upload_progress) puis `./test.sh` :
0 controle en echec ; `.phpt` des correctifs : 92 echecs sur la base `-15`, 0 apres
mise a jour ; OOM CLI 255 -> 1 ; FPM remplace le worker et continue de servir.
Detail dans README.md, section Resultats.

**Reste a faire.**
- Surveiller une eventuelle revision du correctif amont (la mitigation remi/Red Hat
  est qualifiee de minimale pour version EOL).

## 2026-10-23 : signature et publication

**Quoi.** Cle GPG dediee (RSA 4096, empreinte `1CC551C70005E1519385BA44207C6D805F513ECA`, UID `Julien Niedergang (php74-el7-php2shell signing key)`, expire en 2028) ; script `sign.sh` qui signe et verifie dans le conteneur CentOS 7 ; README anglais (`README.md`) et francais (`README.fr.md`) ; licence MIT pour les scripts ; publication sur GitHub avec les RPM signes en release.

**Pourquoi.** Permettre a tout utilisateur d'EL7 de verifier l'origine des paquets (`rpm -K`, `gpgcheck=1`) et de reconstruire a l'identique.

**Verification.** `./build.sh` puis `./sign.sh` (toutes les signatures verifiees dans un conteneur CentOS 7) puis `./test.sh` (0 controle en echec).

**Reste a faire.**
- Surveiller une eventuelle revision du correctif amont (mitigation qualifiee de minimale pour version EOL).
- Condensat de signature SHA1 (defaut EL7) : re-signature SHA256 possible (`%_gpg_digest_algo sha256`).

