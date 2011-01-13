
require "lib/format_util.rb"

module Validation
  
  # adding to_yaml and to_rdf functionality to validation
  class Validation < Lib::Validation
  
    # builds hash for valiation, as the internal presentation differs from the owl-object
    # the hash is directly printed in to_yaml, or added to the owl-structure
    def get_content_as_hash()
      
      LOGGER.debug self.validation_uri
      
      h = {}
      (Lib::VAL_PROPS - [:validation_uri]).each do |p|
         h[p] = self.send(p)
      end
      if crossvalidation_id!=nil
        cv = {}
        #skip crossvalidation_id
        cv[:crossvalidation_fold] = self.crossvalidation_fold
        cv[:crossvalidation_uri] = self.crossvalidation_uri
        h[:crossvalidation_info] = cv
      end
      if classification_statistics 
        raise "classification_statistics is no has: "+classification_statistics.class.to_s unless classification_statistics.is_a?(Hash)
        clazz = {}
        Lib::VAL_CLASS_PROPS_SINGLE.each{ |p| clazz[p] = classification_statistics[p] }
        
        # transpose results per class
        class_values = {}
        Lib::VAL_CLASS_PROPS_PER_CLASS.each do |p|
          $sinatra.halt 500, "missing classification statitstics: "+p.to_s+" "+classification_statistics.inspect if classification_statistics[p]==nil
          classification_statistics[p].each do |class_value, property_value|
            class_values[class_value] = {:class_value => class_value} unless class_values.has_key?(class_value)
            map = class_values[class_value]
            map[p] = property_value
          end
        end
        clazz[:class_value_statistics] = class_values.values
        
        #converting confusion matrix
        cells = []
        $sinatra.halt 500,"confusion matrix missing" unless classification_statistics[:confusion_matrix]!=nil
        classification_statistics[:confusion_matrix].each do |k,v|
          cell = {}
          # key in confusion matrix is map with predicted and actual attribute 
          k.each{ |kk,vv| cell[kk] = vv }
          cell[:confusion_matrix_value] = v
          cells.push cell
        end
        cm = { :confusion_matrix_cell => cells }
        clazz[:confusion_matrix] = cm
        
        h[:classification_statistics] = clazz
      elsif regression_statistics
        regr = {}
        Lib::VAL_REGR_PROPS.each{ |p| regr[p] = regression_statistics[p]}
        h[:regression_statistics] = regr
      end
      return h  
    end
    
    def to_rdf
      owl = OpenTox::Owl.create("Validation",validation_uri)
      owl.set_data(get_content_as_hash.keys_to_rdf_format)
      owl.rdf
    end
    
    def to_yaml
      get_content_as_hash.to_yaml
    end
    
  end
    
  class Crossvalidation < Lib::Crossvalidation
  
    def get_content_as_hash
      h = {}
      
      (Lib::CROSS_VAL_PROPS_REDUNDANT - [:crossvalidation_uri]).each do |p|
        h[p] = self.send(p)
      end
      v = []
      #Validation.find( :all, :conditions => { :crossvalidation_id => self.id } ).each do |val|
      Validation.all( :crossvalidation_id => self.id ).each do |val|
        v.push( val.validation_uri.to_s )
      end
      h[:validation_uris] = v
      h
    end

    def to_rdf
      owl = OpenTox::Owl.create("'Crossvalidation",crossvalidation_uri)
      owl.set_data(get_content_as_hash.keys_to_rdf_format)
      owl.rdf
    end
    
    def to_yaml
      get_content_as_hash.to_yaml
    end
  end
end
