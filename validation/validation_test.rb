ENV['RACK_ENV'] = 'test'

load 'validation/validation_application.rb'

require 'test/unit'
require 'rack/test'

load 'lib/test_util.rb'

WS_DATA=@@config[:services]["opentox-dataset"] #"localhost:4002"

DATA="hamster"
FILE=File.new("data/hamster_carcinogenicity.csv","r")

DATA_TRAIN="hamster_train"
FILE_TRAIN= File.new("data/hamster_carcinogenicity_TRAIN.csv","r")

DATA_TEST="hamster_test"
FILE_TEST=File.new("data/hamster_carcinogenicity_TEST.csv","r")

#WS_CLASS_ALG=@@config[:services]["opentox-algorithm"]+"lazar_classification" #"localhost:4003/lazar_classification"
WS_CLASS_ALG=@@config[:services]["opentox-majority"]+"algorithm" #"localhost:4008/algorithm"

#WS_FEATURE_ALG=@@config[:services]["opentox-algorithm"]+"fminer" #"localhost:4003/fminer"
WS_FEATURE_ALG=nil


class ValidationTest < Test::Unit::TestCase
  include Rack::Test::Methods
  include OpenTox::ValidationLib::TestUtil

  def app
    Sinatra::Application
  end

#  def test_all_validations
#    get '/validations'
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
  def test_cv
    begin
      data_uri = upload_data(WS_DATA, DATA, FILE)
      
#      first_validation=nil
#      2.times do 
        
        num_folds = 9
        post '/crossvalidation', { :dataset_uri => data_uri,
          :algorithm_uri => WS_CLASS_ALG, :feature_service_uri => WS_FEATURE_ALG, :num_folds => num_folds, :random_seed => 2 }
      
        puts "crossvalidation: "+last_response.body
        assert last_response.ok?
        crossvalidation_id = last_response.body.split("/")[-1]
        add_resource("/crossvalidation/"+crossvalidation_id)
        puts "id:"+crossvalidation_id
      
        get '/crossvalidation/'+crossvalidation_id
        puts last_response.body
        assert last_response.ok? || last_response.status==202
        
        get '/crossvalidation/'+crossvalidation_id+'/validations'
        puts "validations:\n"+last_response.body
        assert last_response.ok?
        assert last_response.body.split("\n").size == num_folds, "num-folds:"+num_folds.to_s+" but num lines is "+last_response.body.split("\n").size.to_s
        
#        if first_validation
#          # assert that both cross validaitons use the same datasets
#          first_validation2 = last_response.body.split("\n")[0].split("/")[-1]
#          
#          get '/validation/'+first_validation+'/test_dataset_uri'
#          assert last_response.ok?
#          first_val_test_data = last_response.body
#
#          get '/validation/'+first_validation2+'/test_dataset_uri'
#          assert last_response.ok?
#          first_val2_test_data = last_response.body
#          assert first_val_test_data==first_val2_test_data
#        end
#        first_validation = last_response.body.split("\n")[0].split("/")[-1]
#      end
    ensure
      delete_resources
    end
  end
#
#  def test_validate_model
#    begin
#      data_uri_train = upload_data(WS_DATA, DATA_TRAIN, FILE_TRAIN)
#      data_uri_test = upload_data(WS_DATA, DATA_TEST, FILE_TEST)
#      #data_uri_train = WS_DATA+"/"+DATA_TRAIN
#      #data_uri_test = WS_DATA+"/"+DATA_TEST
#       
#      if WS_FEATURE_ALG
#        feature_uri = RestClient.post WS_FEATURE_ALG, :dataset_uri => data_uri_train
#        model_uri = RestClient.post(WS_CLASS_ALG,{ :activity_dataset_uri => data_uri_train, :feature_dataset_uri => feature_uri })
#      else
#        model_uri = RestClient.post(WS_CLASS_ALG,{ :dataset_uri => data_uri_train })
#      end
#      
#      post '/validation', {:test_dataset_uri => data_uri_test, :model_uri => model_uri}
#      verify_validation
#    ensure
#      delete_resources
#    end
#  end
#  
#  def test_validate_algorithm
#    begin
#      data_uri_train = upload_data(WS_DATA, DATA_TRAIN, FILE_TRAIN)
#      data_uri_test = upload_data(WS_DATA, DATA_TEST, FILE_TEST)
#      #data_uri_train = WS_DATA+"/"+DATA_TRAIN
#      #data_uri_test = WS_DATA+"/"+DATA_TEST
#      post '/validation', { :training_dataset_uri => data_uri_train, :test_dataset_uri => data_uri_test,
#        :algorithm_uri => WS_CLASS_ALG, :feature_service_uri => WS_FEATURE_ALG}
#      verify_validation
#    ensure
#      delete_resources
#    end
#  end
  
#  def test_split
#    begin
#      data_uri = upload_data(WS_DATA, DATA, FILE)
#      #data_uri=WS_DATA+"/"+DATA
#      post '/validation/training_test_split', { :dataset_uri => data_uri, :algorithm_uri => WS_CLASS_ALG, 
#        :feature_service_uri => WS_FEATURE_ALG, :split_ratio=>0.9, :random_seed=>2}
#      verify_validation
#    ensure
#      delete_resources
#    end
#  end
  
  private
  def verify_validation (delete=true)
    
    puts "validation: "+last_response.body
    assert last_response.ok?
    validation_id = last_response.body.split("/")[-1]
    add_resource("/validation/"+validation_id) if delete
    puts "uri: "+last_response.body
    puts "id:"+validation_id
    
    get '/validation/'+validation_id
    puts last_response.body
    assert last_response.ok? || last_response.status==202

    ["test_dataset_uri", "model_uri", "prediction_dataset_uri"].each do |t|
      get '/validation/'+validation_id+'/'+t
      puts ""+t+": "+last_response.body
      assert last_response.ok?
      
      content = ext("curl "+last_response.body)
      content = content.split("\n")[0,10].join("\n")+"\n...\n" if content.count("\n")>10
      puts content
    end
  end
  
end
