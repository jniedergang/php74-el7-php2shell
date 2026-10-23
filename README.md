# php74-el7-php2shell

**Unofficial** rebuild of Remi's `php74-php-*` Software Collection packages for
**CentOS 7 / RHEL 7 (EL7)**, fixing **PHP2Shell** (CVE-2026-109618 and
CVE-2026-109619, disclosed on 2026-10-21) and the other security issues Remi fixed on
his EL8 branch after freezing his EL7 repository.

French version: [README.fr.md](README.fr.md).

> **DISCLAIMER.** This is a personal, community rebuild made from the public sources
> of Remi Collet and Red Hat. It is **not produced, tested, endorsed or supported by
> SUSE, Red Hat or Remi Collet**, and it is **not part of any vendor offering** (SUSE
> Multi-Linux Support / SUSE Liberty Linux, RHEL ELS, ...). It is provided as is, with
> no warranty, as a stopgap until you move off CentOS 7 and PHP 7.4 (both end of
> life). Test it on a staging system before any production use.

## Why

- Many CentOS 7 systems run PHP 7.4 from Remi's SCL repository
  `https://rpms.remirepo.net/enterprise/7/safe/x86_64/`, frozen since 2024-06-05
  (last build: `php74-php-7.4.33-15.el7.remi`). CentOS 7 and RHEL 7 never shipped
  PHP 7.4 themselves (base: PHP 5.4; Software Collections stopped at `rh-php73`).
- PHP2Shell affects every PHP version from 5.4 to 8.5.11. The PHP project only fixes
  8.2 and later. Red Hat fixed PHP 7.4 on RHEL 8 (module `php:7.4`, RHSA-2026:87080,
  EUS/AUS RHSA-2026:88565, 88533, 88532) and Remi fixed his EL8 package in
  `7.4.33-31.el8.remi` (2026-10-21). Nobody ships a fix for PHP 7.4 on EL7.
- Remi's `scl-php74` spec is shared by EL7 and EL8, so the fixes added after `-15`
  apply cleanly on the EL7 base.

Version produced: **`7.4.33-15.1.el7.php2shell`**. It sorts above
`7.4.33-15.el7.remi` (a plain `yum update` picks it up) while staying clearly
distinct from Remi's packages.

## Upstream inputs and checksums

