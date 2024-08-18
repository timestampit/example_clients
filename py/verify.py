#!/usr/bin/env python3

import argparse
from base64 import b64decode
import hashlib
from pathlib import Path
from sys import exit
from nacl.signing import VerifyKey
from nacl.exceptions import BadSignatureError
import requests

# Parse the command line
parser = argparse.ArgumentParser(
    description="Verify a Trusted Timestamp from www.timestampit.com"
)
parser.add_argument("file_to_verify", help="The file that is being verified")
parser.add_argument("trusted_timestamp_file", help="The Trusted Timestamp file")
parser.add_argument("-v", "--verbose", action="store_true")
args = parser.parse_args()

# Validate existence of the input files
for filename in [args.file_to_verify, args.trusted_timestamp_file]:
    if not Path(filename).is_file():
        print("Error: File does not exist: " + filename)
        exit(1)

# Read the trusted timestamp file, split into message (first line) and signature (second line)
tt = Path(args.trusted_timestamp_file).open()
# Remove any trailing whitespace/newline.
# The tt_message is the verification message so it must be a single line with no trailing whitespace
tt_message = tt.readline().rstrip()
tt_signature = tt.readline().rstrip()
tt.close()

# parse the message into individual fields
tt_ver, tt_id, tt_ts, tt_algo, tt_digest, tt_key_url, tt_ext_data = tt_message.split(
    "|"
)

# Verify the digest from the Trusted Timestamp matches the actual digest
file_bytes = Path(args.file_to_verify).read_bytes()
if tt_algo == "sha256":
    actual_digest = hashlib.sha256(file_bytes).hexdigest()
else:
    print("Error: unsupported hash algorithm: " + tt_algo)
    exit(1)

if args.verbose:
    print("Verifying hash digest")
if not actual_digest == tt_digest:
    print("Fail: Digest mismatch")
    exit(2)

# Retrieve the needed key
if args.verbose:
    print("Retrieving key: " + tt_key_url)
key_response = requests.get(
    tt_key_url, headers={"Accept": "application/octet-stream"}
)
if not key_response.status_code == 200:
  print("Warn: Failed to retrieve verification key from " + tt_key_url + ". Attempting to retrieve from fallback repo...")
  key_id = tt_key_url.split('/')[-1]
  alt_url = "https://raw.githubusercontent.com/timestampit/keychain/main/keys/raw/" + key_id + ".raw"
  key_response = requests.get(alt_url)
  if not key_response.status_code == 200:
    print("Error: Failed to retrieve from verification key")
    exit(3)

# Verify the authenticity of the trusted timestamp
vk = VerifyKey(key_response.content)
try:
    vk.verify(bytes(tt_message, "utf-8"), b64decode(tt_signature))
except BadSignatureError:
    print("Fail: Signature fails verification. This timestamp is not authentic.")
    exit(3)

if args.verbose:
    print("All verifications successful")
print(args.file_to_verify + " was created no later than " + tt_ts)
