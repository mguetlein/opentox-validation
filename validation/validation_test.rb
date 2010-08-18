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
    
#    d = OpenTox::Dataset.find("http://ot-dev.in-silico.ch/dataset/307")
#    puts d.compounds.inspect
#    exit
    
    #get "?model=http://localhost/model/1" 
#    get "/crossvalidation/3/predictions"
#    puts last_response.body

#    post "/validate_datasets",{
#      :test_dataset_uri=>"http://apps.deaconsult.net:8080/ambit2/dataset/R3924",
#      :prediction_dataset_uri=>"http://apps.ideaconsult.net:8080/ambit2/dataset/R3924?feature_uris[]=http%3A%2F%2Fapps.ideaconsult.net%3A8080%2Fambit2%2Fmodel%2F52%2Fpredicted",
#      #:test_target_dataset_uri=>"http://localhost/dataset/202",
#      :prediction_feature=>"http://apps.ideaconsult.net:8080/ambit2/feature/21715",
#      :predicted_feature=>"http://apps.ideaconsult.net:8080/ambit2/feature/28944",
#      :regression=>"true"}
#      #:classification=>"true"}
#    puts last_response.body
    
    #delete "/7"

    #get "/crossvalidation/4/statistics"
#    post "",:model_uri=>"http://localhost/model/1",:test_dataset_uri=>"http://localhost/dataset/3",
#      :test_target_dataset_uri=>"http://localhost/dataset/1"

  #  get "/1",nil,'HTTP_ACCEPT' => "application/rdf+xml" 
   # puts last_response.body
    
#    post "/test_validation",:select=>"6d" #,:report=>"yes,please"
#    puts last_response.body
    
#    post "/validate_datasets",{
#      :test_dataset_uri=>"http://localhost/dataset/204",
#      :prediction_dataset_uri=>"http://localhost/dataset/206",
#      :test_target_dataset_uri=>"http://localhost/dataset/202",
#      :prediction_feature=>"http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk",
#      :predicted_feature=>"http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk_lazar_regression",
#      :regression=>"true"}
#      #:classification=>"true"}
#    puts last_response.body
    
    run_test("1b") #, "http://localhost/validation/crossvalidation/5" )# //localhost/validation/42")#, "http://localhost/validation/report/validation/8") #,"http://localhost/validation/report/validation/36") #, "http://localhost/validation/321")
    
   # run_test("7a","http://localhost/validation/40") #,"http://localhost/validation/crossvalidation/10") #, "http://localhost/validation/321")
    
    #run_test("8b", "http://localhost/validation/crossvalidation/4")
 
    #puts Nightly.build_nightly("1")
    
    #prepare_examples
    #do_test_examples # USES CURL, DO NOT FORGET TO RESTART VALIDATION SERVICE
  end

  def app
    Sinatra::Application
  end
  
  def run_test(select=nil, validation_uri=nil, report_uri=nil)
    puts ValidationExamples.list unless select
    validationExamples = ValidationExamples.select(select)
    validationExamples.each do |vv|
      vv.each do |v| 
        ex = v.new
        ex.validation_uri = validation_uri
        unless ex.validation_uri
          ex.upload_files
          ex.check_requirements
          ex.validate
          LOGGER.debug "validation done '"+ex.validation_uri.to_s+"'"
        end
        ex.report_uri = report_uri
        unless ex.report_uri
          ex.report
        end
        ex.verify_yaml
        ex.compare_yaml_vs_rdf
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
