#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '>&2 $script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

usage="$(basename "$0") [-h|q|f|t]

Query DGraph database.

flags:
	-h show this help text
	-q query
	-f query stored in file (mutually exclusive with -q)
	-t query type (optional) (can be: graphql or dql) (defaults to graphql)
	-o output file (optional) (defaults to none)
"

# Defaults
query_type="graphql"

while getopts ":h?q:f:t:o:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		q) arg_query=$OPTARG ;;
		f) query_file=$OPTARG ;;
		t) query_type=$OPTARG ;;
		o) output=$OPTARG ;;
	esac
done
if [ -z "$arg_query" ] && [ -z "$query_file" ]; then
	echo "$usage"
	exit 1
fi

if [ -z "$DGRAPH_ALPHA_HOST" ]; then
	>&2 echo "Please configure the DGRAPH_ALPHA_HOST environment variable"
	exit 1
fi
if [ -z "$DGRAPH_ALPHA_HTTP_PORT" ]; then
	>&2 echo "Please configure the DGRAPH_ALPHA_HTTP_PORT environment variable"
	exit 1
fi

# If output was not defined, use temp file
if [ -z "$output" ]; then
	output=$(mktemp)
fi

if [ -n "$arg_query" ]; then
	initial_query=$arg_query
else
	initial_query=$(cat $query_file)
fi

# Prepare query
#   1. Remove return/tab chars
#   2. Turn into one line string
#   3. Remove quotes from keys
query=$(echo "$initial_query" | sed 's/\\n//g' | sed 's/\\t//g' | sed 's/\\r//g' | while read line; do echo -n "$line"; done | sed -E 's/"([^"]*)":/\1:/g')

# Prepare request
if [[ "$query_type" == "graphql" ]] ; then
	body="{\"query\":\"$(echo $query | sed 's/"/\\"/g')\"}"
	content_type="application/json"
	path="graphql"
elif [[ "$query_type" == "dql" ]]; then
	body=$query
	# Set content type and path based on body
	if [[ "$body" =~ ^( )*(upsert) ]]; then
		content_type="application/rdf"
		path="mutate?commitNow=true"
	else
		content_type="application/dql"
		path="query?ro=true"
	fi
else
	echo "$usage"
	exit 1
fi

# Save body to file
body_file=$(mktemp) && echo "$body" > $body_file

$script_path/_log.sh 'debug' 'Querying database' "query=$body"

# Get start time
start_time=$(date +%s%3N)

until curl --no-progress-meter --fail \
	$DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/$path \
	--header "Content-Type: $content_type" \
	--data "@$body_file" \
; do
		$script_path/_log.sh 'info' 'Unable to reach database. Retrying in 5 seconds'
		sleep 5
done > $output

# Parse output
if [[ "$(jq 'has("errors")' $output)" == "true" ]]; then
	$script_path/_log.sh 'error' 'Database query returned errors' "query_result=$(cat $output)"
else
	$script_path/_log.sh 'debug' 'Database query successful' "query_result=$(cat $output)"
fi

# Get end time
end_time=$(date +%s%3N)
# Calculate timespan
timespan=$((end_time - start_time))
