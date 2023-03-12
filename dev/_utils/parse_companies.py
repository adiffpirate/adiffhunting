import argparse
import re
import json

def main():
    parser = argparse.ArgumentParser(
        description=(
            'Write csv files based on companies JSON'
        )
    )
    parser.add_argument('-f', '--file', help='JSON file', required=True)
    parser.add_argument('-o', '--output', help='Directory where files will be created', required=True)
    # Parse out arguments ignoring the first two (because we're inside a command)
    args = parser.parse_args()

    # Read JSON file
    with open(args.file) as file:
        parsed_json = json.loads(file.read())

    # For each key on JSON, write csv file
    for company in parsed_json.keys():
        # Open out file
        csv_file = open(f"{args.output}/{company}.csv", 'w')
        # Get headers
        headers = sorted(list(set([ key for domains in parsed_json[company] for key in domains.keys() ])))
        csv_file.write(','.join(headers) + '\n')
        # Write domains to file
        for domain in parsed_json[company]:
            for header in headers:
                if header in domain.keys():
                    csv_file.write(f"{str(domain[header]).lower()}")
                if header != headers[-1]: # If is not the last header
                    csv_file.write(',') # Add comma
            csv_file.write('\n')

    # Close file
    csv_file.close()

if __name__ == '__main__':
    main()
