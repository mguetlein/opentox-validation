
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

module Reports
end

load "report/r_plot_factory.rb"
load "report/xml_report.rb"
load "report/xml_report_util.rb"
load "report/report_persistance.rb"
load "report/report_factory.rb"
load "report/report_service.rb"
load "report/report_format.rb"
load "report/validation_access.rb"
load "report/validation_data.rb"
load "report/predictions.rb"
load "report/util.rb"
load "report/external/mimeparse.rb"

load "lib/prediction_util.rb"

unless(defined? LOGGER)
  LOGGER = Logger.new(STDOUT)
  LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
end


