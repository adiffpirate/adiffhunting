#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '>&2 $script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

usage="$(basename "$0") [-h|c|f]

Save company in DGraph

flags:
	-h show this help text
	-c company name
	-f csv file containg domains (file should have at least the 'name' header)
"

while getopts ":h?c:f:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		c) company=$OPTARG ;;
		f) company_domains_csv_file=$OPTARG ;;
	esac
done
if [ -z "$company" ] || [ -z "$company_domains_csv_file" ]; then
	echo "$usage"
	exit 1
fi

input="
	{
		name: \"$company\",
		domains: $(python3 $script_path/parse_domains.py -f $company_domains_csv_file | jq -c '[select(.type == "root") | {name: .name}]')
	}
"

query="
	mutation {
		addCompany(input: [$input], upsert: true){
			company {
				name
			}
		}
	}
"

$script_path/query_dgraph.sh -q "$query"
$script_path/save_domains.sh -f "$company_domains_csv_file"
