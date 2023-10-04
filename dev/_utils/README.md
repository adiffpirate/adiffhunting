Get domains with level greater than 5 that has a CNAME record
```
./query_dgraph.sh -t dql -q '{
  records(func: eq(DnsRecord.type, "CNAME")) {
    domain as DnsRecord.domain
  }
	result(func: uid(domain)) @filter(gt(Domain.level, 5)) {
		expand(_all_)
	}
}'
```
