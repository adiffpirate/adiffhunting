#!/bin/bash

OP_ID=$1
ERR_CODE=$2
ERR_FILE=$3
ERR_COMMAND=$4
ERR_LINE=$5

jq --null-input --compact-output \
	--arg OP_ID "$OP_ID" \
	--arg ERR_CODE "$ERR_CODE" \
	--arg ERR_FILE "$ERR_FILE" \
	--arg ERR_COMMAND "$ERR_COMMAND" \
	--arg ERR_LINE "$ERR_LINE" '
	{
		"level": "error",
		"operation_id": $OP_ID,
		"message": "There was an error processing the operation",
		"body": {
			"return_code": $ERR_CODE,
			"file": $ERR_FILE,
			"line": $ERR_LINE,
			"command": $ERR_COMMAND
		}
	}
'

exit 1
