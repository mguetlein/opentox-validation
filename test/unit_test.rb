#TEST_USER = "mgtest"
#TEST_PW = "mgpasswd"
#ENV['RACK_ENV'] = 'test'

require "rubygems"
require "sinatra"
require "uri"
require "yaml"
require 'application.rb'
require 'test/unit'
require 'rack/test'
require 'lib/test_util.rb'
require 'test/test_examples.rb'

TEST_USER = "guest"
TEST_PW = "guest"

#LOGGER = OTLogger.new(STDOUT)
#LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
#LOGGER.formatter = Logger::Formatter.new

module Sinatra
  set :raise_errors, false
  set :show_exceptions, false
end

class Exception
  def message
    errorCause ? errorCause.to_yaml : to_s
  end
end

class ValidationTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Lib::TestUtil
  
  def global_setup
    puts "login and upload datasets"
    if AA_SERVER
      @@subjectid = OpenTox::Authorization.authenticate(TEST_USER,TEST_PW)
      raise "could not log in" unless @@subjectid
      puts "logged in: "+@@subjectid.to_s
    else
      puts "AA disabled"
      @@subjectid = nil
    end
    f = File.new("data/hamster_carcinogenicity.mini.csv")
    @@data_class_mini = ValidationExamples::Util.upload_dataset(f, @@subjectid)
    @@feat_class_mini = ValidationExamples::Util.prediction_feature_for_file(f)
  end
  
  def global_teardown
    puts "delete and logout"
    OpenTox::Dataset.find(@@data_class_mini,@@subjectid).delete(@@subjectid) if defined?@@data_class_mini
    @@cv.delete(@@subjectid) if defined?@@cv
    @@report.delete(@@subjectid) if defined?@@report
    @@qmrfReport.delete(@@subjectid) if defined?@@qmrfReport
    OpenTox::Authorization.logout(@@subjectid) if AA_SERVER
  end
 
  def test_crossvalidation
    puts "test_crossvalidation"
    #assert_rest_call_error OpenTox::NotFoundError do 
    #  OpenTox::Crossvalidation.find(File.join(CONFIG[:services]["opentox-validation"],"crossvalidation/noexistingid"))
    #end
    p = { 
      :dataset_uri => @@data_class_mini,
      :algorithm_uri => File.join(CONFIG[:services]["opentox-algorithm"],"lazar"),
      :algorithm_params => "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc"),
      :prediction_feature => @@feat_class_mini,
      :num_folds => 2 }
    t = OpenTox::SubTask.new(nil,0,1)
    def t.progress(pct)
      if !defined?@last_msg or @last_msg+3<Time.new
        puts "waiting for crossvalidation: "+pct.to_s
        @last_msg=Time.new
      end
    end
    def t.waiting_for(task_uri); end
    cv = OpenTox::Crossvalidation.create(p, @@subjectid, t)
    assert cv.uri.uri?
    if @@subjectid
      assert_rest_call_error OpenTox::NotAuthorizedError do
        OpenTox::Crossvalidation.find(cv.uri)
      end
    end
    cv = OpenTox::Crossvalidation.find(cv.uri, @@subjectid)
    assert cv.uri.uri?
    if @@subjectid
      assert_rest_call_error OpenTox::NotAuthorizedError do
        cv.summary(cv)
      end
    end
    summary = cv.summary(@@subjectid)
    assert_kind_of Hash,summary
    @@cv = cv
  end
    
  def test_crossvalidation_report
    #@@cv = OpenTox::Crossvalidation.find("http://local-ot/validation/crossvalidation/47", @@subjectid)
    
    puts "test_crossvalidation_report"
    assert defined?@@cv,"no crossvalidation defined"
    assert_kind_of OpenTox::Crossvalidation,@@cv
    #assert_rest_call_error OpenTox::NotFoundError do 
    #  OpenTox::CrossvalidationReport.find_for_crossvalidation(@@cv.uri)
    #end
    if @@subjectid
      assert_rest_call_error OpenTox::NotAuthorizedError do
        OpenTox::CrossvalidationReport.create(@@cv.uri)
      end
    end
    report = OpenTox::CrossvalidationReport.create(@@cv.uri,@@subjectid)
    assert report.uri.uri?
    if @@subjectid
      assert_rest_call_error OpenTox::NotAuthorizedError do
        OpenTox::CrossvalidationReport.find(report.uri)
      end
    end
    report_uri = OpenTox::CrossvalidationReport.find(report.uri,@@subjectid)
    assert report_uri.uri?
    report2 = OpenTox::CrossvalidationReport.find_for_crossvalidation(@@cv.uri,@@subjectid)
    assert_equal report_uri,report2.uri
    report3 = @@cv.find_or_create_report(@@subjectid)
    assert_equal report_uri,report3.uri
    @report = report2
  end
  
  def test_qmrf_report
    #@@cv = OpenTox::Crossvalidation.find("http://local-ot/validation/crossvalidation/47", @@subjectid)
    
    puts "test_qmrf_report"
    assert defined?@@cv,"no crossvalidation defined"
    
    validations = @@cv.metadata[OT.validation]
    assert_kind_of Array,validations
    assert validations.size==@@cv.metadata[OT.numFolds]
    
    val = OpenTox::Validation.find(validations[0], @@subjectid)
    model_uri = val.metadata[OT.model]
    model = OpenTox::Model::Generic.find(model_uri, @@subjectid)
    assert model!=nil
    
    #assert_rest_call_error OpenTox::NotFoundError do 
    #  OpenTox::QMRFReport.find_for_model(model_uri, @@subjectid)
    #end
    
    @@qmrfReport = OpenTox::QMRFReport.create(model_uri, @@subjectid)
  end
  
  ################### utils and overrides ##########################
  
  def app
    Sinatra::Application
  end
  
  # checks RestCallError type
  def assert_rest_call_error( ex )
    if ex==OpenTox::NotAuthorizedError and @@subjectid==nil
      puts "AA disabled: skipping test for not authorized"
      return
    end
    begin
      yield
    rescue OpenTox::RestCallError => e
      report = e.errorCause
      while report.errorCause
        report = report.errorCause
      end
      assert_equal report.errorType,ex.to_s
    end
  end
  
  # hack to have a global_setup and global_teardown 
  def teardown
    if((@@expected_test_count-=1) == 0)
      global_teardown
    end
  end
  def setup
    unless defined?@@expected_test_count
      @@expected_test_count = (self.class.instance_methods.reject{|method| method[0..3] != 'test'}).length
      global_setup
    end
  end

end

  
