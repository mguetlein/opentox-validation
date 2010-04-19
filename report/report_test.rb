require "fileutils"
ENV['RACK_ENV'] = 'test'
require 'report/report_application.rb'
require 'test/unit'
require 'rack/test'
require "lib/test_util.rb"
LOGGER = Logger.new(STDOUT)
LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "

class Reports::ApplicationTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end
  
  
  
  def test_nothing
  
#    get "/match"
#    puts last_response.body.to_s
    
    #Reports::XMLReport.generate_demo_xml_report.write_to
    #raise "stop"
    
    #uri = '/report/css_style_sheet?css_style_sheet='+CGI.escape("http://apps.ideaconsult.net:8180/ToxPredict/style/global.css")
    #puts uri
    #get uri
    
    #get '/report/validation/1',nil,'HTTP_ACCEPT' => "text/html"     
    #post '/report/validation/1/format_html',:css_style_sheet=>"http://apps.ideaconsult.net:8180/ToxPredict/style/global.css"
    
    #post 'http://ot.validation.de/report/crossvalidation',:validation_uris=>"http://ot.validation.de/crossvalidation/1"
    #uri = last_response.body.to_s
    
#    post 'http://ot.validation.de/report/algorithm_comparison',:validation_uris=>"http://ot.validation.de/validation/15\n"+
#      "http://ot.validation.de/validation/16\n"+
#      "http://ot.validation.de/validation/18\n"
#    uri = last_response.body.to_s
#    puts uri
#    
#    post uri.to_s+'/format_html',:css_style_sheet=>"http://apps.ideaconsult.net:8180/ToxPredict/style/global.css"
#    puts last_response.body.to_s.gsub(/\n.*/,"")
    
  end
#
#  def test_webservice
#    
#    ENV['USE_OT_MOCK_LAYER'] = "true"
#    Reports.reset_ot_access
#    
#    get '/'
#    assert last_response.ok?
#    assert last_response.body.split("\n").size == Reports::ReportFactory::REPORT_TYPES.size
#    
#    Reports::ReportFactory::REPORT_TYPES.each do |t|
#      get '/'+t.to_s
#      assert last_response.ok?
#    end
#    get '/osterhase'
#    assert last_response.not_found?
#
#    post '', :validation_uris => "validation_uri_1\nvalidation_uri_2"  
#    assert last_response.status == 400
# 
#    post '', :validation_uris => "validation_uri_1"
#    assert last_response.ok?
#    report_uri = last_response.body 
#    type = $rep.parse_type(report_uri)
#    assert type == "validation"
#    id = $rep.parse_id(report_uri)
#    
#    get '/'+id.to_s, {}, {"HTTP_ACCEPT" => "weihnachtsmann"}
#    assert last_response.status == 400
#    get '/'+id.to_s, {}, {"HTTP_ACCEPT" => "text/xml"}
#    assert last_response.ok?
#    get '/'+id.to_s, {}, {"HTTP_ACCEPT" => "text/html"}
#    assert last_response.ok?
#    
#    delete '/43984398'
#    assert last_response.not_found?
#    delete '/'+id.to_s
#    assert last_response.ok?
#    
#    map = {"crossvalidation"=>"validation_uri_1\nvalidation_uri_2\nvalidation_uri_3\nvalidation_uri_4\nvalidation_uri_5",
#           "algorithm_comparison"=> ("validation_uri\n"*(Reports::OTMockLayer::NUM_DATASETS * Reports::OTMockLayer::NUM_ALGS * Reports::OTMockLayer::NUM_FOLDS)) }
#    map.each do |t,u|
#      Reports.reset_ot_access
#      post '/'+t.to_s, :validation_uris=>u.to_s
#      assert last_response.ok?
#      report_uri = last_response.body 
#      type = $rep.parse_type(report_uri)
#      assert type == t
#      id = $rep.parse_id(report_uri)
#      delete '/'+t.to_s+'/'+id.to_s
#      assert last_response.ok?
#    end
#  end
#  
end



