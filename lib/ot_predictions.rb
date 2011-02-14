
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
  
    def initialize(feature_type, test_dataset_uri, test_target_dataset_uri, 
      prediction_feature, prediction_dataset_uri, predicted_variable, subjectid=nil, task=nil)
      
        LOGGER.debug("loading prediciton via test-dataset:'"+test_dataset_uri.to_s+
          "', test-target-datset:'"+test_target_dataset_uri.to_s+
          "', prediction-dataset:'"+prediction_dataset_uri.to_s+
          "', prediction_feature: '"+prediction_feature.to_s+"' "+
          "', predicted_variable: '"+predicted_variable.to_s+"'")
          
        predicted_variable=prediction_feature if predicted_variable==nil
        
        test_dataset = OpenTox::Dataset.find test_dataset_uri,subjectid
        raise "test dataset not found: '"+test_dataset_uri.to_s+"'" unless test_dataset
        raise "prediction_feature missing" unless prediction_feature
        
        if test_target_dataset_uri == nil || test_target_dataset_uri.strip.size==0 || test_target_dataset_uri==test_dataset_uri
          test_target_dataset_uri = test_dataset_uri
          test_target_dataset = test_dataset
          raise "prediction_feature not found in test_dataset, specify a test_target_dataset\n"+
                "prediction_feature: '"+prediction_feature.to_s+"'\n"+
                "test_dataset: '"+test_target_dataset_uri.to_s+"'\n"+
                "available features are: "+test_target_dataset.features.inspect if test_target_dataset.features.keys.index(prediction_feature)==nil
        else
          test_target_dataset = OpenTox::Dataset.find test_target_dataset_uri,subjectid
          raise "test target datset not found: '"+test_target_dataset_uri.to_s+"'" unless test_target_dataset
          if CHECK_VALUES
            test_dataset.compounds.each do |c|
              raise "test compound not found on test class dataset "+c.to_s unless test_target_dataset.compounds.include?(c)
            end
          end
          raise "prediction_feature not found in test_target_dataset\n"+
                "prediction_feature: '"+prediction_feature.to_s+"'\n"+
                "test_target_dataset: '"+test_target_dataset_uri.to_s+"'\n"+
                "available features are: "+test_target_dataset.features.inspect if test_target_dataset.features.keys.index(prediction_feature)==nil
        end
        
        test_dataset.load_all(subjectid)
        @compounds = test_dataset.compounds
        LOGGER.debug "test dataset size: "+@compounds.size.to_s
        raise "test dataset is empty "+test_dataset_uri.to_s unless @compounds.size>0
        class_values = feature_type=="classification" ? OpenTox::Feature.find(prediction_feature, subjectid).domain : nil
        
        actual_values = []
        @compounds.each do |c|
          case feature_type
          when "classification"
            actual_values << classification_value(test_target_dataset, c, prediction_feature, class_values)
          when "regression"
            actual_values << regression_value(test_target_dataset, c, prediction_feature)
          end
        end
        task.progress(40) if task # loaded actual values
        
        prediction_dataset = OpenTox::Dataset.find prediction_dataset_uri,subjectid
        raise "prediction dataset not found: '"+prediction_dataset_uri.to_s+"'" unless prediction_dataset
        
        # TODO: remove LAZAR_PREDICTION_DATASET_HACK
        no_prediction_feature = prediction_dataset.features.keys.index(predicted_variable)==nil
        if no_prediction_feature
          one_entry_per_compound = true
          @compounds.each do |c|
            if prediction_dataset.data_entries[c] and prediction_dataset.data_entries[c].size != 1
              one_entry_per_compound = false
              break
            end
          end
          msg = "prediction-feature not found: '"+predicted_variable+"' in prediction-dataset: "+prediction_dataset_uri.to_s+", available features: "+
            prediction_dataset.features.keys.inspect
          if one_entry_per_compound
            LOGGER.warn msg
          else
            raise msg
          end
        end

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
            case feature_type
            when "classification"
              # TODO: remove LAZAR_PREDICTION_DATASET_HACK
              predicted_values << classification_value(prediction_dataset, c, no_prediction_feature ? nil : predicted_variable, class_values)
            when "regression"
              predicted_values << regression_value(prediction_dataset, c, no_prediction_feature ? nil : predicted_variable)
            end
            # TODO confidence_values << prediction_dataset.get_prediction_confidence(c, predicted_variable)
            conf = 1
            begin
              feature = prediction_dataset.data_entries[c].keys[0]
              feature_data = prediction_dataset.features[feature]
              conf = feature_data[OT.confidence] if feature_data[OT.confidence]!=nil 
            rescue
              LOGGER.warn "could not get confidence"
            end
            confidence_values << conf
          end
        end
        task.progress(80) if task # loaded predicted values and confidence
        
        super(predicted_values, actual_values, confidence_values, feature_type, class_values)
        raise "illegal num compounds "+num_info if  @compounds.size != @predicted_values.size
        task.progress(100) if task # done with the mathmatics
    end
    
    private
    def regression_value(dataset, compound, feature)
      v = value(dataset, compound, feature)
      begin
        v = v.to_f unless v==nil or v.is_a?(Numeric)
        v
      rescue
        LOGGER.warn "no numeric value for regression: '"+v.to_s+"'"
        nil
      end
    end
    
    def classification_value(dataset, compound, feature, class_values)
      v = value(dataset, compound, feature)
      i = class_values.index(v)
      raise "illegal class_value of prediction (value is '"+v.to_s+"', class is '"+v.class.to_s+"'), possible values are "+
        class_values.inspect unless v==nil or i!=nil
      i
    end
    
    def value(dataset, compound, feature)
      return nil if dataset.data_entries[compound]==nil
      if feature==nil
        v = dataset.data_entries[compound].values[0]
      else
        v = dataset.data_entries[compound][feature]
      end
      raise "no array" unless v.is_a?(Array)
      if v.size>1
        v.uniq!
        raise "not yet implemented: multiple non-equal values "+compound.to_s+" "+v.inspect if v.size>1
        v = v[0]
      elsif v.size==1
        v = v[0]
      else
        v = nil
      end
      raise "array" if v.is_a?(Array)
      v = nil if v.to_s.size==0
      v
    end

    public
    def compute_stats
    
      res = {}
      case @feature_type
      when "classification"
        (Lib::VAL_CLASS_PROPS).each{ |s| res[s] = send(s)}  
      when "regression"
        (Lib::VAL_REGR_PROPS).each{ |s| res[s] = send(s) }  
      end
      return res
    end
    
    def to_array()
      OTPredictions.to_array( [self] )
    end
    
    def self.to_array( predictions, add_pic=false, format=false )
  
      res = []
      predictions.each do |p|
        (0..p.num_instances-1).each do |i|
          a = []
          
          #PENDING!
          begin
            #a.push( "http://ambit.uni-plovdiv.bg:8080/ambit2/depict/cdk?search="+
            #  URI.encode(OpenTox::Compound.new(:uri=>p.identifier(i)).smiles) ) if add_pic
            a << p.identifier(i)+"/image"
          rescue => ex
            raise ex
            #a.push("Could not add pic: "+ex.message)
            #a.push(p.identifier(i))
          end
          
          a << (format ? p.actual_value(i).to_nice_s : p.actual_value(i))
          a << (format ? p.predicted_value(i).to_nice_s : p.predicted_value(i))
          if p.feature_type=="classification"
            if (p.predicted_value(i)!=nil and p.actual_value(i)!=nil)
              a << (p.classification_miss?(i) ? 1 : 0)
            else
              a << nil
            end
          end
          if p.confidence_values_available?
            a << (format ? p.confidence_value(i).to_nice_s : p.confidence_value(i))
          end
          a << p.identifier(i)
          res << a
        end
      end
        
      header = []
      header << "compound" if add_pic
      header << "actual value"
      header << "predicted value"
      header << "missclassified" if predictions[0].feature_type=="classification"
      header << "confidence value" if predictions[0].confidence_values_available?
      header << "compound-uri"
      res.insert(0, header)
      
      return res
  end
    
  end
end
