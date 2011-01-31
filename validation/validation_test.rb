
require "rubygems"
require "sinatra"
before {
  request.env['HTTP_HOST']="local-ot/validation"
  request.env["REQUEST_URI"]=request.env["PATH_INFO"]
}

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

if AA_SERVER
  #TEST_USER = "mgtest"
  #TEST_PW = "mgpasswd"
  TEST_USER = "guest"
  TEST_PW = "guest"
  SUBJECTID = OpenTox::Authorization.authenticate(TEST_USER,TEST_PW)
  raise "could not log in" unless SUBJECTID
  puts "logged in: "+SUBJECTID.to_s
else
  puts "AA disabled"
  SUBJECTID = nil
end

#Rack::Test::DEFAULT_HOST = "local-ot" #"/validation"
module Sinatra
  
  set :raise_errors, false
  set :show_exceptions, false

  module UrlForHelper
    BASE = "http://local-ot/validation"
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
    begin
      $test_case = self
      
#      get "/19999",nil,'HTTP_ACCEPT' => "text/html"
#      exit
#       
#      get "/234234232341",nil,'HTTP_ACCEPT' => "application/x-yaml"
#      puts last_response.body
##      
#      get "/crossvalidation/1",nil,'HTTP_ACCEPT' => "application/rdf+xml"
#      puts last_response.body
#      exit
      
  #    d = OpenTox::Dataset.find("http://ot-dev.in-silico.ch/dataset/307")
  #    puts d.compounds.inspect
  #    exit
      
      #get "?model=http://local-ot/model/1" 
  #    get "/crossvalidation/3/predictions"
  #    puts last_response.body
  
  #    post "/validate_datasets",{
  #      :test_dataset_uri=>"http://apps.deaconsult.net:8080/ambit2/dataset/R3924",
  #      :prediction_dataset_uri=>"http://apps.ideaconsult.net:8080/ambit2/dataset/R3924?feature_uris[]=http%3A%2F%2Fapps.ideaconsult.net%3A8080%2Fambit2%2Fmodel%2F52%2Fpredicted",
  #      #:test_target_dataset_uri=>"http://local-ot/dataset/202",
  #      :prediction_feature=>"http://apps.ideaconsult.net:8080/ambit2/feature/21715",
  #      :predicted_feature=>"http://apps.ideaconsult.net:8080/ambit2/feature/28944",
  #      :regression=>"true"}
  #      #:classification=>"true"}
  #    puts last_response.body
      
      #post "/crossvalidation/cleanup"
      #puts last_response.body
  
      #get "/crossvalidation/19/predictions",nil,'HTTP_ACCEPT' => "application/x-yaml" #/statistics"
  #    post "",:model_uri=>"http://local-ot/model/1",:test_dataset_uri=>"http://local-ot/dataset/3",
  #      :test_target_dataset_uri=>"http://local-ot/dataset/1"
  
  #    get "/crossvalidation/2",nil,'HTTP_ACCEPT' => "application/rdf+xml" 
     #puts last_response.body
     #exit
      
      #get "/crossvalidation?model_uri=lazar"
  #    post "/test_validation",:select=>"6d" #,:report=>"yes,please"
      #puts last_response.body
      
  #    post "/validate_datasets",{
  #      :test_dataset_uri=>"http://local-ot/dataset/204",
  #      :prediction_dataset_uri=>"http://local-ot/dataset/206",
  #      :test_target_dataset_uri=>"http://local-ot/dataset/202",
  #      :prediction_feature=>"http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk",
  #      :predicted_feature=>"http://ot-dev.in-silico.ch/toxcreate/feature#IRIS%20unit%20risk_lazar_regression",
  #      :regression=>"true"}
  #      #:classification=>"true"}
  #    puts last_response.body
  
  #     post "/validate_datasets",{
  #      :test_dataset_uri=>"http://local-ot/dataset/89",
  #       :prediction_dataset_uri=>"http://local-ot/dataset/91",
  #       :test_target_dataset_uri=>"http://local-ot/dataset/87",
  #       :prediction_feature=>"http://local-ot/dataset/1/feature/hamster_carcinogenicity",
  #       :predicted_feature=>"",
  ##      :regression=>"true"}
  #       :classification=>"true"}
  #    puts last_response.body
  
      # m = OpenTox::Model::Generic.find("http://local-ot/model/1323333")
      # puts m.to_yaml
  
  #     post "/validate_datasets",{
  #      :test_dataset_uri=>"http://local-ot/dataset/506",
  #       :prediction_dataset_uri=>"http://local-ot/dataset/526",
  #       :test_target_dataset_uri=>"http://local-ot/dataset/504",
  #       :prediction_feature=>"http://local-ot/dataset/504/feature/LC50_mmol",
  #       :model_uri=>"http://local-ot/model/48"}
  #      #:regression=>"true"}
  ##       :classification=>"true"}
  #    puts last_response.body
      
      #run_test("13a","http://local-ot/validation/39",nil,false) #,"http://local-ot/validation/28")#,"http://local-ot/validation/394");
      
      #puts OpenTox::Authorization.list_policy_uris(SUBJECTID).inspect
      
      #puts OpenTox::Authorization.list_policy_uris(SUBJECTID).inspect

      run_test("15a",nil,nil,false) #,{:dataset_uri=>"http://local-ot/dataset/45", :prediction_feature => "http://local-ot/dataset/45/feature/Hamster%20Carcinogenicity"})
      
      #get "/12123123123123123"
      #get "/chain"
      
      #OpenTox::RestClientWrapper.get("http://local-ot/validation/task-error")
      #get "/error",nil,'HTTP_ACCEPT' => "application/rdf+xml"
      #puts ""
      #puts ""
      #puts last_response.body 
      #exit
      
