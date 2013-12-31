#!/usr/bin/ruby
require 'blogins'

include BLogins

login_file = ARGV[0]
directory = ARGV[1]

def pull_fidelity_positions(user, pass, directory = 'Fidelity')
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
    autosave_mime_types = 'text/comma-separated-values,text/csv'
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
    b.a(:text => 'Accounts').wait_until_present
    b.a(:text => 'Accounts').click

    b.frame(:name => 'mainapp').a(:text => /Portfolio Investments/).wait_until_present
    b.frame(:name => 'mainapp').a(:text => /Portfolio Investments/).click

    b.frame(:title => 'Main Content').body.a(:onclick => 'displayCSVPage();').wait_until_present
    frame = b.frame(:title => 'Main Content')
    frame.body.a(:onclick => 'displayCSVPage();').click
    date = frame.div(:class => 'foot-notes').p.text.split[-2...-1]
    date = '%s 16:00:00' % date
    date = Time.parse(date).iso8601

    # Logout
    puts 'Logging out'
    fidelity_logout(b)
    b.close()

    # Copy the position data to the simple filename
    update_local_positions_file('Portfolio_Position', date)

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
    pull_fidelity_positions(user, pass, directory = ARGV[1])
else
    pull_fidelity_positions(user, pass)
end
