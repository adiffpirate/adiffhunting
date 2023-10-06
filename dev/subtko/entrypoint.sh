#!/bin/bash

nuclei_scan(){
	nuclei_input=$1
	nuclei_output=$2
	nuclei_args=$3

	# Get updated list of resolvers once a day
	resolvers=/tmp/resolvers.txt
	if [ $(($(date +%s)-$(date +%s -r $resolvers || echo 86401))) -gt 86400 ]; then
		wget https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt -O $resolvers
	fi
	# Abort if resolvers file is empty (probably the download didn't succeed for some reason)
	if [ ! -s $resolvers ]; then
		>&2 "Resolvers file is empty. Aborting."
		rm -f $resolvers
		exit 1
	fi

	nuclei \
		-list $nuclei_input -output $nuclei_output -jsonl \
		-no-stdin -resolvers $resolvers -no-httpx \
		-concurrency 1 -rate-limit 10 -silent \
		$nuclei_args

	if [ ! -s $nuclei_output ]; then
		echo "Nothing was found."
	fi
}

dangling_cname_scan(){
	input=$1
	output=$2

	# Scan with nuclei
	unrefined_output=$(mktemp)
	nuclei_scan $input $unrefined_output '-t dns/detect-dangling-cname.yaml'

	# Get unique list of domains from dangling cnames findings
	domains=$(mktemp)
	cat $unrefined_output | while read line; do
		cname=$(echo $line | jq -r '."extracted-results"[0]' | sed 's/\.$//')
		# Get domain using the tld list file
		echo $cname | egrep -o "[^.]+\.($(xargs -a /src/tld-list.txt | sed 's/ /|/g'))(\.[^.]+)?$" >> $domains
	done
	sort -u $domains -o $domains

	if [[ $DEBUG == "true" ]]; then
		echo "Will check the following domains availability:"
		cat $domains
	fi

	# For each domain
	cat $domains | while read domain; do
		# Check if is available to claim
		echo -n "Checking if $domain is available: "
		if whois $domain 2>/dev/null | grep -i 'no match\|not found' > /dev/null; then
			echo "YES"
			# Add to output all dangling cname findings from nuclei with this domain
			jq -c "select(.\"extracted-results\"[0] | test(\"$domain(.)?$\"))" $unrefined_output 2>/dev/null >> $output
		else
			echo "NO"
		fi
	done
}

scan_and_save(){
	scan=$1
	input=$2
	args=$3

	# Scan
	output=$(mktemp)
	$scan $input $output $args

	# Save vulns on database
	if [ -s $output ]; then
		query_file=$(mktemp)
		echo "
			mutation {
				addVuln(input: $(cat $output | parse_output | jq -s), upsert: true){
					vuln { name }
				}
			}
		" > $query_file
		$UTILS/query_dgraph.sh -f $query_file | jq -c .
	fi
}

parse_output(){
	while read line; do
		echo $line | jq -c '{
			"name": ( .info.name + ": " + ."matched-at" ),
			"domain": { "name": ."matched-at" },
			"title": .info.name,
			"class": { "name": "subdomain takeover" },
			"description": .info.description,
			"severity": .info.severity,
			"references": .info.reference,
			"evidence": { "target": ."extracted-results"[0], "request": .request, "response": .response },
			"foundBy": [ { "name": "nuclei", "type": "exploit" } ],
			"updatedAt": .timestamp
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
			-f "not eq(Domain.skipScans, true) and lt(Domain.lastExploit, \"$(date -Iseconds -d "-$DOMAIN_SCAN_COOLDOWN")\")" \
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

	# Scan for dangling cname
	>&2 echo "Starting: Dangling CNAME Scan"
	scan_and_save 'dangling_cname_scan' $domains

done
