# php74-el7-php2shell

English version: [README.md](README.md).

Reconstruction **non officielle** des paquets SCL `php74-php-*` de remi pour
**CentOS 7.9 (EL7)**, corrigeant **PHP2Shell** (CVE-2026-109618 et CVE-2026-109619,
divulguees le 21/10/2026) ainsi que les autres failles corrigees par remi sur sa
branche EL8 depuis le gel de son depot EL7.

> **AVERTISSEMENT.** Reconstruction personnelle et communautaire, faite a partir des
> sources publiques de Remi Collet et de Red Hat. Ces RPM ne sont **ni produits, ni
> testes, ni approuves, ni supportes par SUSE, Red Hat ou Remi Collet**, et ne font
> partie **d'aucune offre editeur** (SUSE Multi-Linux Support / SUSE Liberty Linux,
> RHEL ELS...). Ils sont fournis tels quels, sans garantie, comme mesure transitoire
> en attendant la sortie de CentOS 7 / PHP 7.4 (tous deux en fin de vie). A valider
> sur un environnement de recette avant tout deploiement.

## Pourquoi

- De nombreux serveurs CentOS 7 font tourner PHP 7.4 depuis les paquets SCL remi
  `php74-php-*` du depot `https://rpms.remirepo.net/enterprise/7/safe/x86_64/`, gele
  depuis le 05/06/2024 (derniere version : `php74-php-7.4.33-15.el7.remi`). CentOS 7
  et RHEL 7 n'ont jamais fourni PHP 7.4 (base : PHP 5.4 ; Software Collections
  arretees a `rh-php73`).
- Aucun editeur ne livre de correctif PHP 7.4 pour EL7. Red Hat a corrige PHP 7.4 sur
  RHEL 8 (module `php:7.4`, RHSA-2026:87080, EUS/AUS RHSA-2026:88565, 88533, 88532) ;
  remi a corrige son paquet EL8 en `7.4.33-31.el8.remi` (21/10/2026).
- La spec `scl-php74` de remi est commune a EL7 et EL8 : les correctifs posterieurs a
  `-15` s'appliquent donc sur la base EL7.

Version produite : **`7.4.33-15.1.el7.php2shell`**. Elle se classe au-dessus de
`7.4.33-15.el7.remi` (un `yum update` la prend) tout en restant clairement
distincte des paquets remi.

## Sources amont et sommes de controle

