#!/usr/bin/ruby
require 'rubygems'

require 'csv'
require 'fastercsv'
require 'fileutils'
require 'headless'
require 'time'
require 'watir-webdriver'

login_file = ARGV[0]
directory = ARGV[1]

def pull_schwab_position(b, stem, directory)    
    # Goto local directory
    puts 'Prepping directory ' + directory
    begin
        FileUtils.cd(directory)
    rescue Errno::ENOENT
        FileUtils.mkdir(directory)
        FileUtils.cd(directory)
    end

    # Parse the html tables for header and data
    bodies = Hash.new
    b.h2s.each_with_index {|h2, h2i| bodies[h2.text] = b.tbodys[h2i]}

    header = Hash.new
    bodies.each_pair {|key, value| header[key] = value.tr(:class => 'header-row').ths}

    data = Hash.new
    bodies.each_pair {|key, value| data[key] = value.trs(:class => 'data-row')}

    # Store the data
    data.keys.each { |key|
        puts 'Pulling data for ' + key
        headers = header[key].collect {|i| i.text.gsub("\n", " ")}
        if key == "Cash & Money Market"
            headers.delete("Name (Full | Short)")
        end
        fname = [stem, key].join('_') + '.csv'
        fname_ts = [stem, key, Time.now.getutc.iso8601].join('_') + '.csv'
        
        f = File.new(fname_ts, 'w')
        csv = FCSV.new(f, {:headers => :first_row, :write_headers => true})
        head_row = FCSV::Row.new(headers, headers, header_row = true)
        csv << head_row
        data[key].each { |row|
            fields = row.tds.collect.delete_if{|td| !td.visible?}.collect {|td| td.text}
            field_row = FCSV::Row.new(headers, fields)
            csv << field_row
        }
        csv.close()

        # Copy the position data to the simple filename
        if Dir.entries('.').include?(fname)
            FileUtils.rm(fname)
        end
        puts 'Latest datafile is ' + fname_ts
        FileUtils.cp(fname_ts, fname)
        puts 'Copied to ' + fname
    }
    FileUtils.cd('..')
end

def get_schwab(user, pass, directory = 'Schwab')
    headless = Headless.new
    headless.start

    url = 'https://www.schwab.com/public/schwab/client_home'

    # Goto page    
    puts 'Opening url ' + url
    b = Watir::Browser.new :firefox
    b.goto(url)

    # Login
    puts 'Logging In'
    begin
        b.text_field(:name => 'SignonAccountNumber').set user
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
        b.text_field(:name => 'SignonAccountNumber').set user
    end

    begin
        b.text_field(:name => 'SignonPassword').set pass
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
        b.text_field(:name => 'SignonPassword').set pass
    end

    begin
        b.select_list(:name => 'StartAnchor').select 'Positions'
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
        b.select_list(:name => 'StartAnchor').select 'Positions'
    end

    b.execute_script('javascript:submitLogin()')

    # Show full descriptions
    b.execute_script("javascript:swapColumnWithResize('longtext','ctl00_wpm_P_P_outerDiv','ctl00_wpm_P_P_hDOrP','ctl00_wpm_P_P_hLOrS')")

    # Pull positions for first account
    stem = 'first_account'
    puts 'Pulling positions from ' + stem
    pull_schwab_position(b, stem, directory)


    # Goto last account
    begin
        b.link(:id => 'lnkAcctSelector').click
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
        b.link(:id => 'lnkAcctSelector').click
    end

    while (!b.li(:class => 'last').link(:class => 'link-account').exists?)
        sleep(0.5)
    end
    b.li(:class => 'last').link(:class => 'link-account').click

    # Show full descriptions
    b.execute_script("javascript:swapColumnWithResize('longtext','ctl00_wpm_P_P_outerDiv','ctl00_wpm_P_P_hDOrP','ctl00_wpm_P_P_hLOrS')")

    # Pull positions for last account
    stem = 'last_account'
    puts 'Pulling positions from ' + stem
    pull_schwab_position(b, stem, directory)

    # Pull data for bank account
    b.a(:href => 'https://investing.schwab.com/secure/cc/accounts?cmsid=P-1924981&lvl1=accounts').click
    bank_cash = b.span(:id => 'ctl00_wpm_ac_ac_ltd').text

    # Logout
    puts 'Logging out'
    b.a(:href => 'https://client.schwab.com/logout/logout.aspx?explicit=y').click
    b.close()

    # Goto local directory
    begin
        FileUtils.cd(directory)
    rescue Errno::ENOENT
        FileUtils.mkdir(directory)
        FileUtils.cd(directory)
    end

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
    FileUtils.cd('..')

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
