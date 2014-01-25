#!/usr/bin/ruby
module BLogins
    require 'rubygems'

    require 'csv'
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

        browser.a(:text => 'Secure Login').when_present.click
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
        if browser.frame(:title => 'Site Navigation').a(:text => 'Log Out').exists?
            browser.frame(:title => 'Site Navigation').a(:text => 'Log Out').click
        else
            browser.a(:text => 'Log Out').click
        end
    end

    ########################################################################
    # Positions file updater
    ########################################################################
    def update_local_positions_file(posfile_stub, date=nil, acct_num=nil, 
                                    extension='csv')
        # Copy the position data to the simple filename
        puts 'Updating local files'
        if Dir.entries('.').include?('%s.%s' % [posfile_stub, extension])
            FileUtils.rm('%s.%s' % [posfile_stub, extension])
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
        FileUtils.cp(latest, '%s.%s' % [posfile_stub, extension])
        puts 'Latest datafile is ' + latest
        puts "Copied to %s.%s\n\n" % [posfile_stub, extension]
        FileUtils.cd('..')
        

    end

end
