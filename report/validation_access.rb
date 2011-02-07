require "lib/validation_db.rb"

# = Reports::ValidationDB
# 
# connects directly to the validation db, overwirte with restclient calls 
# if reports/reach reports are seperated from validation someday
#  
class Reports::ValidationDB
  
  def resolve_cv_uris(validation_uris, subjectid=nil)
    res = []
    validation_uris.each do |u|
      if u.to_s =~ /.*\/crossvalidation\/[0-9]+/
        cv_id = u.split("/")[-1].to_i
        cv = nil
        
        raise OpenTox::NotAuthorizedError.new "Not authorized: GET "+u.to_s if
          AA_SERVER and !OpenTox::Authorization.authorized?(u,"GET",subjectid)
#        begin
#          #cv = Lib::Crossvalidation.find( cv_id )
#        rescue => ex
#          raise "could not access crossvalidation with id "+validation_id.to_s+", error-msg: "+ex.message
#        end
        cv = Lib::Crossvalidation.get( cv_id )
        raise OpenTox::NotFoundError.new "crossvalidation with id "+cv_id.to_s+" not found" unless cv
        raise OpenTox::BadRequestError.new("crossvalidation with id '"+cv_id.to_s+"' not finished") unless cv.finished
        #res += Lib::Validation.find( :all, :conditions => { :crossvalidation_id => cv_id } ).collect{|v| v.validation_uri.to_s}
        res += Lib::Validation.all( :crossvalidation_id => cv_id ).collect{|v| v.validation_uri.to_s }
      else
        res += [u.to_s]
      end
    end
    res
  end
  
  def init_validation(validation, uri, subjectid=nil)
  
    raise OpenTox::BadRequestError.new "not a validation uri: "+uri.to_s unless uri =~ /.*\/[0-9]+/
    validation_id = uri.split("/")[-1]
    raise OpenTox::BadRequestError.new "invalid validation id "+validation_id.to_s unless validation_id!=nil and 
      (validation_id.to_i > 0 || validation_id.to_s=="0" )
    v = nil
    raise OpenTox::NotAuthorizedError.new "Not authorized: GET "+uri.to_s if
      AA_SERVER and !OpenTox::Authorization.authorized?(uri,"GET",subjectid)
    v = Lib::Validation.get(validation_id)
    raise OpenTox::NotFoundError.new "validation with id "+validation_id.to_s+" not found" unless v
    raise OpenTox::BadRequestError.new "validation with id "+validation_id.to_s+" is not finished yet" unless v.finished
    
    (Lib::VAL_PROPS + Lib::VAL_CV_PROPS).each do |p|
      validation.send("#{p.to_s}=".to_sym, v.send(p))
    end
    
    {:classification_statistics => Lib::VAL_CLASS_PROPS, 
     :regression_statistics => Lib::VAL_REGR_PROPS}.each do |subset_name,subset_props|
      subset = v.send(subset_name)
      subset_props.each{ |prop| validation.send("#{prop.to_s}=".to_sym, subset[prop]) } if subset
    end
  end
    
  def init_cv(validation)
    
    #cv = Lib::Crossvalidation.find(validation.crossvalidation_id)
    cv = Lib::Crossvalidation.get(validation.crossvalidation_id)
    raise OpenTox::BadRequestError.new "no crossvalidation found with id "+validation.crossvalidation_id.to_s unless cv
    
    Lib::CROSS_VAL_PROPS.each do |p|
      validation.send("#{p.to_s}=".to_sym, cv[p])        
    end
  end

  def get_predictions(validation, subjectid=nil, task=nil)
    Lib::OTPredictions.new( validation.feature_type, validation.test_dataset_uri, 
      validation.test_target_dataset_uri, validation.prediction_feature, validation.prediction_dataset_uri, 
      validation.predicted_variable, subjectid, task)
  end
  
  def get_class_domain( validation )
    OpenTox::Feature.new( validation.prediction_feature ).domain
  end
  
  def feature_type( validation, subjectid=nil )
    OpenTox::Model::Generic.new(validation.model_uri).feature_type(subjectid)
    #get_model(validation).classification?
  end
  
  def predicted_variable(validation, subjectid=nil)
    raise "cannot derive model depended props for merged validations" if Lib::MergeObjects.merged?(validation)
    model = OpenTox::Model::Generic.find(validation.model_uri, subjectid)
    raise OpenTox::NotFoundError.new "model not found '"+validation.model_uri+"'" unless model
    model.metadata[OT.predictedVariables]
    #get_model(validation).predictedVariables
  end
  
#  private
#  def get_model(validation)
#    raise "cannot derive model depended props for merged validations" if Lib::MergeObjects.merged?(validation)
#    model = @model_store[validation.model_uri]
#    unless model
#      model = OpenTox::Model::PredictionModel.find(validation.model_uri)
#      raise "model not found '"+validation.model_uri+"'" unless validation.model_uri && model
#      @model_store[validation.model_uri] = model
#    end
#    return model
#  end
  
end
