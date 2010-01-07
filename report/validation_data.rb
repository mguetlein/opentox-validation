
# the variance is computed when merging results for these attributes 
VAL_ATTR_VARIANCE = [ :area_under_roc, :percent_correct, :root_mean_squared_error, :mean_absolute_error, :r_square ]
VAL_ATTR_RANKING = [ :area_under_roc, :percent_correct, :true_positive_rate, :true_negative_rate ]

class Object
  
  def to_nice_s
    return "%.2f" % self if is_a?(Float)
    return collect{ |i| i.to_nice_s  }.join(", ") if is_a?(Array)
    return collect{ |i,j| i.to_nice_s+": "+j.to_nice_s  }.join(", ") if is_a?(Hash)
    return to_s
  end
  
  
  # checks weather an object has equal values as stored in the map
  # example o.att = "a", o.att2 = 12, o.has_values?({ att => a }) is true
  #
  # call-seq:
  #   has_values?(map) => boolean
  # 
  def has_values?(map)
    map.each{|k,v| return false if send(k)!=v}
    return true
  end
end


module Reports
  
  def self.validation_access
    @@validation_access
  end
  
  def self.reset_validation_access( validation_access=nil )
    
    if validation_access
      @@validation_access=validation_access
    else
      case ENV['REPORT_VALIDATION_ACCESS']
      when "mock_layer"
        @@validation_access = Reports::ValidationMockLayer.new
      when "webservice"
        @@validation_access = Reports::ValidationWebservice.new
      else #default
        @@validation_access = Reports::ValidationDB.new
      end
    end
  end
  
  # initialize validation_access
  reset_validation_access


  # = Reports::Validation
  #
  # contains all values of a validation object
  #
  class Validation
    
    @@validation_attributes = Lib::ALL_PROPS + 
      VAL_ATTR_VARIANCE.collect{ |a| (a.to_s+"_variance").to_sym } +
      VAL_ATTR_RANKING.collect{ |a| (a.to_s+"_ranking").to_sym }
    
    @@validation_attributes.each{ |a| attr_accessor a } 
  
    attr_reader :predictions, :merge_count
    
    def initialize(uri = nil)
      Reports.validation_access.init_validation(self, uri) if uri
      @merge_count = 1
    end
  
    # returns predictions, these are dynamically generated and stored in this object
    #
    # call-seq:
    #   get_predictions => Reports::Predictions
    # 
    def get_predictions
      return @predictions if @predictions
      unless @prediction_dataset_uri
        LOGGER.info("no predictions available, prediction_dataset_uri not set")
        return nil
      end
      @predictions = Reports.validation_access.get_predictions( self )
    end
    
    # returns the predictions feature values (i.e. the range of the class attribute)
    #
    def get_prediction_feature_values
      return @prediction_feature_values if @prediction_feature_values
      @prediction_feature_values = Reports.validation_access.get_prediction_feature_values(:prediction_feature) 
    end
    
    # loads all crossvalidation attributes, of the corresponding cv into this object 
    def load_cv_attributes
      raise "crossvalidation-id not set" unless @crossvalidation_id
      Reports.validation_access.init_cv(self)
    end
    
    def clone_validation
      new_val = clone
      VAL_ATTR_VARIANCE.each { |a| new_val.send((a.to_s+"_variance=").to_sym,nil) }
      new_val.set_merge_count(1)
      return new_val
    end
    
    # merges this validation and another validation object to a new validation object
    # * v1.att = "a", v2.att = "a" => r.att = "a"
    # * v1.att = "a", v2.att = "b" => r.att = "a / b"
    # * v1.att = "1", v2.att = "2" => r.att = "1.5"
    # * the attributes in __equal_attributes__ are assumed to be equal
    #
    # call-seq:
    #   merge( validation, equal_attributes) => Reports::Validation
    # 
    def merge_validation( validation, equal_attributes)
  
      new_validation = Reports::Validation.new
      raise "not working" if validation.merge_count > 1

      @@validation_attributes.each do |a|
        next if a.to_s =~ /_variance$/
      
        if (equal_attributes.index(a) != nil)
          new_validation.send("#{a.to_s}=".to_sym, send(a))
        else
          
          compute_variance = VAL_ATTR_VARIANCE.index(a)!=nil
          old_variance = compute_variance ? send((a.to_s+"_variance").to_sym) : nil 
          m = Validation::merge_value( send(a), @merge_count, compute_variance, old_variance, validation.send(a) )
          
          new_validation.send("#{a.to_s}=".to_sym, m[:value])
          new_validation.send("#{a.to_s+"_variance"}=".to_sym, m[:variance]) if compute_variance
        end
      end
  
      new_validation.set_merge_count(@merge_count + 1);
      return new_validation
    end  
    
    def merge_count
      @merge_count
    end
    
    protected
    def set_merge_count(c)
      @merge_count = c
    end
    
    # merges to values (value1 and value2), value1 has weight weight1, value2 has weight 1,
    # computes variance if corresponding params are set
    #
    # return hash with merge value (:value) and :variance (if necessary)
    # 
    def self.merge_value( value1, weight1, compute_variance, variance1, value2 )
      
      if (value1.is_a?(Numeric))
        value = (value1 * weight1 + value2) / (weight1 + 1).to_f;
        if compute_variance
          variance = Lib::Util::compute_variance( variance1!=nil ? variance1 : 0, weight1+1, value, value1, value2 )
        end
      elsif value1.is_a?(Array)
        raise "not yet implemented : merging arrays"
      elsif value1.is_a?(Hash)
        value = {}
        variance = {}
        value1.keys.each do |k|
          m = merge_value( value1[k], weight1, compute_variance, variance1==nil ? nil : variance1[k], value2[k] )
          value[k] = m[:value]
          variance[k] = m[:variance] if compute_variance
        end
      else
        if value1.to_s != value2.to_s
          value = value1.to_s + "/" + value2.to_s
        else
          value = value2.to_s
        end
      end
      
      {:value => value, :variance => (compute_variance ? variance : nil) }
    end    
  end
  
  # = Reports:ValidationSet
  #
  # contains an array of validations, including some functionality as merging validations..
  #
  class ValidationSet
    
    def initialize(uri_list = nil)
      @validations = Array.new
      uri_list.each{|u| @validations.push(Reports::Validation.new(u))} if uri_list
    end
    
    def get(index)
      return @validations[index]
    end
    
    def first()
      return @validations.first
    end
    
    # returns the values of the validations for __attribute__
    # * if unique is true a set is returned, i.e. not redundant info
    # * => if unique is false the size of the returned array is equal to the number of validations  
    #
    # call-seq:
    #   get_values(attribute, unique=true) => array
    # 
    def get_values(attribute, unique=true)
      a = Array.new
      @validations.each{ |v| a.push(v.send(attribute).to_s) if !unique || a.index(v.send(attribute).to_s)==nil } 
      return a
    end
    
    # returns the number of different values that exist for an attribute in the validation set  
    #
    # call-seq:
    #   num_different_values(attribute) => integer
    # 
    def num_different_values(attribute)
      return get_values(attribute).size
    end
    
    # returns true if at least one validation has a nil value for __attribute__  
    #
    # call-seq:
    #   has_nil_values?(attribute) => boolean
    # 
    def has_nil_values?(attribute)
      @validations.each{ |v| return true unless v.send(attribute) } 
      return false
    end
    
    # loads the attributes of the related crossvalidation into all validation objects
    #
    def load_cv_attributes
      @validations.each{ |v| v.load_cv_attributes }
    end
    
    # checks weather all validations are classification validations
    #
    def all_classification?
      @validations.each{ |v| return false if v.percent_correct==nil }
      true
    end

    # checks weather all validations are regression validations
    #
    def all_regression?
      @validations.each{ |v| return false if v.root_mean_squared_error==nil }
      true
    end
    
    # returns a new set with all validation that have values as specified in the map
    #
    # call-seq:
    #   filter(map) => Reports::ValidationSet
    # 
    def filter(map)
      new_set = Reports::ValidationSet.new
      validations.each{ |v| new_set.validations.push(v) if v.has_values?(map) }
      return new_set
    end
    
    # returns an array, with values for __attributes__, that can be use for a table
    # * first row is header row
    # * other rows are values
    #
    # call-seq:
    #   to_array(attributes, remove_nil_attributes) => array
    # 
    def to_array(attributes, remove_nil_attributes=true)
      array = Array.new
      array.push(attributes)
      attribute_not_nil = Array.new(attributes.size)
      @validations.each do |v|
        index = 0
        array.push(attributes.collect do |a|
          variance = v.send( (a.to_s+"_variance").to_sym ) if VAL_ATTR_VARIANCE.index(a)
          variance = " +- "+variance.to_nice_s if variance
          attribute_not_nil[index] = true if remove_nil_attributes and v.send(a)!=nil
          index += 1
          v.send(a).to_nice_s + variance.to_s
        end)
      end
      if remove_nil_attributes #delete in reverse order to avoid shifting of indices
        (0..attribute_not_nil.size-1).to_a.reverse.each do |i|
          array.each{|row| row.delete_at(i)} unless attribute_not_nil[i]
        end
      end
      return array
    end
    
    # creates a new validaiton set, that contains merged validations
    # all validation with equal values for __equal_attributes__ are summed up in one validation, i.e. merged 
    #
    # call-seq:
    #   to_array(attributes) => array
    # 
    def merge(equal_attributes)
      new_set = Reports::ValidationSet.new
      
      #compute grouping
      grouping = Reports::Util.group(@validations, equal_attributes)
  
      #merge
      grouping.each do |g|
        new_set.validations.push(g[0].clone_validation)
        g[1..-1].each do |v|
          new_set.validations[-1] = new_set.validations[-1].merge_validation(v, equal_attributes)
        end
      end
      
      return new_set
    end
    
    # creates a new validaiton set, that contains a ranking for __ranking_attribute__
    # (i.e. for ranking attribute :acc, :acc_ranking is calculated)
    # all validation with equal values for __equal_attributes__ are compared
    # (the one with highest value of __ranking_attribute__ has rank 1, and so on) 
    #
    # call-seq:
    #   compute_ranking(equal_attributes, ranking_attribute) => array
    # 
    def compute_ranking(equal_attributes, ranking_attribute)
    
      new_set = Reports::ValidationSet.new
      (0..@validations.size-1).each do |i|
        new_set.validations.push(@validations[i].clone_validation)
      end
      
      grouping = Reports::Util.group(new_set.validations, equal_attributes)
      grouping.each do |group|
  
        # put indices and ranking values for current group into hash
        rank_hash = {}
        (0..group.size-1).each do |i|
          rank_hash[i] = group[i].send(ranking_attribute)
        end
              
        # sort group accrording to second value (= ranking value)
        rank_array = rank_hash.sort { |a, b| b[1] <=> a[1] } 
        
        # create ranks array
        ranks = Array.new
        (0..rank_array.size-1).each do |j|
          
          val = rank_array.at(j)[1]
          rank = j+1
          ranks.push(rank.to_f)
          
          # check if previous ranks have equal value
          equal_count = 1;
          equal_rank_sum = rank;
          
          while ( j - equal_count >= 0 && (val - rank_array.at(j - equal_count)[1]).abs < 0.0001 )
            equal_rank_sum += ranks.at(j - equal_count);
            equal_count += 1;
          end
          
          # if previous ranks have equal values -> replace with avg rank
          if (equal_count > 1)
            (0..equal_count-1).each do |k|
              ranks[j-k] = equal_rank_sum / equal_count.to_f;            
            end
          end
        end
        
        # set rank as validation value
        (0..rank_array.size-1).each do |j|
          index = rank_array.at(j)[0]
          group[index].send( (ranking_attribute.to_s+"_ranking=").to_sym, ranks[j])
        end
      end
      
      return new_set
    end
    
    def size
      return @validations.size
    end
    
    def validations
      @validations
    end
    
  end
end 