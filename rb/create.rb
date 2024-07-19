#!/usr/bin/env ruby
# frozen_string_literal: true

# This example implementation uses only the ruby stdlib, no gems
require 'net/http'
require 'openssl'
require 'optparse'

# Parse the command line
usage_help = "Usage: #{$PROGRAM_NAME} [options] <file to timestamp> <username> <password>"
options = {
  host: 'https://www.timestampit.com',
  verbose: false
}
OptionParser.new do |parser|
  parser.banner = usage_help

  parser.on('-h', '--host hostname', 'Timestampit host to use') do |host|
    options[:host] = host
  end

  parser.on('-o', '--output filename', 'Filename to save the new Trusted Timestamp to') do |filename|
    options[:output_filename] = filename
  end

  parser.on('-v', '--[no-]verbose', 'Run verbosely') do |v|
    options[:verbose] = v
  end
end.parse!

if ARGV.count != 3
  puts usage_help
  exit(1)
end

options[:file_to_timestamp] = ARGV.shift
options[:username] = ARGV.shift
options[:password] = ARGV.shift

# Hash the input file. The hash digest will be sent to the API
unless File.exist?(options[:file_to_timestamp])
  puts "Error: File not found: #{options[:file_to_timestamp]}"
  exit(1)
end
puts "INFO: Hashing input file #{options[:file_to_timestamp]}" if options[:verbose]
digest = Digest::SHA256.file(options[:file_to_timestamp]).hexdigest

# Perform the POST request to create the Trusted Timestamp
# This takes a few lines of code using just the standard library Net
post_uri = URI("#{options[:host]}/create")
req = Net::HTTP::Post.new(post_uri)
req.set_form_data(algorithm: 'sha256', digest: digest)
req.basic_auth(options[:username], options[:password])
puts "INFO: Performing POST request to #{post_uri.hostname}" if options[:verbose]
response = Net::HTTP.start(post_uri.hostname, post_uri.port, use_ssl: post_uri.scheme == 'https') do |http|
  http.request(req)
end
puts "INFO: Got response code #{response.code}" if options[:verbose]

# Ensure the creation was successful
unless response.code == '201'
  puts 'Error: The request to create a Trusted Timestamp was not successful'
  print response.body
  exit(1)
end

# Save the new proof into a file
output_filename = options.fetch(:output_filename, "#{options[:file_to_timestamp]}.tt")
puts "INFO: Writing the new Trusted Timestamp to #{output_filename}" if options[:verbose]
File.open(output_filename, 'w') { |f| f.write response.body }

puts 'INFO: Trusted Timestamp successfully created' if options[:verbose]
