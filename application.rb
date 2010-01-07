
require "validation/validation_application.rb"
require "report/report_application.rb"
require "example.rb"

[ 'rubygems', 'sinatra', 'sinatra/url_for' ].each do |lib|
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



