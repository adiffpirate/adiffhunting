Get domains with level greater than 5 that has a CNAME record
```
./query_dgraph.sh -t dql -q '{
  record as f(func: eq(DnsRecord.type, "CNAME")) {
    domain as DnsRecord.domain
  }
	results(func: uid(domain)) @filter(gt(Domain.level, 5)) {
    Domain.name,
    Domain.dnsRecords @filter(uid(record)) {
      DnsRecord.type, DnsRecord.values
    }
	}
}'
```
