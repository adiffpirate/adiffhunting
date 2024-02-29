#!/bin/bash

format_to_json(){
	input=$1

	# If input is a valid JSON object
	input_json=$(printf '%s' "$input" | sed -z 's/\\n//g' | jq -c 2>/dev/null || printf 'null')
	if jq 'keys' <<< "$input_json" > /dev/null 2>&1; then
		# Return the JSON object
		printf '%s' "$input_json"
	else
		# Use jq to return input as JSON string
		printf '%s' "$input" | jq -s -R
	fi
}

LEVEL=$1
OP_ID=$(cat /tmp/adh-operation-id)
MESSAGE=$(format_to_json "$2" | sed 's/^"//' | sed 's/"$//')

# Skip if is an debug message but debug is not enabled
if [[ "$LEVEL" == "debug" ]] && [[ "$DEBUG" == "false" ]]; then
  exit 0
fi

# Create json body from arguments
BODY='{' # Open json
for arg in "${@:3}"; do
	# Convert multiline string into one line
	arg=$(printf '%s' "$arg" | sed -z 's/\n/\\n/g')
	# Get key
	key=$(printf '%s' "$arg" | awk -F= '{print $1}')
	# Get value
	value=$(printf '%s' "$arg" | awk -F= '{print $2}')
	# Add to json
	BODY+="\"$key\":$(format_to_json "$value"),"
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
