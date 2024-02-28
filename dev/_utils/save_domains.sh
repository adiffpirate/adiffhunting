#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '>&2 $script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

usage="$(basename "$0") [-h|f|t]

Save domains in DGraph

flags:
	-h show this help text
	-f csv file containg domains (file should have at least the 'name' header)
	-t tool that discovered all domains (optional)
"

while getopts ":h?f:t:s:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		f) domains_csv_file=$OPTARG ;;
		t) tool=$OPTARG ;;
		k) skip_fqdn_check='true' ;;
	esac
done
if [ -z "$domains_csv_file" ]; then
	echo "$usage"
	exit 1
fi

domains_json_file=$(mktemp)

# Write JSONLines from domains file
python3 $script_path/parse_domains.py -f "$domains_csv_file" -t "$tool" > $domains_json_file

# For each line
cat $domains_json_file | while read line; do
	# Send query to database
	$script_path/query_dgraph.sh -q "
		mutation {
			addDomain(input: [$line], upsert: true){
				domain {
					name
				}
			}
		}
	"
done
