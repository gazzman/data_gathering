#!/usr/bin/ruby
require 'rubygems'

require 'csv'
require 'fastercsv'
require 'fileutils'
require 'headless'
require 'time'
require 'watir-webdriver'

login_file = ARGV[0]

def pull_fidelity_positions(user, pass)
    headless = Headless.new
    headless.start

    # Set some variables
    url = 'http://401k.com'

    # Goto page    
    $stderr.puts 'Opening url ' + url
    b = Watir::Browser.new :firefox
    b.goto(url)

    # Login
    $stderr.puts 'Logging In'
    b.text_field(:name => 'temp_id').set user
    b.text_field(:name => 'PIN').set pass
    b.input(:id => 'logButton').click

    # Grab the data
    $stderr.puts 'Grabbing Data'
    while !b.a(:title => 'Accounts').exists?
        sleep(0.5)
    end
    b.a(:title => 'Accounts').click

    while !b.a(:title => 'Review Investment Choices').exists?
        sleep(0.5)
    end
    b.a(:title => 'Review Investment Choices').click

    f = b.frame(:title => 'Main Content').frame(:title => 'Savings and Retirement Section').frame(:title => 'Section Content')    
    as = f.table(:class => 'invBorder').table.tbody.as
    for i in 0...as.length
        title = as[i].text
        as[i].click
        b.windows[1].use
        d = b.frame(:name => 'content').div(:class => 'header-wrapper')
        if d.span(:class => 'subhead').exists?
            puts [title, d.span(:class => 'subhead').text].join(',')
        else
            puts [title, "No symbol"].join(',')
        end
        b.windows[1].close
        f = b.frame(:title => 'Main Content').frame(:title => 'Savings and Retirement Section').frame(:title => 'Section Content')    
        as = f.table(:class => 'invBorder').table.tbody.as
    end

    # Logout
    $stderr.puts 'Logging out'
    b.frame(:title => 'Site Navigation').a(:href => '/Catalina/LongBeach?Command=LOGOUT&Realm=netbenefits').click
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
