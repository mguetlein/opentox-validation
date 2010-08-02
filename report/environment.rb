
['rubygems', 'logger', 'fileutils', 'sinatra', 'sinatra/url_for', 'rest_client', 
  'yaml', 'fileutils', 'mime/types', 'abbrev', 
  'rexml/document',  'ruby-plot', 'active_record', 'ar-extensions', 'opentox-ruby-api-wrapper' ].each do |g|
    require g
end
gem 'ruby-plot', '= 0.0.2'

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
require "lib/active_record_setup.rb"



