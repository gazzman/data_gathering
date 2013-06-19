#!/usr/bin/ruby
module BLogins
    require 'rubygems'

    require 'csv'
    require 'fastercsv'
    require 'fileutils'
    require 'headless'
    require 'time'
    require 'watir-webdriver'

    ########################################################################
    # Schwab
    ########################################################################
    def schwab_login(browser, user, pass, opts={})
        defaults = {:url => 'http://www.schwab.com', 
                    :start_page => 'Positions'}
        opts = defaults.merge(opts)
        
        browser.goto(opts[:url])
        form = browser.form(:id => 'login')

        form.text_field(:name => 'SignonAccountNumber').when_present.click
        form.text_field(:name => 'SignonAccountNumber').when_present.set user
        form.text_field(:name => 'SignonPassword').when_present.click
        form.text_field(:name => 'SignonPassword').when_present.set pass
        form.select_list(:name => 'StartAnchor').select opts[:start_page]

        form.a(:onclick => 'submitLogin()').click
    end

    def schwab_logout(browser)
        browser.a(:text => 'Log Out').click
    end    

    ########################################################################
    # Scottrade
    ########################################################################
    def scottrade_login(browser, user, pass, url='http://www.scottrade.com', 
                        start_page='Positions')
        browser.goto(url)

        browser.text_field(:name => 'account').when_present.set user
        browser.text_field(:name => 'password').when_present.set pass
        browser.select_list(:name => 'firstPage').when_present.select start_page

        browser.button(:class => 'login-btn').click        
    end

    def scottrade_logout(browser)
        browser.button(:class => 'LogoffButton').click
    end

    ########################################################################
    # Fidelity
    ########################################################################
    def fidelity_login(browser, user, pass, url='http://www.401k.com')
        browser.goto(url)

        browser.text_field(:name => 'temp_id').when_present.set user
        browser.text_field(:name => 'PIN').when_present.set pass

        browser.button(:value => 'Log In').click        
    end

    def fidelity_logout(browser)
        browser.frame(:title => 'Site Navigation').a(:text => 'Log Out').click
    end

    ########################################################################
    # Positions file updater
    ########################################################################
    def update_local_positions_file(posfile_stub, date=nil, acct_num=nil)
        # Copy the position data to the simple filename
        puts 'Updating local files'
        if Dir.entries('.').include?('%s.csv' % posfile_stub)
            FileUtils.rm('%s.csv' % posfile_stub)
        end
        e = []
        re = Regexp.new('%s' % posfile_stub)
        Dir.entries('.').select{|f| f =~ re}.each {|i|
            e << [i, File.ctime(i)]
        }
        latest = e.sort_by{|i| i[1]}[-1][0]

        if date
            temp = File.new('temp', 'w')
            temp << "Positions as of %s\n" % date
            data = File.open(latest, 'r')
            temp << data.read()
            temp.close()
            FileUtils.rm(latest)
            FileUtils.cp('temp', latest)
            FileUtils.rm('temp')
        end
        if acct_num
            temp = File.new('temp', 'w')
            temp << "Account_Num %s\n" % acct_num
            data = File.open(latest, 'r')
            temp << data.read()
            temp.close()
            FileUtils.rm(latest)
            FileUtils.cp('temp', latest)
            FileUtils.rm('temp')
        end
        FileUtils.cp(latest, '%s.csv' % posfile_stub)
        puts 'Latest datafile is ' + latest
        puts "Copied to %s.csv\n\n" % posfile_stub
        FileUtils.cd('..')
        

    end

end
