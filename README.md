data_gathering
==============

Ruby scripts to gather financial data from the web


----------
blogins.rb
----------

This file contains the BLogins module, which is just a collection of methods
for a Watir::Browser to log in and out of various websites.


--------------
The login_file
--------------

Many of the scripts in this repo take as their first argument the name of a
two-line file. With the exception of the pull_ib_positions.rb script, the 
first line of this file is the the login username, and the second line is the 
login password.
