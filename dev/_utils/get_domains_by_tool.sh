#!/bin/bash

usage="$(basename "$0") [-h|t|a|u]

Get all domains found by tool (-t) from DGraph using GraphQL \"queryTool\" function.
More info: https://dgraph.io/docs/graphql/queries

flags:
	-h show this help text
	-t tool
	-a args (optional)
	-u return only domains that are unique to that tool (optional) (defaults to false)
"

# Defaults
args=""
unique="false"

while getopts ":h?a:t:u:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		a) args=$OPTARG ;;
		t) tool=$OPTARG ;;
		u) unique=$OPTARG ;;
	esac
done
if [ -z "$tool" ]; then
	echo "$usage"
	exit 1
fi

script_path=$(dirname "$0")

get_domains(){
	$script_path/query_dgraph.sh -q "
		query {
			queryTool ( $1 ) {
				subdomains { name }
			}
		}
	" | jq -r '(.data.queryTool // [] | .[].subdomains // [] | .[].name) // .'
}

if [[ "$unique" == "true" ]]; then
	# Get domains discovered by other tools
	domains_other_tools_file=$(mktemp)
	get_domains "filter: { not: { name: { eq: \"$tool\" } } }, $args" > $domains_other_tools_file
	# Get domains discovered by tool
	domains_tool_file=$(mktemp)
	get_domains "filter: { name: { eq: \"$tool\" } }, $args" > $domains_tool_file
	# Print unique domains (https://stackoverflow.com/a/4717415)
	awk 'FNR==NR {a[$0]++; next} !($0 in a)' $domains_other_tools_file $domains_tool_file
else
	# Get domains discovered by tool
	get_domains "filter: { name: { eq: \"$tool\" } }, $args"
fi
