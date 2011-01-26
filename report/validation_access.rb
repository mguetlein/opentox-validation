require "lib/validation_db.rb"

# = Reports::ValidationAccess
# 
# service that connects (mainly) to the validation-service
#  
class Reports::ValidationAccess

  # initialize Reports::Validation object with data from Lib:Validation object
  #  
  def init_validation(validation, uri, subjectid=nil)
    raise "not implemented"
  end
  
  # sets cv-attributes in Reports::Validation object  
  #
  def init_cv(validation)
    raise "not implemented"
  end
  
  # yields predictions (Lib::OTPredictions) if available 
  #
  def get_predictions(validation, subjectid=nil, task=nil)
    raise "not implemented"
  end
  
  # replaces crossvalidations uris with corresponding validation uris, in-/output: array
  #
  def resolve_cv_uris(validation_uris,subjectid=nil)
    raise "not implemented"
  end
  
  # get domain/class values of prediction feature
  #
  def get_class_domain(validation)
    raise "not implemented"
  end
  
  # is validation classification/regression?
  def feature_type(validation, subjectid=nil)
    raise "not implemented"
  end
  
  def predicted_variable(validation, subjectid=nil)
    raise "not implemented"
  end
  
end

class Reports::ValidationDB < Reports::ValidationAccess
  
#  def initialize()
#    @model_store = {}
#  end
  
  def resolve_cv_uris(validation_uris, subjectid=nil)
    res = []
    validation_uris.each do |u|
      if u.to_s =~ /.*\/crossvalidation\/[0-9]+/
        cv_id = u.split("/")[-1].to_i
        cv = nil
        
        raise OpenTox::NotAuthorizedError.new "Not authorized: GET "+u.to_s if
          subjectid and !OpenTox::Authorization.authorized?(u,"GET",subjectid)
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
      subjectid and !OpenTox::Authorization.authorized?(uri,"GET",subjectid)
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
    raise "subjectid is nil" unless subjectid
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

#
# OUTDATED, please update before use
#
class Reports::ValidationWebservice < Reports::ValidationAccess
  
  def resolve_cv_uris(validation_uris)
    res = []
    validation_uris.each do |u|
      if u.to_s =~ /.*\/crossvalidation\/.*/
        uri = u.to_s+"/validations"
        begin
          vali_uri_list = RestClientWrapper.get uri
        rescue => ex
          raise OpenTox::BadRequestError.new "cannot get validations for cv at '"+uri.to_s+"', error msg: "+ex.message
        end
        res += vali_uri_list.split("\n")
      else
        res += [u.to_s]
      end
    end
    res
  end
  
  
  def init_validation(validation, uri)
  
    begin
      data = YAML.load(RestClient.get uri)
    rescue => ex
      raise OpenTox::BadRequestError.new "cannot get validation at '"+uri.to_s+"', error msg: "+ex.message
    end
  
    Lib::VAL_PROPS.each do |p|
      validation.send("#{p}=".to_sym, data[p])        
    end
    
    #model = OpenTox::Model::LazarClassificationModel.new(v[:model_uri])
    #raise "cannot access model '"+v[:model_uri].to_s+"'" unless model
    #validation.prediction_feature = model.get_prediction_feature
    
    {Lib::VAL_CV_PROP => Lib::VAL_CV_PROPS,
     Lib::VAL_CLASS_PROP => Lib::VAL_CLASS_PROPS_EXTENDED}.each do |subset_name,subset_props|
      subset = data[subset_name]
      subset_props.each{ |prop| validation.send("#{prop}=".to_sym, subset[prop]) } if subset
    end
  end
    
  def init_cv(validation)
    
    raise "cv-uri not set" unless validation.crossvalidation_uri
    
    begin
      data = YAML.load(RestClient.get validation.crossvalidation_uri)
    rescue => ex
      raise OpenTox::BadRequestError.new "cannot get crossvalidation at '"+validation.crossvalidation_uri.to_s+"', error msg: "+ex.message
    end
    
    Lib::CROSS_VAL_PROPS.each do |p|
      validation.send("#{p.to_s}=".to_sym, data[p])        
    end
  end

  def get_predictions(validation, subjectid=nil, task=nil)
    Lib::Predictions.new( validation.prediction_feature, validation.test_dataset_uri, validation.prediction_dataset_uri)
  end
end

# = Reports::OTMockLayer
#
# OUTDATED, please update before use
#
# does not connect to other services, provides randomly generated data
#
class Reports::ValidationMockLayer < Reports::ValidationAccess
  
  NUM_DATASETS = 1
  NUM_ALGS = 4
  NUM_FOLDS = 5
  NUM_PREDICTIONS = 30
  ALGS = ["naive-bayes", "c4.5", "svm", "knn", "lazar", "id3"]
  DATASETS = ["hamster", "mouse" , "rat", "dog", "cat", "horse", "bug", "ant", "butterfly", "rabbit", "donkey", "monkey", "dragonfly", "frog", "dragon", "dinosaur"]
  FOLDS = [1,2,3,4,5,6,7,8,9,10]
  
  def initialize
    
    super
    @algs = []
    @datasets = []
    @folds = []
    sum = NUM_DATASETS*NUM_ALGS*NUM_FOLDS
    (0..sum-1).each do |i|
      @folds[i] = FOLDS[i%NUM_FOLDS]
      @algs[i] = ALGS[(i/NUM_FOLDS)%NUM_ALGS]
      @datasets[i] = DATASETS[((i/NUM_FOLDS)/NUM_ALGS)%NUM_DATASETS]
    end
    @count = 0
  end
  
  def resolve_cv_uris(validation_uris)
    res = []
    validation_uris.each do |u|
      if u.to_s =~ /.*crossvalidation.*/
        res += ["validation_x"]*NUM_FOLDS
      else
        res += [u.to_s]
      end
    end
    res
  end
  
  def init_validation(validation, uri)
    
    validation.model_uri = @algs[@count]
    validation.test_dataset_uri = @datasets[@count]
    validation.prediction_dataset_uri = "bla"
    
    cv_id = @count/NUM_FOLDS
    validation.crossvalidation_id = cv_id
    validation.crossvalidation_fold = @folds[@count]
    
    validation.auc = 0.5 + cv_id*0.02 + rand/3.0
    validation.acc = 0.5 + cv_id*0.02 + rand/3.0
    validation.tp = 1
    validation.fp = 1
    validation.tn = 1
    validation.fn = 1
    
    validation.algorithm_uri = @algs[@count]
    validation.training_dataset_uri = @datasets[@count]
    validation.test_dataset_uri = @datasets[@count]
    
    validation.prediction_feature = "classification"
    
    @count += 1
  end
  
  def init_cv(validation)
    
    raise "cv-id not set" unless validation.crossvalidation_id
      
    validation.num_folds = NUM_FOLDS
    validation.algorithm_uri = @algs[validation.crossvalidation_id.to_i * NUM_FOLDS]
    validation.dataset_uri = @datasets[validation.crossvalidation_id.to_i * NUM_FOLDS]
    validation.stratified = true
    validation.random_seed = 1
    #validation.CV_dataset_name = @datasets[validation.crossvalidation_id.to_i * NUM_FOLDS]
  end
  
  def get_predictions(validation, task=nil)
  
    p = Array.new
    c = Array.new
    conf = Array.new
    u = Array.new
    (0..NUM_PREDICTIONS).each do |i|
      p.push rand(2)
      c.push rand(2)
      conf.push rand
      u.push("compound no"+(i+1).to_s)
    end
    Lib::MockPredictions.new( p, c, conf, u )
  end

 end
