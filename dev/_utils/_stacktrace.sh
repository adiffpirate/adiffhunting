#!/bin/bash

script_path=$(dirname "$0")

ERR_CODE=$1
ERR_FILE=$2
ERR_COMMAND=$3
ERR_LINE=$4

$script_path/_log.sh \
	'error' \
	'There was an error processing the operation' \
	"return_code=$ERR_CODE" \
	"file=$ERR_FILE" \
	"line=$ERR_LINE" \
	"command=$ERR_COMMAND" \
|| >&2 echo "{\"level\":\"error\",\"operation_id\":\"$OP_ID\",\"message\":\"Unable to create stacktrace\",\"body\":{\"file\":\"$BASH_SOURCE\",\"line\":\"$LINENO\",\"command\":\"$(echo $BASH_COMMAND | sed "s/\"/\\\\\"/g")\"}}"
			
exit 1
