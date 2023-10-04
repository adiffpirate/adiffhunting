#!/bin/bash

usage="$(basename "$0") [-h|a|d]

Get domains from DGraph using GraphQL \"queryDomain\" function.
More info: https://dgraph.io/docs/graphql/queries

flags:
	-h show this help text
	-a args (optional)
	-d get all domains below passed domain (optional)
"

# Defaults
args=""

while getopts ":h?a:d:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		a) args=$OPTARG ;;
		d) domain=$OPTARG ;;
	esac
done
# If an argument was passed but it was not the -a flag or the -d flag
if [ -n "$1" ] && [ -z "$args" ] && [ -z "$domain" ]; then
	echo "$usage"
	exit 1
fi

script_path=$(dirname "$0")
query_result=$(mktemp)

if [ -n "$domain" ]; then
	$script_path/query_dgraph.sh -t dql -q "
		{
			result(func: eq(Domain.name, \"$domain\")) @recurse {
				Domain.name,
				Domain.subdomains
			}
		}
	" | jq -r '.data.result | .. | ."Domain.name"?'
else
	$script_path/query_dgraph.sh -q "
		query {
			queryDomain( $args ) {
				name
			}
		}
	" > $query_result
	
	# Try to get domains. If it fails, print the query output to stderr
	if ! jq -r '.data.queryDomain | .[].name' $query_result 2>/dev/null; then
		>&2 jq -c '.' $query_result
	fi
fi
