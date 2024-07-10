#!/bin/bash
set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

probe(){
	domains=$1
	http_method=$2
	http_method_uppercase=$(echo -E "$http_method" | tr '[:lower:]' '[:upper:]')

	# Run HTTPX and print its output as JSON Lines according to database schema
	httpx -list $domains -silent -rate-limit 10 -threads 2 -json -x $http_method \
	| while read -r line; do
		# Parse output
		$UTILS/_log.sh 'debug' 'Parsing output' "output=$line"
		echo -E "$line" | jq -c '{
			name: ( .method + " " + .url ),
			domain: { name: (.url | capture("^(?:[a-zA-Z][a-zA-Z0-9+.-]*://)?(?<domain>[^/]+)").domain) },
			url: .url,
			scheme: .scheme,
			method: .method,
			statusCode: ."status_code",
			category: .knowledgebase.PageType,
			location: .location,
			contentType: ."content_type",
			contentLength: ."content_length",
			updatedAt: .timestamp
		}' || $UTILS/_log.sh 'error' 'Error while parsing output' "output=$line"
	done
}

probe_and_save(){
	domains=$1
	http_method=$2

	# Probe and save responses on database, one at a time
	probe $domains $http_method | while read -r line; do
		$UTILS/_log.sh 'debug' 'Saving response on database' "response=$line"
		$UTILS/query_dgraph.sh -q "
			mutation {
				addHttpResponse(input: [$line], upsert: true){
					httpResponse { name, statusCode }
				}
			}
		"
	done
}

get_domains(){
	records=/tmp/adh-recon-subprobe-http-get-domains-records

	# Get A/AAAA/CNAME values from 100 domains without the "lastExploit" field
	$UTILS/get_dnsrecords.sh -t 'A AAAA CNAME' -f "not has(Domain.lastExploit)" -a 'first: 100' > $records
	# If all domains have "lastExploit", get 100 oldests that are at least older than $DOMAIN_SCAN_COOLDOWN
	if [ ! -s "$records" ]; then
		$UTILS/get_dnsrecords.sh -t 'A AAAA CNAME' \
			-f "lt(Domain.lastExploit, \"$(date -Iseconds -d "-$DOMAIN_SCAN_COOLDOWN")\")" \
			-a 'first: 100, orderasc: Domain.lastExploit' \
		> $records
	fi

	if [ ! -s "$records" ]; then # Return if unable to get records
		return
	fi

	# Get domains from cname records
	$UTILS/_log.sh 'debug' 'Parsing records' "records=$records"
	domains=/tmp/adh-recon-subprobe-http-get-domains-domains
	awk '{print $1}' $records | sort -u > $domains

	# Print domains
	cat $domains
}

while true; do
	$UTILS/op_start.sh

	domains=/tmp/adh-recon-subprobe-http-domains
	get_domains > $domains

	if [ ! -s "$domains" ]; then
		$UTILS/_log.sh 'info' "No domains to probe. Trying again in 10 seconds"
		sleep 10
		continue
	fi

	# Save to file the domains list as JSON so it looks better on logs
	domains_json=/tmp/adh-recon-subprobe-http-domains.json
	jq -R -s 'split("\n") | map(select(length > 0))' $domains > $domains_json

	$UTILS/_log.sh 'debug' 'Updating lastProbe field' "domains=$domains_json"
	cat $domains | while read -r domain; do
		$UTILS/query_dgraph.sh -q "
			mutation {
				updateDomain(input: {
					filter: { name: { eq: \"$domain\" } },
					set: { lastProbe: \"$(date -Iseconds)\"} }
				){
					domain { name }
				}
			}
		"
	done

	for http_method in 'get' 'post' 'put' 'patch' 'delete'; do
		$UTILS/_log.sh 'info' 'Running: HTTPX' "http_method=$(echo -E "$http_method" | tr '[:lower:]' '[:upper:]')" "domains=$domains_json"
		probe_and_save $domains $http_method
	done

	$UTILS/op_end.sh
done
