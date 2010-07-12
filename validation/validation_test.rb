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


class ValidationTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Lib::TestUtil
  
  def test_it
    $test_case = self

    #get "/crossvalidation/4/statistics"
#    post "",:model_uri=>"http://localhost/model/1",:test_dataset_uri=>"http://localhost/dataset/3",
#      :test_target_dataset_uri=>"http://localhost/dataset/1"

    #get "/crossvalidation/1",nil,'HTTP_ACCEPT' => "application/rdf+xml" 
    #puts last_response.body
    
#    post "/test_validation",:select=>"6d" #,:report=>"yes,please"
#    puts last_response.body
    
    #run_test("9a") #,"http://localhost/validation/report/validation/36") #, "http://localhost/validation/321")
    
    run_test("9a","http://localhost/validation/crossvalidation/10") #, "http://localhost/validation/321")
    
    #run_test("8b", "http://localhost/validation/crossvalidation/4")
 
    #puts Nightly.build_nightly("1")
    
    #prepare_examples
    #do_test_examples # USES CURL, DO NOT FORGET TO RESTART VALIDATION SERVICE
  end

  def app
    Sinatra::Application
  end
  
  def run_test(select, validation_uri=nil)
    validationExamples = ValidationExamples.select(select)
    validationExamples.each do |vv|
      vv.each do |v| 
        ex = v.new
        ex.validation_uri = validation_uri
        unless ex.validation_uri
          ex.upload_files
          ex.check_requirements
          ex.validate
          LOGGER.debug "validation done "+ex.validation_uri.to_s
        end
        ex.verify_yaml
        ex.report
      end
    end
  end
  
  def prepare_examples
    get '/prepare_examples'
  end  
  
 def do_test_examples # USES CURL, DO NOT FORGET TO RESTART
   get '/test_examples'
 end
  
end
