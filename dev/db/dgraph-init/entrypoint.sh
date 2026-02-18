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
		value: String! @id @search(by: [hash, regexp])
		programPage: String
		programPlatform: String @search(by: [hash, term])
		canHack: Boolean @search
		visibility: String @search(by: [hash])
		domains: [Domain] @hasInverse(field: company)
	}

	type Domain {
		id: ID!
		value: String! @id @search(by: [hash, regexp])
		level: Int @search
		type: String @search(by: [hash, term])
		randomSeed: String @search(by: [hash]) # Workaround so we can query for random domains since dgraph doesnt have that built-in

		subdomains: [Domain]
		company: Company @hasInverse(field: domains)
		foundBy: [Tool] @hasInverse(field: subdomains)
		urls: [Url] @hasInverse(field: domain)
		dnsRecords: [DnsRecord] @hasInverse(field: domain)
		vulns: [Vuln] @hasInverse(field: domain)

		skipScans: Boolean @search
		lastPassiveEnumeration: DateTime @search(by: [hour])
		lastActiveEnumeration: DateTime @search(by: [hour])
		lastProbe: DateTime @search(by: [hour])
		lastExploit: DateTime @search(by: [hour])
	}

	type Url {
		id: ID!
		value: String! @id @search(by: [hash, regexp])
		randomSeed: String @search(by: [hash]) # Workaround so we can query for random domains since dgraph doesnt have that built-in

		protocol: Protocol @hasInverse(field: urls)
		domain: Domain @hasInverse(field: urls)
		path: Path @hasInverse(field: urls)
		httpResponses: [HttpResponse] @hasInverse(field: url)

		lastProbe: DateTime @search(by: [hour])
		lastExploit: DateTime @search(by: [hour])
	}

	type Protocol {
		id: ID!
		value: String! @id @search(by: [hash, regexp])
		urls: [Url] @hasInverse(field: protocol)
	}

	type Path {
		id: ID!
		value: String! @id @search(by: [hash, regexp])
		depth: Int @search
		subpaths: [Path]
		urls: [Url] @hasInverse(field: path)
	}

	type Tool {
		id: ID!
		value: String! @id @search(by: [hash, regexp])
		type: String @search(by: [hash, regexp])
		subdomains: [Domain] @hasInverse(field: foundBy)
		vulns: [Vuln] @hasInverse(field: foundBy)
	}

	type DnsRecord {
		id: ID!
		value: String! @id @search(by: [hash, regexp])
		domain: Domain @hasInverse(field: dnsRecords)
		type: String @search(by: [hash, term])
		values: [String] @search(by: [hash, regexp])
		updatedAt: DateTime @search(by: [hour])
	}

	type HttpResponse {
		id: ID!
		value: String! @id @search(by: [hash, regexp])
		url: Url @hasInverse(field: httpResponses)

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
		value: String! @id @search(by: [hash, regexp])
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
		value: String! @id @search(by: [hash, regexp])
		vulns: [Vuln] @hasInverse(field: class)
	}

	type Evidence {
		id: ID!
		target: String
		request: String
		response: String
	}
' | jq -c .
