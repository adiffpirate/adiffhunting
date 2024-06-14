Count subdomains
```
./query_dgraph.sh -o /dev/stdout -t dql -q '{
    result(func: eq(Domain.type, "sub")) {
        count(uid)
    }
}'
```

Count subdomains without 'lastProbe' field
```
./query_dgraph.sh -o /dev/stdout -t dql -q '{
    result(func: eq(Domain.type, "sub")) @filter(not(has(Domain.lastProbe))) {
        count(uid)
    }
}'
```

Get companies
```
./query_dgraph.sh -o /dev/stdout -t dql -q '{
    result(func: has(Company.name)) @recurse(depth: 2) {
        expand(_all_)
    }
}'
```

Get domains with level greater than 5 that has a CNAME record
```
./query_dgraph.sh -o /dev/stdout -t dql -q '{
    record as f(func: eq(DnsRecord.type, "CNAME")) @filter(has(DnsRecord.values)) {
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
