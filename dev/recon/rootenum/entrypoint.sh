#!/bin/bash
set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

save_companies(){
	companies_json="$1"
	jq -c '.[]' $companies_json | while read company; do
		$UTILS/query_dgraph.sh -q "
			mutation {
				addCompany(input: [$company], upsert: true){
					company {
						name
					}
				}
			}
		"
	done
}

$UTILS/op_start.sh

$UTILS/_log.sh 'info' 'Getting companies and their root domains from Hackerone'
save_companies <(python3 crawl_hackerone.py)

$UTILS/op_end.sh
