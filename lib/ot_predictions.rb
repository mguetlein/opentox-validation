
load "lib/predictions.rb"

module Lib
  
  class OTPredictions < Predictions
  
    def compound(instance_index)
      return @compounds[instance_index]
    end
  
    def initialize(prediction_feature, test_dataset_uri, prediction_dataset_uri)
      
        LOGGER.debug("loading prediciton via test-dateset:'"+test_dataset_uri.to_s+
          "' and prediction-dataset:'"+prediction_dataset_uri.to_s+
          "', prediction_feature: '"+prediction_feature.to_s+"'")
        
        test_dataset = OpenTox::Dataset.find(:uri => test_dataset_uri)
        prediction_dataset = OpenTox::Dataset.find(:uri => prediction_dataset_uri)
        raise "test dataset not found: "+test_dataset_uri.to_s unless test_dataset
        raise "prediction dataset not found: "+prediction_dataset_uri.to_s unless prediction_dataset
        
        predicted_values = []
        actual_values = []
        confidence_values = []
        @compounds = []
         
        class_values = [] 
         
        test_dataset.compounds.each do |c|
          
          @compounds.push(c.smiles)
        
          {prediction_dataset => predicted_values, test_dataset => actual_values}.each do |d, v|
            d.features(c).each do |a|
              val = OpenTox::Feature.new(:uri => a.uri).value(prediction_feature).to_s
              val = nil if val.to_s.size==0
              class_values.push(val)  if val!=nil and class_values.index(val)==nil
              v.push(class_values.index(val)) 
            end
          end
          
          prediction_dataset.features(c).each do |a|
            confidence_values.push OpenTox::Feature.new(:uri => a.uri).value('confidence').to_f
          end
        end
        
        super(predicted_values, actual_values, confidence_values, prediction_feature, true, class_values)
        raise "illegal num compounds "+num_info if  @compounds.size != @predicted_values.size
    end
    

    def compute_classification_stats
    
      res = {}
      if @is_classification
        (OpenTox::Validation::VAL_CLASS_PROPS_SINGLE + OpenTox::Validation::VAL_CLASS_PROPS_PER_CLASS).each do |s|
          res[s] = send(s)  
        end
      else
        raise "regression not yet implemented"
      end
      return res
    end
    
  end
end