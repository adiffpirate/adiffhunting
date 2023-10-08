#!/bin/bash

usage="$(basename "$0") [-h|a|f|d]

Get domains from DGraph using DQL

flags:
	-h show this help text
	-a args (optional)
	-f filter (optional)
	-d get all domains below passed domain (optional)
"

while getopts ":h?a:f:d:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		a) args=$OPTARG ;;
		f) filter=$OPTARG ;;
		d) domain=$OPTARG ;;
	esac
done

script_path=$(dirname "$0")
query_result=$(mktemp)

if [ -n "$domain" ]; then
	regex_filter="regexp(Domain.name, /^.*\\\\.$domain$/)"
	if [ -n "$filter" ]; then
		filter="$regex_filter and $filter"
	else
		filter="$regex_filter"
	fi
fi

$script_path/query_dgraph.sh -t dql -q "
	{
		results(func: ge(Domain.level, 2) $(if [ -n "$args" ]; then echo ",$args"; fi))
		@filter(not eq(Domain.skipScans, true) $(if [ -n "$filter" ]; then echo "and $filter"; fi))
		{
			Domain.name
		}
	}
" > $query_result

# Try to get domains. If it fails, print the query output to stderr
jq -c -r '.data.results | .[] | ."Domain.name"' $query_result 2>/dev/null || >&2 jq -c '.' $query_result
