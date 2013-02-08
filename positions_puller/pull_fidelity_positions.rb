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
    while !b.a(:title => 'Accounts').exists?
        sleep(0.5)
    end
    b.a(:title => 'Accounts').click

    while !b.a(:title => 'Portfolio Investments').exists?
        sleep(0.5)
    end
    b.a(:title => 'Portfolio Investments').click

    while !b.frame(:title => 'Main Content').body.a(:onclick => 'displayCSVPage();').exists?
        sleep(0.5)
    end
    b.frame(:title => 'Main Content').body.a(:onclick => 'displayCSVPage();').click

    # Logout
    puts 'Logging out'
    fidelity_logout(b)
    b.close()

    # Copy the position data to the simple filename
    puts 'Updating local files'
    if Dir.entries('.').include?('Portfolio_Position.csv')
        FileUtils.rm('Portfolio_Position.csv')
    end
    e = []
    Dir.entries('.').select{|f| f =~ /Portfolio_Position_/}.each {|i|
        e << [i, File.ctime(i)]
    }
    latest = e.sort_by{|i| i[1]}[-1][0]

    puts 'Latest datafile is ' + latest
    FileUtils.cp(latest, 'Portfolio_Position.csv')
    puts "Copied to Portfolio_Position.csv\n\n"
    FileUtils.cd('..')

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
