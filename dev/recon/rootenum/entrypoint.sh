#!/bin/bash

script_path=$(dirname "$0")

set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

$UTILS/op_start.sh

$UTILS/_log.sh 'info' 'Getting companies and their root domains from Hackerone'
python3 $script_path/crawl_hackerone.py

$UTILS/op_end.sh
