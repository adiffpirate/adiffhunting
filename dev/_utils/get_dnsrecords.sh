#!/bin/bash

usage="$(basename "$0") [-h|t|a]

Get all dns records from DGraph using GraphQL \"queryDnsRecord\" function.
More info: https://dgraph.io/docs/graphql/queries

flags:
	-h show this help text
	-t filter by type (optional) (can be: 'A', 'AAAA', 'CNAME', 'NS', 'TXT', 'SRV', 'PTR', 'MX', 'SOA', 'CAA')
	-f additional filter
	-a args (optional)
"

# Defaults
args=""

while getopts ":h?a:t:f:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		a) args=$OPTARG ;;
		t) record_type=$(echo $OPTARG | tr '[:lower:]' '[:upper:]');;
		f) filter=$OPTARG ;;
	esac
done
# If an argument was passed but it was not the -t flag
if [ -n "$1" ] && [ -z "$record_type" ]; then
	echo "$usage"
	exit 1
fi

script_path=$(dirname "$0")
query_result=$(mktemp)

$script_path/query_dgraph.sh -q "
	query {
		queryDnsRecord (
			filter: {
				and: [
					$(if [ -n "$record_type" ]; then echo "{ type: { eq: \"$record_type\" } },"; fi)
					$(if [ -n "$filter" ]; then echo "$filter,"; fi)
					{ has: values }
				]
			},
			$args
		){
			domain { name },
			type,
			values
		}
	}
" > $query_result

# Try to get domains. If it fails, print the query output to stderr
if ! jq -r '.data.queryDnsRecord | .[] | .domain.name as $domain | .type as $type | .values | .[] | [$domain, $type, .] | join(" ")' $query_result 2>/dev/null; then
	>&2 jq -c '.' $query_result
fi
