
[ 'rubygems', 'dm-core', 'datamapper' ].each do |lib|
  require lib
end


module Lib
  class Validation
    include DataMapper::Resource 
  
    property :id, Serial
    property :uri, String, :length => 255
    property :model_uri, String, :length => 255
    property :training_dataset_uri, String, :length => 255
    property :test_dataset_uri, String, :length => 255
    property :prediction_dataset_uri, String, :length => 255
    property :finished, Boolean, :default => false
    property :created_at, DateTime
    property :elapsedTimeTesting, Float
    property :CPUTimeTesting, Float
    
    property :classification_info, Object #Hash
    
    property :crossvalidation_id, Integer
    property :crossvalidation_fold, Integer
  end
  
  class Crossvalidation
    include DataMapper::Resource
    property :id, Serial
    property :uri, String, :length => 255
    property :algorithm_uri, String, :length => 255
    property :dataset_uri, String, :length => 255
    property :num_folds, Integer, :default => 10
    property :prediction_feature, String, :length => 255
    property :stratified, Boolean, :default => false
    property :random_seed, Integer, :default => 1
    property :finished, Boolean, :default => false
  end
end

# sqlite is used for storing validations and crossvalidations
sqlite = "#{File.expand_path(File.dirname(__FILE__))}/#{Sinatra::Base.environment}.sqlite3"
DataMapper.setup(:default, "sqlite3:///#{sqlite}")

unless FileTest.exists?("#{sqlite}")
  [Lib::Validation, Lib::Crossvalidation].each do |model|
    model.auto_migrate!
  end
end