| Entree | Origine | Empreinte |
|---|---|---|
| Archive PHP | `https://www.php.net/distributions/php-7.4.33.tar.xz` (signature `.asc` verifiee par la spec avec `SOURCES/php-keyring.gpg`, cle de Derick Rethans) | sha256 `924846abf93bc613815c55dd3f5809377813ac62a9ec4eb3778675b82a27b927` (identique a l'archive du SRPM Red Hat) |
| Spec et fichiers remi `-15` (base EL7) | `https://git.remirepo.net/cgit/rpms/scl-php74/php.git/`, commit `3114644fa8259712359df5e5b49c83beabbf4705` (04/06/2024, `7.4.33-15`) | commit git |
| Correctifs remi `-16` a `-31` | meme depot, commit `b756db933925a75064f61dfeabec10bbfbd53343` (21/10/2026, `7.4.33-31`) | commit git |
| Correctif PHP2Shell remi | `php-7.4-cve-2026-109618.patch` | sha256 `047a7050ea32086f6b356900cff54510bb1fafab3ca36f4dc30b824ae50f161a` |
| Correctif cumulatif 8.2.34 remi | `php-from-8.2.34-to-7.4.patch` | sha256 `9907a2ffc01dd7d735f6918b8af50bca80db5021e1aa787773877491d7c2c998` |
| SRPM Red Hat (rebuild Rocky 8.10) | `https://dl.rockylinux.org/pub/rocky/8/AppStream/source/tree/Packages/p/php-7.4.33-8.module+el8.10.0+40393+c071e357.src.rpm` (signature Rocky 8 `6d745a60` verifiee) | sha256 `d1e465bc61cce16301763ef63cc6712d056b39c0aead5b233d662f3e2eab1e96` |
| SRPM Red Hat (rebuild AlmaLinux 8.10) | `https://vault.almalinux.org/8.10/AppStream/Source/Packages/php-7.4.33-8.module_el8.10.0+4321+cf5fd4bb.src.rpm` (signature AlmaLinux 8 verifiee) | sha256 `ab9a6197c49486c18ea2b8b2a0e840061bb9b72a46709260d8b5191a0f3fdf05` |
| Correctif PHP2Shell Red Hat | `php-ghsa-w8hw-w9fx-j79w-74.patch` (dans les deux SRPM, contenus identiques) | sha256 `fe78d899b555856bf92d231e18ff3b703d5a4416f51d70f1312cb3f9f3dd9a83` |
| Image de base | `docker.io/library/centos:7@sha256:dead07b4d8ed7e29e98de0f4504d87e8880d4347859d839686a31da35a3b532f` | digest |
| Cles GPG des depots | `container/keys/` : remi `1EE04CCE88A4AE4AA29A5DF5004E6F4700F97F56`, EPEL 7 `91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5`, CentOS SIG SCLo `C4DBD535B1FBBA14F8BA64A84EB84E71F2EE9D55` | empreintes |

Le SRPM `php-7.4.33-8` est le paquet RHEL 8 `php:7.4` publie le 21/10/2026 avec le
changelog « Avoid state corruption via bailout, CVE-2026-109618, CVE-2026-109619 »
(RHSA-2026:87080).

## Comparaison Red Hat / remi

| Element | Red Hat (`php-7.4.33-8`, RHEL 8) | remi (`7.4.33-31`) | Resultat |
|---|---|---|---|
| PHP2Shell | `php-ghsa-w8hw-w9fx-j79w-74.patch` | `php-7.4-cve-2026-109618.patch` | **identiques hunk par hunk** : meme commit amont (Arnaud Le Blanc, co-auteur Ilija Tovilo, « Avoid state corruption via bailout. Minimal mitigation for EOL version », cherry-pick de `b62095c7`), 17 fichiers. Seules differences : lignes `index`, statistique d'en-tete et ligne `cherry picked from` (metadonnees git). |
| Correctifs 8.2.34 (CVE-2026-91765 a 91769, CVE-2025-1218, CVE-2026-6103, CVE-2025-14181, CVE-2026-92842, CVE-2026-93682) | `php-from-8.2.34.patch` | `php-from-8.2.34-to-7.4.patch` | **identiques octet par octet** |
| Autres correctifs de securite (CVE-2022-31631 a CVE-2026-7260, GHSA) | 42 fichiers `php-cve-*`, `php-ghsa-*`, `php-gh22643` | memes noms | **identiques octet par octet** |

Les deux SRPM Rocky et AlmaLinux ont un contenu identique. Red Hat n'a aucun
correctif de securite que remi n'ait pas (ses seuls fichiers propres sont des
ajustements de tests et de `phpinfo`). Le correctif retenu est donc indifferemment
celui de Red Hat ou de remi : on a garde les fichiers de remi pour rester aligne sur
sa spec SCL, la preuve d'identite avec Red Hat etant documentee ci-dessus.

### Ce que change le correctif PHP2Shell (a connaitre en exploitation)

Le correctif est une **mitigation minimale** pour une version en fin de vie : lors
d'un depassement de `memory_limit` ou d'un debordement de taille d'allocation, PHP
n'execute plus `zend_error()` + `longjmp` (qui laissait l'etat de la requete
partiellement initialise, base des deux CVE) mais ecrit `Fatal error: ...` sur
**stderr** et termine le processus par `_exit(1)`. Consequences visibles :

