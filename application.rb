

require "example.rb"

[ 'rubygems', 'sinatra', 'sinatra/url_for', 'logger' ].each do |lib|
  require lib
end

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



