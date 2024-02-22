#!/bin/bash
set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

get_domain(){
	filter='anyofterms(Domain.type, "root sub")'

	# PRIO 1: Get a rootdomain without the "lastPassiveEnumeration" field
	domain=$($UTILS/get_domains.sh -f 'eq(Domain.type, "root") and not has(Domain.lastPassiveEnumeration)' -a 'first: 1')

	# PRIO 2: Get a rootdomain whose "lastPassiveEnumeration" is older than $ROOTDOMAIN_SCAN_COOLDOWN
	if [ -z "$domain" ]; then
		domain=$($UTILS/get_domains.sh -f "eq(Domain.type, \"root\") and lt(Domain.lastPassiveEnumeration, \"$(date -Iseconds -d "-$ROOTDOMAIN_SCAN_COOLDOWN")\")" -a 'first: 1')
	fi

	# PRIO 3: Get a subdomain without the "lastPassiveEnumeration" field ordered by level so that higher levels are scanned first
	if [ -z "$domain" ]; then
		domain=$($UTILS/get_domains.sh -f 'eq(Domain.type, "sub") and not has(Domain.lastPassiveEnumeration)' -a 'orderasc: Domain.level, first: 1')
	fi

	# PRIO 4: Get a subdomain with the oldest "lastPassiveEnumeration"
	if [ -z "$domain" ]; then
		domain=$($UTILS/get_domains.sh -f 'eq(Domain.type, "sub")' -a 'orderasc: Domain.lastPassiveEnumeration, first: 1')
	fi

	if [ -z "$domain" ]; then
		$UTILS/_log.sh 'info' 'No domains to enumerate. Trying again in 10 seconds'
		sleep 10
		return
	fi

	$UTILS/_log.sh 'info' 'Updating lastPassiveEnumeration field' "domain=$domain"
	$UTILS/query_dgraph.sh -q "
		mutation {
			updateDomain(input: {
				filter: { name: { eq: \"$domain\" } },
				set: { lastPassiveEnumeration: \"$(date -Iseconds)\"} }
			){
				domain { name }
			}
		}
	" > /dev/null

	echo $domain
}


run(){
	tool=$1
	domain=$2

	if [[ "$tool" == "subfinder" ]]; then
		subfinder -silent -d $domain
	elif [[ "$tool" == "chaos" ]] && [ -n "$CHAOS_KEY" ]; then
		# Chaos doesn't accept domains which levels are greater than 2, so we strip the domain and filter the results
		chaos -silent -d $(echo $domain | grep -Eo '[^.]+\.[^.]+$') | sed -n "/^.*\.$domain$/p"
	fi
}

run_and_save(){
	tool=$1
	domain=$2

	if [ -z "$domain" ]; then
		$UTILS/_log.sh 'info' 'Skipping since no domain was provided'
		return
	fi

	subdomains_csv_file=/tmp/subdomains_$tool.csv

	echo 'name' > $subdomains_csv_file
	run $tool $domain >> $subdomains_csv_file
	>&2 $UTILS/save_domains.sh -f $subdomains_csv_file -t "$tool:passive"
}

while true; do

	export OP_ID=$(uuidgen -r)
	$UTILS/wait_for_db.sh

	domain=$(get_domain)

	$UTILS/_log.sh 'info' 'Running: Subfinder'
	run_and_save subfinder $domain

	$UTILS/_log.sh 'info' 'Running: Chaos'
	run_and_save chaos $domain

done
