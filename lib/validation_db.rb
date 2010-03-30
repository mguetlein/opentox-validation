
[ 'rubygems', 'dm-core', 'datamapper' ].each do |lib|
  require lib
end

require "lib/merge.rb"

module Lib

  VAL_PROPS_GENERAL = [ :id, :uri, :model_uri, :algorithm_uri, :training_dataset_uri, :prediction_feature,
                :test_dataset_uri, :prediction_dataset_uri, :created_at ] 
  VAL_PROPS_SUM = [ :num_instances, :num_without_class, :num_unpredicted ]
  VAL_PROPS_AVG = [:real_runtime, :percent_without_class, :percent_unpredicted ]
  VAL_PROPS = VAL_PROPS_GENERAL + VAL_PROPS_SUM + VAL_PROPS_AVG
  
  # :crossvalidation_info
  VAL_CV_PROPS = [ :crossvalidation_id, :crossvalidation_fold ]
  
  # :classification_statistics
  VAL_CLASS_PROPS_SINGLE_SUM = [ :num_correct, :num_incorrect, :confusion_matrix  ]
  VAL_CLASS_PROPS_SINGLE_AVG = [ :percent_correct, :percent_incorrect, :weighted_area_under_roc ]
  VAL_CLASS_PROPS_SINGLE = VAL_CLASS_PROPS_SINGLE_SUM + VAL_CLASS_PROPS_SINGLE_AVG
  
  # :class_value_statistics
  VAL_CLASS_PROPS_PER_CLASS_SUM = [ :num_false_positives, :num_false_negatives, 
                                :num_true_positives, :num_true_negatives ]
  VAL_CLASS_PROPS_PER_CLASS_AVG = [ :area_under_roc, :false_negative_rate, :false_positive_rate,
                                :f_measure, :precision, 
                                :true_negative_rate, :true_positive_rate ] #:recall,
  VAL_CLASS_PROPS_PER_CLASS = VAL_CLASS_PROPS_PER_CLASS_SUM + VAL_CLASS_PROPS_PER_CLASS_AVG
  VAL_CLASS_PROPS_PER_CLASS_COMPLEMENT_EXISTS = [ :num_false_positives, :num_false_negatives, 
                                :num_true_positives, :num_true_negatives, :false_negative_rate, :false_positive_rate,
                                :true_negative_rate, :true_positive_rate ] #:precision, :recall, 
                                
  VAL_CLASS_PROPS = VAL_CLASS_PROPS_SINGLE + VAL_CLASS_PROPS_PER_CLASS
  VAL_CLASS_PROPS_EXTENDED = VAL_CLASS_PROPS + [:accuracy]

  # :regression_statistics
  VAL_REGR_PROPS = [ :root_mean_squared_error, :mean_absolute_error, :r_square, :target_variance_actual, :target_variance_predicted ]
  
  CROSS_VAL_PROPS = [:dataset_uri, :num_folds, :stratified, :random_seed]
  CROSS_VAL_PROPS_REDUNDANT = [:algorithm_uri] + CROSS_VAL_PROPS 
  
  ALL_PROPS = VAL_PROPS + VAL_CV_PROPS + VAL_CLASS_PROPS_EXTENDED + VAL_REGR_PROPS + CROSS_VAL_PROPS

  VAL_MERGE_GENERAL = VAL_PROPS_GENERAL + VAL_CV_PROPS + [:classification_statistics, :regression_statistics] + CROSS_VAL_PROPS
  VAL_MERGE_SUM = VAL_PROPS_SUM + VAL_CLASS_PROPS_SINGLE_SUM + VAL_CLASS_PROPS_PER_CLASS_SUM
  VAL_MERGE_AVG = VAL_PROPS_AVG + VAL_CLASS_PROPS_SINGLE_AVG + VAL_CLASS_PROPS_PER_CLASS_AVG + VAL_REGR_PROPS
 
  class Validation
    include DataMapper::Resource 
  
    property :id, Serial
    property :uri, String, :length => 255
    property :model_uri, String, :length => 255
    property :algorithm_uri, String, :length => 255
    property :training_dataset_uri, String, :length => 255
    property :test_dataset_uri, String, :length => 255
    property :prediction_dataset_uri, String, :length => 255
    property :prediction_feature, String, :length => 255
    property :created_at, DateTime
    property :real_runtime, Float
    
    property :num_instances, Integer
    property :num_without_class, Integer
    property :percent_without_class, Float
    property :num_unpredicted, Integer
    property :percent_unpredicted, Float
        
    property :classification_statistics, Object #Hash
    property :regression_statistics, Object
    
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
    property :stratified, Boolean, :default => false
    property :random_seed, Integer, :default => 1
  end
end

# sqlite is used for storing validations and crossvalidations
#sqlite = "#{File.expand_path(File.dirname(__FILE__))}/#{Sinatra::Base.environment}.sqlite3"
#DataMapper.setup(:default, "sqlite3:///#{sqlite}")
#unless FileTest.exists?("#{sqlite}")
#  [Lib::Validation, Lib::Crossvalidation].each do |model|
#    model.auto_migrate!
#  end
#end

#raise "':database:' configuration missing in config file" unless @@config.has_key?(:database)
#[ "adapter","database","username","password","host" ].each do |field|
  #raise "field '"+field+":' missing in database configuration" unless @@config[:database].has_key?(field)
#end
#DataMapper.setup(:default, { 
    #:adapter  => @@config[:database]["adapter"],
    #:database => @@config[:database]["database"],
    #:username => @@config[:database]["username"],
   # :password => @@config[:database]["password"],
#    :host     => @@config[:database]["host"]
  #})
[Lib::Validation, Lib::Crossvalidation].each do |resource|
    resource.auto_migrate! unless resource.storage_exists?
end
