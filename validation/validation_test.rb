require "uri"
require "yaml"
ENV['RACK_ENV'] = 'test'
require 'application.rb'
require 'test/unit'
require 'rack/test'
require 'lib/test_util.rb'
require 'test/test_examples.rb'

LOGGER = OTLogger.new(STDOUT)
LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
LOGGER.formatter = Logger::Formatter.new

#Rack::Test::DEFAULT_HOST = "localhost" #"/validation"
module Sinatra
  module UrlForHelper
    BASE = "http://localhost/validation"
    def url_for url_fragment, mode=:path_only
      case mode
      when :path_only
        raise "not impl"
      when :full
      end
      "#{BASE}#{url_fragment}"
    end
  end
end


class ValidationTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Lib::TestUtil
  
  def test_it
    $test_case = self
    
    #get "/1",nil,'HTTP_ACCEPT' => "text/html" 
    #get "/2",nil,'HTTP_ACCEPT' => "application/rdf+xml" 
    #puts last_response.body
    #exit
    
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
    
    #post "/crossvalidation/cleanup"
    #puts last_response.body

    #get "/crossvalidation/19/predictions",nil,'HTTP_ACCEPT' => "application/x-yaml" #/statistics"
#    post "",:model_uri=>"http://localhost/model/1",:test_dataset_uri=>"http://localhost/dataset/3",
#      :test_target_dataset_uri=>"http://localhost/dataset/1"

#    get "/crossvalidation/2",nil,'HTTP_ACCEPT' => "application/rdf+xml" 
   #puts last_response.body
   #exit
    
    #get "/crossvalidation?model_uri=lazar"
#    post "/test_validation",:select=>"6d" #,:report=>"yes,please"
    #puts last_response.body
    
#    post "/validate_datasets",{
#      :test_dataset_uri=>"http://localhost/dataset/204",
#      :prediction_dataset_uri=>"http://localhost/dataset/206",
#      :test_target_dataset_uri=>"http://localhost/dataset/202",
#      :prediction_feature=>"http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk",
#      :predicted_feature=>"http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk_lazar_regression",
#      :regression=>"true"}
#      #:classification=>"true"}
#    puts last_response.body

#     post "/validate_datasets",{
#      :test_dataset_uri=>"http://localhost/dataset/89",
#       :prediction_dataset_uri=>"http://localhost/dataset/91",
#       :test_target_dataset_uri=>"http://localhost/dataset/87",
#       :prediction_feature=>"http://localhost/dataset/1/feature/hamster_carcinogenicity",
#       :predicted_feature=>"",
##      :regression=>"true"}
#       :classification=>"true"}
#    puts last_response.body

    # m = OpenTox::Model::Generic.find("http://localhost/model/1323333")
    # puts m.to_yaml

#     post "/validate_datasets",{
#      :test_dataset_uri=>"http://localhost/dataset/506",
#       :prediction_dataset_uri=>"http://localhost/dataset/526",
#       :test_target_dataset_uri=>"http://localhost/dataset/504",
#       :prediction_feature=>"http://localhost/dataset/504/feature/LC50_mmol",
#       :model_uri=>"http://localhost/model/48"}
#      #:regression=>"true"}
##       :classification=>"true"}
#    puts last_response.body
    
    #run_test("13a","http://localhost/validation/39",nil,false) #,"http://localhost/validation/28")#,"http://localhost/validation/394");
    run_test("1b",nil,nil,false)
    
    #run_test("7b","http://localhost/validation/21")
    
    #run_test("3a","http://localhost/validation/crossvalidation/4")
    #run_test("3b","http://localhost/validation/crossvalidation/3")
    
    #run_test("8a", "http://localhost/validation/crossvalidation/6")
    #run_test("8b", "http://localhost/validation/crossvalidation/5")

    #run_test("11b", "http://localhost/validation/crossvalidation/2" )# //localhost/validation/42")#, "http://localhost/validation/report/validation/8") #,"http://localhost/validation/report/validation/36") #, "http://localhost/validation/321")
   # run_test("7a","http://localhost/validation/40") #,"http://localhost/validation/crossvalidation/10") #, "http://localhost/validation/321")
    #run_test("8b", "http://localhost/validation/crossvalidation/4")
 
    #puts Nightly.build_nightly("1")
    
    #prepare_examples
    #do_test_examples # USES CURL, DO NOT FORGET TO RESTART VALIDATION SERVICE
    #do_test_examples_ortona
  end

  def app
    Sinatra::Application
  end
  
  def run_test(select=nil, validation_uri=nil, report_uri=nil, delete=false)
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
        #ex.verify_yaml
        #ex.compare_yaml_vs_rdf
        ex.delete if delete
      end
    end
  end
  
  def prepare_examples
    get '/prepare_examples'
  end  
  
 def do_test_examples # USES CURL, DO NOT FORGET TO RESTART
   post '/test_examples'
 end
 
  def do_test_examples_ortona 
   post '/test_examples',:examples=>"http://ortona.informatik.uni-freiburg.de/validation/examples"
 end
  
end
