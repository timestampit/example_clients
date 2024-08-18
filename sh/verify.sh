#!/bin/bash

# Stop immediately if any command errors
set -e

# Parse the command line
if [ "$#" -ne 2 ]; then
  echo "usage: $0 <file to verify> <proof file>"
  exit 1
fi
file_to_verify=$1
trusted_timestamp_file=$2

# Validate the arguments
if ! test -f "$file_to_verify"; then
  echo "Error: No such file: $file_to_verify"
  exit 1
fi
if ! test -f "$trusted_timestamp_file"; then
  echo "Error: No such file: $trusted_timestamp_file"
  exit 1
fi

# split the trusted timestamp into first and second lines (message and signature)
trusted_timestamp_data=$(head -1 "$trusted_timestamp_file" | tr -d "\n")

# ensure the trusted timestamp file starts with 1.0|
if [[ $trusted_timestamp_data != 1.0\|*  ]]; then
  echo "Error: $trusted_timestamp_file does not appear to be a TimestampIt! Trusted Timestamp version 1.0 file"
  exit 1
fi

# ensure the trusted timestamp file first line has 6 | characters (7 fields)
if [[ 6 -ne $(echo $trusted_timestamp_data | tr -cd '|' | wc -c) ]]; then
  echo "Error: $trusted_timestamp_file does not have exactly 6 | characters on the first line, indicating this is not a valid TimestampIt! Trusted Timestamp version 1.0 file"
  exit 1
fi

# Extract the needed fields from the Trusted Timestamp message (the first line)
timestamp=$(echo $trusted_timestamp_data | cut -d "|" -f "3")
hash_algo=$(echo $trusted_timestamp_data | cut -d "|" -f "4")
expected_hash_digest=$(echo $trusted_timestamp_data | cut -d "|" -f "5")
key_url=$(echo $trusted_timestamp_data | cut -d "|" -f "6")

if [[ "$hash_algo" != "sha256" ]]; then
  echo "This script only supports timestamps made with sha256 hashes"
  exit 1
fi

# Validate the hash in the trusted timestamp matches the actual hash of the file
echo "$expected_hash_digest $file_to_verify" | sha256sum --check

# Prepare files for openssl which is used to perform the actual verification
# Create distinct files for the message and the signature
tmp_dir=$(mktemp -d)
message_file="$tmp_dir/message"
signature_file="$tmp_dir/sig"
key_filename="$tmp_dir/key"
# message is the first line of the Trusted Timestamp **without a newline**
echo -n "$trusted_timestamp_data" > "$message_file"
# signature is the second line of the Trusted Timestamp, decoded from base64 to raw bytes
head -2 "$trusted_timestamp_file" | tail -1 | tr -d "\n" | base64 -D > "$signature_file"
# Attempt to get the key from the key url within the Trusted Timestamp.
# If that fails, get it from the GitHub replica repo
if ! curl --fail --silent --output "$key_filename" "$key_url"; then
  # get the key id from the key url
  # key id is kleybzu2afwz for https://timestampit.com/key/kleybzu2afwz
  key_id=$(echo "$key_url" | rev | cut -d '/' -f 1 | rev)
  github_backup_key_url="https://raw.githubusercontent.com/timestampit/keychain/main/keys/pem/$key_id.pem"
  echo "Failed to get verification key at $key_url. Attempting to get it from backup repo: $github_backup_key_url"
  if ! curl --fail --silent --output "$key_filename" "$github_backup_key_url"; then
    echo "ERROR: Failed to acquire verification key from either $key_url or $github_backup_key_url"
    exit 1
  fi
fi

# Perform the openssl verification
openssl pkeyutl \
  -verify -pubin \
  -inkey "$key_filename" \
  -rawin -in "$message_file" \
  -sigfile "$signature_file"

echo "All verifications successful"
echo "$file_to_verify was created no later than $timestamp"

rm -rf $tmp_dir
