#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '>&2 $script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

usage="$(basename "$0") [-h|t|a]

Get all dns records from DGraph using DQL

flags:
	-h show this help text
	-t filter by types (delimited by space) (optional) (can be: 'A', 'AAAA', 'CNAME', 'NS', 'TXT', 'SRV', 'PTR', 'MX', 'SOA', 'CAA')
	-f domain filter (optional)
	-a args to add on function invocation (optional)
"

# Defaults
args=""

while getopts ":h?t:f:a:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		a) args=$OPTARG ;;
		t) record_types=$(echo $OPTARG | tr '[:lower:]' '[:upper:]');;
		f) filter=$OPTARG ;;
		a) args=$OPTARG ;;
	esac
done
# If an argument was passed but it was not the -t flag
if [ -n "$1" ] && [ -z "$record_types" ]; then
	echo "$usage"
	exit 1
fi

query_result=$(mktemp)

$script_path/query_dgraph.sh -o $query_result -t dql -q "
	{
		record as f(func: has(DnsRecord.values))
		$(if [ -n "$record_types" ]; then echo "@filter(anyofterms(DnsRecord.type, \"$record_types\"))"; fi)
		{
			domain as DnsRecord.domain
		}

		results(func: uid(domain) $(if [ -n "$args" ]; then echo ",$args"; fi))
		@filter(not eq(Domain.skipScans, true) $(if [ -n "$filter" ]; then echo "and $filter"; fi))
		{
			Domain.name,
			Domain.dnsRecords @filter(uid(record)) {
				DnsRecord.type, DnsRecord.values
			}
		}
	}
"

# Try to parse records from output. If it fails, print the whole query output to stderr
jq -c -r '.data.results | .[] | ."Domain.name" as $domain | ."Domain.dnsRecords" | .[] | ."DnsRecord.type" as $type | ."DnsRecord.values" | .[] | [$domain, $type, .] | join(" ")' $query_result 2>/dev/null || >&2 jq -c '.' $query_result
