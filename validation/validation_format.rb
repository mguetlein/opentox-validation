
# adding to_yaml and to_rdf functionality to validation
class Validation < Lib::Validation

  # get_content is the basis for to_yaml and to_rdf
  # the idea is that everything is stored in a hash structure
  # the hash is directly printed in to_yaml, while the has_keys can be used to resolve 
  # the right properties, classes
  def get_content
    
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
        classification_statistics[p].each do |class_value, property_value|
          class_values[class_value] = {:class_value => class_value} unless class_values.has_key?(class_value)
          map = class_values[class_value]
          map[p] = property_value
        end
      end
      clazz[:class_value_statistics] = class_values.values
      
      #converting confusion matrix
      cells = []
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
  
  def to_yaml
    get_content.to_yaml
  end
  
  def to_rdf
    owl = ValidationOwl.new()
    owl.title = "Validation"
    owl.uri = uri
    owl.add_content( ValidationToRDF.new, get_content, "Validation" )
    owl.rdf
  end
 end
  
class Crossvalidation < Lib::Crossvalidation
  
  def get_content
    h = {}
    Lib::CROSS_VAL_PROPS.each{|p| h[p] = self.send(p)}
    
    v = []
    Validation.all(:crossvalidation_id => self.id).each do |val|
      v.push({ :validation_uri => val.uri.to_s })
    end
    h[:validations] = v
    h
  end
  
  def to_yaml
    get_content.to_yaml
  end
  
  def to_rdf
    owl = ValidationOwl.new()
    owl.title = "Crossvalidation"
    owl.uri = uri
    owl.add_content( CrossvalidationToRDF.new, get_content, "Crossvalidation" )
    owl.rdf
  end
  
end
  

class ValidationOwl
  include OpenTox::Owl
 
  def initialize
    super
  end 
  
  def add_content( content_to_rdf, output, clazz ) 
    @content_to_rdf = content_to_rdf
    recursiv_add_content( output, @model.subject(RDF['type'],OT[clazz]) )
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
      elsif @content_to_rdf.literal?(k)
        set_literal( k, v, node)
      elsif @content_to_rdf.object_property?(k)
        add_object_property( k, v, node)
      elsif [ :uri, :id, :finished ].index(k)!=nil
        #skip
      else
        raise "illegal value k:"+k.to_s+" v:"+v.to_s
      end
    end
  end

  def add_class( property, node )
    raise "no object prop: "+property.to_s unless @content_to_rdf.object_property?(property)
    raise "no class name: "+property.to_s unless @content_to_rdf.class_name(property) 
    res = @model.create_resource
    @model.add res, RDF['type'], @content_to_rdf.class_name(property)
    @model.add res, DC['title'], @content_to_rdf.class_name(property)
    @model.add node, @content_to_rdf.object_property_name(property), res
    return res
  end
  
  def set_literal(property, value, node )
    raise "empty literal value "+property.to_s if value==nil || value.to_s.size==0
    raise "no literal name "+propety.to_s unless @content_to_rdf.literal_name(property)
    begin
      l = @model.object(subject, @content_to_rdf.literal_name(property))
      @model.delete node, @content_to_rdf.literal_name(property), l
    rescue
    end
    @model.add node, @content_to_rdf.literal_name(property), value.to_s
  end
  
  def add_object_property(property, value, node )
    raise "empty object property value "+property.to_s if value==nil || value.to_s.size==0
    raise "no object property name "+propety.to_s unless @content_to_rdf.object_property_name(property)
    @model.add node, @content_to_rdf.object_property_name(property), Redland::Uri.new(value) # untyped individual comes from this line, why??
    #@model.add Redland::Uri.new(value), RDF['type'], type
  end
  
end


class ContentToRDF
  
  def literal?( prop )
    @literals.index( prop ) != nil
  end
  
  def literal_name( prop )
    #PENDING
    return OT[prop.to_s]
  end
  
  def object_property?( prop )
    @object_properties.has_key?( prop )
  end
  
  def object_property_name( prop )
    return @object_properties[ prop ]
  end

  def class_name( prop )
    return @classes[ prop ]
  end
  
end


class CrossvalidationToRDF < ContentToRDF
  
  def initialize()
    @literals = [ :stratified, :num_folds, :random_seed ]
    @object_properties = { :dataset_uri => OT['crossvalidationDataset'], :algorithm_uri => OT['crossvalidationAlgorithm'],
                           :validation_uri => OT['crossvalidationValidation'], :validations => OT['crossvalidationValidations'] } 
    @classes = { :validations => OT['CrossvalidationValidations'] }
  end
end

class ValidationToRDF < ContentToRDF

  def initialize()
    @literals = [ :created_at, :real_runtime, :num_instances, :num_without_class,
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
                 
                 
    @object_properties = { :model_uri => OT['validationModel'], :training_dataset_uri => OT['validationTrainingDataset'], 
                     :prediction_feature => OT['predictedFeature'], :test_dataset_uri => OT['validationTestDataset'], 
                     :prediction_dataset_uri => OT['validationPredictionDataset'], :crossvalidation_info => OT['hasValidationInfo'],
                     :classification_statistics => OT['hasValidationInfo'],
                     :class_value_statistics => OT['classValueStatistics'], :confusion_matrix => OT['confusionMatrix'],
                     :confusion_matrix_cell => OT['confusionMatrixCell'], :class_value => OT['class_value'], 
                     :confusion_matrix_actual => OT['confusionMatrixActual'], :confusion_matrix_predicted => OT['confusionMatrixPredicted'] } 
                     
    @classes = { :crossvalidation_info => OT['CrossvalidationInfo'], :classification_statistics => OT['ClassificationStatistics'],
                 :class_value_statistics => OT['ClassValueStatistics'],
                 :confusion_matrix => OT['ConfusionMatrix'], :confusion_matrix_cell => OT['ConfusionMatrixCell']}  
  end

end
