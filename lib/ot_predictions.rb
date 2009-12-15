
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
         
        #PENDING: classification or regresssion?
        if (true)
          is_classification = true
          class_values = ["true", "false"]
        else
          is_classification = false
          class_values = nil
        end
         
        test_dataset.compounds.each do |c|
          
          @compounds.push(c.smiles)
        
          {prediction_dataset => predicted_values, test_dataset => actual_values}.each do |d, v|
            d.features(c).each do |a|
              val = OpenTox::Feature.new(:uri => a.uri).value(prediction_feature).to_s
              val = nil if val.to_s.size==0
              if is_classification
                raise "illegal class_value "+val.to_s unless val==nil or class_values.index(val)!=nil
                v.push(class_values.index(val)) 
              else
                val = val.to_f unless val==nil or val.is_a?(Numeric)
                v.push(val)
              end
            end
          end
          
          prediction_dataset.features(c).each do |a|
            confidence_values.push OpenTox::Feature.new(:uri => a.uri).value('confidence').to_f
          end
        end
        
        super(predicted_values, actual_values, confidence_values, prediction_feature, is_classification, class_values)
        raise "illegal num compounds "+num_info if  @compounds.size != @predicted_values.size
    end
    

    def compute_stats
    
      res = {}
      if @is_classification
        (OpenTox::Validation::VAL_CLASS_PROPS_SINGLE + OpenTox::Validation::VAL_CLASS_PROPS_PER_CLASS).each{ |s| res[s] = send(s)}  
      else
        (OpenTox::Validation::VAL_REGR_PROPS).each{ |s| res[s] = send(s) }  
      end
      return res
    end
    
  end
end