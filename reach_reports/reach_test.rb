require "uri"
require "yaml"
ENV['RACK_ENV'] = 'test'
require 'application.rb'
require 'test/unit'
require 'rack/test'
require 'lib/test_util.rb'
require 'test/test_examples.rb'

LOGGER = MyLogger.new(STDOUT)
LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
LOGGER.formatter = Logger::Formatter.new


class ReachTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Lib::TestUtil

  
  def app
    Sinatra::Application
  end
  
  def test_it
    #$test_case = self

    post '/reach_report/qmrf',:model_uri=>"http://localhost/model/16"
    ##post '/reach_report/qprf',:compound_uri=>"http://localhost/compound/XYZ"
    uri = last_response.body
    id = uri.split("/")[-1]
    puts uri

    #get '/reach_report/qmrf'
    #puts last_response.body
    
    get '/reach_report/qmrf/'+id.to_s,nil,'HTTP_ACCEPT'=>"application/x-yaml"
    puts "YAML"
    puts last_response.body
    
#    get '/reach_report/qmrf/'+id.to_s,nil,'HTTP_ACCEPT'=>"application/rdf+xml"
#    puts "RDF"
#    puts last_response.body

    get '/reach_report/qmrf/'+id,nil,'HTTP_ACCEPT' => "application/qmrf-xml"
    puts "XML"
    puts last_response.body

    
  end
end


#    query = <<EOF
#PREFIX ot:<http://www.opentox.org/api/1.1#>
#PREFIX rdf:<http://www.w3.org/1999/02/22-rdf-syntax-ns#>
#select ?model  
#where {
#?model rdf:type ot:Model
#}
#EOF
#    puts OpenTox::RestClientWrapper.post("http://apps.ideaconsult.net:8080/ontology/",{:accept => "application/rdf+xml", :query => query}) 
#    exit