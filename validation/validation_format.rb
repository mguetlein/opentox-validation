
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
      
      LOGGER.debug self.validation_uri
      
      h = {}
      Lib::VAL_PROPS.each{|p| h[p] = self.send(p)}
      if crossvalidation_id!=nil
        cv = {}
        Lib::VAL_CV_PROPS.each do |p|
          cv[p] = self.send(p)
        end
        # replace crossvalidation id with uri
        h[:crossvalidation_info] = cv
      end
      if classification_statistics 
        clazz = {}
        Lib::VAL_CLASS_PROPS_SINGLE.each{ |p| clazz[p] = classification_statistics[p] }
        
        # transpose results per class
        class_values = {}
        Lib::VAL_CLASS_PROPS_PER_CLASS.each do |p|
          $sinatra.halt 500, "missing classification statitstics: "+p.to_s+" "+classification_statistics.inspect unless classification_statistics[p]
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
    
    def rdf_title
      "Validation"
    end
    
    def uri
      validation_uri
    end
    
    LITERALS = [ :created_at, :real_runtime, :num_instances, :num_without_class,
                   :percent_without_class, :num_unpredicted, :percent_unpredicted, 
                   :crossvalidation_fold, #:crossvalidation_id, 
                   :num_correct, :num_incorrect, :percent_correct, :percent_incorrect,
                   :area_under_roc, :false_negative_rate, :false_positive_rate,
                   :f_measure, :num_false_positives, :num_false_negatives, 
                   :num_true_positives, :num_true_negatives, :precision, 
                   :recall, :true_negative_rate, :true_positive_rate,
                   :confusion_matrix_value, :weighted_area_under_roc, 
                   :target_variance_actual, :root_mean_squared_error,
                   :target_variance_predicted, :mean_absolute_error, :r_square, :class_value,
                   :confusion_matrix_actual, :confusion_matrix_predicted ]
                   
    LITERAL_NAMES = {:created_at => OT["date"] }
                
    OBJECT_PROPERTIES = { :model_uri => OT['validationModel'], :training_dataset_uri => OT['validationTrainingDataset'], :algorithm_uri => OT['validationAlgorithm'],
                     :prediction_feature => OT['predictedFeature'], :test_dataset_uri => OT['validationTestDataset'], :test_target_dataset_uri => OT['validationTestTargetDataset'],
                     :prediction_dataset_uri => OT['validationPredictionDataset'], :crossvalidation_info => OT['hasValidationInfo'],
                     :crossvalidation_uri =>  OT['validationCrossvalidation'],
                     :classification_statistics => OT['hasValidationInfo'], :regression_statistics => OT['hasValidationInfo'],
                     :class_value_statistics => OT['classValueStatistics'], :confusion_matrix => OT['confusionMatrix'],
                     :confusion_matrix_cell => OT['confusionMatrixCell'], #:class_value => OT['classValue'], 
                     #:confusion_matrix_actual => OT['confusionMatrixActual'], :confusion_matrix_predicted => OT['confusionMatrixPredicted']
                      } 

    OBJECTS = { :model_uri => OT['Model'], :training_dataset_uri => OT['Dataset'], :test_dataset_uri => OT['Dataset'], 
                :test_target_dataset_uri => OT['Dataset'], :prediction_dataset_uri => OT['Dataset'], :prediction_feature => OT['Feature'],
                :algorithm_uri => OT['Algorithm'],}
                     
    CLASSES = { :crossvalidation_info => OT['CrossvalidationInfo'], :classification_statistics => OT['ClassificationStatistics'],
                  :regression_statistics => OT['RegresssionStatistics'], :class_value_statistics => OT['ClassValueStatistics'],
                 :confusion_matrix => OT['ConfusionMatrix'], :confusion_matrix_cell => OT['ConfusionMatrixCell']}  
    
    IGNORE = [ :id, :validation_uri, :crossvalidation_id ]
    
  end
    
  class Crossvalidation < Lib::Crossvalidation
    include Lib::RDFProvider
    
    def get_content_as_hash
      h = {}
      Lib::CROSS_VAL_PROPS_REDUNDANT.each{|p| h[p] = self.send(p)}
      
      v = []
      Validation.find( :all, :conditions => { :crossvalidation_id => self.id } ).each do |val|
        v.push( val.validation_uri.to_s )
      end
      h[:validations] = v
      h
    end

    def uri
      crossvalidation_uri
    end
    
    def rdf_title
      "Crossvalidation"
    end
    
    LITERALS = [ :created_at, :stratified, :num_folds, :random_seed ]
    
    LITERAL_NAMES = {:created_at => OT["date"] }
    
    OBJECT_PROPERTIES = { :dataset_uri => OT['crossvalidationDataset'], :algorithm_uri => OT['crossvalidationAlgorithm'],
                           :validations => OT['crossvalidationValidation'] } 
                           
    OBJECTS = { :dataset_uri => OT['Dataset'], :validations => OT['Validation'], :algorithm_uri => OT['Algorithm']}
    
    CLASSES = {}
    
    IGNORE = [ :id, :crossvalidation_uri ]
  end
end
