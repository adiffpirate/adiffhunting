from pathlib import Path
import argparse
import re
import json
import csv
import sys
import uuid

def main():
    parser = argparse.ArgumentParser(
        description=(
            'Parse (sub)domains CSV file as JSON formatted to comply with Domain schema on DGraph'
        )
    )
    parser.add_argument('-f', '--file', help='CSV file', required=True)
    parser.add_argument('-t', '--tool', help='Tool used to discover all (sub)domains. Should follow the format: {NAME}:{TYPE} (e.g. amass:passive)')
    # Parse out arguments ignoring the first two (because we're inside a command)
    args = parser.parse_args()

    # Read CSV file
    parsed_csv = list()  # List to store valid CSV lines
    with open(args.file) as csv_file:
        csv_reader = csv.DictReader(csv_file)

        # Iterate through each line in the CSV file
        for line in csv_reader:
            # Check if the domain name matches the FQDN (Fully Qualified Domain Name) pattern
            if re.match('(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{0,62}[a-zA-Z0-9]\.)+[a-zA-Z]{2,63}$)', line['name']):
                # Add the valid line to the result list
                parsed_csv.append(line)
            else:
                # Print a warning for invalid FQDN
                print(f"WARNING: Invalid FQDN: {line['name']}", file=sys.stderr)

    # Read tld-list.txt located at the script directory
    with Path(__file__).with_name('tld-list.txt').open('r') as tld_file:
        tld_list = tld_file.read().splitlines()

    # Extract the list of domains from the parsed CSV file
    domains_on_csv_file = [line['name'] for line in parsed_csv]

    # Create dict with domains separated by level
    domains_by_level_dict = dict()
    for domain in domains_on_csv_file:
        get_domains_by_level(domain, domains_by_level_dict)

    all_domains = set()

    # Collect all domains and subdomains into a set
    for domain in domains_by_level_dict.keys():
        all_domains.add(domain)
    for lower_level_domains in domains_by_level_dict.values():
        all_domains.update(lower_level_domains)

    # Print JSONLines in a format that reflects the Domain schema in the database
    for domain in all_domains:
        tmp = dict()

        # Get name
        tmp['name'] = domain

        # Get type
        tld_regex = '(' + '|'.join(tld_list) + ')(\.[^.]+)?'
        if re.match(f'^{tld_regex}$', domain): # TLD (e.g. 'com')
            tmp['type'] = 'tld'
        elif re.match(f'^[^.]+\.{tld_regex}$', domain): # Root (one level above TLD e.g. 'foobar.com')
            tmp['type'] = 'root'
        else: # Everything else is Sub (e.g. 'sub.foobar.com')
            tmp['type'] = 'sub'

        # Get other fields from CSV if not TLD (and if there are any defined for this domain)
        # (we dont add custom fields on TLDs to avoid wrongfully setting things like 'company' for a TLD)
        if tmp['type'] != 'tld' and domain in domains_on_csv_file:
            # Get object that represents domain on parsed CSV
            domain_obj = next((obj for obj in parsed_csv if obj['name'] == domain), {})
            for key, value in domain_obj.items():
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

        # Get tool (only for subdomains since rootdomains are added by rootenum)
        if args.tool and tmp['type'] == 'sub':
            tmp['foundBy'] = [{"name": args.tool.split(':')[0], "type": args.tool.split(':')[1]}]

        # Generate random seed
        tmp['randomSeed'] = str(uuid.uuid4())

        # Print JSON
        print(json.dumps(tmp))

        # If has subdomains, print each one as a different JSON
        lower_level_domains = domains_by_level_dict.get(domain, set())
        for sub in lower_level_domains:
            print(json.dumps({"name": domain, "subdomains": [{"name": sub}]}))


def get_domains_by_level(domain, domains_by_level_dict):
    # Get higher level domain from passed domain
    higher_level_domain = re.sub('^.*?\.', '', domain)

    # Add domain to a list whose key corresponds to its higher level domain
    # (or create a list if one doesn't exist for that higher-level domain)
    domains_by_level_dict.setdefault(higher_level_domain, set()).add(domain)

    # Recursively add even higher domains, stopping when no dot is found
    if '.' in higher_level_domain:
        get_domains_by_level(higher_level_domain, domains_by_level_dict)


if __name__ == '__main__':
    main()