#      get "/error"
#      puts last_response.body

      #delete "/1",:subjectid=>SUBJECTID
      
      #run_test("7b","http://local-ot/validation/21")
      
      #run_test("3a","http://local-ot/validation/crossvalidation/4")
      #run_test("3b","http://local-ot/validation/crossvalidation/3")
      
      #run_test("8a", "http://local-ot/validation/crossvalidation/6")
      #run_test("8b", "http://local-ot/validation/crossvalidation/5")
  
      #run_test("11b", "http://local-ot/validation/crossvalidation/2" )# //local-ot/validation/42")#, "http://local-ot/validation/report/validation/8") #,"http://local-ot/validation/report/validation/36") #, "http://local-ot/validation/321")
     # run_test("7a","http://local-ot/validation/40") #,"http://local-ot/validation/crossvalidation/10") #, "http://local-ot/validation/321")
      #run_test("8b", "http://local-ot/validation/crossvalidation/4")
   
      #puts Nightly.build_nightly("1")
      
      #prepare_examples
      #do_test_examples # USES CURL, DO NOT FORGET TO RESTART VALIDATION SERVICE
      #do_test_examples_ortona
      
    ensure
      OpenTox::Authorization.logout(SUBJECTID) if AA_SERVER
    end
  end

  def app
    Sinatra::Application
  end
  
  def run_test(select=nil, validation_uri=nil, report_uri=nil, delete=false, overwrite={})
    
    if AA_SERVER && SUBJECTID && delete
      policies_before = OpenTox::Authorization.list_policy_uris(SUBJECTID)
    end
    
    puts ValidationExamples.list unless select
    validationExamples = ValidationExamples.select(select)
    validationExamples.each do |vv|
      vv.each do |v| 
        ex = v.new
        ex.subjectid = SUBJECTID
        
        ex.validation_uri = validation_uri
        overwrite.each do |k,v|
          ex.send(k.to_s+"=",v)
        end
        
        unless ex.validation_uri
          ex.upload_files
          ex.check_requirements
          ex.validate
          LOGGER.debug "validation done '"+ex.validation_uri.to_s+"'"
          puts ex.validation_uri+"?subjectid="+CGI.escape(SUBJECTID) if SUBJECTID and !delete and ex.validation_uri
        end
        ex.report_uri = report_uri
        unless ex.report_uri
          ex.report
          puts ex.report_uri+"?subjectid="+CGI.escape(SUBJECTID)  if SUBJECTID and !delete and ex.report_uri
        end
        ##ex.verify_yaml
        ##ex.compare_yaml_vs_rdf
        ex.delete if delete
      end
    end
    
    if AA_SERVER && SUBJECTID && delete
      policies_after= OpenTox::Authorization.list_policy_uris(SUBJECTID)
      diff = policies_after.size - policies_before.size
      if (diff != 0)
        policies_before.each do |k,v|
          policies_after.delete(k)
        end
        LOGGER.warn diff.to_s+" policies NOT deleted:\n"+policies_after.collect{|k,v| k.to_s+" => "+v.to_s}.join("\n")
      else
        LOGGER.debug "all policies deleted"
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
