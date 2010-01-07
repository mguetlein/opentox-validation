
require "lib/validation_db.rb"

# = Reports::ValidationAccess
# 
# service that connects to the validation-service
#  
class Reports::ValidationAccess

  # initialize validation object with 
  def init_validation(validation, uri)
    raise "not implemented"
  end
  
  def init_cv(validation)
    raise "not implemented"
  end
  
  def get_predictions(validation)
    raise "not implemented"
  end
  
  def resolve_cv_uris(uri_list)
    raise "not implemented"
  end
  
  def get_prediction_feature_values(prediction_feature)
    raise "not implemented"
  end
  
end

class Reports::ValidationDB < Reports::ValidationAccess
  
  def resolve_cv_uris(uri_list)
    res = []
    uri_list.each do |u|
      if u.to_s =~ /.*\/crossvalidation\/[0-9]+/
        cv_id = u.split("/")[-1].to_i
        res += Lib::Validation.all(:crossvalidation_id => cv_id).collect{|v| v.uri.to_s}
      else
        res += [u.to_s]
      end
    end
    res
  end
  
  
  def init_validation(validation, uri)
  
    raise Reports::BadRequest.new "not a validation uri: "+uri.to_s unless uri =~ /.*\/validation\/[0-9]+/
    validation_id = uri.split("/")[-1]
    v = Lib::Validation.get(validation_id)
    raise Reports::BadRequest.new "no validation found with id "+validation_id.to_s unless v
    
    (Lib::VAL_PROPS + Lib::VAL_CV_PROPS).each do |p|
      validation.send("#{p.to_s}=".to_sym, v[p])
    end
    
    #model = OpenTox::Model::LazarClassificationModel.new(v[:model_uri])
    #raise "cannot access model '"+v[:model_uri].to_s+"'" unless model
    #validation.prediction_feature = model.get_prediction_feature
    
    {Lib::VAL_CLASS_PROP => Lib::VAL_CLASS_PROPS, 
     Lib::VAL_REGR_PROP => Lib::VAL_REGR_PROPS}.each do |subset_name,subset_props|
      subset = v[subset_name]
      subset_props.each{ |prop| validation.send("#{prop.to_s}=".to_sym, subset[prop]) } if subset
    end
  end
    
  def init_cv(validation)
    
    cv = Lib::Crossvalidation.get(validation.crossvalidation_id)
    raise Reports::BadRequest.new "no crossvalidation found with id "+validation.crossvalidation_id.to_s unless cv
    
    Lib::CROSS_VAL_PROPS.each do |p|
      validation.send("#{p.to_s}=".to_sym, cv[p])        
    end
  end

  def get_predictions(validation)
    Lib::OTPredictions.new( validation.prediction_feature, validation.test_dataset_uri, validation.prediction_dataset_uri)
  end
  
  def get_prediction_feature_values(prediction_feature)
    #TODO: get feature range from ontology
    return  ["true", "false"]
  end
  
end


class Reports::ValidationWebservice < Reports::ValidationAccess
  
  def resolve_cv_uris(uri_list)
    res = []
    uri_list.each do |u|
      if u.to_s =~ /.*\/crossvalidation\/.*/
        uri = u.to_s+"/validations"
        begin
          vali_uri_list = RestClient.get uri
        rescue => ex
          raise Reports::BadRequest.new "cannot get validations for cv at '"+uri.to_s+"', error msg: "+ex.message
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
      raise Reports::BadRequest.new "cannot get validation at '"+uri.to_s+"', error msg: "+ex.message
    end
  
    Lib::VAL_PROPS.each do |p|
      validation.send("#{p}=".to_sym, data[p])        
    end
    
    #model = OpenTox::Model::LazarClassificationModel.new(v[:model_uri])
    #raise "cannot access model '"+v[:model_uri].to_s+"'" unless model
    #validation.prediction_feature = model.get_prediction_feature
    
    {Lib::VAL_CV_PROP => Lib::VAL_CV_PROPS,
     Lib::VAL_CLASS_PROP => Lib::VAL_CLASS_PROPS}.each do |subset_name,subset_props|
      subset = data[subset_name]
      subset_props.each{ |prop| validation.send("#{prop}=".to_sym, subset[prop]) } if subset
    end
  end
    
  def init_cv(validation)
    
    raise "cv-id not set" unless validation.crossvalidation_id
    
    cv_uri = validation.uri.split("/")[0..-3].join("/")+"/crossvalidation/"+validation.crossvalidation_id.to_s
    begin
      data = YAML.load(RestClient.get cv_uri)
    rescue => ex
      raise Reports::BadRequest.new "cannot get crossvalidation at '"+cv_uri.to_s+"', error msg: "+ex.message
    end
    
    Lib::CROSS_VAL_PROPS.each do |p|
      validation.send("#{p.to_s}=".to_sym, data[p])        
    end
  end

  def get_predictions(validation)
    Lib::Predictions.new( validation.prediction_feature, validation.test_dataset_uri, validation.prediction_dataset_uri)
  end
end

# = Reports::OTMockLayer
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
  
  def resolve_cv_uris(uri_list)
    res = []
    uri_list.each do |u|
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
  
  def get_predictions(validation)
  
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
