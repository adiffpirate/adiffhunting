#!/bin/bash

scan_and_save(){
	domains=$1
	args=$2

	# Scan with nuclei
	nuclei_output=$(mktemp)
	nuclei -l $domains -stats -nh -rl 10 -no-stdin -j -o $nuclei_output $args

	# Save vulns on database
	if [ -s $nuclei_output ]; then
		query_file=$(mktemp)
		echo "
			mutation {
				addVuln(input: $(cat $nuclei_output | parse_nuclei_output | jq -s), upsert: true){
					vuln { name }
				}
			}
		" > $query_file
		$UTILS/query_dgraph.sh -f $query_file | jq -c .
	fi
}

parse_nuclei_output(){
	while read line; do
		echo $line | jq -c '{
			"name": ( .info.name + ": " + ."matched-at" ),
			"domain": { "name": ."matched-at" },
			"title": .info.name,
			"class": { "name": "subdomain takeover" },
			"description": .info.description,
			"severity": .info.severity,
			"references": .info.reference,
			"evidence": { "results": ."extracted-results", "request": .request, "response": .response },
			"foundBy": [ { "name": "nuclei", "type": "exploit" } ],
			"updatedOn": .timestamp
		}'
	done
}

while true; do

	$UTILS/wait_for_db.sh

	# Get CNAME values from 100 domains without the "lastExploit" field
	records=$(mktemp)
	$UTILS/get_dnsrecords.sh -t CNAME -f 'not eq(Domain.skipScans, true) and not has(Domain.lastExploit)' -a 'first: 100' > $records
	# If all domains have "lastExploit", get 100 oldests that are at least older than 4 hours
	if [ ! -s $records ]; then
		$UTILS/get_dnsrecords.sh -t CNAME \
			-f "not eq(Domain.skipScans, true) and lt(Domain.lastExploit, \"$(date -Iseconds -d '-6 hours')\")" \
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
	domains=$(mktemp)
	awk '{print $1}' $records | sort -u > $domains

	>&2 echo "Updating lastExploit field"
	$UTILS/save_domains.sh -f <(cat $domains | sed '1i name,lastExploit' | sed "s/$/,$(date -Iseconds)/") | jq -c .

	# Scan
	scan_and_save $domains '-t dns/detect-dangling-cname.yaml -t dns/*takeover*.yaml'

done
