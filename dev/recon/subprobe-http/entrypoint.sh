#!/bin/bash
set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

probe(){
	local targets=$1
	local http_method=$2
	local http_method_uppercase=$(echo -E "$http_method" | tr '[:lower:]' '[:upper:]')

	# Run HTTPX and print its output as JSON Lines according to database schema
	httpx -list $targets -silent -rate-limit 10 -threads 2 -json -x $http_method \
	| while read -r line; do
		# Save HttpResponse
		$UTILS/_log.sh 'debug' 'Parsing output' "output=$line"
		echo -E "$line" | jq -c '{
			value: ( .method + " " + .url ),
			url: { value: .url },
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
	local targets=$1
	local http_method=$2

	# Probe and save responses on database, one at a time
	probe $targets $http_method | while read -r line; do
		$UTILS/_log.sh 'debug' 'Saving response on database' "response=$line"
		$UTILS/query_dgraph.sh -q "
			mutation {
				addHttpResponse(input: [$line], upsert: true){
					httpResponse { value }
				}
			}
		"
	done
}

get_domains(){
	local records=/tmp/adh-recon-subprobe-http-get-domains-records

	# Get A/AAAA/CNAME values from 100 domains without the "lastProbe" field
	$UTILS/get_dnsrecords.sh -t 'A AAAA CNAME' -f "not has(Domain.lastProbe)" -a 'first: 100' > $records
	# If all domains have "lastProbe", get 100 oldests that are at least older than $SCAN_COOLDOWN
	if [ ! -s "$records" ]; then
		$UTILS/get_dnsrecords.sh -t 'A AAAA CNAME' \
			-f "lt(Domain.lastProbe, \"$(date -Iseconds -d "-$SCAN_COOLDOWN")\")" \
			-a 'first: 100, orderasc: Domain.lastProbe' \
		> $records
	fi

	if [ ! -s "$records" ]; then # Return if unable to get records
		$UTILS/_log.sh 'info' "No domains to probe"
		return
	fi

	# Get domains from cname records
	$UTILS/_log.sh 'debug' 'Parsing records' "records=$records"
	local domains=/tmp/adh-recon-subprobe-http-get-domains-domains
	awk '{print $1}' $records | sort -u > $domains

	# Save to file the domains list as JSON so it looks better on logs
	local domains_json=/tmp/adh-recon-subprobe-http-get-domains-domains.json
	jq -R -s 'split("\n") | map(select(length > 0))' $domains > $domains_json

	# Update lastProbe field for all domains
	$UTILS/_log.sh 'debug' 'Updating lastProbe field' "domains=$domains_json"
	cat $domains | while read -r domain; do
		$UTILS/query_dgraph.sh -q "
			mutation {
				updateDomain(input: {
					filter: { value: { eq: \"$domain\" } },
					set: { lastProbe: \"$(date -Iseconds)\"} }
				){
					domain { value }
				}
			}
		"
	done

	# Print domains
	cat $domains
}

get_urls(){
	local urls=/tmp/adh-recon-subprobe-http-get-urls-urls

	# Get 100 urls without the "lastProbe" field
	$UTILS/get_urls.sh -f "not has(Url.lastProbe)" -a 'first: 100' > $urls
	# If all urls have "lastProbe", get 100 oldests that are at least older than $SCAN_COOLDOWN
	if [ ! -s "$urls" ]; then
		$UTILS/get_urls.sh \
			-f "lt(Url.lastProbe, \"$(date -Iseconds -d "-$SCAN_COOLDOWN")\")" \
			-a 'first: 100, orderasc: Url.lastProbe' \
		> $urls
	fi

	if [ ! -s "$urls" ]; then # Return if unable to get urls
		$UTILS/_log.sh 'info' "No URLs to probe"
		return
	fi

	# Save to file the urls list as JSON so it looks better on logs
	local urls_json=/tmp/adh-recon-subprobe-http-get-urls-urls.json
	jq -R -s 'split("\n") | map(select(length > 0))' $urls > $urls_json

	# Update lastProbe field for all urls
	$UTILS/_log.sh 'debug' 'Updating lastProbe field' "urls=$urls_json"
	cat $urls | while read -r url; do
		$UTILS/query_dgraph.sh -q "
			mutation {
				updateUrl(input: {
					filter: { value: { eq: \"$url\" } },
					set: { lastProbe: \"$(date -Iseconds)\"} }
				){
					url { value }
				}
			}
		"
	done

	# Print urls
	cat $urls
}

while true; do
	$UTILS/op_start.sh

	targets=/tmp/adh-recon-subprobe-http-targets
	get_domains > $targets
	get_urls >> $targets

	if [ ! -s "$targets" ]; then # Stop and sleep for a bit if there's nothing to probe
		$UTILS/_log.sh 'info' "No targets to probe. Trying again in 1 minute."
		sleep 60
		continue
	fi

	# Save to file the targets list as JSON so it looks better on logs
	targets_json=/tmp/adh-recon-subprobe-http-targets.json
	jq -R -s 'split("\n") | map(select(length > 0))' $targets > $targets_json

	for http_method in 'get' 'post' 'put' 'patch'; do
		$UTILS/_log.sh 'info' 'Running: HTTPX' "http_method=$(echo -E "$http_method" | tr '[:lower:]' '[:upper:]')" "targets=$targets_json"
		probe_and_save $targets $http_method
	done

	$UTILS/op_end.sh
done
