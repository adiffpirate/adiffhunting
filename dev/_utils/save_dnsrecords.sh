#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '$script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

usage="$(basename "$0") [-h|f]

Save dns records in DGraph

flags:
	-h show this help text
	-f csv file (delimited by pipe) containg dns records (must have headers: domain|type|values)
"

while getopts ":h?f:t:s:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		f) records_csv_file=$OPTARG ;;
	esac
done
if [ -z "$records_csv_file" ] || [[ "$(head -n1 $records_csv_file)" != "domain|type|values" ]]; then
	echo "$usage"
	exit 1
fi

now=$(date -Iseconds)

# Parse CSV
records_json_file=/tmp/records_file_$now.json
echo '[]' > $records_json_file
tail -n '+2' $records_csv_file | while read line; do
	# Get vars
	domain=$(echo "$line" | awk -F'|' '{print $1}')
	record_type=$(echo "$line" | awk -F'|' '{print $2}' | tr '[:lower:]' '[:upper:]')
	values=$(echo "$line" | awk -F'|' '{print $3}')
	# Append to list of JSONs
	list="$(jq ". += [
		{
			\"name\": \"$record_type: $domain\",
			\"domain\": { \"name\": \"$domain\" },
			\"type\": \"$record_type\",
			\"values\": $values,
			\"updatedAt\": \"$now\"
		}
	]" $records_json_file)"
	echo -E "$list" > $records_json_file
done

query_file=/tmp/query_$(date -Iseconds).graphql
echo "
	mutation {
		addDnsRecord(input: $(cat $records_json_file), upsert: true){
			dnsRecord {
				domain {
					name
				},
				type,
				values
			}
		}
	}
" > $query_file

if [[ "$DEBUG" == "true" ]]; then
	>&2 echo "[save_dnsrecord.sh] cat $query_file"
fi

$script_path/query_dgraph.sh -f $query_file
