#!/usr/bin/ruby

module BLogins

    ########################################################################
    # Schwab
    ########################################################################
    def schwab_login(browser, user, pass, opts={})
        defaults = {:url => 'http://www.schwab.com', 
                    :start_page => 'Positions'}
        opts = defaults.merge(opts)
        
        browser.goto(opts[:url])
        form = browser.form(:id => 'SignonForm')

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

end
