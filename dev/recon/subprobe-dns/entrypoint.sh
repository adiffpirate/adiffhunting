#!/bin/bash

resolve(){
	domains=$1
	record_type=$2
	dnsx_output=$3

	# Get updated list of resolvers once a day
	resolvers_file=/tmp/resolvers.txt
	if [ $(($(date +%s)-$(date +%s -r $resolvers_file || echo 86401))) -gt 86400 ]; then
		>&2 wget https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt -O $resolvers_file
	fi
	# Abort if resolvers file is empty (probably the download didn't succeed for some reason)
	if [ ! -s $resolvers_file ]; then
		>&2 "Resolvers file is empty. Aborting."
		rm -f $resolvers_file
		exit 1
	fi

	# Run DNSX
	dnsx \
		-list $domains -resolver $resolvers_file \
		-silent -omit-raw -threads 10 \
		-json -$record_type -o $dnsx_output
}

resolve_and_save(){
	domains=$1
	record_type=$2

	output=$(mktemp)
	resolve "$domains" "$record_type" "$output"

	# Save records on database
	if [ -s $output ]; then
		query_file=$(mktemp)
		echo "
			mutation {
				addDnsRecord(input: $(cat $output | parse_output | jq -s), upsert: true){
					dnsRecord { name, values }
				}
			}
		" > $query_file
		$UTILS/query_dgraph.sh -f $query_file | jq -c .
	fi
}

# Print output in JSON Lines format
parse_output(){
	record_type=$1
	record_type_uppercase=$(echo "$record_type" | tr '[:lower:]' '[:upper:]')

	# Sed pattern to escape quotes inside values
	sed_pattern='s/([-_=+~;.!@#$%&*^" a-zA-Z0-9])"([-_=+~;.!@#$%&*^" a-zA-Z0-9])/\1\\"\2/g'
	while read line; do
		# Run sed pattern twice to handle overlapping matches.
		# Also run another sed to handle wronfully escaped "@" chars
		echo "$line" | sed -E "$sed_pattern" | sed -E "$sed_pattern" | sed 's/\\@/@/g' | jq -c "{
			name: ( \"$record_type_uppercase: \" + .host ),
			domain: { name: .host },
			type: \"$record_type_uppercase\",
			values: .\"$record_type\",
			updatedAt: .timestamp
		}" || >&2 echo "Error while processing: $line"
	done
}

domains=$(mktemp)

while true; do

	$UTILS/wait_for_db.sh

	# Get 100 domains without the "lastProbe" field
	$UTILS/get_domains.sh -a '
		filter: {
			and: [
				{ not: { skipScans: true } },
				{ not: { has: lastProbe } },
				{ level: { ge: 2 } }
			]
		},
		first: 100
	' > $domains

	# If all domains have "lastProbe", get the 100 oldest
	if [ ! -s $domains ]; then
		$UTILS/get_domains.sh -a '
			filter: {
				and: [
					{ not: { skipScans: true } },
					{ level: { ge: 2 } }
				]
			},
			order: {
				asc: lastProbe
			},
			first: 100
		' > $domains
	fi

	if [[ $DEBUG == "true" ]]; then
		echo "Will probe the following domains:"
		cat $domains
	fi

	if [ ! -s $domains ]; then
		echo "No domains to probe. Trying again in 10 seconds."
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
