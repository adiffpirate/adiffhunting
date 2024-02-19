#!/bin/bash

ERR_CODE=$1
ERR_FILE=$2
ERR_COMMAND=$3
ERR_LINE=$4

echo "========= ERROR ========="
echo
echo "CODE: ${ERR_CODE}"
echo "FILE: ${ERR_FILE}"
echo "COMMAND: ${ERR_COMMAND}"
echo "LINE: ${ERR_LINE}"
echo
echo "========== END =========="

exit 1
