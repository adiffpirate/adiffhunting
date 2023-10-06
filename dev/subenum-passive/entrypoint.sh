#!/bin/bash

get_oldest_enum_domain(){
	filter=$1

	# Get a domain without the "lastPassiveEnumeration" field
	domain=$($UTILS/get_domains.sh -a "
		filter: {
			and: [
				{ not: { skipScans: true } },
				{ not: { has: lastPassiveEnumeration } },
				{ $filter }
			]
		},
		first: 1
	")

	# If all domains have "lastPassiveEnumeration", get the oldest
	if [ -z "$domain" ]; then
		domain=$($UTILS/get_domains.sh -a "
			filter: {
				and: [
					{ not: { skipScans: true } },
					{ $filter }
				]
			},
			order: {
				asc: lastPassiveEnumeration
			},
			first: 1
		")
	fi

	echo $domain
}

update_last_enum_field(){
	domain=$1

	echo "[$domain] Updating lastPassiveEnumeration field"
	if [ -z "$domain" ]; then
		>&2 echo "WARNING: Skipping since no domain was provided."
		return
	fi

	$UTILS/query_dgraph.sh -q "
		mutation {
			updateDomain(input: {
				filter: { name: { eq: \"$domain\" } },
				set: { lastPassiveEnumeration: \"$(date -Iseconds)\"} }
			){
				domain { name }
			}
		}
	" | jq -c .
}

run(){
	tool=$1
	domain=$2

	if [[ $tool == "amass-passive" ]]; then
		timeout 600 amass enum -passive -nocolor -d $domain
	elif [[ $tool == "subfinder" ]]; then
		subfinder -d $domain
	elif [[ $tool == "chaos" ]] && [ -n "$CHAOS_KEY" ]; then
		if [[ $domain =~ ^[^.]+\.[^.]+$ ]]; then # If domain is a level 2 domain
			chaos -d $domain
		else
			# Chaos doesn't accept domains which levels are greater than 2, so we strip the domain and filter the results
			chaos -d $(echo $domain | grep -Eo '[^.]+\.[^.]+$') | grep -E "^.*\.$domain$"
		fi
	fi
}

run_and_save(){
	tool=$1
	domain=$2

	if [ -z "$domain" ]; then
		>&2 echo "WARNING: Skipping since no domain was provided."
		return
	fi

	subdomains_csv_file=/tmp/subdomains_$tool.csv

	echo 'name' > $subdomains_csv_file
	run $tool $domain >> $subdomains_csv_file
	$UTILS/save_domains.sh -f $subdomains_csv_file -t "$tool:passive" | jq -c .
}

while true; do

	$UTILS/wait_for_db.sh

	#------------------------------------------------------------#
	# STEP 1: Run for the oldest "lastPassiveEnumeration" domain #
	#------------------------------------------------------------#

	domain=$(get_oldest_enum_domain 'level: { eq: 2 }')
	update_last_enum_field $domain

	echo "[$domain] Running: Amass"
	run_and_save amass-passive $domain

	echo "[$domain] Running: Subfinder"
	run_and_save subfinder $domain

	echo "[$domain] Running: Chaos"
	run_and_save chaos $domain

	#--------------------------------------------------------------------#
	# STEP 2: Run for the 100 oldest "lastPassiveEnumeration" subdomains #
	#--------------------------------------------------------------------#

	for i in {1..100}; do
		subdomain=$(get_oldest_enum_domain 'level: { gt: 2 }')
		update_last_enum_field $subdomain

		echo "[$subdomain] Running: Subfinder"
		run_and_save subfinder $subdomain

		echo "[$subdomain] Running: Chaos"
		run_and_save chaos $subdomain
	done

done
