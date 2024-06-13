> **To see the results DEBUG must be enabled!**

Get subdomains count
```
./query_dgraph.sh -t dql -q '{
    result(func: eq(Domain.type, "sub")) {
        count(uid)
    }
}' 2>&1 | tail -n1 | jq
```

Get companies
```
./query_dgraph.sh -t dql -q '{
    result(func: has(Company.name)) @recurse(depth: 2) {
        expand(_all_)
    }
}' 2>&1 | tail -n1 | jq
```

Get domains with level greater than 5 that has a CNAME record
```
./query_dgraph.sh -t dql -q '{
  record as f(func: eq(DnsRecord.type, "CNAME")) @filter(has(DnsRecord.values)) {
    domain as DnsRecord.domain
  }
	results(func: uid(domain)) @filter(gt(Domain.level, 5)) {
    Domain.name,
    Domain.dnsRecords @filter(uid(record)) {
      DnsRecord.type, DnsRecord.values
    }
	}
}' 2>&1 | tail -n1 | jq
```
