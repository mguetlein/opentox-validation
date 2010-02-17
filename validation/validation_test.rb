ENV['RACK_ENV'] = 'test'

#require 'validation/validation_application.rb'
require 'application.rb'

require 'test/unit'
require 'rack/test'

require 'lib/test_util.rb'

WS_DATA=@@config[:services]["opentox-dataset"] #"localhost:4002"

#DATA="hamster"
#FILE=File.new("data/hamster_carcinogenicity.csv","r")
#FILE=File.new("data/hamster_carcinogenicity_REG.csv","r")
FILE=File.new("data/hamster_carcinogenicity.owl","r")

##DATA_TRAIN="hamster_train"
#FILE_TRAIN= File.new("data/hamster_carcinogenicity_TRAIN.csv","r")
FILE_TRAIN=File.new("data/hamster_carcinogenicity.owl","r")

##DATA_TEST="hamster_test"
#FILE_TEST=File.new("data/hamster_carcinogenicity_TEST.csv","r")
FILE_TEST=File.new("data/hamster_carcinogenicity.owl","r")

FEATURE_URI="http://www.epa.gov/NCCT/dsstox/CentralFieldDef.html#ActivityOutcome_CPDBAS_Hamster"

#WS_CLASS_ALG="http://webservices.in-silico.ch/test/algorithm/lazar"
WS_CLASS_ALG=File.join(@@config[:services]["opentox-algorithm"],"lazar") #"localhost:4003/lazar"
#WS_CLASS_ALG=@@config[:services]["opentox-majority"]+"algorithm" #"localhost:4008/algorithm"

WS_FEATURE_ALG=File.join(@@config[:services]["opentox-algorithm"],"fminer") #"localhost:4003/fminer"
#WS_FEATURE_ALG=nil


class ValidationTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include Lib::TestUtil

  def app
    Sinatra::Application
  end

#  def test_all_validations
#    get '/'
#    assert last_response.ok?
#    puts "all validations:\n"+last_response.body
#    validations = last_response.body.split("\n")
#    puts validations.inspect
#    if validations && validations.size>0
#      validations.each do |v|
#        get v
#        puts "get "+v+":\n"+last_response.body
#        assert last_response.ok? || last_response.status==202
#      end
#    end
#  end
#
#  def test_all_cvs
#    get '/crossvalidations'
#    assert last_response.ok?
#    puts "all crossvalidations:\n"+last_response.body+"\n"
#    crossvalidations = last_response.body.split("\n")
#    #puts crossvalidations.inspect
#    if crossvalidations && crossvalidations.size>0
#      crossvalidations.each do |v|
#        get v
#        puts "get "+v+":\n"+last_response.body
#        assert last_response.ok? || last_response.status==202
#      end
#    end   
#  end
#  
#  def test_cv
#    begin
#      data_uri = upload_data(WS_DATA, FILE)
#      
##      first_validation=nil
##      2.times do 
#        
#        num_folds = 9
#        post '/crossvalidation', { :dataset_uri => data_uri, :algorithm_uri => WS_CLASS_ALG, :prediction_feature => FEATURE_URI,
#           :algorithm_params => "feature_generation_uri="+WS_FEATURE_ALG, :num_folds => num_folds, :random_seed => 2 }
#      
#        puts "crossvalidation: "+last_response.body
#        assert last_response.ok?
#        crossvalidation_id = last_response.body.split("/")[-1]
#        add_resource("/crossvalidation/"+crossvalidation_id)
#        puts "id:"+crossvalidation_id
#      
#        get '/crossvalidation/'+crossvalidation_id
#        puts last_response.body
#        assert last_response.ok? || last_response.status==202
#        
#        get '/crossvalidation/'+crossvalidation_id+'/validations'
#        puts "validations:\n"+last_response.body
#        assert last_response.ok?
#        assert last_response.body.split("\n").size == num_folds, "num-folds:"+num_folds.to_s+" but num lines is "+last_response.body.split("\n").size.to_s
#        
##        if first_validation
##          # assert that both cross validaitons use the same datasets
##          first_validation2 = last_response.body.split("\n")[0].split("/")[-1]
##          
##          get '/'+first_validation+'/test_dataset_uri'
##          assert last_response.ok?
##          first_val_test_data = last_response.body
##
##          get '/'+first_validation2+'/test_dataset_uri'
##          assert last_response.ok?
##          first_val2_test_data = last_response.body
##          assert first_val_test_data==first_val2_test_data
##        end
##        first_validation = last_response.body.split("\n")[0].split("/")[-1]
##      end
#    ensure
#      #delete_resources
#    end
#  end
#
#  def test_validate_model
#    begin
##      data_uri_train = upload_data(WS_DATA, DATA_TRAIN, FILE_TRAIN)
##      data_uri_test = upload_data(WS_DATA, DATA_TEST, FILE_TEST)
##      #data_uri_train = WS_DATA+"/"+DATA_TRAIN
##      #data_uri_test = WS_DATA+"/"+DATA_TEST
##       
##      if WS_FEATURE_ALG
##        feature_uri = RestClient.post WS_FEATURE_ALG, :dataset_uri => data_uri_train
##        model_uri = RestClient.post(WS_CLASS_ALG,{ :activity_dataset_uri => data_uri_train, :feature_dataset_uri => feature_uri })
##      else
##        model_uri = RestClient.post(WS_CLASS_ALG,{ :dataset_uri => data_uri_train })
##      end 
#      
#      #model_uri = "http://ot.model.de/12"
#      #data_uri_test = "http://ot.dataset.de/67"
#      
#      model_uri = "http://ot.model.de/9" 
#      data_uri_test = "http://ot.dataset.de/33"
#      
#      post '', {:test_dataset_uri => data_uri_test, :model_uri => model_uri, :prediction_feature => FEATURE_URI}
#      
#      puts last_response.body
#      #verify_validation
#    ensure
#      #delete_resources
#    end
#  end
#  
#  def test_validate_algorithm
#    begin
#      
#      #get '/41',nil,'HTTP_ACCEPT' => "application/rdf+xml" #"text/x-yaml"
#      #puts last_response.body
#      data_uri_train = upload_data(WS_DATA, FILE_TRAIN)
#      data_uri_test = upload_data(WS_DATA, FILE_TEST)
#      
#      #data_uri_train = WS_DATA+"/"+DATA_TRAIN
#      #data_uri_test = WS_DATA+"/"+DATA_TEST
#      post '', { :training_dataset_uri => data_uri_train, :test_dataset_uri => data_uri_test,
#        :algorithm_uri => WS_CLASS_ALG, :prediction_feature => FEATURE_URI, :algorithm_params => "feature_generation_uri="+WS_FEATURE_ALG }
#        
#      puts last_response.body
#      #verify_validation
#    ensure
#      #delete_resources
#    end
#  end
  
