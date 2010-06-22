
class String
  def convert_underscore
    gsub(/_./) do |m|
      m.gsub!(/^_/,"")
      m.upcase
    end
  end
end

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
    
    def to_yaml
      get_content_as_hash.to_yaml
    end
    
    def rdf_ignore?( prop )
      self.class::IGNORE.index( prop ) != nil
    end
    
    def literal?( prop )
      self.class::LITERALS.index( prop ) != nil
    end
    
    def literal_name( prop )
      if self.class::LITERAL_NAMES.has_key?(prop)
        self.class::LITERAL_NAMES[prop]
      else
        OT[prop.to_s.convert_underscore]
      end
    end
    
    def object_property?( prop )
      self.class::OBJECT_PROPERTIES.has_key?( prop )
    end
    
    def object_property_name( prop )
      return self.class::OBJECT_PROPERTIES[ prop ]
    end
    
    def object_type( prop )
      return self.class::OBJECTS[ prop ]
    end
  
    def class?(prop)
      self.class::CLASSES.has_key?( prop )
    end
    
    def class_name( prop )
      return self.class::CLASSES[ prop ]
    end
    
  end
  
  class HashToOwl
    #include OpenTox::Owl
    
    def self.to_rdf( rdf_provider )
      
      owl = OpenTox::Owl.create(rdf_provider.rdf_title, rdf_provider.uri )
      toOwl = HashToOwl.new(owl)
      toOwl.add_content(rdf_provider)
      toOwl.rdf
    end
  
    def add_content( rdf_provider ) 
      @rdf_provider = rdf_provider
      recursiv_add_content( @rdf_provider.get_content_as_hash, @owl.root_node )
    end
    
    def rdf
      @owl.rdf
    end
    
    private
    def initialize(owl)
      @owl = owl
      @model = owl.model
    end
    
    def recursiv_add_content( output, node )
      output.each do |k,v|
        if v==nil
          LOGGER.warn "skipping nil value: "+k.to_s
          next
        end
        if @rdf_provider.rdf_ignore?(k)
          #do nothing
        elsif v.is_a?(Hash)
          new_node = add_class( k, node )
          recursiv_add_content( v, new_node )
        elsif v.is_a?(Array)
          v.each do |value|
            if @rdf_provider.class?(k)
              new_node = add_class( k, node )
              recursiv_add_content( value, new_node )
            else
              add_object_property( k, value, node)
            end
          end
        elsif @rdf_provider.literal?(k)
          set_literal( k, v, node)
        elsif @rdf_provider.object_property?(k)
          add_object_property( k, v, node)
        else
          raise "illegal value k:"+k.to_s+" v:"+v.to_s
        end
      end
    end
  
    def add_class( property, node )
      raise "no object prop: "+property.to_s unless @rdf_provider.object_property?(property)
      raise "no class name: "+property.to_s unless @rdf_provider.class_name(property)
      # to avoid anonymous nodes, make up uris for sub-objects
      # use counter to make sure each uri is unique
      # for example we will get ../confusion_matrix_cell/1, ../confusion_matrix_cell/2, ...
      count = 1
      while (true)
        res = Redland::Resource.new( File.join(node.uri.to_s,property.to_s+"/"+count.to_s) )  
        break if @model.subject(@rdf_provider.object_property_name(property), res).nil?
        count += 1
      end
      clazz = Redland::Resource.new(@rdf_provider.class_name(property))
      @model.add res, RDF['type'], clazz
      @model.add res, DC['title'], clazz
      @model.add clazz, RDF['type'], OWL['Class']
      @model.add DC['title'], RDF['type'],OWL['AnnotationProperty']
      
      objectProp = Redland::Resource.new(@rdf_provider.object_property_name(property))
      @model.add objectProp, RDF['type'], OWL['ObjectProperty']
      @model.add node, objectProp, res
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
      literalProp =  Redland::Resource.new(@rdf_provider.literal_name(property))
      @model.add literalProp, RDF['type'],OWL['AnnotationProperty']
      @model.add node, literalProp, Redland::Literal.create(value)
    end
    
    def add_object_property(property, value, node )
      raise "empty object property value "+property.to_s if value==nil || value.to_s.size==0
      raise "no object property name "+propety.to_s unless @rdf_provider.object_property_name(property)
      raise "no object type "+property.to_s unless @rdf_provider.object_type(property)
      
      objectProp = Redland::Resource.new(@rdf_provider.object_property_name(property))
      @model.add objectProp, RDF['type'], OWL['ObjectProperty']
      
      val = Redland::Resource.new(value)
      type = Redland::Resource.new(@rdf_provider.object_type(property))
      @model.add node, objectProp, val
      @model.add val, RDF['type'], type
      @model.add type, RDF['type'], OWL['Class']
    end
    
  end
end
