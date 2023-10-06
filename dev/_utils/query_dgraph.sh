#!/bin/bash

usage="$(basename "$0") [-h|q|f|t]

Query DGraph database.

flags:
	-h show this help text
	-q query
	-f query stored in file (mutually exclusive with -q)
	-t query type (optional) (can be: graphql or dql) (defaults to graphql)
"

# Defaults
query_type="graphql"

while getopts ":h?q:f:t:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		q) arg_query=$OPTARG ;;
		f) query_file=$OPTARG ;;
		t) query_type=$OPTARG ;;
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

if [[ $DEBUG == "true" ]]; then
	>&2 echo "[query_dgraph.sh] $query"
fi

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

# Send request
body_file=$(mktemp) && echo "$body" > $body_file
curl --silent $DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/$path \
	--header "Content-Type: $content_type" \
	--data "@$body_file" \
| jq .
