Configure DGRAPH environment variables
```sh
export DGRAPH_ALPHA_HOST="$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}' | head -n1)"
export DGRAPH_ALPHA_HTTP_PORT="$(kubectl get svc dgraph-alpha -n adh -o jsonpath='{.spec.ports[0].nodePort}')"
```

Count subdomains
```sh
./query_dgraph.sh -o /dev/stdout -t dql -q '{
    result(func: eq(Domain.type, "sub")) {
        count(uid)
    }
}'
```

Count subdomains without 'lastProbe' field
```sh
./query_dgraph.sh -o /dev/stdout -t dql -q '{
    result(func: eq(Domain.type, "sub")) @filter(not(has(Domain.lastProbe))) {
        count(uid)
    }
}'
```

Get companies
```sh
./query_dgraph.sh -o /dev/stdout -t dql -q '{
    result(func: has(Company.name)) @recurse(depth: 2) {
        expand(_all_)
    }
}'
```

Count domains that have a CNAME record
```sh
./query_dgraph.sh -o /dev/stdout -t dql -q '{
    record as f(func: eq(DnsRecord.type, "CNAME")) @filter(has(DnsRecord.values)) {
        domain as DnsRecord.domain
    }
    results(func: uid(domain)) {
        count(uid)
        Domain.dnsRecords @filter(uid(record))
    }
}'
```

Get domains with level greater than 5 that have a CNAME record
```sh
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
