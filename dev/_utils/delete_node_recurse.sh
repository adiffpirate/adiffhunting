#!/bin/bash

usage="$(basename "$0") [-h|f|c]

Delete domain from DGraph database.

flags:
	-h show this help text
	-f filter
	-c children to delete
"

while getopts ":h?f:c:" opt; do
	case "$opt" in
		h) echo "$usage" && exit 0 ;;
		f) filter=$OPTARG ;;
		c) children=$OPTARG ;;
	esac
done
if [ -z "$filter" || -z "$children" ]; then
	echo "$usage"
	exit 1
fi

script_path=$(dirname "$0")

$script_path/query_dgraph.sh -t dql -q "
	upsert {
		query {
			q(func: $filter) @recurse @normalize {
				all_ids as uid,
				$children
			}
		}
		
		mutation {
			delete {
				uid(all_ids) * * .
			}
		}
	}
"