| Input | Origin | Fingerprint |
|---|---|---|
| PHP tarball | `https://www.php.net/distributions/php-7.4.33.tar.xz` (`.asc` signature checked by the spec against `SOURCES/php-keyring.gpg`) | sha256 `924846abf93bc613815c55dd3f5809377813ac62a9ec4eb3778675b82a27b927` (same as the tarball in Red Hat's SRPM) |
| Remi spec and files `-15` (EL7 base) | `https://git.remirepo.net/cgit/rpms/scl-php74/php.git/`, commit `3114644fa8259712359df5e5b49c83beabbf4705` (2024-06-04, `7.4.33-15`) | git commit |
| Remi fixes `-16` to `-31` | same repository, commit `b756db933925a75064f61dfeabec10bbfbd53343` (2026-10-21, `7.4.33-31`) | git commit |
| Remi PHP2Shell patch | `php-7.4-cve-2026-109618.patch` | sha256 `047a7050ea32086f6b356900cff54510bb1fafab3ca36f4dc30b824ae50f161a` |
| Remi 8.2.34 cumulative patch | `php-from-8.2.34-to-7.4.patch` | sha256 `9907a2ffc01dd7d735f6918b8af50bca80db5021e1aa787773877491d7c2c998` |
| Red Hat SRPM (Rocky 8.10 rebuild) | `https://dl.rockylinux.org/pub/rocky/8/AppStream/source/tree/Packages/p/php-7.4.33-8.module+el8.10.0+40393+c071e357.src.rpm` (Rocky 8 signature checked) | sha256 `d1e465bc61cce16301763ef63cc6712d056b39c0aead5b233d662f3e2eab1e96` |
| Red Hat SRPM (AlmaLinux 8.10 rebuild) | `https://vault.almalinux.org/8.10/AppStream/Source/Packages/php-7.4.33-8.module_el8.10.0+4321+cf5fd4bb.src.rpm` (AlmaLinux 8 signature checked) | sha256 `ab9a6197c49486c18ea2b8b2a0e840061bb9b72a46709260d8b5191a0f3fdf05` |
| Red Hat PHP2Shell patch | `php-ghsa-w8hw-w9fx-j79w-74.patch` (identical in both SRPMs) | sha256 `fe78d899b555856bf92d231e18ff3b703d5a4416f51d70f1312cb3f9f3dd9a83` |
| Base image | `docker.io/library/centos:7@sha256:dead07b4d8ed7e29e98de0f4504d87e8880d4347859d839686a31da35a3b532f` | digest |
| Repository GPG keys | `container/keys/`: Remi `1EE04CCE88A4AE4AA29A5DF5004E6F4700F97F56`, EPEL 7 `91E97D7C4A5E96F17F3E888F6A2FAEA2352C64E5`, CentOS SIG SCLo `C4DBD535B1FBBA14F8BA64A84EB84E71F2EE9D55` | fingerprints |

## Red Hat vs Remi comparison

| Item | Red Hat (`php-7.4.33-8`, RHEL 8) | Remi (`7.4.33-31`) | Result |
|---|---|---|---|
| PHP2Shell | `php-ghsa-w8hw-w9fx-j79w-74.patch` | `php-7.4-cve-2026-109618.patch` | **identical hunk by hunk**: same upstream commit ("Avoid state corruption via bailout. Minimal mitigation for EOL version", cherry-pick of `b62095c7`), 17 files. Only git metadata lines differ. |
| 8.2.34 fixes (CVE-2026-91765 to 91769, CVE-2025-1218, CVE-2026-6103, CVE-2025-14181, CVE-2026-92842, CVE-2026-93682) | `php-from-8.2.34.patch` | `php-from-8.2.34-to-7.4.patch` | **byte-identical** |
| Other security fixes (CVE-2022-31631 to CVE-2026-7260, GHSA) | 42 `php-cve-*`, `php-ghsa-*`, `php-gh22643` files | same names | **byte-identical** |

Red Hat has no security fix that Remi lacks. Remi's files are used to stay aligned
with his SCL spec.

### What the PHP2Shell fix changes (operations)

The fix is a **minimal mitigation** for an end-of-life branch: when `memory_limit` is
exceeded (or an allocation size overflows), PHP no longer runs `zend_error()` plus
`longjmp` (which left the request state half initialised, the root of both CVEs). It
writes `Fatal error: ...` to **stderr** and ends the process with `_exit(1)`:

- CLI: "Allowed memory size exhausted" now exits with code **1** (was 255).
- **PHP-FPM**: the worker dies and the master spawns a new one (`child ... exited
  with code 1`); the offending request gets an empty response / 502.
- **mod_php**: the Apache child process exits.
- Shutdown functions (`register_shutdown_function`) no longer run after memory
  exhaustion.
- **Session upload progress (`session.upload_progress`) is disabled** (the upstream
  fix hard-codes `if (!PS(rfc1867_enabled) || true)`). Same in Red Hat's and Remi's
  builds.
- In `multipart/form-data` bodies, only the `Content-Disposition` and `Content-Type`
  part headers are kept, and a duplicated header is ignored (first one wins).

## Included / skipped fixes

Every security fix Remi added after `-15` is included; all apply with `--fuzz=0`.

| Remi release | CVE / advisory | Status |
|---|---|---|
| -31 | **CVE-2026-109618, CVE-2026-109619** (PHP2Shell) | included |
| -30 | CVE-2026-93682 | included |
| -29 | CVE-2026-91765, CVE-2026-91766, CVE-2026-91767, CVE-2026-91768, CVE-2026-91769, CVE-2025-1218, CVE-2026-6103, CVE-2025-14181, CVE-2026-92842, FILTER_SANITIZE_ENCODED 0xFF | included |
| -28 | CVE-2026-17543, CVE-2026-7260, DatePeriod leak (GH-22643) | included |
| -28 | CVE-2026-9672 (libgd) | included but **no effect**: it patches the bundled libgd, while these packages link against Remi's system `gd3php` (frozen on EL7 as well) |
| -27 | CVE-2026-14355 | included |
| -26 | CVE-2026-6735, CVE-2026-6722, CVE-2026-7261, CVE-2026-7262, CVE-2026-7568, CVE-2026-7258 | included |
| -25 | CVE-2025-14178, CVE-2025-14177, GHSA-www2-q4fc-65wf | included |
| -24 | CVE-2025-1735, CVE-2025-6491, CVE-2025-1220 | included |
| -23 | CVE-2025-1219, CVE-2025-1736, CVE-2025-1861, CVE-2025-1734, CVE-2025-1217 | included |
| -21 | CVE-2024-8929 | included |
| -20 | CVE-2024-8932, CVE-2024-11236, CVE-2024-11234, CVE-2024-11233, GHSA-4w77-75f9-2c8w | included |
| -18 | CVE-2024-4577, CVE-2024-8926, CVE-2024-8927, CVE-2024-9026, CVE-2024-8925 | included |

Remi changes **not** carried over (not security related, or only for newer
distributions): Oracle 23.x client, ICU 74+, strict prototypes, bash 5.3, pcre2 10.45
tests, firebird on EL10, bugs.php.net 79589 (OpenSSL 3).

Differences from Remi's `-15` spec:
- `Patch7` (`php-7.4.33-libxml212.patch`) dropped, as Remi did in `7.4.33-24`: its
  content is part of `php-cve-2025-1219.patch`.
- EL7 patch `php-7.0.7-curl.patch` kept (Remi dropped it in `-22` when he stopped EL7).
- `Release: 15.1` and `%global dist .el7.php2shell`.

## Install

Download the RPMs from the [release page](../../releases), then:

```
sha256sum -c SHA256SUMS
rpm --import RPM-GPG-KEY-php74-el7-php2shell
rpm -K *.rpm                     # expect "pgp md5 OK" for every package
yum update ./php74-php-*.x86_64.rpm     # or serve the directory as a local yum repo
systemctl restart php74-php-fpm  # and/or httpd when using mod_php
```

Remi's `safe` repository must stay reachable for the libraries the packages depend on
(`gd3php`, `oniguruma5php`, `libzip5`, ...). Rollback: `yum downgrade 'php74-php*'`
returns to Remi's `7.4.33-15.el7.remi`.

## Package signing

RPMs and SRPM are signed with a key dedicated to this rebuild:

- public key: [`RPM-GPG-KEY-php74-el7-php2shell`](RPM-GPG-KEY-php74-el7-php2shell);
- fingerprint: `1CC5 51C7 0005 E151 9385  BA44 207C 6D80 5F51 3ECA` (RSA 4096,
  expires 2028-10-22), UID `Julien Niedergang (php74-el7-php2shell signing key)`.

Signing runs inside the CentOS 7 container (`./sign.sh`), RSA/SHA1 digest (EL7
default, read by EL7's rpm 4.11).

## Layout

```
SPECS/php.spec          Remi -15 spec + Patch210..Patch243 + changelog
SOURCES/                patches and config files (PHP tarball downloaded by build.sh)
container/              Containerfiles, yum repos (vault, SCLo, EPEL archive, remi-safe), GPG keys
build.sh                replayable full build
sign.sh                 signs out/ RPMs in the CentOS 7 container (SIGN_KEY_FILE=...)
test.sh                 replayable tests in a clean centos:7
tests/in-container.sh   test scenario run inside the container
tests/php2shell/        extra .phpt tests (regression only, no exploit)
out/                    (git-ignored) RPMs, build tree, logs
```

## Build

Requirements: podman (rootless is fine), outbound HTTPS (php.net, vault.centos.org,
archives.fedoraproject.org, rpms.remirepo.net).

```
./build.sh                  # ~12 min with cached images (~20 min the first time), %check included
RUNSELFTEST=0 ./build.sh    # skip the %check test suite
SIGN_KEY_FILE=key.asc ./sign.sh
```

Pitfalls already handled:
- `mirrorlist.centos.org` is gone: repositories point to `vault.centos.org/7.9.2009`.
- vault.centos.org answers **403 on `*.sqlite.bz2`**: `mddownloadpolicy=xml` in
  `yum.conf` forces `primary.xml.gz`.
- Remi's `-devel` library packages (`libicu73-devel`, `gd3php-devel`,
  `libwebp7-devel`, `oniguruma5php-devel`, `libzip5-devel`) are only in the `remi`
  repository, not `safe`: a `remi-devel` repo, disabled by default and restricted to
  those packages, is enabled for the build only.

## Test

```
./test.sh
```

In a **clean** `centos:7` container (vault + remi-safe, no build dependency): install
Remi's `7.4.33-15.el7.remi` (19 packages), record the baseline behaviour, `yum update`
to the built RPMs, then check `php74 -v`, `php74 -m`, `php-fpm -t`, `httpd -t` with
mod_php, the CVEs in `rpm -q --changelog`, the fix symbols in `php`, `php-fpm` and
`libphp7.so`, memory exhaustion behaviour (CLI and FPM), and run with `run-tests.php`
the `.phpt` files shipped with the fixes plus the extra tests. No public exploit or
PoC is run.

## Results (2026-10-23)

**Build**: 35 binary RPMs + 1 SRPM. `%check` (CLI): 15,909 tests, 9,077 passed,
11 failed, all explained:
- 7 `ext/session/tests/rfc1867*.phpt`: intended effect of the PHP2Shell fix (upload
  progress disabled, see above);
- `tests/lang/bug45392.phpt`: memory exhaustion output changed by the fix;
- `ext/openssl/tests/sni_server*.phpt` (2): known failures, removed by Remi from his
  own suite.

**Tests** (`./test.sh`): **0 failed check**.
- Remi `-15` installed (19 packages) then `yum update`: 19 packages updated, no `-15`
  left, `rpm -V` clean.
- `php-fpm -t` and `httpd -t` (with `php7_module`) pass; 26 extensions checked in
  `php74 -m`, no startup warning.
- Memory exhaustion, CLI: exit code **255 on `-15`, 1 after the fix**. FPM: the worker
  exits, the master spawns a new one, the service keeps answering.
- `.phpt` tests shipped with the fixes (149) + 2 extra: **92 failures on `-15`, 0 after
  the update** (127 passed, 24 skipped). No regression.

Known, pre-existing: `ext/libxml/tests/libxml_set_external_entity_loader_error1.phpt`
is flaky with EL7's libxml2 2.9.1 (random bytes in the error message, seen 3 times
out of 3 on Remi's `-15`).

## License

- PHP and the patches: PHP License v3.01 (upstream).
- `SPECS/php.spec`: MIT, as stated in Remi's spec header (derived from Fedora's spec).
- Build, sign and test scripts of this repository: MIT, see [LICENSE](LICENSE).
