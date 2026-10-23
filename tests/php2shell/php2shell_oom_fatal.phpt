--TEST--
PHP2Shell (CVE-2026-109618/109619): memory_limit exhaustion still reports a fatal error
--DESCRIPTION--
Functional regression check of the bailout mitigation: an allocation over
memory_limit must print the usual fatal error and stop the script (the patched
engine now terminates the process instead of unwinding with longjmp).
--INI--
memory_limit=8M
display_errors=1
--FILE--
<?php
echo "start\n";
$a = str_repeat("x", 64 * 1024 * 1024);
echo "not reached\n";
?>
--EXPECTF--
start
%AFatal error: Allowed memory size of 8388608 bytes exhausted%s(tried to allocate %d bytes) in %s on line %d
