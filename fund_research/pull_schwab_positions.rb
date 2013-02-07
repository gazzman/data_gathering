#!/usr/bin/ruby
require 'rubygems'

require 'csv'
require 'fastercsv'
require 'fileutils'
require 'headless'
require 'logger'
require 'time'
require 'watir-webdriver'

require 'blogins'

login_file = ARGV[0]
directory = ARGV[1]

class SchwabPositions
    include BLogins
    attr_accessor :browser, :frame, :main, :logger

    def initialize(user, pass, opts={})
        default = {:logfile => STDOUT, :log_age => nil, :directory => 'Schwab'}
        opts = default.merge(opts)

        @directory = opts[:directory]
        @logger = Logger.new(opts[:logfile], opts[:log_age])
        @logger.info 'Initializing browser and data'

        # Set some variables
        autosave_mime_types = 'text/comma-separated-values,text/csv,application/csv'
        download_directory = "#{Dir.pwd}/" + @directory
        url = 'http://www.scottrade.com/'

        # Autodownload profile (thanks to WatirMelon!)
        profile = Selenium::WebDriver::Firefox::Profile.new
        profile['browser.download.folderList'] = 2 # custom location
        profile['browser.download.dir'] = download_directory
        profile['browser.helperApps.neverAsk.saveToDisk'] = autosave_mime_types

        @browser = Watir::Browser.new :firefox, :profile => profile
        @user = user
        @pass = pass
    end

    def login()
        @logger.info 'Logging in...'
        schwab_login(@browser, @user, @pass, :start_page => 'Positions')
        @logger.info 'Logged in'
    end

    def logout()
        @logger.info 'Logging out of Schwab...'
        schwab_logout(@browser)
        @logger.info 'Logged out of Schwab.'
    end

    def close()
        logout
        @browser.close
        @logger.info 'Closed @browser'
    end

    def reinit_browser()
        @logger.info 'Reinitializing @browser...'
        @browser.close
        @logger.info 'Opening new @browser'
        @browser = Watir::Browser.new
        login
        @logger.info 'Reinitialization complete'
    end

    def pull_schwab_positions()
        @logger.info 'Prepping directory ' + @directory
        begin
            FileUtils.cd(@directory)
        rescue Errno::ENOENT
            FileUtils.mkdir(@directory)
            FileUtils.cd(@directory)
        end

        # Pull up all accounts
        @browser.div(:id => 'accountSelector').a.click
        @browser.a(:id => 'lnkShowAllBrokerage').wait_until_present
        @browser.a(:id => 'lnkShowAllBrokerage').click
                
        # Pull positions for all accounts
        
        @logger.info 'Pulling positions for all accounts'
        @browser.a(:class => 'link-export').wait_until_present
        @browser.a(:class => 'link-export').click
        @browser.windows[1].use
        @browser.span(:text => 'OK').click
        @browser.windows[0].use
        @logger.info 'Positions pulled'

        @logger.info 'Pulling bank cash data'
        @browser.a(:href => 'https://investing.schwab.com/secure/cc/accounts?cmsid=P-1924981&lvl1=accounts').click
        bank_cash = @browser.span(:id => 'ctl00_wpm_ac_ac_ltd').text
        @logger.info 'Bank cash data pulled'

        @logger.info 'Updating local position files'
        all_pos_fname = 'All_Accounts_Positions.csv'
        if Dir.entries('.').include?(all_pos_fname)
            FileUtils.rm(all_pos_fname)
        end
        latest = nil
        while not latest
            latest = Dir.entries('.').select{|f| f =~ /All_Accounts_Positions_/}.sort[-1]
        end
        @logger.info 'Latest datafile is ' + latest
        FileUtils.cp(latest, all_pos_fname)
        @logger.info 'Copied to ' + all_pos_fname


        @logger.info 'Updating local bank cash files'
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
        @logger.info 'Latest datafile is ' + fname_ts
        FileUtils.cp(fname_ts, fname)
        @logger.info "Copied to " + fname
        FileUtils.cd('..')
    end
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
headless = Headless.new
headless.start
if ARGV[1]
    sp = SchwabPositions.new user, pass, :directory => ARGV[1]
else
    sp = SchwabPositions.new user, pass
end
sp.login
sp.pull_schwab_positions
sp.close
headless.destroy
