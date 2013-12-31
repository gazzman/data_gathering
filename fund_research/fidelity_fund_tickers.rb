#!/usr/bin/ruby
'''
A script for printing the ticker symbols of investment
choices a Fidelity 401k offers.

'''
require 'rubygems'

require 'blogins'

include BLogins

login_file = ARGV[0]

def pull_fidelity_positions(user, pass)
    headless = Headless.new
    headless.start

    # Goto page    
    b = Watir::Browser.new :firefox
    $stderr.puts 'Logging in'
    fidelity_login(b, user, pass)

    # Grab the data
    $stderr.puts 'Navigating to Data'
    b.a(:text => /Quick Links/).wait_until_present
    b.a(:text => /Quick Links/).click
    b.a(:text => "Investment Performance and Research").wait_until_present
    b.a(:text => "Investment Performance and Research").click

    $stderr.puts 'Sending Data to STDOUT'
    b.tr(:class => "0AR row-border").wait_until_present
    b.trs(:class => "0AR row-border").each{ |tr|
        m = /\(([A-Z]+)\)/.match(tr.td.text)
        if m
            puts m[1]
        end
    }

    # Logout
    $stderr.puts 'Logging out'
    fidelity_logout(b)
    b.close()

    headless.destroy
end

# Rudimentary and insecure way of getting login data
# First argument is a two-line file.
# Line 1 is username
# Line 2 is password
user = String.new
pass = String.new
File.open(login_file) do |f|
  user, pass = f.read.split("\n")
end

pull_fidelity_positions(user, pass)
