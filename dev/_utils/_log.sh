#!/bin/bash

format_to_json_string(){
  printf '%s' "$1" | jq -s -R | sed 's/^"//' | sed 's/"$//'
}

LEVEL=$1
OP_ID=$(cat /tmp/adh-operation-id)
MESSAGE=$(format_to_json_string "$2")

# Skip if is an debug message but debug is not enabled
if [[ "$LEVEL" == "debug" ]] && [[ "$DEBUG" == "false" ]]; then
  exit 0
fi

# Create json body from arguments
BODY='{' # Open json
for arg in "${@:3}"; do
	# Use jq create a valid JSON string and sed to remove quotes created by jq
  formatted_arg=$(format_to_json_string "$arg")
	# Get key
	key=$(echo "$formatted_arg" | awk -F= '{print $1}')
	# Get value
	value=$(echo "$formatted_arg" | awk -F= '{print $2}')
	# Add to json
	BODY+="\"$key\":\"$value\","
done
BODY="${BODY%,*}}" # Remove the trailing comma and close json

>&2 jq --null-input --compact-output \
	--arg OP_ID "$OP_ID" \
	--arg LEVEL "$LEVEL" \
	--arg MESSAGE "$MESSAGE" \
	--argjson BODY "$BODY" '
	{
		level: $LEVEL,
		operation_id: $OP_ID,
		message: $MESSAGE,
		body: $BODY
	}
' || >&2 echo "{\"level\":\"error\",\"operation_id\":\"$OP_ID\",\"message\":\"Unable to create log message from provided arguments\"}"

if [[ "$LEVEL" == "error" ]]; then
	exit 1
fi
