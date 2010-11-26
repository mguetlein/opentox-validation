
class InitValidation < ActiveRecord::Migration
  def self.up

    create_table :crossvalidations do |t|
      
      [:algorithm_uri, 
       :dataset_uri ].each do |p|
        t.column p, :string, :limit => 255
      end
      
      [:created_at ].each do |p|
        t.column p, :datetime 
      end
      
      [:num_folds, 
       :random_seed ].each do |p|
        t.column p, :integer, :null => false
      end
     
      [ :stratified, :finished ].each do |p|
        t.column p, :boolean, :null => false
      end
    end
    
    create_table :validations do |t|
      
      [:validation_type,
       :model_uri,
       :algorithm_uri, 
       :training_dataset_uri, 
       :test_target_dataset_uri, 
       :test_dataset_uri, 
       :prediction_dataset_uri, 
       :prediction_feature].each do |p|
        t.column p, :string, :limit => 255
      end
      
      [:created_at ].each do |p|
        t.column p, :datetime 
      end
      
      [:real_runtime, :num_instances, :num_without_class, :num_unpredicted, :crossvalidation_id, :crossvalidation_fold ].each do |p|
        t.column p, :integer
      end
      
      [:real_runtime, :percent_without_class, :percent_unpredicted ].each do |p|
        t.column p, :float 
      end
      
      [:classification_statistics, :regression_statistics].each do |p|
        t.column(p, :text, :limit => 16320)
      end
      
      [ :finished ].each do |p|
        t.column p, :boolean, :null => false
      end      
    end
  end

  def self.down
    drop_table :validations if table_exists? :validations
    drop_table :crossvalidations if table_exists? :crossvalidations
  end
end
