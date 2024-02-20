#!/bin/bash
set -eEo pipefail
trap '>&2 $UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

resolve(){
	domains=$1
	record_type=$2
	record_type_uppercase=$(echo "$record_type" | tr '[:lower:]' '[:upper:]')

	# Get updated list of resolvers once a day
	resolvers_file=/tmp/resolvers.txt
	if [ $(($(date +%s)-$(date +%s -r $resolvers_file || echo 86401))) -gt 86400 ]; then
		>&2 echo "Downloading resolvers file"
		curl --no-progress-meter --fail https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt > $resolvers_file
	fi

	# Sed pattern to escape quotes inside values
	sed_pattern='s/([-_=+~;.!@#$%&*^" a-zA-Z0-9])"([-_=+~;.!@#$%&*^" a-zA-Z0-9])/\1\\"\2/g'

	output_json_lines=$(mktemp)
	# Run DNSX and parse its output as JSON Lines according to database schema
	dnsx -list $domains -resolver $resolvers_file -silent -omit-raw -threads 10 -json -$record_type \
	| while read line; do
		if [[ "$DEBUG" == "true" ]]; then >&2 echo "Processing record: $line"; fi
		# Run sed pattern twice to handle overlapping matches.
		# Also run another sed to handle wronfully escaped "@" chars
		echo "$line" | sed -E "$sed_pattern" | sed -E "$sed_pattern" | sed 's/\\@/@/g' | jq -c "{
			name: ( \"$record_type_uppercase: \" + .host ),
			domain: { name: .host },
			type: \"$record_type_uppercase\",
			values: ( .\"$record_type\" // [] ),
			updatedAt: .timestamp
		}" || >&2 echo "Error while processing record: $line"
	done > $output_json_lines

	# Print JSON Lines as JSON Array
	cat $output_json_lines | jq -s
}

resolve_and_save(){
	domains=$1
	record_type=$2

	output=$(mktemp)
	resolve $domains $record_type > $output

	# Save records on database
	if [ -s "$output" ]; then
		query_file=$(mktemp)
		echo "
			mutation {
				addDnsRecord(input: $(cat $output), upsert: true){
					dnsRecord { name, values }
				}
			}
		" > $query_file
		>&2 $UTILS/query_dgraph.sh -f $query_file
	else
		>&2 echo "Nothing found"
	fi
}

domains=$(mktemp)

while true; do

	$UTILS/wait_for_db.sh

	# Get 100 domains without the "lastProbe" field
	$UTILS/get_domains.sh -f 'not has(Domain.lastProbe)' -a 'first: 100' > $domains
	# If all domains have "lastProbe", get the 100 oldest
	if [ ! -s "$domains" ]; then
		$UTILS/get_domains.sh -a 'orderasc: Domain.lastProbe, first: 100' > $domains
	fi

	if [[ "$DEBUG" == "true" ]]; then
		echo "Will probe the following domains:"
		cat $domains
	fi

	if [ ! -s "$domains" ]; then
		echo "No domains to probe. Trying again in 10 seconds"
		sleep 10
		continue
	fi

	echo "Updating lastProbe field"
	$UTILS/save_domains.sh -f <(cat $domains | sed '1i name,lastProbe' | sed "s/$/,$(date -Iseconds)/") | jq -c .

	echo "Starting: DNSX"
	for record_type in 'a' 'aaaa' 'cname' 'ns' 'txt' 'srv' 'ptr' 'mx' 'soa' 'caa'; do
		echo "Running: DNSX for $(echo $record_type | tr '[:lower:]' '[:upper:]') record type"
		resolve_and_save $domains $record_type
	done

done
