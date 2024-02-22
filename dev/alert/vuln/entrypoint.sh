#!/bin/bash
set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

while true; do

	export OP_ID=$(uuidgen -r)
	$UTILS/wait_for_db.sh

	vuln=$($UTILS/query_dgraph.sh -t dql -q "{
		results(func: has(Vuln.name)) @filter(not eq(Vuln.notified, true)) {
			Vuln.name,
			Vuln.updatedAt,
			Vuln.description,
			Vuln.evidence { expand(_all_) }
			Vuln.references
		}
	}" | yq -P '.data.results | .[]')

	if [ -n "$vuln" ]; then
		$UTILS/log.sh 'info' 'Vulnerability found! Sending alert' "vuln=$vuln"
	else
		$UTILS/log.sh 'info' "Nothing to alert. Trying again in $ALERT_COOLDOWN_SECONDS seconds"
		sleep $ALERT_COOLDOWN_SECONDS
		continue
	fi

	echo "$vuln" | notify -silent -bulk -provider-config <(yq -n -P '{
		"telegram":[{
			"id": "vuln",
			"telegram_api_key": env(TELEGRAM_API_KEY),
			"telegram_chat_id": env(TELEGRAM_CHAT_ID),
			"telegram_format": "```yaml\n{{data}}\n```",
			"telegram_parsemode": "Markdown"
		}]
	}')

	$UTILS/log.sh 'info' 'The alert has been sent successfully. Updating its notified status on database'
	$UTILS/query_dgraph.sh -q $query_file "
		mutation {
			addVuln(input: [{
				\"name\": \"$(echo "$vuln" | yq -r '.["Vuln.name"]')\",
				\"notified\": true
			}], upsert: true){
				vuln { name, notified }
			}
		}
	" > /dev/null

done
