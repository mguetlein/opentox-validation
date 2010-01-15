
module Lib
  module RDFProvider
    
    def to_rdf
      HashToOwl.to_rdf(self)
    end
    
    def uri
      raise "not implemented"
    end
    
    def rdf_title
      raise "not implemented"
    end
    
    # the rdf output is generated from the hash that is provided by this method
    # the keys in the hash structure are used to defined type of the resource (literal, objectProperty, dataProperty)
    # example: if the structure should contain a literal named "size" with value 5
    # * add :property_xy => 5 to your hash
    # * make sure literal?(:property_xy) returns true
    # * literal_name(:property_xy) must return "size"
    #
    def get_content_as_hash
      raise "not implemented"
    end
    
    def literal?( property )
      raise "not yet implemented"
    end
    
    def literal_name( property )
      raise "not yet implemented"
    end
    
    def object_property?( property )
      raise "not yet implemented"
    end
    
    def object_property_name( property )
      raise "not yet implemented"
    end
  
    def class_name( property )
      raise "not yet implemented"
    end
  end
  
  class HashToOwl
    include OpenTox::Owl
    
    def self.to_rdf( rdf_provider )
      owl = HashToOwl.new()
      owl.title = rdf_provider.rdf_title
      owl.uri = rdf_provider.uri
      owl.add_content( rdf_provider )
      owl.rdf
    end
  
    def add_content( rdf_provider ) 
      @rdf_provider = rdf_provider
      recursiv_add_content( @rdf_provider.get_content_as_hash, @model.subject(RDF['type'],rdf_provider.rdf_title) )
    end
    
    private
    def recursiv_add_content( output, node )
      output.each do |k,v|
        raise "null value: "+k.to_s if v==nil
        if v.is_a?(Hash)
          new_node = add_class( k, node )
          recursiv_add_content( v, new_node )
        elsif v.is_a?(Array)
          v.each do |value|
            new_node = add_class( k, node )
            recursiv_add_content( value, new_node )
          end
        elsif @rdf_provider.literal?(k)
          set_literal( k, v, node)
        elsif @rdf_provider.object_property?(k)
          add_object_property( k, v, node)
        elsif [ :uri, :id, :finished ].index(k)!=nil
          #skip
        else
          raise "illegal value k:"+k.to_s+" v:"+v.to_s
        end
      end
    end
  
    def add_class( property, node )
      raise "no object prop: "+property.to_s unless @rdf_provider.object_property?(property)
      raise "no class name: "+property.to_s unless @rdf_provider.class_name(property) 
      res = @model.create_resource
      @model.add res, RDF['type'], @rdf_provider.class_name(property)
      @model.add res, DC['title'], @rdf_provider.class_name(property)
      @model.add node, @rdf_provider.object_property_name(property), res
      return res
    end
    
    def set_literal(property, value, node )
      raise "empty literal value "+property.to_s if value==nil || value.to_s.size==0
      raise "no literal name "+propety.to_s unless @rdf_provider.literal_name(property)
      begin
        l = @model.object(subject, @rdf_provider.literal_name(property))
        @model.delete node, @rdf_provider.literal_name(property), l
      rescue
      end
      @model.add node, @rdf_provider.literal_name(property), value.to_s
    end
    
    def add_object_property(property, value, node )
      raise "empty object property value "+property.to_s if value==nil || value.to_s.size==0
      raise "no object property name "+propety.to_s unless @rdf_provider.object_property_name(property)
      @model.add node, @rdf_provider.object_property_name(property), Redland::Uri.new(value) # untyped individual comes from this line, why??
      #@model.add Redland::Uri.new(value), RDF['type'], type
    end
    
  end
end
