
['rubygems', 'logger', 'fileutils', 'sinatra', 'sinatra/url_for', 'rest_client', 
  'yaml', 'fileutils', 'mime/types', 'abbrev', 
  'rexml/document',  'ruby-plot', 'active_record', 'ar-extensions', 'opentox-ruby-api-wrapper' ].each do |g|
    require g
end
gem 'ruby-plot', '= 0.0.2'

unless ActiveRecord::Base.connected?
  ActiveRecord::Base.establish_connection(  
     :adapter => @@config[:database][:adapter],
     :host => @@config[:database][:host],
     :database => @@config[:database][:database],
     :username => @@config[:database][:username],
     :password => @@config[:database][:password]
  )
  ActiveRecord::Base.logger = Logger.new("/dev/null")
end

module Reports
end

require "report/plot_factory.rb"
require "report/xml_report.rb"
require "report/xml_report_util.rb"
require "report/report_persistance.rb"
require "report/report_factory.rb"
require "report/report_service.rb"
require "report/report_format.rb"
require "report/validation_access.rb"
require "report/validation_data.rb"
require "report/prediction_util.rb"
require "report/util.rb"
require "report/external/mimeparse.rb"

require "lib/ot_predictions.rb"



