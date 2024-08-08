#!/bin/sh

# Stop immediately if any command errors
set -e

# Parse the command line
if [ "$#" -ne 2 ]; then
  echo "usage: $0 <file to verify> <proof file>"
  exit 1
fi
file_to_verify=$1
proof_file=$2

# Validate the arguments
if ! test -f "$file_to_verify"; then
  echo "Error: No such file: $file_to_verify"
  exit 1
fi
if ! test -f "$proof_file"; then
  echo "Error: No such file: $proof_file"
  exit 1
fi

# Extract the needed fields from the Trusted Timestamp message (the first line)
hash_algo=$(head -1 "$proof_file" | cut -d "|" -f "4")
expected_hash_digest=$(head -1 "$proof_file" | cut -d "|" -f "5")
key_url=$(head -1 "$proof_file" | cut -d "|" -f "6")
key_id=$(echo "$key_url" | rev | cut -d '/' -f 1 | rev)

# Validate the hash in the trusted timestamp matches the actual hash of the file
echo "$expected_hash_digest $file_to_verify" | sha256sum --check

# Prepare files for openssl which is used to perform the actual verification
# Create distinct files for the message and the signature
tmp_dir=$(mktemp -d -t $(basename $0))
message_file="$tmp_dir/$(basename "$proof_file").message"
signature_file="$tmp_dir/$(basename "$proof_file").sig"
# message is the first line of the Trusted Timestamp **without a newline**
head -1 "$proof_file" | tr -d "\n" > "$message_file"
# signature is the second line of the Trusted Timestamp, decoded from base64 to raw bytes
tail -1 "$proof_file" | tr -d "\n" | base64 -D > "$signature_file"
# Ensure the public/verification key file is in place
key_filename="$tmp_dir/$key_id.pem"
if ! test -f "$key_filename"; then
  curl -s -o "$key_filename" "$key_url"
fi

# Perform the openssl verification
openssl pkeyutl \
  -verify -pubin \
  -inkey "$key_filename" \
  -rawin -in "$message_file" \
  -sigfile "$signature_file"

echo "All verifications successful"
timestamp=$(head -1 "$proof_file" | cut -d "|" -f "3")
echo "$file_to_verify was created no later than $timestamp"

rm -rf $tmp_dir
