
require "lib/predictions.rb"

module Lib
  
  class OTPredictions < Predictions
  
    def compound(instance_index)
      return @compounds[instance_index]
    end
  
    def initialize(is_classification, prediction_feature, test_dataset_uri, prediction_dataset_uri)
      
        LOGGER.debug("loading prediciton via test-dateset:'"+test_dataset_uri.to_s+
          "' and prediction-dataset:'"+prediction_dataset_uri.to_s+
          "', prediction_feature: '"+prediction_feature.to_s+"'")
        
        test_dataset = OpenTox::Dataset.find test_dataset_uri
        prediction_dataset = OpenTox::Dataset.find prediction_dataset_uri
        raise "test dataset not found: '"+test_dataset_uri.to_s+"'" unless test_dataset
        raise "prediction dataset not found: '"+prediction_dataset_uri.to_s+"'" unless prediction_dataset
        
        class_values = OpenTox::Feature.range(prediction_feature)
        
        actual_values = []
        @compounds = []
        test_dataset.data.each do |compound,featuresValues|
          @compounds.push compound
  
          featuresValues.each do | featureValue |
            featureValue.each do |feature, value|
              if feature == prediction_feature
                value = nil if value.to_s.size==0
                if is_classification
                  raise "illegal class_value "+value.to_s unless value==nil or class_values.index(value)!=nil
                  actual_values.push class_values.index(value) 
                else
                  value = value.to_f unless value==nil or value.is_a?(Numeric)
                  actual_values.push value
                end
              end
            end
          end
        end
        
        predicted_values = Array.new(actual_values.size)
        confidence_values = Array.new(actual_values.size)
        
        prediction_dataset.data.each do |compound,featuresValues|
      
          index = @compounds.index(compound)
          raise "compound "+compound.to_s+" not found in\n"+@compounds.inspect if index==nil
    
          featuresValues.each do | featureValue |
            featureValue.each do |feature, value|
              if feature == prediction_feature
                value = nil if value.to_s.size==0
                if is_classification
                  
                  ### PENDING ####
                  confidence = nil
                  if value.is_a?(Hash)
                    confidence = value["confidence"].to_f.abs if value.has_key?("confidence")
                    value = value["classification"] if value.has_key?("classification")
                  end
                  ################
                  
                  raise "illegal class_value "+value.to_s unless value==nil or class_values.index(value)!=nil
                  predicted_values[index] = class_values.index(value) 
                  confidence_values[index] = confidence if confidence!=nil
                else
                  value = value.to_f unless value==nil or value.is_a?(Numeric)
                  predicted_values[index] = value
                end
              end
            end
          end
          index += 1
        end

        super(predicted_values, actual_values, confidence_values, is_classification, class_values)
        raise "illegal num compounds "+num_info if  @compounds.size != @predicted_values.size
    end
    

    def compute_stats
    
      res = {}
      if @is_classification
        (Lib::VAL_CLASS_PROPS).each{ |s| res[s] = send(s)}  
      else
        (Lib::VAL_REGR_PROPS).each{ |s| res[s] = send(s) }  
      end
      return res
    end
    
  end
end