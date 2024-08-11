#!/bin/bash

set -e

LC_ALL=POSIX

# Parse the command line
if [ "$#" -ne 1 ]; then
  echo "usage: $0 <repo timestamp file>"
  exit 1
fi
repo_timestamp_file=$1
if ! test -f "$repo_timestamp_file"; then
  echo "Error: No such file: $repo_timestamp_file"
  exit 1
fi

timestamp=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "3")
hash_algo=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "4")
expected_repo_digest=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "5")
key_url=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "6")
sha=$(head -1 "$repo_timestamp_file" | cut -d "|" -f "7" | jq -r .sha)

if [[ "$hash_algo" != "sha256" ]]; then
  echo "This script only supports timestamps made with sha256 hashes"
  exit 1
fi

local_clone=$(mktemp -d)
git clone . $local_clone

pushd $local_clone
git checkout $sha
repo_digest=$(git ls-tree --full-tree -r --name-only HEAD | sort | xargs shasum -a 256 | shasum -a 256 | awk '{print $1}')
popd
rm -rf $local_clone

if [[ "$expected_repo_digest" == "$repo_digest" ]]; then
  echo "Repo digests match"
else
  echo "Repo digests do not match"
  exit 1
fi

tmp_dir=$(mktemp -d)
message_file="$tmp_dir/message"
signature_file="$tmp_dir/sig"
key_file="$tmp_dir/key"

head -1 "$repo_timestamp_file" | tr -d "\n" > "$message_file"
head -2 "$repo_timestamp_file" | tail -1 | tr -d "\n" | base64 -D > "$signature_file"
curl -s -o "$key_file" "$key_url"

# Perform the openssl verification
openssl pkeyutl \
  -verify -pubin \
  -inkey "$key_file" \
  -rawin -in "$message_file" \
  -sigfile "$signature_file"

echo "All verifications successful"
echo "All files in this repo at commit $sha were created no later than $timestamp"
