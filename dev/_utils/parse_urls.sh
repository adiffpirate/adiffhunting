#!/bin/bash
script_path=$(dirname "$0")
set -eEo pipefail
trap '>&2 $script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

parse_domain(){
	domain="$1"
	subdomain="$2"

	# Count the number of words delimeted by a dot
	domain_level="$(echo "$domain" | awk -F. '{print NF}')"

	# Get the parent domain (e.g. for "foo.example.com" the parent_domain is "example.com")
	parent_domain="$(echo "$domain" | sed -E 's|^([^\.]+\.)(.+)$|\2|')"

	# Determine domain type (tld, root or sub)
	if grep -qw "$domain" $script_path/tld-list.txt; then # If domain is TLD
		domain_type='tld'
	elif grep -qw "$parent_domain" $script_path/tld-list.txt; then # If domain is one level above TLD
		domain_type='root'
	else # If domain is two or more levels above TLD
		domain_type='sub'
	fi

	# Print parsed JSON (with subdomain if provided)
	jq -nc "{
		record_type: \"Domain\",
		record_data: {
			name: \"$domain\",
			type: \"$domain_type\",
			level: \"$domain_level\",
			$(if [[ -n "$subdomain" ]]; then echo "subdomains:[{name: \"$subdomain\"}],"; fi)
			randomSeed: \"$(uuidgen -r)\"
		}
	}"

	# Call this function recursively for the parent domains until it reachs TLD
	if [[ "$domain_type" != "tld" ]]; then
		parse_domain "$parent_domain" "$domain"
	fi
}

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

	$script_path/_log.sh 'debug' 'Parsing URL' "protocol=$protocol" "domain=$domain" "path=$path" "args=$args"
	parse_domain "$domain"

done
