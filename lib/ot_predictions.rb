
require "lib/predictions.rb"

module Lib
  
  class OTPredictions < Predictions
  
    CHECK_VALUES = ENV['RACK_ENV']=="test"
  
    def identifier(instance_index)
      return compound(instance_index)
    end
  
    def compound(instance_index)
      return @compounds[instance_index]
    end
  
    def initialize(is_classification, test_dataset_uri, prediction_feature, prediction_dataset_uri, predicted_variable)
      
        LOGGER.debug("loading prediciton via test-dateset:'"+test_dataset_uri.to_s+
          "' and prediction-dataset:'"+prediction_dataset_uri.to_s+
          "', prediction_feature: '"+prediction_feature.to_s+"' "+
          "', predicted_variable: '"+predicted_variable.to_s+"'")
         
        predicted_variable=prediction_feature if predicted_variable==nil
        
        test_dataset = OpenTox::Dataset.find test_dataset_uri
        prediction_dataset = OpenTox::Dataset.find prediction_dataset_uri
        raise "test dataset not found: '"+test_dataset_uri.to_s+"'" unless test_dataset
        raise "prediction dataset not found: '"+prediction_dataset_uri.to_s+"'" unless prediction_dataset
        raise "test dataset feature not found: '"+prediction_feature+"', available features: "+test_dataset.features.inspect if test_dataset.features.index(prediction_feature)==nil
        raise "prediction dataset feature not found: '"+predicted_variable+"', available features: "+prediction_dataset.features.inspect if prediction_dataset.features.index(predicted_variable)==nil
        
        class_values = OpenTox::Feature.domain(prediction_feature)
        
        @compounds = test_dataset.compounds
        raise "test dataset is empty" unless @compounds.size>0
        raise "more predicted than test compounds test:"+@compounds.size.to_s+" < prediction:"+
          prediction_dataset.compounds.size.to_s if @compounds.size < prediction_dataset.compounds.size
        
        if CHECK_VALUES
          prediction_dataset.compounds.each do |c| 
            raise "predicted compound not found in test dataset" if @compounds.index(c)==nil
          end
        end
        
        actual_values = []
        @compounds.each do |c|
          
          value = test_dataset.get_value(c, prediction_feature)
          
          if is_classification
            value = value.to_s unless value==nil
            raise "illegal class_value of actual value "+value.to_s+" class: "+
              value.class.to_s unless value==nil or class_values.index(value)!=nil
            actual_values.push class_values.index(value) 
          else
            begin
              value = value.to_f unless value==nil or value.is_a?(Numeric)
            rescue
              LOGGER.warn "no numeric value for regression: '"+value.to_s+"'"
              value = nil
            end
            actual_values.push value
          end
        end
        
        predicted_values = []
        confidence_values = []
        @compounds.each do |c|
          if prediction_dataset.compounds.index(c)==nil
            predicted_values << nil
            confidence_values << nil
          else
            if is_classification
              value = prediction_dataset.get_predicted_class(c, predicted_variable)
              value = value.to_s unless value==nil
              raise "illegal class_value of predicted value "+value.to_s+" class: "+value.class.to_s unless value==nil or class_values.index(value)!=nil
              predicted_values << class_values.index(value)
              confidence_values << prediction_dataset.get_prediction_confidence(c, predicted_variable)
            else
              raise "TODO regression"
            end
          end
        end
        
        super(predicted_values, actual_values, confidence_values, is_classification, class_values)
        raise "illegal num compounds "+num_info if  @compounds.size != @predicted_values.size
    end
    

    def compute_stats
    
      res = {}
      if @is_classification
        (Lib::VAL_CLASS_PROPS_EXTENDED).each{ |s| res[s] = send(s)}  
      else
        (Lib::VAL_REGR_PROPS).each{ |s| res[s] = send(s) }  
      end
      return res
    end
    
  end
end