require 'rubygems'
gem "opentox-ruby", "~> 0"
[ 'sinatra', 'sinatra/url_for', 'opentox-ruby' ].each do |lib|
  require lib
end

#unless(defined? LOGGER)
  #LOGGER = Logger.new(STDOUT)
  #LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
#end

#require "error_application.rb"

require "example.rb"

get '/examples/?' do
  LOGGER.info "list examples"
  
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    content_type "text/html"
    OpenTox.text_to_html Example.transform_example
  else
    content_type "text/plain"
    Example.transform_example
  end
end

get '/prepare_examples/?' do
  LOGGER.info "prepare examples"
  content_type "text/plain"
  Example.prepare_example_resources
end

post '/test_examples/?' do
  examples = params[:examples]
  LOGGER.info "test examples "+examples.to_s
  content_type "text/plain"
  Example.test_examples(examples)
end

require "test/test_application.rb"
require "nightly/nightly_application.rb"

# order is important, first add example methods and reports, than validation 
# (otherwise sinatra will try to locate a validation with name examples or report)

require "report/report_application.rb"
require "reach_reports/reach_application.rb"
require "validation/validation_application.rb"




