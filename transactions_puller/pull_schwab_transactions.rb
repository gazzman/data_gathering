#!/usr/bin/ruby
require 'blogins'

include BLogins

login_file = ARGV[0]
directory = ARGV[1]

def get_schwab_transactions(user, pass, directory = 'Schwab')
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
    schwab_login(b, user, pass, :start_page => 'History')

    fname_stubs = []
    # Grab the data
    puts 'Grabbing Data'

    # Pull all brokerage positions
    b.div(:id => 'accountSelector').a.click
    num_accts = b.ul(:class => 'brokerage-account-list').when_present.lis.length
    b.div(:id => 'accountSelector').a.click
    for i in 0...num_accts
        b.div(:id => 'accountSelector').a.click
        
        acc_num = b.ul(:class => 'brokerage-account-list').when_present\
                   .lis[i]\
                   .span(:class => 'account-number')\
                   .text
        fname_stubs << '%s%s_Transactions' % ['X'*4, acc_num[-4..-1]]
        b.ul(:class => 'brokerage-account-list').lis[i].a.click
        b.a(:text => 'Export').when_present.click
        b.windows[1].use
        b.a(:id => "ctl00_WebPartManager1_wpExportDisclaimer_ExportDisclaimer_btnOk").click
        b.windows[0].use
    end

    # Pull data for bank account
    b.div(:id => 'accountSelector').a.click
    acc_num = b.ul(:class => 'schwab-account-list').when_present\
                .li\
                .span(:class => 'account-number')\
                .text
    acc_name = b.ul(:class => 'schwab-account-list').when_present\
                .li\
                .span(:class => 'account-name')\
                .text.strip
    fname_stubs << '%s%s_%s_Transactions' % ['X'*6, acc_num[-6..-1], acc_name]
    b.ul(:class => 'schwab-account-list').li.a.click
    b.a(:text => 'Export').when_present.click
    b.windows[1].use
    b.a(:id => "ctl00_WebPartManager1_wpExportDisclaimer_ExportDisclaimer_btnOk").click
    b.windows[0].use

    # Logout
    puts 'Logging out'
    schwab_logout(b)
    b.close()

    # Copy the position data to the simple filename
    fname_stubs.each do |stub|
        update_local_positions_file(stub)
        FileUtils.cd(directory)
    end
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
    get_schwab_transactions(user, pass, ARGV[1])
else
    get_schwab_transactions(user, pass)
end
