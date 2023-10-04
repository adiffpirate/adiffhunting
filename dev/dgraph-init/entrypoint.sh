#!/bin/bash

$UTILS/wait_for_db.sh

# Create schemas
echo "Creating Schemas"
curl --silent $DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/admin/schema --data '
	type Company {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domains: [Domain]
	}

	type Domain {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		level: Int @search
		subdomains: [Domain]

		skipScans: Boolean @search
		lastPassiveEnumeration: DateTime @search(by: [hour])
		lastActiveEnumeration: DateTime @search(by: [hour])
		lastProbe: DateTime @search(by: [hour])
		lastExploit: DateTime @search(by: [hour])

		foundBy: [Tool] @hasInverse(field: subdomains)
		dnsRecords: [DnsRecord] @hasInverse(field: domain)
	}

	type Tool {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		type: String! @search(by: [hash, regexp])
		subdomains: [Domain] @hasInverse(field: foundBy)
	}

	type DnsRecord {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: dnsRecords)
		type: String! @search(by: [hash])
		values: [String!]! @search(by: [hash, regexp])
		updatedOn: DateTime @search(by: [hour])
	}
' | jq -c .

mkdir /tmp/domains
python3 $UTILS/parse_companies.py -f /src/data/companies.json -o /tmp/domains

for company_domains_file in /tmp/domains/*; do
	company=$(echo "$company_domains_file" | awk -F/ '{print $NF}' | awk -F. '{print $1}')
	echo "[$company] Creating company"
	$UTILS/save_company.sh -c "$company" -f "$company_domains_file" | jq -c .
done
