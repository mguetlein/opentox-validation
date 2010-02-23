
if ENV['R_HOME']
  ENV['PATH'] = ENV['R_HOME']+":"+ENV['PATH'] unless ENV['PATH'].split(":").index(ENV['R_HOME'])
else
  LOGGER.warn "Environment variable R_HOME not set"
end
require 'rinruby'

module Lib

  module Util
    
    def self.compute_variance( old_variance, n, new_mean, old_mean, new_value )
      # use revursiv formular for computing the variance
      # ( see Tysiak, Folgen: explizit und rekursiv, ISSN: 0025-5866
      #  http://www.frl.de/tysiakpapers/07_TY_Papers.pdf )
      return (n>1 ? old_variance * (n-2)/(n-1) : 0) +
             (new_mean - old_mean)**2 +
             (n>1 ? (new_value - new_mean)**2/(n-1) : 0 )
    end
  end
  
  class Predictions
  
    def initialize( predicted_values, 
                    actual_values, 
                    confidence_values, 
                    is_classification, 
                    prediction_feature_values=nil )
                    
      @predicted_values = predicted_values
      @actual_values = actual_values
      @confidence_values = confidence_values
      @is_classification = is_classification
      @prediction_feature_values = prediction_feature_values
      @num_classes = 1
      
      raise "no predictions" if @predicted_values.size == 0
      num_info = "predicted:"+@predicted_values.size.to_s+
        " confidence:"+@confidence_values.size.to_s+" actual:"+@actual_values.size.to_s
      raise "illegal num actual values "+num_info if  @actual_values.size != @predicted_values.size
      raise "illegal num confidence values "+num_info if  @confidence_values.size != @predicted_values.size
      
      @confidence_values.each{ |c| raise "illegal confidence value: '"+c.to_s+"'" unless c==nil or (c.is_a?(Numeric) and c>=0 and c<=1) }
      
      if @is_classification
        raise "prediction_feature_values missing while performing classification" unless @prediction_feature_values
        @num_classes = @prediction_feature_values.size
        raise "num classes < 2" if @num_classes<2
        { "predicted"=>@predicted_values, "actual"=>@actual_values }.each do |s,values|
          values.each{ |v| raise "illegal "+s+" classification-value ("+v.to_s+"),"+
            "has to be either nil or index of predicted-values" if v!=nil and (v<0 or v>@num_classes)}
        end
      else
        raise "prediction_feature_values != nil while performing regression" if @prediction_feature_values
        { "predicted"=>@predicted_values, "actual"=>@actual_values }.each do |s,values|
          values.each{ |v| raise "illegal "+s+" regression-value ("+v.to_s+"),"+
            "has to be either nil or number" unless v==nil or v.is_a?(Numeric)}
        end
      end
      
      init_stats()
      (0..@predicted_values.size-1).each do |i|
        update_stats( @predicted_values[i], @actual_values[i], @confidence_values[i] )
      end
    end
    
    def init_stats
      @num_no_actual_value = 0
      @num_with_actual_value = 0
      
      @num_predicted = 0
      @num_unpredicted = 0
      
      if @is_classification
        @confusion_matrix = []
        @prediction_feature_values.each do |v|
          @confusion_matrix.push( Array.new( @num_classes, 0 ) )
        end
        
        @num_correct = 0
        @num_incorrect = 0
      else
        @sum_error = 0
        @sum_abs_error = 0
        @sum_squared_error = 0
        
        @prediction_mean = 0
        @actual_mean = 0
        
        @variance_predicted = 0
        @variance_actual = 0
      end
    end
    
    def update_stats( predicted_value, actual_value, confidence_value )
      
      if actual_value==nil
        @num_no_actual_value += 1
      else 
        @num_with_actual_value += 1
        
        if predicted_value==nil
          @num_unpredicted += 1
        else
          @num_predicted += 1
          
          if @is_classification
            @confusion_matrix[actual_value][predicted_value] += 1
            if (predicted_value == actual_value)
              @num_correct += 1
            else
              @num_incorrect += 1
            end
          else
            delta = predicted_value - actual_value
            @sum_error += delta
            @sum_abs_error += delta.abs
            @sum_squared_error += delta**2
            
            old_prediction_mean = @prediction_mean
            @prediction_mean = (@prediction_mean * (@num_predicted-1) + predicted_value) / @num_predicted.to_f
            old_actual_mean = @actual_mean
            @actual_mean = (@actual_mean * (@num_predicted-1) + actual_value) / @num_predicted.to_f

            @variance_predicted = Util.compute_variance( @variance_predicted, @num_predicted, 
              @prediction_mean, old_prediction_mean, predicted_value )
            @variance_actual = Util.compute_variance( @variance_actual, @num_predicted, 
              @actual_mean, old_actual_mean, actual_value )
          end
        end
      end
    end
    
    def percent_correct
      raise "no classification" unless @is_classification
      return 0 if @num_with_actual_value==0
      return 100 * @num_correct / @num_with_actual_value.to_f
    end
    
    def percent_incorrect
      raise "no classification" unless @is_classification
      return 0 if @num_with_actual_value==0
      return 100 * @num_incorrect / @num_with_actual_value.to_f
    end
    
    def percent_unpredicted
      return 0 if @num_with_actual_value==0
      return 100 * @num_unpredicted / @num_with_actual_value.to_f
    end

    def num_unpredicted
      @num_unpredicted
    end

    def percent_without_class
      return 0 if @predicted_values==0
      return 100 * @num_no_actual_value / @predicted_values.size.to_f
    end
    
    def num_without_class
      @num_no_actual_value
    end

    def num_correct
      raise "no classification" unless @is_classification
      return @num_correct
    end

    def num_incorrect
      raise "no classification" unless @is_classification
      return @num_incorrect
    end
    
    def num_unclassified
      raise "no classification" unless @is_classification
      return @num_unpredicted
    end
    
    # internal structure of confusion matrix:
    # hash with keys: hash{ :confusion_matrix_actual => <class_value>, :confusion_matrix_predicted => <class_value> }
    #     and values: <int-value>
    def confusion_matrix
      
      raise "no classification" unless @is_classification
      res = {}
      (0..@num_classes-1).each do |actual|
          (0..@num_classes-1).each do |predicted|
            res[{:confusion_matrix_actual => @prediction_feature_values[actual],
                 :confusion_matrix_predicted => @prediction_feature_values[predicted]}] = @confusion_matrix[actual][predicted]
        end
      end
      return res
    end
    
    def area_under_roc(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| area_under_roc(i) } ) if class_index==nil
      
      LOGGER.warn("TODO: implement approx computiation of AUC,"+
        "so far Wilcoxon-Man-Whitney is used (exponential)") if @predicted_values.size>1000
      
      tp_conf = []
      fp_conf = []
      (0..@predicted_values.size-1).each do |i|
        if @predicted_values[i]==class_index
          if @actual_values[i]==class_index
            tp_conf.push(@confidence_values[i])
          else
            fp_conf.push(@confidence_values[i])
          end
        end
      end
      
      return 0.0 if tp_conf.size == 0
      return 1.0 if fp_conf.size == 0
      sum = 0
      tp_conf.each do |tp|
        fp_conf.each do |fp|
          sum += 1 if tp>fp
        end
      end
      return sum / (tp_conf.size * fp_conf.size).to_f
    end
    
    def f_measure(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| f_measure(i) } ) if class_index==nil
      
      prec = precision(class_index)
      rec = recall(class_index)
      return 0 if prec == 0 and rec == 0
      return 2 * prec * rec / (prec + rec).to_f;
    end
    
    def precision(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| precision(i) } ) if class_index==nil
      
      correct = 0
      total = 0
      (0..@num_classes-1).each do |i|
         correct += @confusion_matrix[i][class_index] if i == class_index
         total += @confusion_matrix[i][class_index]
      end
      return 0 if total==0
      return correct/total.to_f
    end
    
    def recall(class_index=nil)
      return true_positive_rate(class_index)
    end
    
    def true_negative_rate(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| true_negative_rate(i) } ) if class_index==nil
      
      correct = 0
      total = 0
      (0..@num_classes-1).each do |i|
        if i != class_index
          (0..@num_classes-1).each do |j|    
            correct += @confusion_matrix[i][j] if j != class_index
            total +=  @confusion_matrix[i][j]
          end
        end
      end
      return 0 if total==0
      return correct/total.to_f
    end
    
    def num_true_negatives(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| num_true_negatives(i) } ) if class_index==nil
      
      correct = 0
      (0..@num_classes-1).each do |i|
        if i != class_index
          (0..@num_classes-1).each do |j|    
            correct += @confusion_matrix[i][j] if j != class_index
          end
        end
      end
      return correct
    end
    
    def true_positive_rate(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| true_positive_rate(i) } ) if class_index==nil
      
      correct = 0
      total = 0
      (0..@num_classes-1).each do |i|
        correct += @confusion_matrix[class_index][i] if i == class_index
        total += @confusion_matrix[class_index][i]
      end
      return 0 if total==0
      return correct/total.to_f
    end
    
    def num_true_positives(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| num_true_positives(i) } ) if class_index==nil
      
      correct = 0
      (0..@num_classes-1).each do |i|
        correct += @confusion_matrix[class_index][i] if i == class_index
      end
      return correct
    end
    
    def false_negative_rate(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| false_negative_rate(i) } ) if class_index==nil
      
      total = 0
      incorrect = 0
      (0..@num_classes-1).each do |i|
        if i == class_index
          (0..@num_classes-1).each do |j|
            incorrect += @confusion_matrix[i][j] if j != class_index
            total += @confusion_matrix[i][j]
          end
        end
      end
      return 0 if total == 0
      return incorrect / total.to_f
    end
    
    def num_false_negatives(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| num_false_negatives(i) } ) if class_index==nil
      
      incorrect = 0
      (0..@num_classes-1).each do |i|
        if i == class_index
          (0..@num_classes-1).each do |j|
            incorrect += @confusion_matrix[i][j] if j != class_index
          end
        end
      end
      return incorrect
    end

    def false_positive_rate(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| false_positive_rate(i) } ) if class_index==nil
      
      total = 0
      incorrect = 0
      (0..@num_classes-1).each do |i|
        if i != class_index
          (0..@num_classes-1).each do |j|
            incorrect += @confusion_matrix[i][j] if j == class_index
            total += @confusion_matrix[i][j]
          end
        end
      end
      return 0 if total == 0
      return incorrect / total.to_f
    end
    
    def num_false_positives(class_index=nil)
      return prediction_feature_value_map( lambda{ |i| num_false_positives(i) } ) if class_index==nil
      
      incorrect = 0
      (0..@num_classes-1).each do |i|
        if i != class_index
          (0..@num_classes-1).each do |j|
            incorrect += @confusion_matrix[i][j] if j == class_index
          end
        end
      end
      return incorrect
    end
    
    
    # regression #######################################################################################
    
    def root_mean_squared_error
      return 0 if (@num_with_actual_value - @num_unpredicted)==0
      Math.sqrt(@sum_squared_error / (@num_with_actual_value - @num_unpredicted).to_f)
    end
    
    def mean_absolute_error
      return 0 if (@num_with_actual_value - @num_unpredicted)==0
      Math.sqrt(@sum_abs_error / (@num_with_actual_value - @num_unpredicted).to_f)
    end
    
    def r_square
      return 0 if @variance_actual==0
      return @variance_predicted / @variance_actual
    end
    
    # data for roc-plots ###################################################################################
    
    def get_roc_values(class_value)
      
      class_index = @prediction_feature_values.index(class_value)
      raise "class not found "+class_value.to_s if class_index==nil and class_value!=nil
      
      c = []; p = []; a = []
      (0..@predicted_values.size-1).each do |i|
        # NOTE: not predicted instances are ignored here
        if (@predicted_values[i]!=nil and (class_value==nil or @predicted_values[i]==class_index))
          c << @confidence_values[i]
          p << @predicted_values[i]
          a << @actual_values[i]
        end
      end
      return {:predicted_values => p, :actual_values => a, :confidence_values => c}
    end
    
    ########################################################################################
    
    def num_instances
      return @predicted_values.size
    end
  
    def predicted_value(instance_index)
      if @is_classification
        @predicted_values[instance_index]==nil ? nil : @prediction_feature_values[@predicted_values[instance_index]]
      else
        @predicted_values[instance_index]
      end
    end
    
    def actual_value(instance_index)
      if @is_classification
        @actual_values[instance_index]==nil ? nil : @prediction_feature_values[@actual_values[instance_index]]
      else
        @actual_values[instance_index]
      end
    end
    
    def confidence_value(instance_index)
      return @confidence_values[instance_index]
    end      
    
    def classification_miss?(instance_index)
      raise "no classification" unless @is_classification
      return false if predicted_value(instance_index)==nil or actual_value(instance_index)==nil
      return predicted_value(instance_index) != actual_value(instance_index)
    end
    
    def classification?
      @is_classification
    end
    
    ###################################################################################################################
    
    private
    def prediction_feature_value_map(proc)
      res = {}
      (0..@num_classes-1).each do |i|
        res[@prediction_feature_values[i]] = proc.call(i)
      end
      return res
    end
    
  end
end