#!/usr/bin/env ruby
# frozen_string_literal: true

# This example implementation uses only the ruby stdlib, no gems
require 'base64'
require 'net/http'
require 'openssl'
require 'optparse'

# Parse the command line
usage_help = "Usage: #{$PROGRAM_NAME} [options] <file to verify> <trusted timestamp file>"
options = {
  verbose: false
}
OptionParser.new do |parser|
  parser.banner = usage_help

  parser.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    options[:verbose] = v
  end
end.parse!

if ARGV.count != 2
  puts usage_help
  exit(1)
end

options[:file_to_verify] = ARGV.shift
options[:trusted_timestamp_file] = ARGV.shift

# Validate that the input files exist
[options[:file_to_verify], options[:trusted_timestamp_file]].each do |filename|
  unless File.exist?(filename)
    puts "Error: File not found: #{filename}"
    exit(1)
  end
end

# Validate Trusted Timestamp file is in correct format
tt_content = File.read(options[:trusted_timestamp_file])
unless tt_content =~ /\A1.0\|\w{12}\|20\d\d-\d\d-\d\dT\d\d:\d\d:\d\dZ\|\w+\|\w+\|http[^|]+\|[^|]*\n[^|]+\z/m
  puts "Error: #{options[:trusted_timestamp_file]} does not appear to be a valid trusted timestamp file"
  exit(1)
end
# Parse the individual fields from the trusted timestamp file
tt_message, tt_signature = tt_content.lines(chomp: true)
_, _, tt_ts, tt_algo, tt_digest, tt_key_url, = tt_message.split('|')

# Hash the file to verify so it can be compared to hash digest in trusted timestamp
puts "INFO: Hashing #{options[:file_to_verify]}" if options[:verbose]
actual_digest = case tt_algo.to_sym
                when :sha256
                  Digest::SHA256.file(options[:file_to_verify]).hexdigest
                else
                  print "Unsupported Hash algorithm: #{tt_algo}"
                end

# Verify the hash digests match
unless actual_digest == tt_digest
  print "FAIL: hash digest mismatch: #{actual_digest} != #{tt_digest}"
  exit(1)
end

# Initialize the key using the pem key retrieved from the location in the Trusted Timestamp
pem_key = Net::HTTP.get(URI(tt_key_url))
openssl_pkey = OpenSSL::PKey.read(pem_key)
# convert the signature from Base64 to bytes
binary_signature = Base64.strict_decode64(tt_signature)
if openssl_pkey.verify(nil, binary_signature, tt_message)
  puts 'Signature is verified' if options[:verbose]
  puts "Success: #{options[:file_to_verify]} was created no later than #{tt_ts}"
else
  puts 'Fail: Signature fails verification. This Trusted Timestamp is not authentic.'
  exit(1)
end
