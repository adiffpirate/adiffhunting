#!/bin/bash

$UTILS/wait_for_db.sh

# Create schemas
echo "Creating Schemas"
curl --silent $DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/admin/schema --data '
	type Company {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domains: [Domain]

		createdAt: DateTime @default(add: { value: "$now" })
		updatedAt: DateTime @default(update: { value: "$now" })
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
		vulns: [Vuln] @hasInverse(field: domain)

		createdAt: DateTime @default(add: { value: "$now" })
		updatedAt: DateTime @default(update: { value: "$now" })
	}

	type Tool {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		type: String! @search(by: [hash, regexp])
		subdomains: [Domain] @hasInverse(field: foundBy)
		vulns: [Vuln] @hasInverse(field: foundBy)
	}

	type DnsRecord {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: dnsRecords)
		type: String! @search(by: [hash])
		values: [String!]! @search(by: [hash, regexp])

		createdAt: DateTime @default(add: { value: "$now" })
		updatedAt: DateTime @default(update: { value: "$now" })
	}

	type Vuln {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: vulns)

		title: String! @search(by: [hash, regexp])
		class: VulnClass @hasInverse(field: vulns)
		description: String @search(by: [hash, regexp])
		severity: String @search(by: [hash])
		references: [String] @search(by: [hash, regexp])
		evidence: Evidence
		foundBy: [Tool] @hasInverse(field: vulns)

		createdAt: DateTime @default(add: { value: "$now" })
		updatedAt: DateTime @default(update: { value: "$now" })
	}

	type VulnClass {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		vulns: [Vuln] @hasInverse(field: class)
	}

	type Evidence {
		id: ID!
		target: String
		request: String
		response: String
	}
' | jq -c .

mkdir /tmp/domains
python3 $UTILS/parse_companies.py -f /src/data/companies.json -o /tmp/domains

for company_domains_file in /tmp/domains/*; do
	company=$(echo "$company_domains_file" | awk -F/ '{print $NF}' | awk -F. '{print $1}')
	echo "[$company] Creating company"
	$UTILS/save_company.sh -c "$company" -f "$company_domains_file" | jq -c .
done
