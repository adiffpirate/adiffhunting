#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '>&2 $script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

usage="$(basename "$0") [-h|a|d]

Get vulns from DGraph.

flags:
	-h show this help text
	-p get vulns from the past '-p' time (e.g. '1 hour')
"

# Defaults
args=""

while getopts ":h?a:p:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		a) args=$OPTARG ;;
		p) past_time=$OPTARG ;;
	esac
done
# If an argument was passed but it was not the -p flag
if [ -n "$1" ] && [ -z "$past_time" ]; then
	echo "$usage"
	exit 1
fi

query_result=$(mktemp)
$script_path/query_dgraph.sh -o $query_result -t dql -q "{
	results(func: gt(Vuln.updatedAt, \"$(date -Iseconds -d "-$past_time")\")) {
		Vuln.name,
		Vuln.updatedAt,
		Vuln.description,
		Vuln.evidence { expand(_all_) }
		Vuln.references
	}
}"

jq -r '.data.results | .[]' $query_result
