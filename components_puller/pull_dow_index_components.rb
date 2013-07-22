#!/usr/bin/ruby
require 'blogins'

include BLogins

index_info = {"DJX" => {"url" => "http://www.djaverages.com/?go=industrial-components",
                        "fnameroot" => "DJIComponents"}}

def pull_dow_index_components(directory, url, fnameroot, 
                                              clicktext="Download Components", 
                                              extension="xls")
    headless = Headless.new
    headless.start

    # Goto local directory
    puts 'Prepping directory ' + directory
    begin
        FileUtils.cd(directory)
    rescue Errno::ENOENT
        FileUtils.mkdir(directory)
        FileUtils.cd(directory)
    end
    FileUtils.touch("%s.%s" % [fnameroot, extension])

    # Set some variables
    autosave_mime_types = 'text/comma-separated-values,text/csv,application/vnd.ms-excel'
    download_directory = "#{Dir.pwd}"

    # Autodownload profile (thanks to WatirMelon!)
    profile = Selenium::WebDriver::Firefox::Profile.new
    profile['browser.download.folderList'] = 2 # custom location
    profile['browser.download.dir'] = download_directory
    profile['browser.helperApps.neverAsk.saveToDisk'] = autosave_mime_types

    # Goto page    
    b = Watir::Browser.new :firefox, :profile => profile
    b.goto(url)
    b.a(:text => clicktext).click
    b.close()
    # Update the latest components data
    update_local_positions_file(fnameroot, date=nil, acct_num=nil, extension=extension)

    headless.destroy
end

# Argument is a custom path where you want the data.
# Default is the name of the brokerage.
index = ARGV[0]
pull_dow_index_components(directory=index, 
                          url=index_info[index]['url'], 
                          fnameroot=index_info[index]['fnameroot'])
