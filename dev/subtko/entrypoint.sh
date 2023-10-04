#!/bin/bash

records=$(mktemp)
domains=$(mktemp)

scan_and_save(){
	input_file=$1
	args=$2
	output=$(mktemp)

	nuclei -l $input_file -stats -nh -rl 10 -no-stdin -j -o $output $args
}

while true; do

	$UTILS/wait_for_db.sh

	# Get CNAME values from 100 domains without the "lastExploit" field
	$UTILS/get_dnsrecords.sh -t CNAME -f 'not has(Domain.lastExploit)' -a 'first: 100' > $records
	# If all domains have "lastExploit", get 100 oldests that are at least older than 4 hours
	if [ ! -s $records ]; then
		$UTILS/get_dnsrecords.sh -t CNAME \
			-f "lt(Domain.lastExploit, $(date -Iseconds -d '-6 hours'))" \
			-a 'first: 100, orderasc: Domain.lastExploit' \
		> $records
	fi

	if [[ $DEBUG == "true" ]]; then
		>&2 echo "Will scan the following records:"
		>&2 cat $records
	fi

	if [ ! -s $records ]; then
		>&2 echo "WARNING: No records to scan. Trying again in 10 seconds."
		sleep 10
		continue
	fi

	# Get domains from records
	awk '{print $1}' $records | sort -u > $domains

	>&2 echo "Updating lastExploit field"
	$UTILS/save_domains.sh -f <(cat $domains | sed '1i name,lastExploit' | sed "s/$/,$(date -Iseconds)/") | jq -c .

	# Scan
	scan_and_save $domains '-t dns/detect-dangling-cname.yaml -t dns/*takeover*.yaml'

done
