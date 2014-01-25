#!/usr/bin/ruby
require 'rubygems'

require 'fastercsv'
require 'fileutils'
require 'headless'
require 'time'

require 'schwab_data'

'''
    This is a command-line script for gathering research data from
    Schwab. It takes a list of ticker symbols and pulls as much info 
    as it can and stores the data in a csv file.
'''

Thread.abort_on_exception = true

# Eat the arguments (only the first two are necessary)
login_file = ARGV[0]
symbols_file = ARGV[1]
num_threads = ARGV[2]

if !num_threads
    # Default is 4
    num_threads = 4
else
    num_threads = num_threads.to_i
end

# Read the symbols into a list
symbols = {}
File.open(symbols_file, 'r') {|f| 
    f.each {|line|
        line.strip!
        if !(line == '' or line[0...1] == '#')
            symbols[line] = ''
        end
    }
}
symbols = symbols.keys.sort

# Split the symbols up for multithreading.
m = symbols.length/num_threads
split_symbols = []
for i in 1...num_threads
    split_symbols << symbols[0...m]
    symbols = symbols[m..-1]
end
split_symbols << symbols

# Parse the login file
user = pass = ''
File.open(login_file, 'r') {|f|
    user, pass = f.read.split("\n").each(&:strip!)
}

# A method to store the data as a csv, one per symbol
def get_data(user, pass, sd, symbols, progname=nil)
    errs = [Watir::Exception::UnknownFrameException, 
            Watir::Exception::UnknownObjectException,
            Watir::Wait::TimeoutError, 
            NameError,
            Timeout::Error,
            Errno::ETIMEDOUT,
            Selenium::WebDriver::Error::StaleElementReferenceError]

    sd.logger.progname = progname
    sd.login()
    sd.logger.info 'Starting processing for ' + symbols.length.to_s + ' symbols'
    for symbol in symbols
        headers = data = []
        fname = symbol + '.csv'
        fname_ts = [symbol, Time.now.getutc.iso8601].join('_') + '.csv'

        s = symbol.gsub("-", "/")
        try = 0
        try_thresh = 5
        begin
            headers, data = sd.pull_data(s)
            headers.each {|header|
                if (header =~ /^[^\\][[:punct:]|[:alnum:]|[:blank:]]+$/) != 0 
                    raise  NameError, "Asian characters in header %s retrying" % header
                end
            }
            csv = CSV.open(fname_ts, 'w')
            csv << CSV::Row.new(headers, headers, header_row = true)
            csv << CSV::Row.new(headers, data)
            csv.close
            sd.logger.info 'Wrote data to ' + fname_ts

            # Copy the position data to the simple filename
            if Dir.entries('.').include?(fname) then FileUtils.rm(fname) end
            FileUtils.cp(fname_ts, fname)
            sd.logger.info 'Copied data to ' + fname
        rescue *errs => err
            try += 1
            e_msg = "Exception " + err.class.to_s
            e_msg += " raised with message \'" + err.to_s
            e_msg += "\' on symbol " + symbol
            sd.logger.error e_msg
            if try == 1
                retry
            elsif try <= try_thresh
                sd.reinit_browser()
                retry
            else
                f_msg = "We've tried this " + try_thresh.to_s 
                f_msg += " times already. Something is wrong."
                f_msg += " I'm giving up on " + symbol
                sd.logger.error f_msg
                sd.reinit_browser()
            end    
        end

    end
    sd.close()
end    

# Start running the threads headlessly
headless = Headless.new
headless.start
sfds = []
for i in 0...num_threads
    sfds << SchwabData.new(user, pass)
end

threads = []
sfds.each_with_index {|sfd, i|
    threads << Thread.new {
        Thread.current['id'] = 'Thread ' + i.to_s
        get_data(user, pass, sfd, split_symbols[i], 
                 progname="#{Thread.current['id']}")
    }
}
threads.each {|thread| thread.join}
headless.destroy
