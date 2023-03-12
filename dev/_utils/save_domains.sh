#!/bin/bash

usage="$(basename "$0") [-h|f|t]

Save domains in DGraph

flags:
	-h show this help text
	-f csv file containg domains (file should have at least the 'name' header)
	-t tool that discovered all domains (optional)
"

while getopts ":h?f:t:s:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		f) domains_csv_file=$OPTARG ;;
		t) tool=$OPTARG ;;
	esac
done
if [ -z "$domains_csv_file" ]; then
	echo "$usage"
	exit 1
fi

script_path=$(dirname "$0")

domains_json_file=/tmp/save_domains_$(date -Iseconds).json

# Write JSON from domains file
python3 $script_path/parse_domains.py -f "$domains_csv_file" -t "$tool" | jq -c . > $domains_json_file

# For each level
jq '.[] | .level' $domains_json_file | sort -n -u | while read level; do
	# Get domains which level equals $level
	input=$(jq -c "[.[] | select(.level == $level)]" $domains_json_file)
	# Write query to file using input above
	query_file=/tmp/query_$(date -Iseconds).graphql
	echo "
		mutation {
			addDomain(input: $input, upsert: true){
				domain {
					name
				}
			}
		}
	" > $query_file

	if [[ $DEBUG == "true" ]]; then
		>&2 echo "[save_domains.sh] $(cat $query_file)"
	fi

	# Send query to database
	$script_path/query_dgraph.sh -f "$query_file" | jq .
done

rm $domains_json_file
