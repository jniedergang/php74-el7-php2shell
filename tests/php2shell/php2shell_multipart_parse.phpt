--TEST--
PHP2Shell (CVE-2026-109618/109619): request body parsing still works (rfc1867, php_variables)
--DESCRIPTION--
The mitigation touches main/rfc1867.c and main/php_variables.c. This checks that
regular multipart/form-data parsing (fields, nested arrays, file upload) is unchanged.
--INI--
file_uploads=1
upload_max_filesize=1024
max_file_uploads=10
--POST_RAW--
Content-Type: multipart/form-data; boundary=---------------------------20896060251896012921717172737
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="a[b][c]"

nested
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="plain"

value
-----------------------------20896060251896012921717172737
Content-Disposition: form-data; name="f"; filename="t.txt"
Content-Type: text/plain

hello
-----------------------------20896060251896012921717172737--
--FILE--
<?php
var_dump($_POST['a']['b']['c'], $_POST['plain']);
var_dump($_FILES['f']['name'], $_FILES['f']['error'], $_FILES['f']['size']);
var_dump(file_get_contents($_FILES['f']['tmp_name']));
?>
--EXPECT--
string(6) "nested"
string(5) "value"
string(5) "t.txt"
int(0)
int(5)
string(5) "hello"
