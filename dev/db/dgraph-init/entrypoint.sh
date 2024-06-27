#!/bin/bash
set -eEo pipefail
trap '$UTILS/_stacktrace.sh "$?" "$BASH_SOURCE" "$BASH_COMMAND" "$LINENO"' ERR

export OP_ID=$(uuidgen -r)
$UTILS/wait_for_db.sh

# Enable query logging
$UTILS/_log.sh 'info' "Enabling query logging"
curl --no-progress-meter $DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/admin -H 'Content-Type: application/graphql' --data '
	mutation {
		config(input: {logDQLRequest: true}) {
			response {
				code
				message
			}
		}
	}
' | jq -c .

# Create schemas
$UTILS/_log.sh 'info' "Creating Schemas"
curl --no-progress-meter $DGRAPH_ALPHA_HOST:$DGRAPH_ALPHA_HTTP_PORT/admin/schema --data '
	type Company {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		programPage: String
		programPlatform: String @search(by: [hash, term])
		canHack: Boolean @search
		visibility: String @search(by: [hash])
		domains: [Domain] @hasInverse(field: company)
	}

	type Domain {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		level: Int @search
		type: String @search(by: [hash, term])
		company: Company @hasInverse(field: domains)
		randomSeed: String @search(by: [hash]) # Workaround so we can query for random domains since dgraph doesnt have that built-in
		subdomains: [Domain]

		skipScans: Boolean @search
		lastPassiveEnumeration: DateTime @search(by: [hour])
		lastActiveEnumeration: DateTime @search(by: [hour])
		lastProbe: DateTime @search(by: [hour])
		lastExploit: DateTime @search(by: [hour])

		foundBy: [Tool] @hasInverse(field: subdomains)
		dnsRecords: [DnsRecord] @hasInverse(field: domain)
		httpResponses: [HttpResponse] @hasInverse(field: domain)
		vulns: [Vuln] @hasInverse(field: domain)
	}

	type Tool {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		type: String @search(by: [hash, regexp])
		subdomains: [Domain] @hasInverse(field: foundBy)
		vulns: [Vuln] @hasInverse(field: foundBy)
	}

	type DnsRecord {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: dnsRecords)
		type: String @search(by: [hash, term])
		values: [String] @search(by: [hash, regexp])
		updatedAt: DateTime @search(by: [hour])
	}

	type HttpResponse {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: httpResponses)
		url: String  @search(by: [hash, regexp])
		scheme: String @search(by: [hash, term])
		method: String @search(by: [hash, term])
		statusCode: Int @search
		category: String @search(by: [hash, term])
		location: String @search(by: [hash, regexp])
		contentType: String @search(by: [hash, term])
		contentLength: Int @search
		updatedAt: DateTime @search(by: [hour])
	}

	type Vuln {
		id: ID!
		name: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: vulns)
		title: String @search(by: [hash, regexp])
		class: VulnClass @hasInverse(field: vulns)
		description: String @search(by: [hash, regexp])
		severity: String @search(by: [hash])
		references: [String] @search(by: [hash, regexp])
		evidence: Evidence
		foundBy: [Tool] @hasInverse(field: vulns)
		notified: Boolean @search
		updatedAt: DateTime @search(by: [hour])
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
