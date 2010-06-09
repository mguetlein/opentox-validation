
require 'rubygems'
require 'logger'
require 'fileutils'
require 'sinatra'
require 'sinatra/url_for' 
require 'rest_client'
require 'yaml'
require 'opentox-ruby-api-wrapper'
require 'fileutils'
require 'mime/types'
require 'ruby-plot'
gem 'ruby-plot', '= 0.0.2'

require 'active_record'
require 'ar-extensions'
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

require "lib/rdf_provider.rb"

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



