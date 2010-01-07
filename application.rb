
require "validation/validation_application.rb"
require "report/report_application.rb"


[ 'rubygems', 'sinatra', 'sinatra/url_for' ].each do |lib|
  require lib
end

get '/examples/?' do
  content_type "text/plain"
  Demo.transform_example
end

get '/prepare_examples/?' do
  Demo.prepare_example_resources
  "done"
end

private

class Demo
  
  @@file=File.new("data/hamster_carcinogenicity.owl","r")
  @@model=File.join @@config[:services]["opentox-model"],"1"
  @@feature="http://www.epa.gov/NCCT/dsstox/CentralFieldDef.html#ActivityOutcome_CPDBAS_Hamster"
  @@alg = File.join @@config[:services]["opentox-algorithm"],"lazar"
  @@alg_params = "feature_generation_uri="+File.join(@@config[:services]["opentox-algorithm"],"fminer")
  @@data=File.join @@config[:services]["opentox-dataset"],"1"
  @@train_data=File.join @@config[:services]["opentox-dataset"],"2"
  @@test_data=File.join @@config[:services]["opentox-dataset"],"3"
  
  def self.transform_example
  
    file = File.new("EXAMPLES", "r")
    res = ""
    while (line = file.gets) 
      res += line
    end
    file.close
    
    sub = { "validation_service" => @@config[:services]["opentox-validation"], 
            "validation_id" => "1",
            "model_uri" => @@model,
            "dataset_uri" => @@data,
            "training_dataset_uri" => @@train_data,
            "test_dataset_uri" => @@test_data,
            "prediction_feature" => @@feature,
            "algorithm_uri" => @@alg,
            "algorithm_params" => @@alg_params,
            "crossvalidation_id" => "1",}
    
    sub.each do |k,v|
      res.gsub!(/<#{k}>/,v)
    end
    res
  end
  
  def self.delete_all(uri_list_service)
    uri_list = RestClient.get(uri_list_service)
    uri_list.split("\n").each do |uri|
      RestClient.delete(uri)
    end
  end
  
  def self.prepare_example_resources
    
    delete_all(@@config[:services]["opentox-dataset"])
    data = File.read(@@file.path)
    data_uri = RestClient.post @@config[:services]["opentox-dataset"], data, :content_type => "application/rdf+xml"
    puts "uploaded dataset "+data_uri
    raise "failed to prepare demo" unless data_uri==@@data
    
    Lib::Validation.auto_migrate!
    delete_all(@@config[:services]["opentox-model"])
    vali_uri = RestClient.post File.join(@@config[:services]["opentox-validation"],'/validation/training_test_split'), { :dataset_uri => data_uri,
                                                         :algorithm_uri => @@alg,
                                                         :prediction_feature => @@feature,
                                                         :algorithm_params => @@alg_params }
    puts "created validation via training test split "+vali_uri
    raise "failed to prepare demo" unless vali_uri==File.join(@@config[:services]["opentox-validation"],'/validation/1')
    
    Lib::Crossvalidation.auto_migrate!
    cv_uri = RestClient.post File.join(@@config[:services]["opentox-validation"],'/crossvalidation'), { :dataset_uri => data_uri,
                                                         :algorithm_uri => @@alg,
                                                         :prediction_feature => @@feature,
                                                         :algorithm_params => @@alg_params,
                                                         :num_folds => 5, :stratified => false }
    puts "created crossvalidation "+cv_uri
    raise "failed to prepare demo" unless cv_uri==File.join(@@config[:services]["opentox-validation"],'/crossvalidation/1')
    
  end
end
