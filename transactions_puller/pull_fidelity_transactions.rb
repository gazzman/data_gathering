#!/usr/bin/ruby
require 'blogins'

include BLogins

login_file = ARGV[0]
directory = ARGV[1]

def pull_fidelity_transactions(user, pass, directory = 'Fidelity')
    headless = Headless.new
    headless.start

    date = (Time.now - 24*60*60)

    # Goto local directory
    puts 'Prepping directory ' + directory
    begin
        FileUtils.cd(directory)
    rescue Errno::ENOENT
        FileUtils.mkdir(directory)
        FileUtils.cd(directory)
    end

    # Set some variables
    autosave_mime_types = 'text/comma-separated-values,text/csv,application/CSV'
    download_directory = "#{Dir.pwd}"

    # Autodownload profile (thanks to WatirMelon!)
    profile = Selenium::WebDriver::Firefox::Profile.new
    profile['browser.download.folderList'] = 2 # custom location
    profile['browser.download.dir'] = download_directory
    profile['browser.helperApps.neverAsk.saveToDisk'] = autosave_mime_types

    # Goto page    
    b = Watir::Browser.new :firefox, :profile => profile
    puts 'Logging in'
    fidelity_login(b, user, pass)

    # Grab the data
    puts 'Grabbing Data'
    b.a(:class => 'top-quick-link').click
    b.a(:text => 'Transaction History').click
    f = b.frame(:title => 'Main Content').frame(:title => 'Savings and Retirement Section')
    f = f.frame(:title => 'Section Content')
    f.a(:text => 'Transaction History').when_present.click
    f.span(:text => 'Download Transaction History').when_present.click
    f.select_list(:name => 'dropDownSelection').when_present.select 'Custom Date Range'
    f.text_field(:name => 'dateFrom').when_present.set '01/01/1990'
    f.text_field(:name => 'dateTo').when_present.set date.strftime('%m/%d/%Y')
    f.select_list(:name => 'fileFormatDropDownSelection').when_present.select 'CSV'
    f.button(:text => 'Download').when_present.click

    # Logout
    puts 'Logging out'
    fidelity_logout(b)
    b.close()

    # Copy the position data to the simple filename
    update_local_positions_file('history', date.iso8601)

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
    pull_fidelity_transactions(user, pass, directory = ARGV[1])
else
    pull_fidelity_transactions(user, pass)
end
