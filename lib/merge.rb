
module Lib
  
  def self.compute_variance( old_variance, n, new_mean, old_mean, new_value )
    # use revursiv formular for computing the variance
    # ( see Tysiak, Folgen: explizit und rekursiv, ISSN: 0025-5866
    #  http://www.frl.de/tysiakpapers/07_TY_Papers.pdf )
    return (n>1 ? old_variance * (n-2)/(n-1) : 0) +
           (new_mean - old_mean)**2 +
           (n>1 ? (new_value - new_mean)**2/(n-1) : 0 )
  end
  
  module MergeObjects
  
    @@merge_count = {}
    @@avg_attributes = {}
    @@sum_attributes = {}
    @@non_numeric_attributes = {}
  
    def self.merge_array_objects( array )
      return nil if array.size == nil
      return array[0] if array.size==1
        
      m = self.merge_objects(array[0], array[1] )
      (2..array.size-1).each do |i|
        m = self.merge_objects(m, array[i] )
      end
      return m
    end
    
    def self.merged?(object)
      return merge_count(object)>1
    end
    
    def self.merge_objects( object1, object2 )
      
      raise "classes not equal" if object1.class != object2.class
      object_class = object1.class
      raise "register which attributes to merge first, nothing found for class "+object_class.to_s unless merge_attributes_registered?(object_class)
      raise "not supported, successivly add unmerged object to a merge object" if merge_count(object2)>1
      
      new_object = object_class.new
      # actually instance_variables would be appropriate, but the datamanager creates objects dynamically
      object1.public_methods.each do |method|
        v = method.to_sym
        if merge_attribute?(object_class, v)
          old_variance = (avg_attribute?(object_class,v) and variance_attribute?(new_object,v)) ? object1.send(variance_symbol(v)) : nil
          m = merge_value( object_class, v, object1.send(v), object2.send(v), merge_count(object1), old_variance  )
          new_object.send("#{v.to_s}=".to_sym, m[:value])
          new_object.send("#{v.to_s}_variance=".to_sym, m[:variance]) if (m[:variance] and variance_attribute?(new_object,v))
        end
      end
      set_merge_count(new_object,merge_count(object1)+1)
      return new_object
    end 
     
    def self.register_merge_attributes( object_class, avg_attributes, sum_attributes, non_numeric_attributes)
      @@avg_attributes[object_class] = avg_attributes + avg_attributes.collect{ |a| (a.to_s+"_ranking").to_sym }
      @@sum_attributes[object_class] = sum_attributes
      @@non_numeric_attributes[object_class] = non_numeric_attributes
    end
    
    def self.merge_attributes_registered?( object_class )
      [ @@avg_attributes, @@sum_attributes, @@non_numeric_attributes ].each{ |map| return false unless map.has_key?(object_class) }
      return true
    end
    
    protected
    def self.merge_value( object_class, attribute, value1, value2, weight1=1, variance1=nil )
      
      variance = nil
      
      if (avg=avg_attribute?(object_class, attribute)) || sum_attribute?(object_class, attribute)
        if (value1==nil and value2==nil )
          #do nothing
        elsif value1.is_a?(Numeric) and value2.is_a?(Numeric)
          if avg
            value = (value1 * weight1 + value2) / (weight1 + 1).to_f;
            variance = Lib::compute_variance( variance1!=nil ? variance1 : 0, weight1+1, value, value1, value2 )
          else
            value = value1 + value2
          end
        elsif value1.is_a?(Array) and value2.is_a?(Array)
          raise "cannot merge arrays with unequal sizes" if !value2.is_a?(Array) || value1.size!=value2.size
          value = []
          variance = [] if avg
          (0..value1.size-1).each do |i|
            if avg 
              value << (value1[i] * weight1 + value2[i]) / (weight1 + 1).to_f;
              variance << Lib::compute_variance( (variance1!=nil && variance1[i]!=nil) ? variance1[i] : 0, weight1+1, value[-1], value1[i], value2[i] )
            else
              value << value1[i] + value2[i]
            end
          end
        elsif value1.is_a?(Hash) and value2.is_a?(Hash)
          value = {}
          variance = {} if avg
          value1.keys.each do |k|
            if avg 
              value[k] = (value1[k] * weight1 + value2[k]) / (weight1 + 1).to_f;
              variance[k] = Lib::compute_variance( (variance1!=nil && variance1[k]!=nil) ? variance1[k] : 0, weight1+1, value[k], value1[k], value2[k] )
            else
              value[k] = value1[k] + value2[k]
            end
          end        
        else
          raise "invalid, cannot avg/sum non-numeric content for attribute: "+attribute.to_s+" contents: '"+value1.to_s+"', '"+value2.to_s+"'"
        end
      elsif non_numeric_attribute?(object_class, attribute)
        if (value1.is_a?(Hash) and value2.is_a?(Hash))
          value = {}
          value1.keys.each do |k|
            if merge_attribute?(object_class, k)
              m = merge_value( object_class, k, value1[k], value2[k], weight1, (variance1!=nil ? variance1[k] : nil) )
              value[k] = m[:value]
              value[variance_symbol(k)] = m[:variance] if m[:variance] 
            end
          end
        elsif value1.is_a?(Array)
          raise "non-numerical arrays not yet supported"
        else
          if value1==nil && value2==nil
            value = nil
          elsif value1.to_s != value2.to_s
            value = value1.to_s + "/" + value2.to_s
          else
            value = value2.to_s
          end
        end
      else
        raise "invalid type '"+attribute.to_s+"'"
      end
      {:value => value, :variance => variance }
    end 
    
    def self.merge_count( object )
      @@merge_count[object] = 1 if @@merge_count[object]==nil
      return @@merge_count[object] 
    end
    
    def self.set_merge_count(object, merge_count)
      @@merge_count[object] = merge_count
    end
    
    def self.avg_attribute?(object_class, attribute)
      return @@avg_attributes[object_class].index(attribute) != nil
    end
    
    def self.sum_attribute?(object_class, attribute)
      return @@sum_attributes[object_class].index(attribute) != nil
    end
    
    def self.non_numeric_attribute?(object_class, attribute)
      return @@non_numeric_attributes[object_class].index(attribute) != nil
    end
    
    def self.merge_attribute?(object_class, attribute)
      return avg_attribute?(object_class, attribute)|| 
        sum_attribute?(object_class, attribute) || 
        non_numeric_attribute?(object_class,attribute)
    end
    
    def self.variance_symbol(attribute)
      return (attribute.to_s+"_variance").to_sym
    end
    
    def self.variance_attribute?(object, attribute)
      return false unless avg_attribute?(object.class, attribute)    
      begin
        return object.respond_to?( variance_symbol(attribute) )
      rescue
        return false
      end
    end
  end
  
  class MergeTest
    
    attr_accessor :string, :integer, :float, :hash_value, :float, :float_array, :float_variance, :float_array_variance, :is_nil 
    
    AVG = [:float, :float_array, :int_key ] 
    SUM = [:integer ]
    ELSE = [:string, :hash_value, :is_nil]
    
    def to_s
      res = [:is_nil, :string, :integer, :float, :hash_value, :float_array].collect do |var|
         variance = nil
         begin
            variance = "+-"+send((var.to_s+"_variance")).inspect if AVG.index(var)!=nil
         rescue
         end
         var.to_s+":"+send(var).inspect+variance.to_s
      end
      res.join(" ")
    end
    
    def self.demo
      to_merge = []
      p = MergeTest.new
      p.string = "asdf"
      p.integer = 39
      p.float = 78.6
      p.float_array = [1, 2]
      p.hash_value = {:mixed_key=>80, :string_key=>"tu", :int_key=>70}
      to_merge << p
      
      p = MergeTest.new
      p.string = "jkl"
      p.integer = 25
      p.float = 35.6
      p.float_array = [1, 3]
      p.hash_value = {:mixed_key=>"bla", :string_key=>"iu", :int_key=>34}
      to_merge << p
      
      p = MergeTest.new
      p.string = "qwert"
      p.integer = 100
      p.float = 100
      p.float_array = [2, 3]
      p.hash_value = {:mixed_key=>45, :string_key=>"op", :int_key=>20}
      to_merge << p
      
      puts "single:\n"+to_merge.collect{|t| t.to_s+"\n"}.to_s+"\n"
      
      MergeObjects.register_merge_attributes(to_merge[0].class, AVG, SUM, ELSE)
      puts "merged:\n"+MergeObjects.merge_array_objects(to_merge).to_s    
    end
    
  end
end

#Lib::MergeTest.demo

