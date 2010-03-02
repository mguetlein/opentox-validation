
$merge_count = {}

class Array
  def merge_array( merge_attributes, equal_attributes=nil )
    return nil if self.size == nil
    return self[0] if self.size==1
      
    m = self[0].merge_object(self[1], merge_attributes, equal_attributes)
    (2..self.size-1).each do |i|
      m = m.merge_object(self[i], merge_attributes, equal_attributes)
    end
    return m
  end
end

class Object
  
  def merge_count()
    $merge_count[self] = 1 if $merge_count[self]==nil
    return $merge_count[self] 
  end
  
  def set_merge_count(merge_count)
    $merge_count[self] = merge_count
  end
  
  def self.compute_variance( old_variance, n, new_mean, old_mean, new_value )
    # use revursiv formular for computing the variance
    # ( see Tysiak, Folgen: explizit und rekursiv, ISSN: 0025-5866
    #  http://www.frl.de/tysiakpapers/07_TY_Papers.pdf )
    return (n>1 ? old_variance * (n-2)/(n-1) : 0) +
           (new_mean - old_mean)**2 +
           (n>1 ? (new_value - new_mean)**2/(n-1) : 0 )
  end
    
  def self.merge_value( value1, weight1, compute_variance, variance1, value2 )
    
    if value1.is_a?(Numeric) and value2.is_a?(Numeric)
      value = (value1 * weight1 + value2) / (weight1 + 1).to_f;
      if compute_variance
        variance = compute_variance( variance1!=nil ? variance1 : 0, weight1+1, value, value1, value2 )
      end
    elsif value1.is_a?(Array) and value2.is_a?(Array)
      raise "cannot merge arrays with unequal sizes" if !value2.is_a?(Array) || value1.size!=value2.size
      value = []
      variance = []
      (0..value1.size-1).each do |i|
        m = merge_value( value1[i], weight1, compute_variance, variance1==nil ? nil : variance1[i], value2[i] )
        value[i] = m[:value]
        variance[i] = m[:variance] if compute_variance
      end
    elsif value1.is_a?(Hash) and value2.is_a?(Hash)
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
  
  def merge_object( object, merge_attributes, equal_attributes=nil )

    raise "classes not equal" if object.class != self.class
    raise "not supported, successivly add unmerged object to a merge object" if object.merge_count>1
    
    new_object = self.class.new
    merge_attributes.each do |variable|
      next if variable.to_s =~ /_variance$/
      
      if (equal_attributes and equal_attributes.index(variable) != nil)
        new_object.send("#{variable.to_s}=".to_sym, send(variable))
      else
        compute_variance = self.respond_to?( (variable.to_s+"_variance").to_sym ) #VAL_ATTR_VARIANCE.index(a)!=nil
        old_variance = compute_variance ? send((variable.to_s+"_variance").to_sym) : nil 
        m = Object::merge_value( send(variable), self.merge_count, compute_variance, old_variance, object.send(variable) )
        new_object.send("#{variable.to_s}=".to_sym, m[:value])
        new_object.send("#{variable.to_s}_variance=".to_sym, m[:variance]) if compute_variance
      end
    end

    new_object.set_merge_count self.merge_count+1
    return new_object
  end 
  
end

class MergeTest
  
  attr_accessor :string, :integer, :float, :hash_value, :float_variance 
 
  def to_s
    res = [:string, :integer, :float, :hash_value].collect do |var|
       variance = nil
       variance = "+-"+send((var.to_s+"_variance")).inspect if self.respond_to?( (var.to_s+"_variance").to_sym )
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
    p.hash_value = {:mixed_key=>80, :string_key=>"tu", :int_key=>70}
    to_merge << p
    
    p = MergeTest.new
    p.string = "jkl"
    p.integer = 25
    p.float = 35.6
    p.hash_value = {:mixed_key=>"bla", :string_key=>"iu", :int_key=>34}
    to_merge << p
    
    p = MergeTest.new
    p.string = "qwert"
    p.integer = 100
    p.float = 100
    p.hash_value = {:mixed_key=>45, :string_key=>"op", :int_key=>20}
    to_merge << p
    
    puts "merged: "+to_merge.merge_array([:string, :integer, :float, :hash_value]).to_s    
  end
  
end

#MergeTest.demo


