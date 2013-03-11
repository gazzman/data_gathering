#!/usr/bin/ruby
require 'blogins'

include BLogins

login_file = ARGV[0]
directory = ARGV[1]

def pull_scottrade_transactions(user, pass, directory = 'Scottrade')
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
    
    # Grab the brokerage data
    puts 'Grabbing Data'
    b.a(:text => 'Account History').when_present.click
    b.select_list(:id => 'Transactions1_ddlDate').when_present.select 'All Available'
    b.button(:id => 'Transactions1_ibtnGo').when_present.click
    b.span(:text => 'Export to Excel').click
    update_local_positions_file('Transactions', date=nil, acct_num=user)
    FileUtils.cd(directory)

    # Grab the banking data
    b.div(:text => 'Banking').click
    b.frame(:id => 'ctl00_MainContent_bankFrame').wait_until_present
    f = b.frame(:id => 'ctl00_MainContent_bankFrame')
    num_accts = f.as(:class => 'textLink').length
    for i in 0...num_accts
        b.div(:text => 'Banking').click
        b.frame(:id => 'ctl00_MainContent_bankFrame').wait_until_present
        f = b.frame(:id => 'ctl00_MainContent_bankFrame')
        f.as(:class => 'textLink')[i].click
        acc_num = f.div(:id => 'unhideNumberCD').text[-4..-1]
        fname = 'trans_%s.csv' % acc_num
        f.div(:class => 'csvLink').a.click
        sleep(3)
        update_local_positions_file('trans', date=nil, acct_num=user)
        FileUtils.cd(directory)
        FileUtils.cp('trans.csv', fname)
        puts "Copied to %s\n\n" % fname
        FileUtils.rm('trans.csv')
    end

    # Logout
    scottrade_logout(b)
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

# Second argument is a custom path where you want the data.
# Default is the name of the brokerage.
if ARGV[1]
    pull_scottrade_transactions(user, pass, directory = ARGV[1])
else
    pull_scottrade_transactions(user, pass)
end
