#!/bin/bash

usage="$(basename "$0") [-h|t|a]

Get all dns records from DGraph using GraphQL \"queryDnsRecord\" function.
More info: https://dgraph.io/docs/graphql/queries

flags:
	-h show this help text
	-t filter by type (optional) (can be: 'A', 'AAAA', 'CNAME', 'NS', 'TXT', 'SRV', 'PTR', 'MX', 'SOA', 'CAA')
	-f domain filter (optional)
	-a args to add on function invocation (optional)
"

# Defaults
args=""

while getopts ":h?t:f:a:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		a) args=$OPTARG ;;
		t) record_type=$(echo $OPTARG | tr '[:lower:]' '[:upper:]');;
		f) filter=$OPTARG ;;
		a) args=$OPTARG ;;
	esac
done
# If an argument was passed but it was not the -t flag
if [ -n "$1" ] && [ -z "$record_type" ]; then
	echo "$usage"
	exit 1
fi

script_path=$(dirname "$0")
query_result=$(mktemp)

$script_path/query_dgraph.sh -t dql -q "
	{
		record as f(func: has(DnsRecord.values))
		$(if [ -n "$record_type" ]; then echo "@filter(eq(DnsRecord.type, \"$record_type\"))"; fi)
		{
			domain as DnsRecord.domain
		}

		results(func: uid(domain) $(if [ -n "$args" ]; then echo ",$args"; fi))
		$(if [ -n "$filter" ]; then echo "@filter($filter)"; fi)
		{
			Domain.name,
			Domain.dnsRecords @filter(uid(record)) {
				DnsRecord.type, DnsRecord.values
			}
		}
	}
" > $query_result

# Try to parse records from output. If it fails, print the whole query output to stderr
if ! jq -r '.data.results | .[] | ."Domain.name" as $domain | ."Domain.dnsRecords" | .[] | ."DnsRecord.type" as $type | ."DnsRecord.values" | .[] | [$domain, $type, .] | join(" ")' $query_result 2>/dev/null; then
	>&2 jq -c '.' $query_result
fi