- en CLI, une erreur « Allowed memory size exhausted » rend le code **1** (au lieu
  de 255) et le message part sur stderr ;
- sous **PHP-FPM**, le worker concerne meurt et le maitre en relance un autre
  (`child ... exited with code 1` dans le journal FPM) ; la requete fautive recoit
  une reponse vide / une erreur 502 du serveur web au lieu de la page d'erreur PHP ;
- sous **mod_php**, c'est le processus enfant Apache qui sort.
- Les fonctions d'arret (`register_shutdown_function`) ne sont plus executees apres
  un depassement memoire.
- **La progression de televersement en session (`session.upload_progress`) est
  desactivee** : le correctif amont neutralise le rappel rfc1867 de l'extension
  session (`if (!PS(rfc1867_enabled) || true)`). `$_SESSION[...upload_progress...]`
  reste vide. C'est le cas aussi chez Red Hat et remi (meme correctif).
- Dans le corps `multipart/form-data`, seuls les en-tetes de partie
  `Content-Disposition` et `Content-Type` sont conserves, et un en-tete duplique est
  ignore (la premiere occurrence fait foi).

## Contenu des correctifs : CVE corrigees / ecartees

Tous les correctifs de securite ajoutes par remi apres `-15` sont inclus : ils
s'appliquent tous **sans fuzz** (`--fuzz=0`) sur la base EL7.

| Version remi | CVE / avis | Statut |
|---|---|---|
| -31 | **CVE-2026-109618, CVE-2026-109619** (PHP2Shell) | inclus |
| -30 | CVE-2026-93682 | inclus |
| -29 | CVE-2026-91765, CVE-2026-91766, CVE-2026-91767, CVE-2026-91768, CVE-2026-91769, CVE-2025-1218, CVE-2026-6103, CVE-2025-14181, CVE-2026-92842, FILTER_SANITIZE_ENCODED 0xFF | inclus |
| -28 | CVE-2026-17543, CVE-2026-7260, fuite DatePeriod (GH-22643) | inclus |
| -28 | CVE-2026-9672 (libgd) | inclus mais **sans effet** : le correctif vise la libgd embarquee, or ce paquet utilise la bibliotheque systeme `gd3php` de remi (comme le `-15`) ; la correction devrait venir de `gd3php`, elle aussi gelee sur EL7 |
| -27 | CVE-2026-14355 | inclus |
| -26 | CVE-2026-6735, CVE-2026-6722, CVE-2026-7261, CVE-2026-7262, CVE-2026-7568, CVE-2026-7258 | inclus |
| -25 | CVE-2025-14178, CVE-2025-14177, GHSA-www2-q4fc-65wf | inclus |
| -24 | CVE-2025-1735, CVE-2025-6491, CVE-2025-1220 | inclus |
| -23 | CVE-2025-1219, CVE-2025-1736, CVE-2025-1861, CVE-2025-1734, CVE-2025-1217 | inclus |
| -21 | CVE-2024-8929 | inclus |
| -20 | CVE-2024-8932, CVE-2024-11236, CVE-2024-11234, CVE-2024-11233, GHSA-4w77-75f9-2c8w | inclus |
| -18 | CVE-2024-4577, CVE-2024-8926, CVE-2024-8927, CVE-2024-9026, CVE-2024-8925 | inclus |

Changements remi **non repris** (non lies a la securite, ou propres aux distributions
recentes) : client Oracle 23.x (oci8 n'est pas construit), ICU 74+ (EL7 reste sur
`libicu73` de remi), prototypes stricts et bash 5.3 (Fedora recentes), tests pcre2
10.45, desactivation firebird sur EL10, correctif bugs.php.net 79589 (OpenSSL 3).

Ecarts par rapport a la spec remi `-15` :
- `Patch7` (`php-7.4.33-libxml212.patch`) est retire, comme remi l'a fait en
  `7.4.33-24` : son contenu fait partie de `php-cve-2025-1219.patch`.
