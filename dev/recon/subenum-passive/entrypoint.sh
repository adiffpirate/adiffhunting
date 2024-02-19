#!/bin/bash
set -eEo pipefail
trap 'echo "ERROR: Command failed"; exit 1' ERR

get_oldest_enum_domain(){
	filter=$1

	# Get a domain without the "lastPassiveEnumeration" field ordered by level so that higher level domains are scanned first
	domain=$($UTILS/get_domains.sh -f "not has(Domain.lastPassiveEnumeration) and $filter" -a 'orderasc: Domain.level, first: 1')
	# If all domains have "lastPassiveEnumeration", get the oldest
	if [ -z "$domain" ]; then
		domain=$($UTILS/get_domains.sh -f "$filter" -a 'orderasc: Domain.lastPassiveEnumeration, first: 1')
	fi

	if [ -z "$domain" ]; then
		>&2 echo "No domains to enumerate. Trying again in 10 seconds"
		sleep 10
		return
	fi

	>&2 echo "[$domain] Updating lastPassiveEnumeration field"
	>&2 $UTILS/query_dgraph.sh -q "
		mutation {
			updateDomain(input: {
				filter: { name: { eq: \"$domain\" } },
				set: { lastPassiveEnumeration: \"$(date -Iseconds)\"} }
			){
				domain { name }
			}
		}
	"

	echo $domain
}


run(){
	tool=$1
	domain=$2

	if [[ "$tool" == "amass-passive" ]]; then
		timeout 600 amass enum -silent -passive -nocolor -d $domain
	elif [[ "$tool" == "subfinder" ]]; then
		subfinder -silent -d $domain
	elif [[ "$tool" == "chaos" ]] && [ -n "$CHAOS_KEY" ]; then
		# Chaos doesn't accept domains which levels are greater than 2, so we strip the domain and filter the results
		chaos -silent -d $(echo $domain | grep -Eo '[^.]+\.[^.]+$') | grep -E "^.*\.$domain$"
	fi
}

run_and_save(){
	tool=$1
	domain=$2

	if [ -z "$domain" ]; then
		>&2 echo "WARNING: Skipping since no domain was provided"
		return
	fi

	subdomains_csv_file=/tmp/subdomains_$tool.csv

	echo 'name' > $subdomains_csv_file
	run $tool $domain >> $subdomains_csv_file
	>&2 $UTILS/save_domains.sh -f $subdomains_csv_file -t "$tool:passive"
}

while true; do

	$UTILS/wait_for_db.sh

	#----------------------------------------------------------------#
	# STEP 1: Run for the oldest "lastPassiveEnumeration" rootdomain #
	#----------------------------------------------------------------#

	rootdomain=$(get_oldest_enum_domain 'eq(Domain.type, "root")')

	echo "[$rootdomain] Running: Amass"
	run_and_save amass-passive $rootdomain

	echo "[$rootdomain] Running: Subfinder"
	run_and_save subfinder $rootdomain

	echo "[$rootdomain] Running: Chaos"
	run_and_save chaos $rootdomain

	#-----------------------------------------------------------------------------------#
	# STEP 2: Run for the 100 oldest "lastPassiveEnumeration" rootdomains or subdomains #
	#-----------------------------------------------------------------------------------#

	for i in {1..100}; do
		subdomain=$(get_oldest_enum_domain 'anyofterms(Domain.type, "root sub")')

		echo "[$subdomain] Running: Subfinder"
		run_and_save subfinder $subdomain

		echo "[$subdomain] Running: Chaos"
		run_and_save chaos $subdomain
	done

done
