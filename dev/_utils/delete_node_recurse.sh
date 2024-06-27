#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '>&2 $script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

usage="$(basename "$0") [-h|f|c|d]

Delete domain from DGraph database.

flags:
	-h show this help text
	-f filter
	-c children to delete
	-d domain (takes precedence over -f and -c)
	-v vuln (takes precedence over -f and -c)
"

while getopts ":h?f:c:d:v:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		f) filter=$OPTARG ;;
		c) children=$OPTARG ;;
		d) domain=$OPTARG ;;
		v) vuln=$OPTARG ;;
	esac
done

if [ -n "$domain" ]; then
	filter="eq(Domain.name, \"$domain\")"
	children='Domain.subdomains, Domain.dnsRecords, Domain.vulns'
elif [ -n "$vuln" ]; then
	filter="eq(Vuln.name, \"$vuln\")"
	children='Vuln.evidence'
fi

if [ -n "$filter" ] && [ -n "$children" ]; then
	echo "$usage"
	exit 1
fi

$script_path/query_dgraph.sh -t dql -q "
	upsert {
		query {
			q(func: $filter) @recurse @normalize {
				all_ids as uid,
				$children
			}
		}
		
		mutation {
			delete {
				uid(all_ids) * * .
			}
		}
	}
"
