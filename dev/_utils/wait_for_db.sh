#!/bin/bash
set -eo pipefail

until curl --silent --fail $DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/health > /dev/null; do
	>&2 echo 'Waiting Alpha Server to be ready'
	sleep 1
done

sleep 5
