#!/usr/bin/ruby
require 'rubygems'

require 'csv'
require 'fastercsv'
require 'fileutils'
require 'headless'
require 'time'
require 'watir-webdriver'

require 'blogins'

include BLogins

login_file = ARGV[0]
directory = ARGV[1]

def get_schwab(user, pass, directory = 'Schwab')
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
    schwab_login(b, user, pass)

    # Show full descriptions
    b.execute_script("javascript:swapColumnWithResize('longtext','ctl00_wpm_P_P_outerDiv','ctl00_wpm_P_P_hDOrP','ctl00_wpm_P_P_hLOrS')")

    # Pull all brokerage positions
    b.div(:id => 'accountSelector').a.click
    b.a(:text => 'Show All Brokerage Accounts').when_present.click
    b.a(:text => 'Export').click
    b.windows[1].use
    b.a(:id => "ctl00_WebPartManager1_wpExportDisclaimer_ExportDisclaimer_btnOk").click
    b.windows[0].use

    # Pull data for bank account
    b.a(:href => 'https://investing.schwab.com/secure/cc/accounts?cmsid=P-1924981&lvl1=accounts').click
    bank_cash = b.span(:id => 'ctl00_wpm_ac_ac_ltd').text

    # Logout
    puts 'Logging out'
    schwab_logout(b)
    b.close()

    # Store the cash data
    fname = 'Bank.csv'
    fname_ts = 'Bank_' + Time.now.getutc.iso8601 + '.csv'

    headers = ['Source', 'Amount']
    f = File.new(fname_ts, 'w')
    csv = FCSV.new(f, {:headers => :first_row, :write_headers => true})
    head_row = FCSV::Row.new(headers, headers, header_row = true)
    csv << head_row
    field_row = FCSV::Row.new(headers, ['Bank', bank_cash])
    csv << field_row
    csv.close()

    if Dir.entries('.').include?(fname)
        FileUtils.rm(fname)
    end
    puts 'Latest datafile is ' + fname_ts
    FileUtils.cp(fname_ts, fname)
    puts "Copied to " + fname + "\n\n"

    # Copy the position data to the simple filename
    update_local_positions_file('All_Accounts_Positions')

    headless.destroy
end

# Rudimentary and insecure way of getting login data
# First (and only) argument is a two-line file.
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
    get_schwab(user, pass, ARGV[1])
else
    get_schwab(user, pass)
end