- Le correctif EL7 `php-7.0.7-curl.patch` (que remi a retire en `-22` quand il a
  arrete EL7) est conserve.
- `Release: 15.1` et `%global dist .el7.php2shell`.

## Installation

Telecharger les RPM depuis la [page des releases](../../releases), puis :

```
sha256sum -c SHA256SUMS
rpm --import RPM-GPG-KEY-php74-el7-php2shell
rpm -K *.rpm                     # attendu : "pgp md5 OK" pour chaque paquet
yum update ./php74-php-*.rpm     # ou servir le dossier comme depot yum local
systemctl restart php74-php-fpm  # et/ou httpd en mod_php
```

Le depot remi `safe` doit rester accessible pour les bibliotheques dont dependent les
paquets (`gd3php`, `oniguruma5php`, `libzip5`...). Retour arriere :
`yum downgrade 'php74-php*'` revient a `7.4.33-15.el7.remi` de remi.

## Signature des paquets

Les RPM et le SRPM sont signes avec une cle dediee a cette reconstruction :

- cle publique : [`RPM-GPG-KEY-php74-el7-php2shell`](RPM-GPG-KEY-php74-el7-php2shell) ;
- empreinte : `1CC5 51C7 0005 E151 9385  BA44 207C 6D80 5F51 3ECA` (RSA 4096, expire le
  22/10/2028), UID `Julien Niedergang (php74-el7-php2shell signing key)`.

Signature faite dans le conteneur CentOS 7 (`./sign.sh`), condensat RSA/SHA1 (valeur par
defaut d'EL7, lue par le `rpm` 4.11 d'EL7).

## Arborescence

```
SPECS/php.spec          spec remi -15 + Patch210..Patch243 + changelog
SOURCES/                correctifs et fichiers de configuration (sans l'archive PHP)
container/              Containerfiles, depots yum (vault, SCLo, EPEL archive, remi-safe), cles GPG
build.sh                build complet rejouable
sign.sh                 signe les RPM de out/ dans le conteneur CentOS 7 (SIGN_KEY_FILE=...)
test.sh                 tests rejouables dans un centos:7 propre
tests/in-container.sh   scenario de test execute dans le conteneur
tests/php2shell/        tests .phpt maison (non-regression, pas d'exploit)
out/                    (ignore par git) archive, RPM, arbre de build, journaux
```

## Construire

Prerequis : podman (rootless suffit), acces HTTPS sortant (php.net, vault.centos.org,
archives.fedoraproject.org, rpms.remirepo.net).

```
./build.sh                  # ~12 min images en cache (~20 min la 1re fois), %check inclus
RUNSELFTEST=0 ./build.sh    # sans la suite de tests du %check
SIGN_KEY_FILE=cle.asc ./sign.sh
```

Le script telecharge l'archive PHP et verifie son sha256, construit deux images
(`localhost/php74-el7-repos`, `localhost/php74-el7-builder`), produit le SRPM, installe
les dependances (`yum-builddep`), puis les RPM. Resultat dans `out/RPMS`, `out/SRPMS`,
`out/SHA256SUMS`, journal dans `out/logs/`.

Pieges rencontres (deja geres) :
- `mirrorlist.centos.org` n'existe plus : depots pointes sur `vault.centos.org/7.9.2009`.
- vault.centos.org renvoie **403 sur les `*.sqlite.bz2`** : `mddownloadpolicy=xml`
  dans `yum.conf` force l'usage de `primary.xml.gz`.
- Les `-devel` des bibliotheques remi (`libicu73-devel`, `gd3php-devel`,
  `libwebp7-devel`, `oniguruma5php-devel`, `libzip5-devel`) ne sont publies que dans le
  depot `remi`, pas `safe` : depot `remi-devel` desactive par defaut, restreint a ces
  paquets, active seulement pour le build.

## Tester

```
./test.sh
```

