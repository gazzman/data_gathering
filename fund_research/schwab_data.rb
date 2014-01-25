#!/usr/bin/ruby
require 'blogins'

require 'date'
require 'logger'

class SchwabData
    '''
        A class for gathering research data from Scwhwab.
    '''
    include BLogins
    attr_accessor :browser, :frame, :main, :logger, :country_data, :alt_id, :headers, :data

    def initialize(user, pass, opts={})
        default = {:logfile => STDOUT, :log_age => nil, :level => Logger::INFO}
        opts = default.merge(opts)

        @logger = Logger.new(opts[:logfile], opts[:log_age])
        @logger.level = opts[:level]
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
        begin
            login
        rescue Timeout::Error, Errno::ETIMEDOUT, Watir::Wait::TimeoutError => err
            e_msg = "Exception " + err.class.to_s
            e_msg += " raised with message \'" + err.to_s
            e_msg += "\' on reinit"
            @logger.error e_msg
            reinit_browser()
        end
        @logger.info 'Reinitialization complete'
    end

    def navigate_to_research_for(symbol)
        @logger.debug 'Navigating to research tab for ' + symbol
        @browser.div(:id => 'chanL1').ul.li(:text => 'Research').a.click
        @frame = @browser.frame(:id => 'wsodIFrame')

        @frame.text_field(:id => 'ccSymbolInput').wait_until_present
        @frame.text_field(:id => 'ccSymbolInput').set symbol
        @frame.button(:id => 'searchSymbolBtn').click
        @frame.div(:id => 'mainContent').wait_until_present

        div = @browser.div(:id => 'chanL2')
        div.ul(:class => 'selected').li(:class => 'active').wait_until_present
        typecount = 0
        while div.ul(:class => 'selected').li(:class => 'active').text == 'Markets' do
            sleep 0.25
            typecount += 1
            if typecount >= 50
                @logger.error "Unable to ascertain type for " + symbol
                return nil
            end
        end
        @type = div.ul(:class => 'selected').li(:class => 'active').text
    end

    def navigate_to_tab(tabname)
        tabname = tabname.split.each(&:capitalize!).join(' ')
        if !@frame.ul(:class => 'contain nav page').li(:class => 'active').exists?
            @logger.error "No fund selected. Select a fund to research first."
        elsif @frame.ul(:class => 'contain nav page').li(:class => 'active').text.include?(tabname)
            @logger.debug "Already at the \'" + tabname + "\' tab."
        elsif @frame.ul(:class => 'contain nav page').li(:text => tabname).exists?
            @logger.debug 'Navigating to ' + tabname
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
        @logger.debug 'Getting description'
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

    def get_allocation_date(div, prefix='')
        @logger.debug 'Getting date'
        header = prefix + 'date'
        @headers << header
        @data[header] = div.span(:class => 'subLabel aside').text.split[-1]
    end

    def get_asset_allocation(prefix='asset_allocation.')
        @logger.debug 'Getting asset allocation overview'
        ass_allocation = @frame.div(:id => 'modAssetAllocationOverview')
        get_allocation_date(ass_allocation, prefix=prefix)
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
        @logger.debug 'Getting country allocation'
        country_allocation = @frame.div(:id => 'modCountryAllocation')
        get_allocation_date(country_allocation, prefix=prefix)
        country_allocation.div(:class => 'col').tbody.trs.each {|tr|
            header = prefix + tr.td.text
            @headers << header
            @data[header] = tr.tds[1].text
        }
    end

    def get_US_nonUS_allocation(div, ass_class, prefix='')
        get_allocation_date(div, prefix=prefix)
        @logger.debug "\tGetting domestic allocation"
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
        table = 'tickers.'
        # Store symbol
        header = table + 'ticker'
        @headers = [header]
        @data = {header => symbol}

        if @alt_id[symbol] then symbol = @alt_id[symbol] end

        navigate_to_research_for(symbol)
        header = table + 'type'
        @headers << header
        @data[header] = @type[0...-1]
        get_description(table)

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
        table = 'equity.'
        navigate_to_tab('summary')
        @logger.debug 'Getting date'
        header = table + 'date'
        @headers << header
        @data[header] = @frame.div(:id => 'modFirstGlance').div(:class => 'subLabel').text.split[-1]

        if @frame.div(:id => 'modFirstGlance').span(:text => /Schwab Equity Rating/).exists?
            @logger.debug 'Getting Schwab Equity Ratng'
            header = table + 'schwab_equity_rating'
            @headers << header
            @data[header] = @frame.div(:id => 'modFirstGlance').span(:text => /Schwab Equity Rating/).text.split[-1]
        end

        @logger.debug 'Getting country info'
        header = 'country_allocation.date'
        @headers << header
        @data[header] = Date.today.to_s
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
        @logger.debug 'Getting details'
        @main.div(:id => 'modQuoteDetails').wait_until_present
        detail = @main.div(:id => 'modQuoteDetails')
        detail.div(:class => 'colRight').table(:class => 'data combo').tbody.trs.each {|tr|
            header = table + tr.th.text.gsub("\n", " ")
            @headers << header
            @data[header] = tr.td.text
        }

        @logger.debug 'Getting EPS, dividend and share info'
        eds = detail.div(:class => 'grid halves').tables(:class => 'data combo')
        eps_text = eds[0].tbody.tr.th.text.split
        eps_date = eps_text[-1][1...-1]
        header = table + eps_text[0..2].join(' ')
        @headers << header
        @data[header] = eds[0].tbody.tr.td.text
        header = table + 'EPS Date'
        @headers << header
        @data[header] = eps_date

        if !(eds[1].text =~ /does not currently pay/ || eds[1].text =~ /information not available/) 
            eds[1].trs.each {|tr|
                header = table + tr.th.text.gsub("\n", " ")
                @headers << header
                @data[header] = tr.td.text
            }
        end            

        @logger.debug 'Getting Mkt Cap Info'
        header = 'mkt_cap_allocation.date'
        @headers << header
        @data[header] = Date.today.to_s
        begin
            header = 'mkt_cap_allocation.' + eds[2].tbody.tr.th.span.text[1...-1]
            @headers << header
            @data[header] = '100%'
        rescue TypeError => err
            @logger.error 'No Mkt Cap category for %s' % symbol
        end
        
        eds[2].tbody.trs.each {|tr|
            header = tr.th.text.split("(")[0].strip
            header = table + header.split("\n")[0].strip
            @headers << header
            @data[header] = tr.td.text
        }

        @logger.debug 'Getting funds holding this stock'
        hs = @main.div(:id => 'fundsHoldingThisCompanyModule').thead.ths.collect {|th| th.text}
        trs = @main.div(:id => 'fundsHoldingThisCompanyModule').tbody.trs
        if @main.div(:id => 'fundsHoldingThisCompanyModule').tbody.text =~ /No ETFs Available/
            @logger.error 'No ETFs holding %s' % symbol
        else
            for i in 0...trs.length
                tr = trs[i]
                hs.each_with_index {|h, hi|
                    header = table + [h, (i+1).to_s].join(' ')
                    @headers << header
                    @data[header] = tr.tds[hi].text
                }
            end
        end
        navigate_to_subtab('sector overview')
        @logger.debug 'Getting sector categories'
        @main.table(:id => 'perfVsPeersTable').wait_until_present
        @main.table(:id => 'perfVsPeersTable').tbody.ths[1..-1].each {|th|
            header = table + th.div(:class => 'subLabel').text
            @headers << header
            @data[header] = th.a.text
            if header == table + 'Sector'
                @logger.debug 'Getting Sector Info'
                header = 'sector_allocation.date'
                @headers << header
                @data[header] = Date.today.to_s
                header = 'sector_allocation.' + th.a.text
                @headers << header
                @data[header] = '100%'
            end
        }

        # Get equity rating info
        if @main.div(:id => 'sectorOverviewModule').ul(:class => 'list dividers rules').exists?
            som = @main.div(:id => 'sectorOverviewModule').ul(:class => 'list dividers rules')
            # Get the Schwab industry rating data
            field = 'Schwab Industry Rating'
            rating, industry_date, date = som.li(:text => /Schwab Industry Rating/).div.divs.to_a
            rating = rating.attribute_value('textContent').split()[-1]
            industry = industry_date.text.split(/\n/)[0]
            date = date.text.split()[-1]

            header = table + field
            @headers << header
            @data[header] = rating

            if @data[table + 'Industry'].downcase != industry.downcase
                @data[table + 'Industry'] = industry
            end

            header = '%s%s_%s' % [table, field, 'date']
            @headers << header
            @data[header] = date

            # Get Schwab Sector View
            field, view = som.li(:text => /Schwab Sector View/).text.split(/\n/)
            header = table + field
            @headers << header
            @data[header] = view

            # Get Ned Davis sector highlights
            ndsh = som.li(:text => /Ned Davis Research Sector Highlights/).text.split(/\n/)
            ndsh_new = []
            ndsh.each{|e| if e != 'PDF'
                            ndsh_new += [e]
                          end
            }
            field, sector, date, recommendation = ndsh_new
            date = date.split()[-1]
            if /today/ =~ date.downcase
                date = Date.today.to_s
            elsif /yesterday/ =~ date.downcase
                date = (Date.today - 1).to_s
            end
            recommendation = recommendation.split()[-1]

            header = table + field
            @headers << header
            @data[header] = recommendation

            header = '%s%s_%s' % [table, field, 'date']
            @headers << header
            @data[header] = date

            if @data[table + 'Sector'].downcase != sector.downcase
                @data[table + 'Sector'] = sector
            end
        end

        navigate_to_tab('peers')
        @logger.debug 'Getting peer data'
        peers = @main.div(:id => 'peersComparison').tbody(:class => 'sortTBody')
        peers.trs[1..-1].each_with_index {|tr, i|
            header = table + 'Peer Symbol ' + (i+1).to_s
            @headers << header
            @data[header] = tr.tds[1].text
        }

        navigate_to_tab('ratios')
        @logger.debug 'Getting various ratios'
        if @main.a(:text => 'View as Ratio').exists?
            @main.a(:text => 'View as Ratio').click
        end

        @main.div(:class => 'ecGroup').tbodys.each {|tbody|
            tbody.trs.each {|tr|
                header = tr.th.text.gsub("\n", " ")
                header = table + header
                @headers << header
                @data[header] = tr.td.text
            }
        }
        @logger.debug 'Getting Asset Allocation'
        header = 'asset_allocation.date'
        @headers << header
        @data[header] = Date.today.to_s
        header = 'asset_allocation.% Long Equity'
        @headers << header
        @data[header] = '100%'
    end

    ########################################################################
    # pull_etf_data
    ########################################################################
    def pull_etf_data()
        table = 'fund.'
        navigate_to_tab('summary')
        @logger.debug 'Getting date'
        header = table + 'date'
        @headers << header
        @data[header] = @frame.div(:id => 'modFirstGlance').div(:class => 'subLabel floatLeft').text.split[-1]

        navigate_to_subtab('quote details')

        @logger.debug 'Getting profile'
        get_profile('FundProfileModule', table)

        @logger.debug 'Getting details date'
        detail = @main.div(:class => 'quoteDetailsModule')
        d = detail.div(:class => 'colRight').span(:class => 'subLabel').text.split[-1]
        header = table + 'Details Date'
        @headers << header
        @data[header] = d

        @logger.debug 'Getting details'
        @main.div(:class => 'quoteDetailsModule').wait_until_present
        detail.div(:class => 'colRight').tbodys.each {|tbody|
            tbody.trs.each {|tr|
                header = tr.th.text
                if header =~ /(\d+\/\d+\/\d+)/
                    header = header.split[0...-1].join(' ')
                end
                header = table + header.gsub("\n", " ")
                @headers << header
                @data[header] = tr.td.text
            }
        }

        if @main.span(:text => 'Top 10 Holdings').exists?
            @main.span(:text => 'Top 10 Holdings').click
        end
        if @main.div(:id => 'modPortfolioHoldings').div(:id => 'modTopTenHoldingsTableModule').exists?
            @logger.debug 'Getting top 10 holdings'
            holdings_div = @main.div(:id => 'modPortfolioHoldings')
            header = 'holdings.date'
            @headers << header
            @data[header] = holdings_div.span(:class => 'subLabel').text.split[-1]
            holdings = holdings_div.div(:id => 'modTopTenHoldingsTableModule')
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
            @logger.debug 'Getting Schwab fund top 10 holdings'
            holdings_div = @main.div(:id => 'SchwabFundsPortfolioWeightingsModule')
            header = 'holdings.date'
            @headers << header
            @data[header] = holdings_div.span(:class => 'subLabel').text.split[-1]
            holdings = holdings_div.div(:id => 'modPortfolioWeightingsTopTenHoldingsModule')
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

        if !(@main.div.text[0..6] == 'No data')
            @main.div(:class => 'col allocationBreakdowns').wait_until_present

            get_asset_allocation

            # Collect the equity information if it exists
            if @main.div(:id => 'modMFPortfolioEquityModule').exists?
                @headers << 'equity.date'
                @data['equity.date'] = @data[table + 'date']
                collect_equity_info
            end

            # Collect the fixed income information if it exists
            if @main.div(:id => 'modMFPortfolioFixedIncomeModule').exists?
                @headers << 'fixed_income.date'
                @data['fixed_income.date'] = @data[table + 'date']
                collect_fixed_income_info
            end

            get_country_allocation
        end
    end

    ########################################################################
    # pull_mf_data
    ########################################################################
    def pull_mf_data()
        table = 'fund.'
        navigate_to_tab('fund facts & fees')

        @logger.debug 'Getting expense data'
        @main.div(:id => 'FundFeesAndExpenses').wait_until_present
        @main.div(:id => 'FundFeesAndExpenses').trs[0..2].each {|tr|
            header = table + tr.th.text.split("\n")[0].strip
            @headers << header
            @data[header] = tr.td.text.strip
        }

        navigate_to_tab('summary')
        @logger.debug 'Getting date'
        header = table + 'date'
        @headers << header
        @data[header] = @frame.div(:id => 'modFirstGlance').p(:class => 'subLabel flushTop').text.split[-1]

        @main.span(:text => 'Historical Quote').click
        @logger.debug 'Getting distribution info'
        @main.div(:class => 'col').table(:class => 'data combo').wait_until_present
        distro = @main.div(:class => 'col').table(:class => 'data combo')
        distro.trs.each {|tr|
            for i in 0..1
                header = tr.ths[i].text.gsub("\n", " ").strip
                data = tr.tds[i].text.strip
                if header != '' and data != ''
                    header = table + header
                    @headers << header
                    @data[header] = tr.tds[i].text
                end
            end
        }

        @logger.debug 'Getting details'
        @main.div(:class => 'colRight').wait_until_present
        detail = @main.div(:class => 'colRight').tbody
        detail.trs.each {|tr|
            header = table + tr.th.text.gsub("\n", " ").strip
            @headers << header
            @data[header] = tr.td.text.strip
        }

        @logger.debug 'Getting profile'
        get_profile('segment ruleTop flushTop fundProfileModule', table)

        @logger.debug 'Getting top 10 holdings'
        if @main.span(:text => 'Top 10 Holdings').exists?
            @main.span(:text => 'Top 10 Holdings').click
        end
        @main.table(:id => 'tableTop10Holdings').wait_until_present
        header = 'holdings.date'
        @headers << header
        date_div = @main.div(:class => 'grid col alpha').divs(:class => 'relative')[-1]
        @data[header] = date_div.span(:class => 'subLabel').text.split[-1]
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
        if !(@main.div.text[0..6] == 'No data')
            @main.div(:class => 'col allocationBreakdowns').wait_until_present
            breakdowns = @main.div(:class => 'col allocationBreakdowns')

            get_asset_allocation

            # Collect the equity information if it exists
            if @main.div(:id => 'modMFPortfolioEquityModule').exists?
                @headers << 'equity.date'
                @data['equity.date'] = @data[table + 'date']
                collect_equity_info
            end

            # Collect the fixed income information if it exists
            if @main.div(:id => 'modMFPortfolioFixedIncomeModule').exists?
                @headers << 'fixed_income.date'
                @data['fixed_income.date'] = @data[table + 'date']
                collect_fixed_income_info
            end

            get_country_allocation
        end
    end

    ########################################################################
    # collect_equity_info (a helper for fund data)
    ########################################################################
    def collect_equity_info()
        table = 'equity.'
        equity = @frame.div(:id => 'modMFPortfolioEquityModule')

        @logger.debug 'Getting equity data'
        # Get US/Non-US
        if equity.div(:id => 'modEquityAllocation').exists?
            get_US_nonUS_allocation(equity.div(:id => 'modEquityAllocation'), 'Equity', table + 'us_allocation_')
        end

        # Get regions
        if equity.div(:id => 'modEquityRegions').exists?
            get_allocation_date(equity.div(:id => 'modEquityRegions'), 'region_allocation.')
            @logger.debug "\tGetting regions"
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
            sectors = equity.div(:id => 'modEquitySectors')
            get_allocation_date(sectors, 'sector_allocation.')
            @logger.debug "\tGetting equity sector distribution"
            sectors.tbodys.each {|tbody|
                data = tbody.tr.text.split()
                sector = data[0...-1].join(' ')
                pct = data[-1]
                header = 'sector_allocation.' + sector
                @headers << header
                @data[header] = pct
            }
        end

        # Get Market Cap
        if equity.div(:id => 'modEquityMarketCap').exists?
            get_allocation_date(equity.div(:id => 'modEquityMarketCap'), 'mkt_cap_allocation.')
            @logger.debug "\tGetting market caps"
            equity.div(:id => 'modEquityMarketCap').tbody.trs.each {|tr|
                header = 'mkt_cap_allocation.' + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end

        # Get Ratios
        if equity.div(:id => 'modPortfolioStatisticalData').exists?
            get_allocation_date(equity.div(:id => 'modPortfolioStatisticalData'), table + 'stats_')
            @logger.debug "\tGetting ratios"
            equity.div(:id => 'modPortfolioStatisticalData').tbody.trs.each {|tr|
                header = table + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end
    end

    ########################################################################
    # collect_fixed_income_info (a helper for fund data)
    ########################################################################
    def collect_fixed_income_info()
        table = 'fixed_income.'
        fixed = @frame.div(:id => 'modMFPortfolioFixedIncomeModule')

        @logger.debug 'Getting fixed income data'
        # Get US/Non-US
        if fixed.div(:id => 'modFixedIncomeAllocation').exists?
            get_US_nonUS_allocation(fixed.div(:id => 'modFixedIncomeAllocation'), 'Fixed Income', table + 'us_allocation_')
        end

        # Get fixed income sectors
        if fixed.div(:id => 'modFixedIncomeSectors').exists? 
            get_allocation_date(fixed.div(:id => 'modFixedIncomeSectors'), table + 'sectors_')
            @logger.debug "\tGetting fixed income sectors"
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
                    header = table + tr.th.text
                    @headers << header
                    @data[header] = tr.td.text
                }
            }
        end

        # Get credit ratings
        if fixed.div(:id => 'modFixedIncomeCreditRating').exists?
            get_allocation_date(fixed.div(:id => 'modFixedIncomeCreditRating'), table + 'ratings_')
            @logger.debug "\tGetting credit ratings"
            fixed.div(:id => 'modFixedIncomeCreditRating').div(:class => 'col').tbody.trs.each {|tr|
                header = table + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end

        # Get maturities
        if fixed.div(:id => 'modFixedIncomeMaturity').exists?
            get_allocation_date(fixed.div(:id => 'modFixedIncomeMaturity'), table + 'maturity_')
            @logger.debug "\tGetting maturities"
            fixed.div(:id => 'modFixedIncomeMaturity').div(:class => 'col').tbody.trs.each {|tr|
                header = table + tr.th.text
                @headers << header
                @data[header] = tr.td.text
            }
        end

        # Get stats
        if fixed.div(:id => 'modFixedIncomeStatistics').exists?
            get_allocation_date(fixed.div(:id => 'modFixedIncomeStatistics'), table + 'stats_')
            @logger.debug "\tGetting stats"
            fixed.div(:id => 'modFixedIncomeStatistics').tbody.trs.each {|tr|
                header = table + tr.th.text.gsub("\n", " ")
                @headers << header
                @data[header] = tr.td.text
            }
        end
    end
end
