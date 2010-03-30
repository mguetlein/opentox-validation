
require "lib/rdf_provider.rb"

module Validation
  
  
  # adding to_yaml and to_rdf functionality to validation
  class Validation < Lib::Validation
    include Lib::RDFProvider
  
    # get_content_as_hash is the basis for to_yaml and to_rdf
    # the idea is that everything is stored in a hash structure
    # the hash is directly printed in to_yaml, whereas the has_keys can be used to resolve 
    # the right properties, classes for to_rdf
    def get_content_as_hash
      
      h = {}
      Lib::VAL_PROPS.each{|p| h[p] = self.send(p)}
      if crossvalidation_id!=nil
        cv = {}
        Lib::VAL_CV_PROPS.each do |p|
          cv[p] = self.send(p)
        end
        h[:crossvalidation_info] = cv
      end
      if classification_statistics 
        clazz = {}
        Lib::VAL_CLASS_PROPS_SINGLE.each{ |p| clazz[p] = classification_statistics[p] }
        
        # transpose results per class
        class_values = {}
        Lib::VAL_CLASS_PROPS_PER_CLASS.each do |p|
          raise "missing classification statitstics: "+p.to_s+" "+classification_statistics.inspect unless classification_statistics[p]
          classification_statistics[p].each do |class_value, property_value|
            class_values[class_value] = {:class_value => class_value} unless class_values.has_key?(class_value)
            map = class_values[class_value]
            map[p] = property_value
          end
        end
        clazz[:class_value_statistics] = class_values.values
        
        #converting confusion matrix
        cells = []
        raise "confusion matrix missing" unless classification_statistics[:confusion_matrix]!=nil
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
    
    # build hash structure and return with to_yaml
    def to_yaml
      get_content_as_hash.to_yaml
      #super.to_yaml
    end
    
    def rdf_title
      "Validation"
    end
    
    def uri
      @uri
    end
    
    @@literals = [ :created_at, :real_runtime, :num_instances, :num_without_class,
                   :percent_without_class, :num_unpredicted, :percent_unpredicted, 
                   :crossvalidation_fold, :crossvalidation_id,
                   :num_correct, :num_incorrect, :percent_correct, :percent_incorrect,
                   :area_under_roc, :false_negative_rate, :false_positive_rate,
                   :f_measure, :num_false_positives, :num_false_negatives, 
                   :num_true_positives, :num_true_negatives, :precision, 
                   :recall, :true_negative_rate, :true_positive_rate,
                   :confusion_matrix_value ]
    # created at -> date
    #      owl.set_literal(OT['numInstances'],validation.num_instances)
    #      owl.set_literal(OT['numWithoutClass'],validation.num_without_class)
    #      owl.set_literal(OT['percentWithoutClass'],validation.percent_without_class)
    #      owl.set_literal(OT['numUnpredicted'],validation.num_unpredicted)
    #      owl.set_literal(OT['percentUnpredicted'],validation.percent_unpredicted)
                 
                 
    @@object_properties = { :model_uri => OT['validationModel'], :training_dataset_uri => OT['validationTrainingDataset'], 
                     :prediction_feature => OT['predictedFeature'], :test_dataset_uri => OT['validationTestDataset'], 
                     :prediction_dataset_uri => OT['validationPredictionDataset'], :crossvalidation_info => OT['hasValidationInfo'],
                     :classification_statistics => OT['hasValidationInfo'],
                     :class_value_statistics => OT['classValueStatistics'], :confusion_matrix => OT['confusionMatrix'],
                     :confusion_matrix_cell => OT['confusionMatrixCell'], :class_value => OT['class_value'], 
                     :confusion_matrix_actual => OT['confusionMatrixActual'], :confusion_matrix_predicted => OT['confusionMatrixPredicted'] } 
                     
    @@classes = { :crossvalidation_info => OT['CrossvalidationInfo'], :classification_statistics => OT['ClassificationStatistics'],
                 :class_value_statistics => OT['ClassValueStatistics'],
                 :confusion_matrix => OT['ConfusionMatrix'], :confusion_matrix_cell => OT['ConfusionMatrixCell']}  
    
    def literal?( prop )
      @@literals.index( prop ) != nil
    end
    
    def literal_name( prop )
      #PENDING
      return OT[prop.to_s]
    end
    
    def object_property?( prop )
      @@object_properties.has_key?( prop )
    end
    
    def object_property_name( prop )
      return @@object_properties[ prop ]
    end
  
    def class_name( prop )
      return @@classes[ prop ]
    end
    
  end
    
  class Crossvalidation < Lib::Crossvalidation
    include Lib::RDFProvider
    
    def get_content_as_hash
      h = {}
      Lib::CROSS_VAL_PROPS_REDUNDANT.each{|p| h[p] = self.send(p)}
      
      v = []
      Validation.all(:crossvalidation_id => self.id).each do |val|
        v.push({ :validation_uri => val.uri.to_s })
      end
      h[:validations] = v
      h
    end
    
    def to_yaml
      get_content_as_hash.to_yaml
    end
    
    def rdf_title
      "Crossvalidation"
    end
    
    def uri
      @uri
    end
    
    @@literals = [ :stratified, :num_folds, :random_seed ]
    @@object_properties = { :dataset_uri => OT['crossvalidationDataset'], :algorithm_uri => OT['crossvalidationAlgorithm'],
                           :validation_uri => OT['crossvalidationValidation'], :validations => OT['crossvalidationValidations'] } 
    @@classes = { :validations => OT['CrossvalidationValidations'] }
    
    def literal?( prop )
      @@literals.index( prop ) != nil
    end
    
    def literal_name( prop )
      #PENDING
      return OT[prop.to_s]
    end
    
    def object_property?( prop )
      @@object_properties.has_key?( prop )
    end
    
    def object_property_name( prop )
      return @@object_properties[ prop ]
    end
  
    def class_name( prop )
      return @@classes[ prop ]
    end
  end
end
