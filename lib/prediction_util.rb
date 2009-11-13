
raise "Environment variable R_HOME missing" unless ENV['R_HOME']
ENV['PATH'] = ENV['R_HOME']+":"+ENV['PATH'] unless ENV['PATH'].split(":").index(ENV['R_HOME'])
require 'rinruby'

module Lib
    
  class Predictions
    
    attr_accessor :predicted_values, :actual_values, :confidence_values, :compounds
    
    # pending: only classification supported so far
    def initialize(test_dataset_uri, prediction_dataset_uri)
      
      LOGGER.debug("loading prediciton via test-dateset:'"+test_dataset_uri.to_s+"' and prediction-dataset:'"+prediction_dataset_uri.to_s+"'")
      
      test_dataset = OpenTox::Dataset.find(:uri => test_dataset_uri)
      prediction_dataset = OpenTox::Dataset.find(:uri => prediction_dataset_uri)
      raise "test dataset not found: "+test_dataset_uri.to_s unless test_dataset
      raise "prediction dataset not found: "+prediction_dataset_uri.to_s unless prediction_dataset
      
      @predicted_values = []
      @actual_values = []
      @confidence_values = []
      @compounds = []
       
      test_dataset.compounds.each do |c|
        
        @compounds.push(c.smiles)
      
        {prediction_dataset => @predicted_values, test_dataset => @actual_values}.each do |d, v|
          d.features(c).each do |a|
            case OpenTox::Feature.new(:uri => a.uri).value('classification').to_s
            when 'true'
              v.push(1.0)  
            when 'false'
              v.push(0.0)
            else
              raise "no class value"
            end 
          end
        end
        
        prediction_dataset.features(c).each do |a|
          @confidence_values.push OpenTox::Feature.new(:uri => a.uri).value('confidence').to_f
        end
      end
      
      raise "no predictions" if @predicted_values.size == 0
      num_info = "compounds:"+@compounds.size.to_s+" predicted:"+@predicted_values.size.to_s+
        " confidence:"+@confidence_values.size.to_s+" actual:"+@actual_values.size.to_s
      raise "illegal num compounds "+num_info if  @compounds.size != @predicted_values.size
      raise "illegal num actual values "+num_info if  @actual_values.size != @predicted_values.size
      raise "illegal num confidence values "+num_info if  @confidence_values.size != @predicted_values.size
    end
    
    def num_instances
      return @predicted_values.size
    end
  
    def predicted_value(instance_index)
      return @predicted_values[instance_index]
    end
    
    def actual_value(instance_index)
      return @actual_values[instance_index]
    end
    
    def confidence_value(instance_index)
      return @confidence_values[instance_index]
    end      
    def compound(instance_index)
      return @compounds[instance_index]
    end
    
    def classification_miss?(instance_index)
      return predicted_value(instance_index) != actual_value(instance_index)
    end
    
    # computes prediction stats using R with library ROCR
    # returns hash with values as specified in Validation::VAL_CLASS_PROPS and Validation::VAL_REGR_PROPS
    # PENDING only classification supported so far
    def compute_prediction_stats
    
      R.eval("library(ROCR)", false)
      
      R.assign "prediction_values", @predicted_values
      R.assign "actual_values", @actual_values
      R.eval "pred <- prediction(prediction_values,actual_values)"
      
      ######## ROCR ##########
      res = {}
      OpenTox::Validation::VAL_CLASS_PROPS_ROCR.each do |s|
        R.eval 'perf <- performance(pred,"'+s+'")'
        values = R.pull "perf@y.values[[1]]"
        res[s] = values.is_a?(Array) ? values[1] : values
      end
      
      ######## MANUAL ##########
      res["num_inst"] = @predicted_values.size
      num_pos=0
      num_neg=0
      (0..num_instances-1).each{|i| actual_value(i)==1 ? num_pos+=1 : num_neg+=1}
      res["num_pos"] = num_pos
      res["num_neg"] = num_neg
      
      ["tp", "fn" ].each{ |x| res[x] = (res[x+"r"] * num_pos).to_i }
      ["tn","fp"].each{ |x| res[x] = (res[x+"r"] * num_neg).to_i }
      return res
    end
  end
    
  class MockPredictions < Predictions
    
    def initialize(predicted_values, actual_values, confidence_values, compounds)
      
      @predicted_values = predicted_values
      @actual_values = actual_values
      @confidence_values = confidence_values
      @compounds = compounds
    end
    
  end
end