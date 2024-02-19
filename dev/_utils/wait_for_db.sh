#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '$script_path/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

until curl --no-progress-meter --fail $DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/health > /dev/null; do
	>&2 echo 'Waiting Alpha Server to be ready'
	sleep 1
done

sleep 5
