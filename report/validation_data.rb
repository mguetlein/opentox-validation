
# the variance is computed when merging results for these attributes 
VAL_ATTR_VARIANCE = [ :auc, :acc ]

class Object
  
  def to_nice_s
    return "%.2f" % self if is_a?(Float)
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
    
    #VAL_ATTR.each{ |a| attr_accessor a }
    OpenTox::Validation::ALL_PROPS.each{ |a| attr_accessor a } 
    VAL_ATTR_VARIANCE.each{ |a| attr_accessor (a.to_s+"_variance").to_sym }
  
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
    
    # loads all crossvalidation attributes, of the corresponding cv into this object 
    def load_cv_attributes
      raise "crossvalidation-id not set" unless @crossvalidation_id
      Reports.validation_access.init_cv(self)
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
    def merge( validation, equal_attributes)
  
      new_validation = Reports::Validation.new
      raise "not working" if validation.merge_count > 1
      
      OpenTox::Validation::ALL_PROPS.each do |a|
        next if a =~ /_variance$/ 
  
        if (equal_attributes.index(a) != nil)
          new_validation.send("#{a.to_s}=".to_sym, send(a))
        else
          value = nil
          variance = nil
  
          if (send(a).is_a?(Float) || send(a).is_a?(Integer))
            value = (send(a) * @merge_count + validation.send(a)) / (@merge_count + 1).to_f;
            if (VAL_ATTR_VARIANCE.index(a) != nil)
              old_std_dev = 0;
              old_std_dev = send((a.to_s+"_variance").to_sym) ** 2 if send((a.to_s+"_variance").to_sym)
              std_dev = (old_std_dev * (@merge_count / (@merge_count + 1.0))) + (((validation.send(a) - value) ** 2) * (1 / @merge_count))
              variance = Math.sqrt(std_dev);
            end
          else
            if send(a).to_s != validation.send(a).to_s
              value = send(a).to_s + "/" + validation.send(a).to_s
            else
              value = validation.send(a).to_s
            end
          end
  
          #value = "test"
          new_validation.send("#{a.to_s}=".to_sym, value)
          new_validation.send("#{a.to_s+"_variance"}=".to_sym, variance) if variance
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
    
    def load_cv_attributes
      @validations.each{ |v| v.load_cv_attributes }
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
    #   to_array(attributes) => array
    # 
    def to_array(attributes)
      array = Array.new
      array.push(attributes)
      @validations.each do |v| 
        array.push(attributes.collect do |a|
          variance = v.send( (a.to_s+"_variance").to_sym ) if VAL_ATTR_VARIANCE.index(a)
          variance = " +- "+variance.to_nice_s if variance
          v.send(a).to_nice_s + variance.to_s 
        end)
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
        new_set.validations.push(g[0].clone)
        g[1..-1].each do |v|
          new_set.validations[-1] = new_set.validations[-1].merge(v, equal_attributes)
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