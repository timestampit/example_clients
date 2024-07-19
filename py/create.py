#!/usr/bin/env python3

# This command line program creates a Trusted Timestamp using timestampit.com.

import argparse
import hashlib
from pathlib import Path
from sys import exit
import requests
from requests.auth import HTTPBasicAuth

# Parse the command line
parser = argparse.ArgumentParser(
    description="Create a Trusted Timestamp using www.timestampit.com"
)
parser.add_argument("filename", help="The file to create a Trusted Timestamp for")
parser.add_argument("username", help="timestampit.com username")
parser.add_argument("password", help="timestampit.com password")
parser.add_argument(
    "-H", "--host", help="API host", default="https://www.timestampit.com"
)
parser.add_argument(
    "-o", "--output-filename", help="The filename where the proof is stored"
)
parser.add_argument("-v", "--verbose", action="store_true")
args = parser.parse_args()

# Hash the input file. The hash digest will be sent to the API
file_path = Path(args.filename)
if not file_path.is_file():
    print("Error: input file does not exist: " + args.filename)
    exit(1)
digest = hashlib.sha256(file_path.read_bytes()).hexdigest()

# The output filename defaults to the input filename with .proof extension added
output_filename = args.output_filename
if output_filename is None:
    output_filename = args.filename + ".tt"

# Get the file hash digest in order to send to the API
post_data = {"algorithm": "sha256", "digest": digest}

# Perform the actual API request to create a Trusted Timestamp
basic_auth = HTTPBasicAuth(args.username, args.password)
create_url = args.host + "/create"
if args.verbose:
    print("Performing request: POST " + create_url)
response = requests.post(create_url, auth=basic_auth, data=post_data)

# Check if the API call succeeded
if response.status_code != 201:
    print("Error: The request to create a Trusted Timestamp was not successful")
    print(response.text)
    exit(1)

# Pretty print the new Trusted Timestamp
if args.verbose:
    print("Trusted Timestamp")
    print("-----")
    print(response.text)
    print("-----")

# Write the new Trusted Timestamp to the output file
if args.verbose:
    print("Writing Trusted Timestamp to output file: " + output_filename)
output = open(output_filename, "w", encoding="utf-8")
output.write(response.text)
output.close()

# Everything worked
if args.verbose:
    print("Trusted Timestamp successfully created")
