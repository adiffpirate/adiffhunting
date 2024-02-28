#!/bin/bash
set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

resolve(){
	domains=$1
	record_type=$2
	record_type_uppercase=$(echo "$record_type" | tr '[:lower:]' '[:upper:]')

	# Get updated list of resolvers once a day
	resolvers_file=/tmp/resolvers.txt
	if [ $(($(date +%s)-$(date +%s -r $resolvers_file || echo 86401))) -gt 86400 ]; then
		$UTILS/_log.sh 'info' 'Downloading resolvers file'
		curl --no-progress-meter --fail https://raw.githubusercontent.com/trickest/resolvers/main/resolvers.txt > $resolvers_file
	fi

	# Sed pattern to escape quotes inside values
	sed_pattern='s/([-_=+~;.!@#$%&*^" a-zA-Z0-9])"([-_=+~;.!@#$%&*^" a-zA-Z0-9])/\1\\"\2/g'

	# Run DNSX and print its output as JSON Lines according to database schema
	dnsx -list $domains -resolver $resolvers_file -silent -omit-raw -threads 10 -json -$record_type \
	| while read line; do
		$UTILS/_log.sh 'debug' 'Parsing DNS record' "record=$line"
		# Run sed pattern twice to handle overlapping matches.
		# Also run another sed to handle wronfully escaped "@" chars
		echo "$line" | sed -E "$sed_pattern" | sed -E "$sed_pattern" | sed 's/\\@/@/g' | jq -c "{
			name: ( \"$record_type_uppercase: \" + .host ),
			domain: { name: .host },
			type: \"$record_type_uppercase\",
			values: ( .\"$record_type\" // [] ),
			updatedAt: .timestamp
		}" || $UTILS/_log.sh 'error' 'Error while parsing DNS record' "record=$line"
	done
}

resolve_and_save(){
	domains=$1
	record_type=$2

	# Resolve and save records on database, one at a time
	resolve $domains $record_type | while read line; do
		$UTILS/query_dgraph.sh -q "
			mutation {
				addDnsRecord(input: [$line], upsert: true){
					dnsRecord { name, values }
				}
			}
		"
	done
}

domains=$(mktemp)

while true; do
	$UTILS/op_start.sh

	# Get 100 domains without the "lastProbe" field ordered by level so that higher levels are scanned first
	$UTILS/get_domains.sh -f 'not has(Domain.lastProbe)' -a 'orderasc: Domain.level, first: 100' > $domains
	# If all domains have "lastProbe", get the 100 oldest
	if [ ! -s "$domains" ]; then
		$UTILS/get_domains.sh -a 'orderasc: Domain.lastProbe, first: 100' > $domains
	fi

	if [ ! -s "$domains" ]; then
		$UTILS/_log.sh 'info' "No domains to probe. Trying again in 10 seconds"
		sleep 10
		continue
	fi

	$UTILS/_log.sh 'info' 'Updating lastProbe field' "domains=$(cat $domains)"
	cat $domains | while read domain; do
		$UTILS/query_dgraph.sh -q "
			mutation {
				updateDomain(input: {
					filter: { name: { eq: \"$domain\" } },
					set: { lastProbe: \"$(date -Iseconds)\"} }
				){
					domain { name }
				}
			}
		" > /dev/null
	done

	for record_type in 'a' 'aaaa' 'cname' 'ns' 'txt' 'srv' 'ptr' 'mx' 'soa' 'caa'; do
		$UTILS/_log.sh 'info' 'Running: DNSX' "record_type=$(echo $record_type | tr '[:lower:]' '[:upper:]')"
		resolve_and_save $domains $record_type
	done

	$UTILS/op_end.sh
done
