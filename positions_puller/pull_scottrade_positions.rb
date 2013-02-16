#!/usr/bin/ruby
require 'blogins'

include BLogins

login_file = ARGV[0]
directory = ARGV[1]

def pull_scottrade_positions(user, pass, directory = 'Scottrade')
    headless = Headless.new
    headless.start

    # Goto local directory
    puts 'Prepping directory ' + directory
    begin
        FileUtils.cd(directory)
    rescue Errno::ENOENT
        FileUtils.mkdir(directory)
        FileUtils.cd(directory)
    end

    # Set some variables
    autosave_mime_types = 'text/comma-separated-values,text/csv,application/csv'
    download_directory = "#{Dir.pwd}"

    # Autodownload profile (thanks to WatirMelon!)
    profile = Selenium::WebDriver::Firefox::Profile.new
    profile['browser.download.folderList'] = 2 # custom location
    profile['browser.download.dir'] = download_directory
    profile['browser.helperApps.neverAsk.saveToDisk'] = autosave_mime_types

    # Goto page    
    b = Watir::Browser.new :firefox, :profile => profile
    puts 'Logging In'
    scottrade_login(b, user, pass)
    
    # Grab the data
    puts 'Grabbing Data'
    
    while !b.div(:class => 'detail-export-container').exists?
        sleep(0.5)
    end
    b.div(:class => 'detail-export-container').click

    b.a(:href => 'Balances.aspx').click
    b.a(:id => 'BalanceSummary1_AccountBalanceTabStrip1_lbtnDetailed').click
    broker_cash = b.span(:id => 'DetailedBalance1_lblCashBalanceTrading').text

    begin
        bank_cash = b.span(:id => 'DetailedBalance1_lblTotalAvailableBankBalance').text
    rescue Watir::Exception::UnknownObjectException
        bank_cash = 0
    end

    # Logout
    scottrade_logout(b)
    b.close()

    # Store the cash data
    fname = 'Cash.csv'
    fname_ts = 'Cash_' + Time.now.getutc.iso8601 + '.csv'

    headers = ['﻿Symbol', 'Description', 'Qty', 'Last Price', 'Mkt Value']

    f = File.new(fname_ts, 'w')
    csv = FCSV.new(f, {:headers => :first_row, :write_headers => true})
    head_row = FCSV::Row.new(headers, headers, header_row = true)
    csv << head_row
    field_row = FCSV::Row.new(headers, ['USD', 'Brokerage', broker_cash, 1, 
                                        broker_cash])
    csv << field_row
    field_row = FCSV::Row.new(headers, ['USD', 'Bank', bank_cash, 1, 
                                        broker_cash])
    csv << field_row
    csv.close()

    if Dir.entries('.').include?(fname)
        FileUtils.rm(fname)
    end
    puts 'Latest datafile is ' + fname_ts
    FileUtils.cp(fname_ts, fname)
    puts "Copied to " + fname + "\n\n"

    # Copy the position data to the simple filename
    update_local_positions_file('DetailPositions')

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

# Second argument is a custom path where you want the data.
# Default is the name of the brokerage.
if ARGV[1]
    pull_scottrade_positions(user, pass, directory = ARGV[1])
else
    pull_scottrade_positions(user, pass)
end
