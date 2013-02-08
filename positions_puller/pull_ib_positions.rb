#!/usr/bin/ruby
require 'rubygems'

require 'fileutils'
require 'open-uri'
require 'rexml/document'
require 'time'
require 'uri'

login_file = ARGV[0]
directory = ARGV[1]

def pull_ib_positions(token, id, directory = 'InteractiveBrokers')
    # Goto local directory
    puts 'Prepping directory ' + directory
    begin
        FileUtils.cd(directory)
    rescue Errno::ENOENT
        FileUtils.mkdir(directory)
        FileUtils.cd(directory)
    end

    base_url = 'https://www.interactivebrokers.com/Universal/servlet/'
    req = 'FlexStatementService.SendRequest?t=' + token + '&q=' + id
    req_url = base_url + req
    req_uri = URI.parse(req_url)

    # Request Data
    puts 'Getting flex query ' + id
    req = open(req_uri)
    resp = REXML::Document.new(req)
    ref_code = resp.root.elements['code'].text
    count = 0
    while ref_code == 'Statement is incomplete at this time. Please try again shortly.'
        if count > 5
            puts "Try getting this one another time.\n\n"
            return ref_code
        end
        puts ref_code + "\nPlease wait just a moment."
        req = open(req_uri)
        resp = REXML::Document.new(req)
        ref_code = resp.root.elements['code'].text
        sleep(1)
        count += 1
    end
    req.close()

    ts = resp.root.attributes['timestamp']
    ts = Time.parse(ts)
    puts 'Timestamp is ' + ts.iso8601

    if ref_code == "Too many requests have been made from this token. Please try again shortly."
        puts ref_code + "\n\n"
        return ref_code
    else
        puts 'Request id is ' + ref_code
    end
    
    # Get data
    get = 'FlexStatementService.GetStatement?q=' + ref_code + '&t=' + token
    get_url = base_url + get
    get_uri = URI.parse(get_url)
    data = open(get_uri)
    statement = REXML::Document.new(data)

    in_progress = 'Statement generation in progress. Please try again shortly.'
    while statement.root[1].text==in_progress
        puts in_progress
        data = open(get_uri)
        statement = REXML::Document.new(data)
        sleep(1)
    end
    data.seek(0)

    fname = 'All_Positions.xml'
    fname_ts = 'All_Positions_%s.xml' % ts.iso8601
    f = File.new(fname_ts, 'w') << data.read()
    f.close()
    data.close()

    puts 'Updating local files'
    if Dir.entries('.').include?(fname)
        FileUtils.rm(fname)
    end
    puts 'Latest datafile is ' + fname_ts
    FileUtils.cp(fname_ts, fname)
    puts "Copied to " + fname + "\n\n"
    FileUtils.cd('..')
end

# First argument is a two-line file.
# Line 1 is token
# Line 2 is flex query id
token = String.new
id = String.new
File.open(login_file) do |f|
  token, id = f.read.split("\n")
end

# Second argument is a custom path where you want the data.
# Default is the name of the brokerage.
if ARGV[1]
    pull_ib_positions(token, id, directory = ARGV[1])
else
    pull_ib_positions(token, id)
end
