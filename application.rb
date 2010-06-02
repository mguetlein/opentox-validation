require 'rubygems'
gem 'opentox-ruby-api-wrapper', '= 1.4.4.4'
[ 'sinatra', 'sinatra/url_for', 'opentox-ruby-api-wrapper', 'logger' ].each do |lib|
  require lib
end

require 'active_record'
ActiveRecord::Base.establish_connection(  
   :adapter => @@config[:database][:adapter],
   :host => @@config[:database][:host],
   :database => @@config[:database][:database],
   :username => @@config[:database][:username],
   :password => @@config[:database][:password]
) 
       
#unless(defined? LOGGER)
  #LOGGER = Logger.new(STDOUT)
  #LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
#end

require "example.rb"

get '/examples/?' do
  LOGGER.info "list examples"
  content_type "text/plain"
  Example.transform_example
end

get '/prepare_examples/?' do
  LOGGER.info "prepare examples"
  content_type "text/plain"
  Example.prepare_example_resources
end

get '/test_examples/?' do
  LOGGER.info "test examples"
  content_type "text/plain"
  Example.test_examples
end

require "test/test_application.rb"
require "nightly/nightly_application.rb"

# order is important, first add example methods and reports, than validation 
# (otherwise sinatra will try to locate a validation with name examples or report)

require "report/report_application.rb"
require "validation/validation_application.rb"




