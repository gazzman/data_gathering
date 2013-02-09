=============
data_gathering/fund_research
=============

Ruby scripts to pull mutual fund, ETF, and equity research from the web.

------------------------
fidelity_fund_tickers.rb
------------------------

Usage: fidelity_fund_tickers.rb login_file

This script only takes the login_file as the argument. It returns a list of
descriptions and ticker symbols of the funds available for investment at your
Fidelity 401k workplace plan.

The results are sent to stdout, with other output messages sent to stderr.


------------------------
pull_schwab_data.rb
------------------------

Usage: pull_schwab_data.rb login_file symbols_file [# of concurrent threads]

The number of concurrent threads defaults to 4.

The symbols file is a file containing the ticker symbols of mutual funds,ETFs,
and equities, one symbol per line. 

The class SchwabData autodetects the asset class.

To ensure previously colleccted data is not overwritten, for each of these
funds, the data is stored in two places: files named  [symbol].csv and
files named [symbol]_[ISO 8601 timestamp].csv.


-------------------
schwab_data.rb
-------------------

This file contains SchwabFundData class, which is implemented in 
pull_schwab_data.rb. The class has its own Watir::Browser instance. It has
several methods that collect fund data from the Schwab equity research website.
