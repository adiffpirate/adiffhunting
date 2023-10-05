#!/bin/bash

resolve(){
	domains_file=$1
	record_type=$2

	# Get updated list of resolvers once a day
	resolvers_file=/tmp/resolvers.txt
	if [ ! -s $resolvers_file || $(($(date +%s)-$(date +%s -r $resolvers_file || echo 86401))) -gt 86400 ]; then
		>&2 wget https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt -O $resolvers_file
	fi
	# Abort if resolvers file is empty (probably the download didn't succeed for some reason)
	if [ ! -s $resolvers_file ]; then
		>&2 "Resolvers file is empty. Aborting."
		rm -f $resolvers_file
		exit 1
	fi

	# Run DNSX
	dnsx -list $domains_file -resolver $resolvers_file -silent -resp -threads 10 -json -$record_type
}

resolve_and_save(){
	domains_file=$1
	record_type=$2
	tmp_file=$(mktemp)

	# Init CSV file
	dns_records_csv=/tmp/dns_records_$record_type.csv
	echo 'domain|type|values' > $dns_records_csv

	# Resolve domains and write records to CSV file
	resolve "$domains_file" "$record_type" | while read line; do
		# Saves line to temp file escaping quotes inside values (run sed twice to handle overlapping matches)
		sed_pattern='s/([-_=+~;.!@#$%&*^" a-zA-Z0-9])"([-_=+~;.!@#$%&*^" a-zA-Z0-9])/\1\\"\2/g'
		echo "$line" | sed -E "$sed_pattern" | sed -E "$sed_pattern" > $tmp_file
		# Write record to CSV file
		domain=$(jq -c -r '.host' $tmp_file || cat $tmp_file >&2)
		values=$(jq -c -r ".$record_type // []" $tmp_file || bash -c "echo '[]' && cat $tmp_file >&2")
		echo "$domain|$record_type|$values" >> $dns_records_csv
	done

	# Save records on database
	$UTILS/save_dnsrecords.sh -f $dns_records_csv | jq -c .
}

domains_file=/tmp/domains.txt

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
	' > $domains_file

	# If all domains have "lastProbe", get the 100 oldest
	if [ ! -s $domains_file ]; then
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
		' > $domains_file
	fi

	if [[ $DEBUG == "true" ]]; then
		>&2 echo "Will probe the following domains:"
		>&2 cat $domains_file
	fi

	if [ ! -s $domains_file ]; then
		>&2 echo "WARNING: Unable to get domains to probe. Trying again in 10 seconds."
		sleep 10
		continue
	fi

	>&2 echo "Updating lastProbe field"
	$UTILS/save_domains.sh -f <(cat $domains_file | sed '1i name,lastProbe' | sed "s/$/,$(date -Iseconds)/") | jq -c .

	>&2 echo "Starting: DNSX"
	for record_type in 'a' 'aaaa' 'cname' 'ns' 'txt' 'srv' 'ptr' 'mx' 'soa' 'caa'; do
		>&2 echo "Running: DNSX for $(echo $record_type | tr '[:lower:]' '[:upper:]') record type"
		resolve_and_save $domains_file $record_type
	done

done
