import argparse
import re
import json
import csv
import sys

def main():
    parser = argparse.ArgumentParser(
        description=(
            'Parse (sub)domains CSV file as a JSON formatted to comply with Domain schema on DGraph'
        )
    )
    parser.add_argument('-f', '--file', help='CSV file', required=True)
    parser.add_argument('-t', '--tool', help='Tool used to discover all (sub)domains. Should follow the format: {NAME}:{TYPE} (e.g. amass:passive)')
    # Parse out arguments ignoring the first two (because we're inside a command)
    args = parser.parse_args()

    # Read CSV file
    parsed_csv = list()
    with open(args.file) as csv_file:
        csv_reader = csv.DictReader(csv_file)
        for line in csv_reader:
            # Only add valids FQDN
            if re.match('(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{0,62}[a-zA-Z0-9]\.)+[a-zA-Z]{2,63}$)', line['name']):
                parsed_csv.append(line)
            else:
                print(f"WARNING: Invalid FQDN: {line['name']}", file=sys.stderr)
    domains_on_csv_file = [ line['name'] for line in parsed_csv ]

    # Create dict with domains separated by level
    domains_by_level_dict = dict()
    for domain in domains_on_csv_file:
        get_domains_by_level(domain, domains_by_level_dict)

    all_domains = set()
    for domain in domains_by_level_dict.keys():
        all_domains.add(domain)
    for lower_level_domains in domains_by_level_dict.values():
        for domain in lower_level_domains:
            all_domains.add(domain)

    # Construct JSON in a format that reflects Domain schema on database
    parsed_domains = list()
    for domain in all_domains:
        tmp = dict()
        # Get name
        tmp['name'] = domain
        # Get other fields from csv (if they are defined for this domains)
        if domain in domains_on_csv_file:
            # Get object that represent domain on parsed csv
            domain_obj = next((obj for obj in parsed_csv if obj['name'] == domain))
            for key,value in domain_obj.items():
                # If key and value are valid (not empty or null)
                if key and value:
                    # Convert if boolean
                    if value == 'true':
                        tmp[key] = True
                    elif value == 'false':
                        tmp[key] = False
                    # Convert if numeric
                    elif value.lstrip('-').replace('.', '', 1).isdigit():
                        if '.' in value:
                            tmp[key] = float(value)
                        else:
                            tmp[key] = int(value)
                    # Defaults to string
                    else:
                        tmp[key] = value
        # Get level
        tmp['level'] = domain.count('.') + 1
        # Get tool (only for subdomains since domains are added by dgraph-init)
        if args.tool and tmp['level'] > 2:
            tmp['foundBy'] = [ { "name": args.tool.split(':')[0], "type": args.tool.split(':')[1] } ]
        # Get subdomains
        lower_level_domains = domains_by_level_dict[domain] if domain in domains_by_level_dict.keys() else []
        tmp['subdomains'] = [ { "name": sub } for sub in lower_level_domains ]

        # Add object to list of parsed domains
        parsed_domains.append(tmp)

    # Print JSON sorted by level
    print(json.dumps(sorted(parsed_domains, key=lambda field: field['level'])))


def get_domains_by_level(domain, domains_by_level_dict):
    # Get higher level domain from passed domain
    higher_level_domain = re.sub('^.*?\.', '', domain)
    # Add domain to list which key corresponds to its higher level domain
    # (or create a list if one doesn't exists for that higher level domain)
    domains_by_level_dict.setdefault(higher_level_domain, set()).add(domain)
    # Recursivelly adds even higher domains stopping when no dot is found
    if '.' in higher_level_domain:
        get_domains_by_level(higher_level_domain, domains_by_level_dict)


if __name__ == '__main__':
    main()
