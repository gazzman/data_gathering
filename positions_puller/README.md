data_gathering/positions_puller
================

Ruby scripts to pull financial position data from various brokers.

------------------------
pull_fidelity_positions.rb
------------------------
Usage: pull_fidelity_positions.rb login_file [directory='Fidelity']

This script logs into your Fidelity account and saves the position data.

It creates a backup of the previous position data so that no historical data
is overwritten.

------------------------
pull_ib_positions.rb
------------------------
Usage: pull_ib_positions.rb login_file [directory='InteractiveBrokers']

This script requests and stores an XML flex query on the local machine.
The first line of the login_file is the flex query token.
The second line of the login_file is the flex query id.
Note that the flex query must have already been created via the IB website.

It creates a backup of the previous position data so that no historical data 
is overwritten.

------------------------
pull_schwab_positions.rb
------------------------
Usage: pull_schwab_positions.rb login_file [directory='Schwab']

This script logs into your Scwhab accounts and saves the position data for
each of your Schwab accounts, as well as a Schwab bank account.

It creates a backup of the previous position data so that no historical data 
is overwritten.

------------------------
pull_scottrade_positions.rb
------------------------
Usage: pull_scottrade_positions.rb login_file [directory='Scottrade']

This script logs into your Scottrade accounts and saves the position data for
your Scottrade accounts, as well the cash positions for the Scottrade brokerage
and bank accounts.

It creates a backup of the previous position data so that no historical data 
is overwritten.