#  def test_split
#    begin
#      data_uri = upload_data(WS_DATA, FILE)
#      #data_uri =  "http://ot.dataset.de/199" #bbrc
#      #data_uri = "http://ot.dataset.de/67" #hamster
#      
#      #data_uri=WS_DATA+"/"+DATA
#      post '/training_test_split', { :dataset_uri => data_uri, :algorithm_uri => WS_CLASS_ALG, :prediction_feature => FEATURE_URI,
#        :algorithm_params => "feature_generation_uri="+WS_FEATURE_ALG, :split_ratio=>0.8, :random_seed=>5}
#      puts last_response.body
#      #verify_validation
#    ensure
#      #delete_resources
#    end
#  end
  
  def test_nothing
    
    #puts "testing nothing"
    
    #get '/'     

    #get '/prepare_examples'
    get '/test_examples'

    #get '/1',nil,'HTTP_ACCEPT' => "application/rdf+xml"
    #get '/350',nil,'HTTP_ACCEPT' => "text/x-yaml"
    
    #get '/crossvalidation/1',nil,'HTTP_ACCEPT' => "application/rdf+xml"
    #get '/crossvalidation/1',nil,'HTTP_ACCEPT' => "text/x-yaml"
    
    puts last_response.body
  end
  
  private
  def verify_validation (delete=true)
    
    puts "validation: "+last_response.body
    assert last_response.ok?
    validation_id = last_response.body.split("/")[-1]

    puts "uri: "+last_response.body
    puts "id:"+validation_id
    add_resource("/"+validation_id) if delete

    #get '/'+validation_id,nil,'HTTP_ACCEPT' => "application/rdf+xml"
    get '/'+validation_id,nil,'HTTP_ACCEPT' => "text/x-yaml"
    puts last_response.body
    assert last_response.ok? || last_response.status==202

#    ["test_dataset_uri", "model_uri", "prediction_dataset_uri"].each do |t|
#      get '/'+validation_id+'/'+t
#      puts ""+t+": "+last_response.body
#      assert last_response.ok?
#      
#      content = ext("curl "+last_response.body)
#      content = content.split("\n")[0,10].join("\n")+"\n...\n" if content.count("\n")>10
#      puts content
#    end
  end
  
end
