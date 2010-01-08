
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'opentox-ruby-api-wrapper', 'logger' ].each do |lib|
  require lib
end

unless(defined? LOGGER)
  LOGGER = Logger.new(STDOUT)
  LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
end

require "example.rb"

get '/examples/?' do
  content_type "text/plain"
  Example.transform_example
end

get '/prepare_examples/?' do
  Example.prepare_example_resources
  "done"
end

# order is important, first add example methods, than validation 
# (otherwise sinatra will try to locate a validation with name examples)

require "validation/validation_application.rb"
require "report/report_application.rb"



