import requests
import json
import os
import subprocess
import re

# Get HackerOne API credentials from environment variables
HACKERONE_USER = os.getenv('HACKERONE_USER')
HACKERONE_TOKEN = os.getenv('HACKERONE_TOKEN')
UTILS_PATH = os.getenv('UTILS')

if not HACKERONE_USER or not HACKERONE_TOKEN or not UTILS_PATH:
    raise ValueError("HACKERONE_USER, HACKERONE_TOKEN, and UTILS environment variables must be set.")

LOG_SCRIPT = os.path.join(UTILS_PATH, "_log.sh")

# Read tld-list.txt located at the script directory
with open(os.path.join(UTILS_PATH, 'tld-list.txt'), 'r') as tld_file:
    tld_list = tld_file.read().splitlines()

# Function to log messages
def log_message(level, message, **kwargs):
    args = [f'{key}={value}' for key, value in kwargs.items()]
    subprocess.run([LOG_SCRIPT, level, message] + args, check=True)

# Base URL for the API
BASE_URL = "https://api.hackerone.com/v1/hackers/programs"

# Function to fetch data from the HackerOne API
def fetch_data(url):
    log_message('info', 'Calling API', url=url)
    response = requests.get(url, auth=(HACKERONE_USER, HACKERONE_TOKEN), headers={'Accept': 'application/json'})
    response.raise_for_status()  # Raise an exception for HTTP errors
    return response.json()

# Function to process the JSON data
def process_data(data):
    processed_data = []
    for item in data:
        attributes = item['attributes']
        program_handle = attributes['handle']
        log_message('info', 'Parsing company', company=program_handle)
        structured_scopes = fetch_structured_scopes(program_handle)
        domains = process_structured_scopes(structured_scopes)

        entry = {
            'name': program_handle,
            'programPage': f"https://hackerone.com/{program_handle}",
            'programPlatform': 'hackerone',
            'canHack': attributes['submission_state'] == 'open',
            'visibility': 'public' if attributes['state'] == 'public_mode' else 'private',
            'domains': domains
        }
        processed_data.append(entry)
    return processed_data

# Function to fetch structured scopes for a given program
def fetch_structured_scopes(handle):
    url = f"https://api.hackerone.com/v1/hackers/programs/{handle}/structured_scopes"
    structured_scopes = []

    log_message('info', 'Fetching structured scopes', company=handle)
    while url:
        data = fetch_data(url)
        structured_scopes.extend(data['data'])
        url = data['links'].get('next')

    return structured_scopes

# Function to process the structured scopes and extract domains
def process_structured_scopes(scopes):
    domains = []

    for scope in scopes:
        attributes = scope['attributes']
        asset_type = attributes['asset_type']
        domain = attributes['asset_identifier']

        if asset_type in ['URL', 'WILDCARD']:
            domain_skip_scans = True

            if domain.startswith('*.'):  # If domain is wildcard
                domain = domain[2:]  # Remove the starting "*."
                if attributes['eligible_for_submission']:
                    # Only run security scans on eligible wildcard domains
                    domain_skip_scans = False

            # TECH DEBT: This should be improved to use the parse_domains.py script

            # Check if the domain name matches the FQDN (Fully Qualified Domain Name) pattern
            if not re.match('(?=^.{4,253}$)(^((?!-)[a-zA-Z0-9-]{0,62}[a-zA-Z0-9]\\.)+[a-zA-Z]{2,63}$)', domain):
                # Skip this asset and log a warning for invalid FQDN
                log_message('warn', 'Asset is not a valid FQDN', asset=domain)
                continue

            # Get domain type
            tld_regex = '(' + '|'.join(tld_list) + ')(\\.[^.]+)?'
            if re.match(f'^{tld_regex}$', domain): # TLD (e.g. 'com')
                domain_type = 'tld'
            elif re.match(f'^[^.]+\\.{tld_regex}$', domain): # Root (one level above TLD e.g. 'foobar.com')
                domain_type = 'root'
            else: # Everything else is Sub (e.g. 'sub.foobar.com')
                domain_type = 'sub'

            domains.append({
                'name': domain,
                'skipScans': domain_skip_scans,
                'level': domain.count('.'),
                'type': domain_type
            })

    # Calculate the number of eligible domains
    eligible_count = 0
    for domain in domains:
        if not domain['skipScans']:
            eligible_count += 1

    log_message('info', 'Processed all domains on scope', total=len(domains), eligible=eligible_count)
    return domains

# Main function to handle pagination and collect all data
def main():
    final_data = []
    url = BASE_URL
    log_message('info', 'Starting crawler')

    while url:
        data = fetch_data(url)
        final_data.extend(process_data(data['data']))
        url = data['links'].get('next')

    print(json.dumps(final_data, indent=2))
    log_message('info', 'Crawling completed successfully')

if __name__ == "__main__":
    main()
