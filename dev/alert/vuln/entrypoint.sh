#!/bin/bash
set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

while true; do
	$UTILS/op_start.sh

	query_result=$(mktemp)
	$UTILS/query_dgraph.sh -o $query_result -t dql -q "{
		results(func: has(Vuln.name)) @filter(not eq(Vuln.notified, true)) {
			Vuln.name,
			Vuln.updatedAt,
			Vuln.description,
			Vuln.evidence { expand(_all_) }
			Vuln.references
		}
	}"
	vuln=$(yq -P '.data.results | .[]' $query_result)

	if [ -n "$vuln" ]; then
		$UTILS/_log.sh 'info' 'Vulnerability found! Sending alert' "vuln=$vuln"
	else
		$UTILS/_log.sh 'info' "Nothing to alert. Trying again in $ALERT_COOLDOWN_SECONDS seconds"
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

	$UTILS/_log.sh 'info' 'The alert has been sent successfully. Updating its notified status on database'
	$UTILS/query_dgraph.sh -q $query_file "
		mutation {
			addVuln(input: [{
				\"name\": \"$(echo "$vuln" | yq -r '.["Vuln.name"]')\",
				\"notified\": true
			}], upsert: true){
				vuln { name, notified }
			}
		}
	"

	$UTILS/op_end.sh
done
