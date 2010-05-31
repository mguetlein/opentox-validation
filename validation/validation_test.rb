require "logger"
require "uri"
require "yaml"
ENV['RACK_ENV'] = 'test'
require 'application.rb'
require 'test/unit'
require 'rack/test'
require 'lib/test_util.rb'
require 'test/test_examples.rb'
LOGGER = Logger.new(STDOUT)
LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "

class ValidationTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Lib::TestUtil
  
  def test_it
    
#    post "/test_validation",:select=>"6d" #,:report=>"yes,please"
#    puts last_response.body
    
    #run_test("6a")
 
    #puts Nightly.build_nightly("6")
    
    #prepare_examples
    do_test_examples # USES CURL, DO NOT FORGET TO RESTART VALIDATION SERVICE
  end

  def app
    Sinatra::Application
  end
  
  def run_test(select)
    $test_case = self
    validationExamples = ValidationExamples.select(select)
    validationExamples.each do |vv|
      vv.each do |v|  
        ex = v.new
        ex.upload_files
        ex.check_requirements
        ex.validate
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
