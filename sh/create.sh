#!/bin/sh

set -e

# Parse the command line
if [ "$#" -ne 2 ]; then
  echo "usage: $0 <file to timestamp> <timestampit username>"
  exit 1
fi
filename_to_timestamp=$1
username=$2
output_filename="$filename_to_timestamp.tt"

if ! test -f "$filename_to_timestamp"; then
  echo "No such file: $filename_to_timestamp"
  exit 2
fi

# Get the hash of the file, trim off any other output like the filename
digest=$(shasum -a 256 "$filename_to_timestamp" | cut -f 1 -d ' ')

host="http://127.0.0.1:3001"
endpoint="/create"
encoded_args="digest=$digest&algorithm=sha256"

cmd="curl -s -u "$username" -X POST -d "$encoded_args" $host$endpoint"

echo "Running: $ $cmd"
echo

proof=$($cmd)

echo
echo "Proof"
echo "-----"
echo "$proof"
echo "-----"
echo

echo "$proof" > "$output_filename"

echo "Wrote to $output_filename"