Dans un conteneur `centos:7` **propre** (depots vault + remi-safe, aucune dependance
de build) : installation de la base remi `7.4.33-15.el7.remi` (19 paquets), mesure du
comportement de reference, `yum update` avec les RPM construits, puis :
`php74 -v`, `php74 -m`, `php-fpm -t`, `httpd -t` avec mod_php, presence des CVE dans
`rpm -q --changelog`, presence des symboles du correctif dans `php`, `php-fpm` et
`libphp7.so`, comportement sur depassement memoire (CLI et FPM), et execution par
`run-tests.php` (arbre de build) des `.phpt` fournis par les correctifs et des tests
maison. Aucun exploit ni PoC public n'est execute.

## Resultats (build et tests du 23/10/2026)

**Build** : 35 RPM binaires + 1 SRPM, tous en
`7.4.33-15.1.el7.php2shell`. Tous les correctifs s'appliquent avec `--fuzz=0`.
Suite de tests PHP du `%check` (CLI) : 15 909 tests, 9 077 reussis, 11 echecs, tous
expliques :
- 7 tests `ext/session/tests/rfc1867*.phpt` : **effet voulu du correctif PHP2Shell**,
  qui desactive la progression de televersement en session (voir plus haut) ;
- `tests/lang/bug45392.phpt` : sortie sur depassement memoire modifiee par le
  correctif (message sur stderr, arret immediat) ;
- `ext/openssl/tests/sni_server*.phpt` (2) : echecs connus, remi les supprime de sa
  suite (`rm ext/openssl/tests/sni_server*.phpt` dans sa spec `-31`).

**Tests** (`./test.sh`) : **0 controle en echec**.
- Base remi `-15` installee (19 paquets) puis `yum update` vers nos RPM : 19 paquets
  mis a jour, plus aucun `-15`, `rpm -V` propre.
- `php74 -v` : `PHP 7.4.33 (cli) (built: Oct 23 2026 15:07:40) ( NTS )`, OPcache
  charge ; 26 extensions verifiees dans `php74 -m`, aucun avertissement au demarrage.
- `php-fpm -t` : `configuration file /etc/opt/remi/php74/php-fpm.conf test is
  successful` ; `httpd -t` OK avec `php7_module`.
- `rpm -q --changelog` mentionne les 16 CVE controlees (dont CVE-2026-109618/109619).
- Symboles du correctif (`zend_mm_safe_error_ex`, `zend_new_array_singleton`)
  presents dans `php`, `php-fpm` et `libphp7.so`.
- Depassement memoire, CLI : code de sortie **255 sur `-15`, 1 apres correctif**.
- Depassement memoire, FPM (1 worker) : sur `-15` le meme worker continue
  (PID 201 avant et apres) ; apres correctif le worker sort (`child 1137 exited with
  code 1`), le maitre en relance un (`child 1149 started`) et le service repond
  toujours.
- `.phpt` fournis par les correctifs (149) + 2 tests maison, lances par
  `run-tests.php` avec les binaires installes : **92 echecs sur la base `-15`,
  0 apres mise a jour** (127 reussis, 24 sautes : variantes libxml2 >= 2.11, tests
  32 bits, bases de donnees absentes). Aucune regression.

Point connu, preexistant : `ext/libxml/tests/libxml_set_external_entity_loader_error1.phpt`
est instable avec la libxml2 2.9.1 d'EL7 (le nom de rappel affiche dans le message
d'erreur contient des octets aleatoires, constate 3 fois sur 3 avec le `-15` de remi) :
il peut echouer aleatoirement, sur la base comme apres correctif.

## Licence

- PHP et les correctifs : PHP License v3.01 (amont).
- `SPECS/php.spec` : MIT, comme indique dans l'en-tete de la spec de remi (derivee de la spec Fedora).
- Scripts de build, de signature et de test de ce depot : MIT, voir [LICENSE](LICENSE).