#class Reports::ReportServiceTest < Test::Unit::TestCase
#  include Lib::TestUtil
#
#  WS_VAL = @@config[:services]["opentox-validation"]
#  WS_DATA=@@config[:services]["opentox-dataset"]
#  FILE=File.new("data/hamster_carcinogenicity.owl","r")
#  
#  WS_CLASS_ALG=File.join(@@config[:services]["opentox-algorithm"],"lazar")
#  WS_FEATURE_ALG=File.join(@@config[:services]["opentox-algorithm"],"fminer")
#  
#  #WS_CLASS_ALG_2="localhost:4008/algorithm"
#  #WS_FEATURE_ALG_2=nil
#
#  def test_service_ot_webservice
#
#    begin
#      
#      rep = Reports::ReportService.new("http://some.location")
#      types = rep.get_report_types
#      assert types.is_a?(String)
#      assert types.split("\n").size == Reports::ReportFactory::REPORT_TYPES.size
#      #Reports::ReportFactory::REPORT_TYPES.each{|t| rep.get_all_reports(t)}
#      #assert_raise(Reports::NotFound){rep.get_all_reports("osterhase")}
#      
#      ### using ot_mock_layer (reporting component does not rely on ot validation webservice)
#      
#      #ENV['REPORT_VALIDATION_ACCESS'] = "mock_layer"
#      #Reports::Validation.reset_validation_access
#      
##      create_report(rep, "validation_uri_1", "validation")
##      assert_raise(Reports::BadRequest){create_report(rep, ["validation_uri_1","validation_uri_2"], "validation")}
##      
##      create_report(rep, "crossvalidation_uri_1", "crossvalidation")
##      create_report(rep, ["validation_uri_1"]*Reports::OTMockLayer::NUM_FOLDS, "crossvalidation")
##      assert_raise(Reports::BadRequest){create_report(rep, ["validation_uri_1"]*(Reports::OTMockLayer::NUM_FOLDS-1), "crossvalidation")}
##      
##      create_report(rep, ["crossvalidation_uri_1"]* (Reports::OTMockLayer::NUM_DATASETS * Reports::OTMockLayer::NUM_ALGS), "algorithm_comparison")
##      create_report(rep, ["validation_uri_1"]* (Reports::OTMockLayer::NUM_DATASETS * Reports::OTMockLayer::NUM_ALGS * Reports::OTMockLayer::NUM_FOLDS), "algorithm_comparison")
#
#      ### using ot webservices (instead of mock layer)
#
#      #ENV['REPORT_VALIDATION_ACCESS'] = nil
#      #Reports::Validation.reset_validation_access
#      
#      #data_uri = upload_data WS_DATA,  FILE
#      #data_uri= File.join(WS_DATA,"1")
#      
##      #val_uri = create_single_validation(data_uri)
##      #val_uri = create_single_validation(data_uri, WS_CLASS_ALG_2, WS_FEATURE_ALG_2)
##      val_uri = File.join(WS_VAL,"15")
###      #add_resource val_uri
##      create_report(rep, val_uri, "validation")
#        
#       #val_uri = create_cross_validation(data_uri, WS_CLASS_ALG_2, WS_FEATURE_ALG_2)
#       #val_uri = create_cross_validation(data_uri)
#       val_uri = File.join(WS_VAL,"crossvalidation/1")
#       #val_uri2 = "http://localhost:4007/crossvalidation/14"
##       # add_resource val_uri
#       create_report(rep, val_uri, "crossvalidation")
#        
##         #val_uri2 = create_cross_validation(data_uri, WS_CLASS_ALG_2, WS_FEATURE_ALG_2)
##         #val_uri = ["http://localhost:4007/crossvalidation/6", "http://localhost:4007/crossvalidation/8"]
#         #val_uri = ["http://localhost:4007/crossvalidation/7", "http://localhost:4007/crossvalidation/8"]
##         #add_resource val_uri
#         #create_report(rep, val_uri, "algorithm_comparison")
#      
#    ensure
#     # delete_resources
#    end
#  end
#  
#  private
#  def create_single_validation(data_uri, ws_class_alg=WS_CLASS_ALG, ws_feat_alg=WS_FEATURE_ALG)
#    puts "validating"
#    val_params = { 
#        :dataset_uri => data_uri, 
#        :algorithm_uri => ws_class_alg, 
#        :split_ratio=>0.7,
#        :prediction_feature => "classification",}
#    val_params[:feature_generation_uri] = ws_feat_alg if ws_feat_alg
#    begin
#      RestClient.post WS_VAL+"/validation/training_test_split", val_params
#    rescue => ex
#      raise "error validating "+WS_VAL+"/validation/training_test_split\n "+val_params.inspect+" \n -> "+ex.message
#    end
#  end
#  
#  def create_cross_validation(data_uri, ws_class_alg=WS_CLASS_ALG, ws_feat_alg=WS_FEATURE_ALG)
#    puts "cross-validating"
#    ext("curl -X POST -d num_folds=3 -d dataset_uri="+data_uri+" -d algorithm_uri="+ws_class_alg+" -d prediction_feature=classification"+
#        (ws_feat_alg ? " -d feature_generation_uri="+ws_feat_alg : "")+
#        " "+WS_VAL+"/crossvalidation",nil)
#  end
#  
#  def create_report(report_service, val_uri, type)
#    
#    Reports.reset_ot_access if ENV['USE_OT_MOCK_LAYER']
#    report_uri = report_service.create_report(type, val_uri)
#    assert type == report_service.parse_type(report_uri)
#    id = report_service.parse_id(report_uri)
#    
#    #puts "created report with id "+id.to_s
#    
#    #assert_raise(Reports::BadRequest){report_service.get_report(type, id, "weihnachtsmann")}
#    
#    report_service.get_report(type, id, "text/html")
#    #report_service.get_report(type, id, "application/pdf")
#    #assert_raise(Reports::NotFound){report_service.delete_report(type, 877658)}
#
##      rep.delete_report(type, id)
#  end
#end

    



