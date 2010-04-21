
require "lib/predictions.rb"

module Lib
  
  class OTPredictions < Predictions
  
    CHECK_VALUES = ENV['RACK_ENV'] =~ /debug|test/
  
    def identifier(instance_index)
      return compound(instance_index)
    end
  
    def compound(instance_index)
      return @compounds[instance_index]
    end
  
    def initialize(is_classification, test_dataset_uri, test_target_dataset_uri, prediction_feature, prediction_dataset_uri, predicted_variable)
      
        LOGGER.debug("loading prediciton via test-dateset:'"+test_dataset_uri.to_s+
          "', test-target-datset:'"+test_target_dataset_uri.to_s+
          "', prediction-dataset:'"+prediction_dataset_uri.to_s+
          "', prediction_feature: '"+prediction_feature.to_s+"' "+
          "', predicted_variable: '"+predicted_variable.to_s+"'")
          
        if prediction_feature =~ /ambit.uni-plovdiv.bg.*feature.*264185/
          LOGGER.warn "HACK for report example"  
          prediction_feature = "http://ambit.uni-plovdiv.bg:8080/ambit2/feature/264187"
        end
         
        predicted_variable=prediction_feature if predicted_variable==nil
        
        test_dataset = OpenTox::Dataset.find test_dataset_uri
        raise "test dataset not found: '"+test_dataset_uri.to_s+"'" unless test_dataset
        raise "prediction_feature missing" unless prediction_feature
        
        if test_target_dataset_uri == nil || test_target_dataset_uri.strip.size==0 || test_target_dataset_uri==test_dataset_uri
          test_target_dataset_uri = test_dataset_uri
          test_target_dataset = test_dataset
          raise "prediction_feature not found in test_dataset, specify a test_target_dataset\n"+
                "prediction_feature: '"+prediction_feature.to_s+"'\n"+
                "test_dataset: '"+test_target_dataset_uri.to_s+"'\n"+
                "available features are: "+test_target_dataset.features.inspect if test_target_dataset.features.index(prediction_feature)==nil
        else
          test_target_dataset = OpenTox::Dataset.find test_target_dataset_uri
          raise "test target datset not found: '"+test_target_dataset_uri.to_s+"'" unless test_target_dataset
          if CHECK_VALUES
            test_dataset.compounds.each do |c|
              raise "test compound not found on test class dataset "+c.to_s unless test_target_dataset.compounds.include?(c)
            end
          end
          raise "prediction_feature not found in test_target_dataset\n"+
                "prediction_feature: '"+prediction_feature.to_s+"'\n"+
                "test_target_dataset: '"+test_target_dataset_uri.to_s+"'\n"+
                "available features are: "+test_target_dataset.features.inspect if test_target_dataset.features.index(prediction_feature)==nil
        end
        
        @compounds = test_dataset.compounds
        LOGGER.debug "test dataset size: "+@compounds.size.to_s
        raise "test dataset is empty" unless @compounds.size>0
        class_values = OpenTox::Feature.domain(prediction_feature)
        
        actual_values = []
        @compounds.each do |c|
          value = test_target_dataset.get_value(c, prediction_feature)
          
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
        
        prediction_dataset = OpenTox::Dataset.find prediction_dataset_uri
        raise "prediction dataset not found: '"+prediction_dataset_uri.to_s+"'" unless prediction_dataset
        raise "prediction dataset feature not found: '"+predicted_variable+"', available features: "+prediction_dataset.features.inspect if prediction_dataset.features.index(predicted_variable)==nil
        
        raise "more predicted than test compounds test:"+@compounds.size.to_s+" < prediction:"+
          prediction_dataset.compounds.size.to_s if @compounds.size < prediction_dataset.compounds.size
        if CHECK_VALUES
          prediction_dataset.compounds.each do |c| 
            raise "predicted compound not found in test dataset:\n"+c+"\ntest-compounds:\n"+
              @compounds.collect{|c| c.to_s}.join("\n") if @compounds.index(c)==nil
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
              value = prediction_dataset.get_value(c, predicted_variable)
              begin
                value = value.to_f unless value==nil or value.is_a?(Numeric)
              rescue
                LOGGER.warn "no numeric value for regression: '"+value.to_s+"'"
                value = nil
              end
              predicted_values << value
              confidence_values << nil
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