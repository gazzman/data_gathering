#!/usr/bin/ruby
require 'blogins'

require 'logger'

class SchwabData
    '''
        A class for gathering research data from Scwhwab.
    '''
    include BLogins
    attr_accessor :browser, :frame, :main, :logger, :country_data, :alt_id, :headers, :data

    def initialize(user, pass, opts={})
        default = {:logfile => STDOUT, :log_age => nil}
        opts = default.merge(opts)

        @logger = Logger.new(opts[:logfile], opts[:log_age])
        @logger.info 'Initializing browser and data'
        @browser = Watir::Browser.new
        @frame = @main = @type = @headers = @data = nil
        @user = user
        @pass = pass

        @country_data = {'BIDU' => 'China', 'YOKU' => 'China',
                         'SINA' => 'China', 'PBR' => 'Brazil',
                         'LULU' => 'Canada', 'UN' => 'Netherlands'}

        @alt_id = {'TCZM' => 'EMC', 'TEM1Z' => 'TEMIX'}

        @field_translator = {'YTD Chg. %' => 'YTD%',
                             'Inception Date' => 'Inception',
                             '52 Week NAV Range' => '52 Week Range',
                             'Total Net Assets' => 'Total Assets',
                             'Net Asset Value' => 'Closing NAV'}
    end

    def login()
        @logger.info 'Logging in...'
        schwab_login(@browser, @user, @pass, :start_page => 'Research')
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

    def navigate_to_research_for(symbol)
        @logger.info 'Navigating to research tab for ' + symbol
        @browser.div(:id => 'chanL1').ul.li(:text => 'Research').a.click
        @frame = @browser.frame(:id => 'wsodIFrame')

        @frame.text_field(:id => 'ccSymbolInput').wait_until_present
        @frame.text_field(:id => 'ccSymbolInput').set symbol
        @frame.button(:id => 'searchSymbolBtn').click
        @frame.div(:id => 'mainContent').wait_until_present

        div = @browser.div(:id => 'chanL2')
        div.ul(:class => 'selected').li(:class => 'active').wait_until_present
        @type = div.ul(:class => 'selected').li(:class => 'active').text
    end

    def navigate_to_tab(tabname)
        tabname = tabname.split.each(&:capitalize!).join(' ')
        if !@frame.ul(:class => 'contain nav page').li(:class => 'active').exists?
            @logger.error "No fund selected. Select a fund to research first."
        elsif @frame.ul(:class => 'contain nav page').li(:class => 'active').text.include?(tabname)
            @logger.info "Already at the \'" + tabname + "\' tab."
        elsif @frame.ul(:class => 'contain nav page').li(:text => tabname).exists?
            @logger.info 'Navigating to ' + tabname
            @frame.ul(:class => 'contain nav page').li(:text => tabname).a.span.click
            @frame.div(:id => 'mainContent').wait_until_present
        else
            @logger.error "Something is wrong. You're not where I expected you to be."
            return nil
        end
        @main = @frame.div(:id => 'mainContent')
    end

    def navigate_to_subtab(tabname)
        tabname = tabname.split.each(&:capitalize!).join(' ')
        if !@frame.ul(:class => 'contain nav pageSub').li(:class => 'active').exists?
            @logger.error "No fund selected. Select a fund to research first."
            return nil
        else
            @frame.ul(:class => 'contain nav pageSub').lis.each {|li|
                if li.text.include?(tabname)
                    li.a.span(:class => 'displayText').click 
                    break
                end
            }
        end
        @main = @frame.div(:id => 'mainContent')
    end

    def get_description(prefix='tickers.')
        @logger.info 'Getting description'
        header = prefix + 'Description'
        @headers << header
        @frame.div(:id => 'modFirstGlance').wait_until_present
        first_glance = @frame.div(:id => 'modFirstGlance') 
        if first_glance.h2(:class => 'heading2 normal flushBottom').exists?
            d = first_glance.h2(:class => 'heading2 normal flushBottom').text
            if @type!='Mutual Funds' then d = d.split(':')[0] end
            d = d.split[0...-1].join(' ')
        elsif first_glance.h2(:class => 'heading2 normal flush').exists?
            t = first_glance.h2(:class => 'heading2 normal flush')
            count = t.spans[0].text.length
            count += t.spans[1].text.length
            count += t.a.text.length
            count *= -1
            name = t.text[0...count]
            adr = t.a.text
            d = [name , adr].join(' ')
        else
            d = ''
        end
        @data[header] = d
        
        if @type!='Stocks'
            header = 'fund.' + 'Morningstar Category'
            @headers << header
            @data[header] = first_glance.div(:class => 'frameBottom').a.text
        end
    end

    def get_profile(class_name, prefix='')
        @main.div(:class => class_name).wait_until_present
        profile = @main.div(:class => class_name)
        profile.tbody.trs.each {|tr|
            for i in 0..1
                header = tr.ths[i].text.gsub("\n", " ").strip
                data = tr.tds[i].text.strip
                if header != '' and data != ''
                    header = prefix + header
                    @headers << header
                    @data[header] = tr.tds[i].text
                end
            end
        }
    end

    def get_allocation_date(prefix='')
        @logger.info  'Getting date'
        allocation = @frame.div(:id => 'modAssetAllocationOverview')
        d = allocation.div(:class => 'ctAside').span(:class => 'subLabel aside').text
        header = prefix + 'Allocation Date'
        @headers << header
        @data[header] = d.split[-1]
    end

    def get_asset_allocation(prefix='asset_allocation.')
        @logger.info 'Getting asset allocation overview'
        ass_allocation = @frame.div(:id => 'modAssetAllocationOverview')
        aa_table = ass_allocation.table(:class => 'data allocationTable')
        hs = aa_table.thead.ths.collect {|th| th.text}
        aa_table.tbody.trs[1..2].each {|tr|
            tr.tds.each_with_index {|td, tdi|
                header = prefix + [tr.th.text, hs[tdi]].join(' ')
                @headers << header
                @data[header] = td.text
            }
        }
    end

    def get_country_allocation(prefix='country_allocation.')
        @logger.info 'Getting country allocation'
        country_allocation = @frame.div(:id => 'modCountryAllocation')
        country_allocation.div(:class => 'col').tbody.trs.each {|tr|
            header = prefix + tr.td.text
            @headers << header
            @data[header] = tr.tds[1].text
        }
    end

    def get_US_nonUS_allocation(div, ass_class, prefix='us_allocation.')
        @logger.info "\tGetting domestic allocation"
        pfx = ass_class
        hs = div.thead.trs[1].ths[1..2].collect {|th| th.text}
        div.tbody.trs[1..2].each {|tr|
            tr.tds[0..1].each_with_index {|td, tdi|
                header = prefix + [ass_class, tr.th.text, hs[tdi]].join(' ')
                @headers << header
                @data[header] = td.text
            }
        }
    end

    ########################################################################
    # pull_data
    ########################################################################
    def pull_data(symbol)
        prefix = 'tickers.'
        # Store symbol
        header = prefix + 'ticker'
        @headers = [header]
        @data = {header => symbol}

        if @alt_id[symbol] then symbol = @alt_id[symbol] end

        navigate_to_research_for(symbol)
        header = prefix + 'type'
        @headers << header
        @data[header] = @type[0...-1]
        get_description(prefix)

        @logger.info ['Starting data collection for', @data['Type'], symbol].join(' ')
        if @type == 'Stocks'
            pull_equity_data(symbol)
        elsif @type == 'ETFs'
            pull_etf_data
        elsif @type == 'Mutual Funds'
            pull_mf_data
        else
            @logger.error "Sorry, we don't know how to deal with " + @type + " yet."
        end        

        headers = []
        data = []
        @headers.each {|old_header|
            new_header = old_header
            @field_translator.each {|substring, replacement|
                if old_header.include?(substring)
                    new_header = old_header.gsub(substring, replacement)
                end
            }
            headers << new_header.gsub('/','_to_')
            data << @data[old_header]
        }

        return headers, data
    end

    ########################################################################
    # pull_equity_data
    ########################################################################
    def pull_equity_data(symbol)
        prefix = 'equity.'
        navigate_to_tab('summary')

        @logger.info 'Getting country info'
        if @country_data[symbol]
            header = 'country_allocation.' + country_data[symbol]
            @headers << header
            @data[header] = '100%'
        elsif @frame.div(:class => 'segment contain').exists?
            c = @frame.div(:class => 'segment contain').div(:class => 'subLabel').a.text
            header = 'country_allocation.' + c
            @headers << header
            @data[header] = '100%'
        else
            header = 'country_allocation.' + 'United States'
            @headers << header
            @data[header] = '100%'
        end

        navigate_to_subtab('quote details')
        @logger.info 'Getting details'
        @main.div(:id => 'modQuoteDetails').wait_until_present
        detail = @main.div(:id => 'modQuoteDetails')
        detail.div(:class => 'colRight').table(:class => 'data combo').tbody.trs.each {|tr|
            header = prefix + tr.th.text.gsub("\n", " ")
            @headers << header
            @data[header] = tr.td.text
        }

        @logger.info 'Getting EPS, dividend and share info'
        eds = detail.div(:class => 'grid halves').tables(:class => 'data combo')
        eps_text = eds[0].tbody.tr.th.text.split
        eps_date = eps_text[-1][1...-1]
        header = prefix + eps_text[0..2].join(' ')
        @headers << header
        @data[header] = eds[0].tbody.tr.td.text
        header = prefix + 'EPS Date'
        @headers << header
        @data[header] = eps_date

        if !(eds[1].text =~ /does not currently pay/)
            eds[1].trs.each {|tr|
                header = prefix + tr.th.text.gsub("\n", " ")
                @headers << header
                @data[header] = tr.td.text
            }
        end            

        @headers << header = 'mkt_cap_allocation.' + eds[2].tbody.tr.th.span.text[1...-1]
        @data[header] = '100%'
        eds[2].tbody.trs.each {|tr|
            header = tr.th.text.split("(")[0].strip
            header = prefix + header.split("\n")[0].strip
            @headers << header
            @data[header] = tr.td.text
        }

        @logger.info 'Getting funds holding this stock'
        hs = @main.div(:id => 'fundsHoldingThisCompanyModule').thead.ths.collect {|th| th.text}
        trs = @main.div(:id => 'fundsHoldingThisCompanyModule').tbody.trs
        for i in 0...trs.length
            tr = trs[i]
            hs.each_with_index {|h, hi|
                header = prefix + [h, (i+1).to_s].join(' ')
                @headers << header
                @data[header] = tr.tds[hi].text
            }
        end

        navigate_to_subtab('sector overview')
        @logger.info 'Getting sector categories'
        @main.table(:id => 'perfVsPeersTable').wait_until_present
        @main.table(:id => 'perfVsPeersTable').tbody.ths[1..-1].each {|th|
            header = prefix + th.div(:class => 'subLabel').text
            @headers << header
            @data[header] = th.a.text
            if header == prefix + 'Sector'
                header = 'sector_allocation.' + th.a.text
                @headers << header
                @data[header] = '100%'
            end
        }

        navigate_to_tab('peers')
        @logger.info 'Getting peer data'
        peers = @main.div(:id => 'peersComparison').tbody(:class => 'sortTBody')
        peers.trs[1..-1].each_with_index {|tr, i|
            header = prefix + 'Peer Symbol ' + (i+1).to_s
            @headers << header
            @data[header] = tr.tds[1].text
        }

        navigate_to_tab('ratios')
        @logger.info 'Getting various ratios'
        if @main.a(:text => 'View as Ratio').exists?
            @main.a(:text => 'View as Ratio').click
        end

        @main.div(:class => 'ecGroup').tbodys.each {|tbody|
            tbody.trs.each {|tr|
                header = tr.th.text.gsub("\n", " ")
                header = prefix + header
                @headers << header
                @data[header] = tr.td.text
            }
        }
        header = 'asset_allocation.% Long Equity'
        @headers << header
        @data[header] = '100%'
    end

    ########################################################################
    # pull_etf_data
    ########################################################################
    def pull_etf_data()
        prefix = 'fund.'
        navigate_to_tab('summary')
        navigate_to_subtab('quote details')

        @logger.info 'Getting profile'
        get_profile('FundProfileModule', prefix)

        @logger.info 'Getting date'
        detail = @main.div(:class => 'quoteDetailsModule')
        d = detail.div(:class => 'colRight').span(:class => 'subLabel').text.split[-1]
        header = prefix + 'Details Date'
        @headers << header
        @data[header] = d

        @logger.info 'Getting details'
        @main.div(:class => 'quoteDetailsModule').wait_until_present
        detail.div(:class => 'colRight').tbodys.each {|tbody|
            tbody.trs.each {|tr|
                header = tr.th.text
                if header =~ /(\d+\/\d+\/\d+)/
                    header = header.split[0...-1].join(' ')
                end
                header = prefix + header.gsub("\n", " ")
                @headers << header
                @data[header] = tr.td.text
            }
        }

        if @main.span(:text => 'Top 10 Holdings').exists?
            @main.span(:text => 'Top 10 Holdings').click
        end
        if @main.div(:id => 'modPortfolioHoldings').div(:id => 'modTopTenHoldingsTableModule').exists?
            @logger.info 'Getting top 10 holdings'
            holdings = @main.div(:id => 'modPortfolioHoldings').div(:id => 'modTopTenHoldingsTableModule')
            if holdings.thead.exists?
                hs = holdings.thead.ths.collect {|th| th.text}
                trs = holdings.tbody.trs
                for i in 0...trs.length
                    tr = trs[i]
                    hs.each_with_index {|h, hi|
                        header = 'holdings.' + [h, (i+1).to_s].join(' ')
                        @headers << header
                        @data[header] = tr.tds[hi].text
                    }
                end
            end
        elsif @main.div(:id => 'SchwabFundsPortfolioWeightingsModule').div(:id => 'modPortfolioWeightingsTopTenHoldingsModule').exists?
            # The page is slightly different for Schwab ETFs        
            @logger.info 'Getting Schwab fund top 10 holdings'
            holdings = @main.div(:id => 'SchwabFundsPortfolioWeightingsModule').div(:id => 'modPortfolioWeightingsTopTenHoldingsModule')
            holdings.tbody.wait_until_present
            hs = holdings.table.thead.ths.collect {|th| th.text}
            trs = holdings.tbody.trs
            for i in 0...trs.length
                tr = trs[i]
                hs.each_with_index {|h, hi|
                    header = 'holdings.' + [h, (i+1).to_s].join(' ')
                    @headers << header
                    @data[header] = tr.tds[hi].text
                }
            end
        end

        navigate_to_tab('portfolio')

        if !(@main.div.text =~ /No data/)
            @main.div(:class => 'col allocationBreakdowns').wait_until_present

            get_allocation_date(prefix)
            get_asset_allocation

            # Collect the equity information if it exists
            if @main.div(:id => 'modMFPortfolioEquityModule').exists?
                collect_equity_info
            end

            # Collect the fixed income information if it exists
            if @main.div(:id => 'modMFPortfolioFixedIncomeModule').exists?
                collect_fixed_income_info
            end

            get_country_allocation
        end
    end

    ########################################################################
    # pull_mf_data
    ########################################################################
    def pull_mf_data()
        prefix = 'fund.'
        navigate_to_tab('fund facts & fees')

        @logger.info 'Getting expense data'
        @main.div(:id => 'FundFeesAndExpenses').wait_until_present
        @main.div(:id => 'FundFeesAndExpenses').trs[0..2].each {|tr|
            header = prefix + tr.th.text.split("\n")[0].strip
            @headers << header
            @data[header] = tr.td.text.strip
        }

        navigate_to_tab('summary')
        @main.span(:text => 'Historical Quote').click

        @logger.info 'Getting distribution info'
        @main.div(:class => 'col').table(:class => 'data combo').wait_until_present
        distro = @main.div(:class => 'col').table(:class => 'data combo')
        distro.trs.each {|tr|
            for i in 0..1
                header = tr.ths[i].text.gsub("\n", " ").strip
                data = tr.tds[i].text.strip
                if header != '' and data != ''
                    header = prefix + header
                    @headers << header
                    @data[header] = tr.tds[i].text
                end
            end
        }

        @logger.info 'Getting details'
        @main.div(:class => 'colRight').wait_until_present
        detail = @main.div(:class => 'colRight').tbody
        detail.trs.each {|tr|
            header = prefix + tr.th.text.gsub("\n", " ").strip
            @headers << header
            @data[header] = tr.td.text.strip
        }

        @logger.info 'Getting profile'
        get_profile('segment ruleTop flushTop fundProfileModule', prefix)

        @logger.info 'Getting top 10 holdings'
        if @main.span(:text => 'Top 10 Holdings').exists?
            @main.span(:text => 'Top 10 Holdings').click
        end
        @main.table(:id => 'tableTop10Holdings').wait_until_present
        holdings = @main.table(:id => 'tableTop10Holdings')
        hs = holdings.thead.ths.collect {|th| th.text}
        trs = holdings.tbody(:id => 'tbodyTop10Holdings').trs
        for i in 0...trs.length
            tr = trs[i]
            hs.each_with_index {|h, hi|
                header = 'holdings.' + [h, (i+1).to_s].join(' ')
                @headers << header
                if hi < 2
                    @data[header] = tr.ths[hi].text
                else
                    @data[header] = tr.tds[hi-2].text
                end
            }
        end

        navigate_to_tab('portfolio')
        if !(@main.div.text =~ /No data/)
            @main.div(:class => 'col allocationBreakdowns').wait_until_present
            breakdowns = @main.div(:class => 'col allocationBreakdowns')

            get_allocation_date(prefix)
            get_asset_allocation

            # Collect the equity information if it exists
            if @main.div(:id => 'modMFPortfolioEquityModule').exists?
                collect_equity_info
            end

            # Collect the fixed income information if it exists
            if @main.div(:id => 'modMFPortfolioFixedIncomeModule').exists?
                collect_fixed_income_info
            end

            get_country_allocation
        end
    end

    ########################################################################
    # collect_equity_info (a helper for fund data)
    ########################################################################
    def collect_equity_info(prefix='equity.')
        equity = @frame.div(:id => 'modMFPortfolioEquityModule')

        @logger.info 'Getting equity data'
        # Get US/Non-US
        if equity.div(:id => 'modEquityAllocation').exists?
            get_US_nonUS_allocation(equity.div(:id => 'modEquityAllocation'), 'Equity', prefix)
        end

        # Get Market Cap
        if equity.div(:id => 'modEquityMarketCap').exists?
            @logger.info "\tGetting market caps"
            equity.div(:id => 'modEquityMarketCap').tbody.trs.each {|tr|
                header = 'mkt_cap_allocation.' + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end

        # Get regions
        if equity.div(:id => 'modEquityRegions').exists?
            @logger.info "\tGetting regions"
            c = 0
            equity.div(:id => 'modEquityRegions').trs(:class => 'ecSet collapsed').each {|tr|
                    tr.th.div.click
                    c += 1
            }
            while equity.div(:id => 'modEquityRegions').div(:class => 'col collapsableTable').trs(:class => 'ecSet').length < c
                'Wating for regions to expand'
                sleep(0.5)
            end
            equity.div(:id => 'modEquityRegions').tbodys(:class => 'ecGroup').each {|tbody|
                tbody.trs(:class => '').each {|tr|
                    header = 'region_allocation.' + tr.th.text
                    @headers << header
                    @data[header] = tr.td.text
                }
            }
        end

        # Get equity sectors
        if equity.div(:id => 'modEquitySectors').exists?
            @logger.info "\tGetting equity sector distribution"
            equity.div(:id => 'modEquitySectors').tbody.trs.each {|tr|
                header = 'sector_allocation.' + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end

        # Get Ratios
        if equity.div(:id => 'modPortfolioStatisticalData').exists?
            @logger.info "\tGetting ratios"
            equity.div(:id => 'modPortfolioStatisticalData').tbody.trs.each {|tr|
                header = prefix + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end
    end

    ########################################################################
    # collect_fixed_income_info (a helper for fund data)
    ########################################################################
    def collect_fixed_income_info(prefix='fixed_income.')
        fixed = @frame.div(:id => 'modMFPortfolioFixedIncomeModule')

        @logger.info 'Getting fixed income data'
        # Get US/Non-US
        if fixed.div(:id => 'modFixedIncomeAllocation').exists?
            get_US_nonUS_allocation(fixed.div(:id => 'modFixedIncomeAllocation'), 'Fixed Income', prefix)
        end

        # Get fixed income sectors
        if fixed.div(:id => 'modFixedIncomeSectors').exists? 
            @logger.info "\tGetting fixed income sectors"
            c = 0
            fixed.div(:id => 'modFixedIncomeSectors').trs(:class => 'ecSet collapsed').each {|tr|
                    tr.th.span.click
                    c += 1
            }
            while fixed.div(:id => 'modFixedIncomeSectors').div(:class => 'col collapsableTable').trs(:class => 'ecSet').length < c
                @logger.debug "\tWating for regions to expand"
                sleep(0.5)
            end
            fixed.div(:id => 'modFixedIncomeSectors').tbodys(:class => 'ecGroup').each {|tbody|
                tbody.trs(:class => '').each {|tr|
                    header = prefix + tr.th.text
                    @headers << header
                    @data[header] = tr.td.text
                }
            }
        end

        # Get credit ratings
        if fixed.div(:id => 'modFixedIncomeCreditRating').exists?
            @logger.info "\tGetting credit ratings"
            fixed.div(:id => 'modFixedIncomeCreditRating').div(:class => 'col').tbody.trs.each {|tr|
                header = prefix + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end

        # Get maturities
        if fixed.div(:id => 'modFixedIncomeMaturity').exists?
            @logger.info "\tGetting maturities"
            fixed.div(:id => 'modFixedIncomeMaturity').div(:class => 'col').tbody.trs.each {|tr|
                header = prefix + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end

        # Get stats
        if fixed.div(:id => 'modFixedIncomeStatistics').exists?
            @logger.info "\tGetting stats"
            fixed.div(:id => 'modFixedIncomeStatistics').tbody.trs.each {|tr|
                header = prefix + tr.th.text.gsub("\n", " ")
                @headers << header
                @data[header] = tr.td.text
            }
        end
    end
end
