#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '>&2 $script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

# Read input from stdin
if [[ -t 0 ]]; then
	$script_path/_log.sh 'error' 'No URLs were provided on input via stdin'
	exit 1
else
	URLS_LIST="$(cat /dev/stdin)"
fi

# For each line
$script_path/_log.sh 'info' 'Saving URLs into the database' "amount=$(echo "$URLS_LIST" | wc -l)"
for url in $URLS_LIST; do
	# Breakdown url into capture groups using regex:
	# Group \1 = full protocol including "://" (e.g. "http://" or "https://")
	# Group \2 = protocol only (e.g. "http" or "https")
	# Group \3 = domain / host (e.g. "example.com")
	# Group \4 = path (e.g. "/foo/bar")
	# Group \5 = full query string including leading "?" (e.g. "?x=1&y=2")
	# Group \6 = query string without "?" (e.g. "x=1&y=2")
	parser_regex='^((https?):\/\/)?([^\/?#]+)?([^?#]*)(\?([^#]*))?$'
	protocol="$(echo "$url" | sed -E "s|$parser_regex|\\2|")"
	domain="$(echo "$url" | sed -E "s|$parser_regex|\\3|")"
	path="$(echo "$url" | sed -E "s|$parser_regex|\\4|")"
	args="$(echo "$url" | sed -E "s|$parser_regex|\\6|")"

	# Skip processing if URL is missing the domain
	if [[ -z "$domain" ]]; then
		$script_path/_log.sh 'warn' 'URL is missing the domain' "protocol=$protocol" "domain=$domain" "path=$path" "args=$args"
		continue
	fi
done
