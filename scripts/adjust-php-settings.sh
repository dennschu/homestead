#!/usr/bin/env bash

CUSTOM_SETTINGS = << EOT
[CUSTOM]
html_errors=1
error_reporting=-1
session.save_path=/var/lib/php/session
memory_limit=256M
post_max_size=8M
;error_log=/var/www/_logs/php_error.log
cgi.fix_pathinfo=1
date.timezone=Europe/Berlin
upload_max_filesize=8M
max_input_vars=3000
display_errors=true
EOT
