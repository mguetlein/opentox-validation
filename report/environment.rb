
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