#class Reports::XMLReportTest < Test::Unit::TestCase
#  
#  def test_all
#    
#    rep = Reports::XMLReport.new("a","b","c")
#    section1 = rep.add_section(rep.get_root_element, "d")
#    rep.add_paragraph(section1, "e")
#    rep.add_imagefigure(section1, "f", "g", "h", "i")
#    section2 = rep.add_section(rep.get_root_element,"j")
#    rep.add_section(section2,"k")
#    rep.add_table( section2, "l", [["m","n","o"],[1,2,3],[4,5,6]] )
#    rep.add_list( section2, [1,2,3,4,5])
#    res = ""
#    rep.write_to(res)
#    assert res.length > 0
#    assert_equal(res.count("<"), res.count(">")) 
#  end
#
#end
#
#
#class Reports::XMLReportUtilTest < Test::Unit::TestCase
#  
#  def test_create_matrix
#    
#    matrix = Reports::XMLReportUtil.create_confusion_matrix(1,2,3,4)
#    assert matrix.is_a?(Array)
#    assert matrix[0].is_a?(Array)
#  end
#  
#end
#
#class Reports::RPlotTest < Test::Unit::TestCase
#  
#  def test_bar_plot
#    test_plot(lambda{|tmp_file| Reports::RPlotFactory.demo_bar_plot(tmp_file)})
#  end
#  
#  def test_roc_plot
#    test_plot(lambda{|tmp_file| Reports::RPlotFactory.demo_roc_plot(tmp_file)})
#  end
#  
#  private
#  def test_plot(build_plot)
#    
#    tmp_file = Reports::Util.create_tmp_file("roc.svg")
#    assert !File.exist?(tmp_file)
#    build_plot.call(tmp_file)
#    assert File.exist?(tmp_file)
#    FileUtils.rm(tmp_file)
#    assert !File.exist?(tmp_file)
#    
#  end
#    
#  
#end
#
#class Reports::UtilTest < Test::Unit::TestCase
#  
#  class Person
#    attr_accessor :name, :age, :gender
#    
#    def initialize(name, age, gender)
#      @name = name
#      @age = age
#      @gender = gender
#    end
#    
#    def to_s
#      return @name.to_s+" "+@age.to_s+" "+@gender.to_s
#    end
#  end
#  
#  def test_grouping
#    
#    people = [ Person.new("Ralf",20,"m"),
#               Person.new("Eva",21,"f"),
#               Person.new("Adam",21,"m"),
#               Person.new("Rolf",20,"m")]
#               
#    grouping = Reports::Util.group(people, ["gender"])
#    assert grouping.size == 2
#    assert grouping[0].size == 3
#    assert grouping[1].size == 1
#    
#    people = [ Person.new("Tom",20,"m"),
#               Person.new("Manu",21,"m"),
#               Person.new("Konni",22,"m"),
#               Person.new("Tom",20,"f"),
#               Person.new("Manu",21,"f"),
#               Person.new("Konni",22,"f")]
#    
#    grouping = Reports::Util.group(people, ["gender"])
#    assert grouping.size == 2
#    assert grouping[0].size == 3
#    assert grouping[1].size == 3
#    
#    Reports::Util.check_group_matching( grouping, ["name", "age" ])
#    
#  end
#  
#end