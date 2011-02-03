
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'opentox-ruby' ].each do |lib|
  require lib
end

require 'lib/merge.rb'
#require 'lib/active_record_setup.rb'
require 'validation/validation_service.rb'

get '/crossvalidation/?' do
  LOGGER.info "list all crossvalidations"
  #uri_list = Validation::Crossvalidation.all.collect{ |cv| cv.crossvalidation_uri }.join("\n")+"\n"
  uri_list = Lib::DataMapperUtil.all(Validation::Crossvalidation,params).collect{ |cv| cv.crossvalidation_uri }.join("\n")+"\n"
  
  #uri_list = Validation::Crossvalidation.find_like(params).collect{ |cv| cv.crossvalidation_uri }.join("\n")+"\n"
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    related_links = 
      "Single validations:      "+url_for("/",:full)+"\n"+
      "Crossvalidation reports: "+url_for("/report/crossvalidation",:full)
    description = 
      "A list of all crossvalidations.\n"+
      "Use the POST method to perform a crossvalidation."
    post_params = [[:dataset_uri,:algorithm_uri,:prediction_feature,[:num_folds,10],[:random_seed,1],[:stratified,false],[:algorithm_params,""]]]
    content_type "text/html"
    OpenTox.text_to_html uri_list,related_links,description,post_params
  else
    content_type "text/uri-list"
    uri_list
  end
end

post '/crossvalidation/?' do
  task = OpenTox::Task.create( "Perform crossvalidation", url_for("/crossvalidation", :full) ) do |task| #, params
    LOGGER.info "creating crossvalidation "+params.inspect
    raise OpenTox::BadRequestError.new "dataset_uri missing" unless params[:dataset_uri]
    raise OpenTox::BadRequestError.new "algorithm_uri missing" unless params[:algorithm_uri]
    raise OpenTox::BadRequestError.new "prediction_feature missing" unless params[:prediction_feature]
    raise OpenTox::BadRequestError.new "illegal param-value num_folds: '"+params[:num_folds].to_s+"', must be integer >1" unless params[:num_folds]==nil or 
      params[:num_folds].to_i>1
    
    cv_params = { :dataset_uri => params[:dataset_uri],  
                  :algorithm_uri => params[:algorithm_uri] }
    [ :num_folds, :random_seed, :stratified ].each{ |sym| cv_params[sym] = params[sym] if params[sym] }
    cv = Validation::Crossvalidation.new cv_params
    cv.subjectid = @subjectid
    cv.perform_cv( params[:prediction_feature], params[:algorithm_params], task )
    cv.crossvalidation_uri
  end
  return_task(task)
end

post '/crossvalidation/cleanup/?' do
  LOGGER.info "crossvalidation cleanup, starting..."
  content_type "text/uri-list"
  deleted = []
  #Validation::Crossvalidation.find_like(params).each do |cv|
  Validation::Crossvalidation.all( { :finished => false } ).each do |cv|
    #num_vals = Validation::Validation.find( :all, :conditions => { :crossvalidation_id => cv.id } ).size
    #num_vals = Validation::Validation.all( :crossvalidation_id => cv.id ).size
    #if cv.num_folds != num_vals || !cv.finished
      LOGGER.debug "delete cv with id:"+cv.id.to_s+", finished is false"
      deleted << cv.crossvalidation_uri
      #Validation::Crossvalidation.delete(cv.id)
      cv.subjectid = @subjectid
      cv.delete
    #end
  end
  LOGGER.info "crossvalidation cleanup, deleted "+deleted.size.to_s+" cvs"
  deleted.join("\n")+"\n"
end

post '/crossvalidation/loo/?' do
  raise "not yet implemented"
end

get '/crossvalidation/loo/?' do
  raise OpenTox::BadRequestError.new "GET operation not supported, use POST for performing a loo-crossvalidation, see "+url_for("/crossvalidation", :full)+" for crossvalidation results"
end

get '/crossvalidation/:id' do
  LOGGER.info "get crossvalidation with id "+params[:id].to_s
#  begin
#    #crossvalidation = Validation::Crossvalidation.find(params[:id])
#  rescue ActiveRecord::RecordNotFound => ex
#    raise OpenTox::NotFoundError.new "Crossvalidation '#{params[:id]}' not found."
#  end
  crossvalidation = Validation::Crossvalidation.get(params[:id])
  raise OpenTox::NotFoundError.new "Crossvalidation '#{params[:id]}' not found." unless crossvalidation
  
  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    crossvalidation.to_rdf
  when /text\/html/
    related_links = 
      "Search for corresponding cv report:  "+url_for("/report/crossvalidation?crossvalidation="+crossvalidation.crossvalidation_uri,:full)+"\n"+
      "Statistics for this crossvalidation: "+url_for("/crossvalidation/"+params[:id]+"/statistics",:full)+"\n"+
      "Predictions of this crossvalidation: "+url_for("/crossvalidation/"+params[:id]+"/predictions",:full)+"\n"+
      "All crossvalidations:                "+url_for("/crossvalidation",:full)+"\n"+
      "All crossvalidation reports:         "+url_for("/report/crossvalidation",:full)
    description = 
        "A crossvalidation resource."
    content_type "text/html"
    OpenTox.text_to_html crossvalidation.to_yaml,related_links,description
  when /application\/x-yaml|\*\/\*/
    content_type "application/x-yaml"
    crossvalidation.to_yaml
  else
    raise OpenTox::BadRequestError.new "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported, valid Accept-Headers: \"application/rdf+xml\", \"application/x-yaml\", \"text/html\"."
  end
end

get '/crossvalidation/:id/statistics' do
  LOGGER.info "get merged validation-result for crossvalidation with id "+params[:id].to_s
#  begin
    #crossvalidation = Validation::Crossvalidation.find(params[:id])
#  rescue ActiveRecord::RecordNotFound => ex
#    raise OpenTox::NotFoundError.new "Crossvalidation '#{params[:id]}' not found."
#  end
  #crossvalidation = Validation::Crossvalidation.find(params[:id])
  crossvalidation = Validation::Crossvalidation.get(params[:id])
  
  raise OpenTox::NotFoundError.new "Crossvalidation '#{params[:id]}' not found." unless crossvalidation
  raise OpenTox::BadRequestError.new "Crossvalidation '"+params[:id].to_s+"' not finished" unless crossvalidation.finished
  
  Lib::MergeObjects.register_merge_attributes( Validation::Validation,
    Lib::VAL_MERGE_AVG,Lib::VAL_MERGE_SUM,Lib::VAL_MERGE_GENERAL-[:date,:validation_uri,:crossvalidation_uri]) unless 
      Lib::MergeObjects.merge_attributes_registered?(Validation::Validation)
  
  #v = Lib::MergeObjects.merge_array_objects( Validation::Validation.find( :all, :conditions => { :crossvalidation_id => params[:id] } ) )
  v = Lib::MergeObjects.merge_array_objects( Validation::Validation.all( :crossvalidation_id => params[:id] ) )
  v.created_at = nil
  v.id = nil
  
  case request.env['HTTP_ACCEPT'].to_s
  when /text\/html/
    related_links = 
       "The corresponding crossvalidation resource: "+url_for("/crossvalidation/"+params[:id],:full)
    description = 
       "The averaged statistics for the crossvalidation."
    content_type "text/html"
    OpenTox.text_to_html v.to_yaml,related_links,description
  else
    content_type "application/x-yaml"
    v.to_yaml
  end
end

delete '/crossvalidation/:id/?' do
  LOGGER.info "delete crossvalidation with id "+params[:id].to_s
  content_type "text/plain"
#  begin
    #crossvalidation = Validation::Crossvalidation.find(params[:id])
#  rescue ActiveRecord::RecordNotFound => ex
#    raise OpenTox::NotFoundError.new "Crossvalidation '#{params[:id]}' not found."
#  end
#  Validation::Crossvalidation.delete(params[:id])
  
  cv = Validation::Crossvalidation.get(params[:id])
  cv.subjectid = @subjectid
  raise OpenTox::NotFoundError.new "Crossvalidation '#{params[:id]}' not found." unless cv
  cv.delete
end

#get '/crossvalidation/:id/validations' do
#  LOGGER.info "get all validations for crossvalidation with id "+params[:id].to_s
#  begin
#    crossvalidation = Validation::Crossvalidation.find(params[:id])
#  rescue ActiveRecord::RecordNotFound => ex
#    raise OpenTox::NotFoundError.new "Crossvalidation '#{params[:id]}' not found."
#  end
#  content_type "text/uri-list"
#  Validation::Validation.find( :all, :conditions => { :crossvalidation_id => params[:id] } ).collect{ |v| v.validation_uri.to_s }.join("\n")+"\n"
#end

get '/crossvalidation/:id/predictions' do
  LOGGER.info "get predictions for crossvalidation with id "+params[:id].to_s
  begin
    #crossvalidation = Validation::Crossvalidation.find(params[:id])
    crossvalidation = Validation::Crossvalidation.get(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    raise OpenTox::NotFoundError.new "Crossvalidation '#{params[:id]}' not found."
  end
  raise OpenTox::BadRequestError.new "Crossvalidation '"+params[:id].to_s+"' not finished" unless crossvalidation.finished
  
  content_type "application/x-yaml"
  #validations = Validation::Validation.find( :all, :conditions => { :crossvalidation_id => params[:id] } )
  validations = Validation::Validation.all( :crossvalidation_id => params[:id] )
  p = Lib::OTPredictions.to_array( validations.collect{ |v| v.compute_validation_stats_with_model(nil, true) } ).to_yaml
  
  case request.env['HTTP_ACCEPT'].to_s
  when /text\/html/
    content_type "text/html"
    description = 
      "The crossvalidation predictions as (yaml-)array."
    related_links = 
      "All crossvalidations:         "+url_for("/crossvalidation",:full)+"\n"+
      "Correspoding crossvalidation: "+url_for("/crossvalidation/"+params[:id],:full)
    OpenTox.text_to_html p, related_links, description
  else
    content_type "text/x-yaml"
    p
  end
end

get '/?' do
  
  LOGGER.info "list all validations, params: "+params.inspect
  #uri_list = Validation::Validation.find_like(params).collect{ |v| v.validation_uri }.join("\n")+"\n"
  #uri_list = Validation::Validation.all(params).collect{ |v| v.validation_uri }.join("\n")+"\n"
  uri_list = Lib::DataMapperUtil.all(Validation::Validation,params).collect{ |v| v.validation_uri }.join("\n")+"\n"
  
  
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    related_links = 
      "To perform a validation:\n"+
      "* "+url_for("/test_set_validation",:full)+"\n"+
      "* "+url_for("/training_test_validation",:full)+"\n"+
      "* "+url_for("/bootstrapping",:full)+"\n"+
      "* "+url_for("/training_test_split",:full)+"\n"+
      "* "+url_for("/crossvalidation",:full)+"\n"+
      "Validation reporting:            "+url_for("/report",:full)+"\n"+
      "REACH relevant reporting:        "+url_for("/reach_report",:full)+"\n"+
      "Examples for using this service: "+url_for("/examples",:full)+"\n"
    description = 
        "A validation web service for the OpenTox project ( http://opentox.org ).\n"+
        "In the root directory (this is where you are now), a list of all validation resources is returned."
    content_type "text/html"
    OpenTox.text_to_html uri_list,related_links,description
  else
    content_type "text/uri-list"
    uri_list
  end
end

post '/?' do
  raise OpenTox::BadRequestError.new "Post not supported, to perfom a validation use '/test_set_validation', '/training_test_validation', 'bootstrapping', 'training_test_split'"
end

post '/test_set_validation' do
  LOGGER.info "creating test-set-validation "+params.inspect
  if params[:model_uri] and params[:test_dataset_uri] and !params[:training_dataset_uri] and !params[:algorithm_uri]
    task = OpenTox::Task.create( "Perform test-set-validation", url_for("/", :full) ) do |task| #, params
      v = Validation::Validation.new :validation_type => "test_set_validation", 
                       :model_uri => params[:model_uri], 
                       :test_dataset_uri => params[:test_dataset_uri],
                       :test_target_dataset_uri => params[:test_target_dataset_uri],
                       :prediction_feature => params[:prediction_feature]
      v.subjectid = @subjectid
      v.validate_model( task )
      v.validation_uri
    end
    return_task(task)
  else
    raise OpenTox::BadRequestError.new "illegal parameters, pls specify model_uri and test_dataset_uri\n"+
      "params given: "+params.inspect
  end
end

get '/test_set_validation' do
  LOGGER.info "list all test-set-validations, params: "+params.inspect
  
  #uri_list = Validation::Validation.find( :all, :conditions => { :validation_type => "test_set_validation" } ).collect{ |v| v.validation_uri }.join("\n")+"\n"
  #uri_list = Validation::Validation.all( :validation_type => "test_set_validation" ).collect{ |v| v.validation_uri }.join("\n")+"\n"
  params[:validation_type] = "test_set_validation"
  uri_list = Lib::DataMapperUtil.all(Validation::Validation,params).collect{ |v| v.validation_uri }.join("\n")+"\n"
  
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    related_links = 
      "All validations:    "+url_for("/",:full)+"\n"+
      "Validation reports: "+url_for("/report/validation",:full)
    description = 
        "A list of all test-set-validations.\n"+
        "To perform a test-set-validation use the POST method."
    post_params = [[:model_uri, :test_dataset_uri, [:test_target_dataset_uri,"same-as-test_dataset_uri"], [:prediction_feature, "dependent-variable-of-model"]]]
    content_type "text/html"
    OpenTox.text_to_html uri_list,related_links,description,post_params
  else
    content_type "text/uri-list"
    uri_list
  end
end

post '/training_test_validation/?' do
  LOGGER.info "creating training-test-validation "+params.inspect
  if params[:algorithm_uri] and params[:training_dataset_uri] and params[:test_dataset_uri] and params[:prediction_feature] and !params[:model_uri]
    task = OpenTox::Task.create( "Perform training-test-validation", url_for("/", :full) ) do |task| #, params
      v = Validation::Validation.new :validation_type => "training_test_validation", 
                        :algorithm_uri => params[:algorithm_uri],
                        :training_dataset_uri => params[:training_dataset_uri], 
                        :test_dataset_uri => params[:test_dataset_uri],
                        :test_target_dataset_uri => params[:test_target_dataset_uri],
                        :prediction_feature => params[:prediction_feature]
      v.subjectid = @subjectid
      v.validate_algorithm( params[:algorithm_params], task ) 
      v.validation_uri
    end
    return_task(task)
  else
    raise OpenTox::BadRequestError.new "illegal parameters, pls specify algorithm_uri, training_dataset_uri, test_dataset_uri, prediction_feature\n"+
        "params given: "+params.inspect
  end
end

get '/training_test_validation' do
  LOGGER.info "list all training-test-validations, params: "+params.inspect
  #uri_list = Validation::Validation.find( :all, :conditions => { :validation_type => "training_test_validation" } ).collect{ |v| v.validation_uri }.join("\n")+"\n"
  #uri_list = Validation::Validation.all( :validation_type => "training_test_validation" ).collect{ |v| v.validation_uri }.join("\n")+"\n"
  params[:validation_type] = "training_test_validation"
  uri_list = Lib::DataMapperUtil.all(Validation::Validation,params).collect{ |v| v.validation_uri }.join("\n")+"\n"
  
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    related_links = 
      "All validations:    "+url_for("/",:full)+"\n"+
      "Validation reports: "+url_for("/report/validation",:full)
    description = 
        "A list of all training-test-validations.\n"+
        "To perform a training-test-validation use the POST method."
    post_params = [[:algorithm_uri,
                    :training_dataset_uri, 
                    :test_dataset_uri, 
                    [:test_target_dataset_uri,"same-as-test_dataset_uri"], 
                    :prediction_feature, 
                    [:algorithm_params, ""]]]
    content_type "text/html"
    OpenTox.text_to_html uri_list,related_links,description,post_params
  else
    content_type "text/uri-list"
    uri_list
  end
end

post '/bootstrapping' do
  task = OpenTox::Task.create( "Perform bootstrapping validation", url_for("/bootstrapping", :full) ) do |task| #, params
    LOGGER.info "performing bootstrapping validation "+params.inspect
    raise OpenTox::BadRequestError.new "dataset_uri missing" unless params[:dataset_uri]
    raise OpenTox::BadRequestError.new "algorithm_uri missing" unless params[:algorithm_uri]
    raise OpenTox::BadRequestError.new "prediction_feature missing" unless params[:prediction_feature]
    
    params.merge!( Validation::Util.bootstrapping( params[:dataset_uri], 
      params[:prediction_feature], @subjectid, 
      params[:random_seed], OpenTox::SubTask.create(task,0,33)) )
    v = Validation::Validation.new :validation_type => "bootstrapping", 
                     :test_target_dataset_uri => params[:dataset_uri],
                     :prediction_feature => params[:prediction_feature],
                     :algorithm_uri => params[:algorithm_uri]
    v.subjectid = @subjectid
    v.validate_algorithm( params[:algorithm_params], OpenTox::SubTask.create(task,33,100))
    v.validation_uri
  end
  return_task(task)
end

get '/bootstrapping' do
  LOGGER.info "list all bootstrapping-validations, params: "+params.inspect
  #uri_list = Validation::Validation.find( :all, :conditions => { :validation_type => "bootstrapping" } ).collect{ |v| v.validation_uri }.join("\n")+"\n"
  #uri_list = Validation::Validation.all( :validation_type => "bootstrapping" ).collect{ |v| v.validation_uri }.join("\n")+"\n"
  params[:validation_type] = "bootstrapping"
  uri_list = Lib::DataMapperUtil.all(Validation::Validation,params).collect{ |v| v.validation_uri }.join("\n")+"\n"
  
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    related_links = 
      "All validations:    "+url_for("/",:full)+"\n"+
      "Validation reports: "+url_for("/report/validation",:full)
    description = 
        "A list of all bootstrapping-validations.\n"+
        "To perform a bootstrapping-validation use the POST method."
    post_params = [[:algorithm_uri,
                    :dataset_uri, 
                    :prediction_feature, 
                    [:algorithm_params, ""],
                    [:random_seed, 1]]]
    content_type "text/html"
    OpenTox.text_to_html uri_list,related_links,description,post_params
  else
    content_type "text/uri-list"
    uri_list
  end
end

post '/training_test_split' do
  
  task = OpenTox::Task.create( "Perform training test split validation", url_for("/training_test_split", :full) )  do |task| #, params
    LOGGER.info "creating training test split "+params.inspect
    raise OpenTox::BadRequestError.new "dataset_uri missing" unless params[:dataset_uri]
    raise OpenTox::BadRequestError.new "algorithm_uri missing" unless params[:algorithm_uri]
    raise OpenTox::BadRequestError.new "prediction_feature missing" unless params[:prediction_feature]
    
    params.merge!( Validation::Util.train_test_dataset_split(params[:dataset_uri], params[:prediction_feature], 
      @subjectid, params[:split_ratio], params[:random_seed], OpenTox::SubTask.create(task,0,33)))
    v = Validation::Validation.new  :validation_type => "training_test_split", 
                     :training_dataset_uri => params[:training_dataset_uri], 
                     :test_dataset_uri => params[:test_dataset_uri],
                     :test_target_dataset_uri => params[:dataset_uri],
                     :prediction_feature => params[:prediction_feature],
                     :algorithm_uri => params[:algorithm_uri]
    v.subjectid = @subjectid
    v.validate_algorithm( params[:algorithm_params], OpenTox::SubTask.create(task,33,100))
    v.validation_uri
  end
  return_task(task)

end

get '/training_test_split' do
  LOGGER.info "list all training-test-split-validations, params: "+params.inspect
  #uri_list = Validation::Validation.find( :all, :conditions => { :validation_type => "training_test_split" } ).collect{ |v| v.validation_uri }.join("\n")+"\n"
  #uri_list = Validation::Validation.all( :validation_type => "training_test_split" ).collect{ |v| v.validation_uri }.join("\n")+"\n"
  params[:validation_type] = "training_test_split"
  uri_list = Lib::DataMapperUtil.all(Validation::Validation,params).collect{ |v| v.validation_uri }.join("\n")+"\n"
  
  if request.env['HTTP_ACCEPT'] =~ /text\/html/
    related_links = 
      "All validations:    "+url_for("/",:full)+"\n"+
      "Validation reports: "+url_for("/report/validation",:full)
    description = 
        "A list of all training-test-split-validations.\n"+
        "To perform a training-test-split-validation use the POST method."
    post_params = [[:algorithm_uri,
                    :dataset_uri, 
                    :prediction_feature, 
                    [:algorithm_params, ""],
                    [:random_seed, 1],
                    [:split_ratio, 0.66]]]
    content_type "text/html"
    OpenTox.text_to_html uri_list,related_links,description,post_params
  else
    content_type "text/uri-list"
    uri_list
  end
end

post '/cleanup/?' do
  LOGGER.info "validation cleanup, starting..."
  content_type "text/uri-list"
  deleted = []
  #Validation::Validation.find( :all, :conditions => { :prediction_dataset_uri => nil } ).each do |val|
  Validation::Validation.all( :finished => false ).each do |val|
    LOGGER.debug "delete val with id:"+val.id.to_s+", finished is false"
    deleted << val.validation_uri
    #Validation::Validation.delete(val.id)
    val.subjectid = @subjectid
    val.delete
  end
  LOGGER.info "validation cleanup, deleted "+deleted.size.to_s+" validations"
  deleted.join("\n")+"\n"
end

post '/plain_training_test_split' do
    LOGGER.info "creating pure training test split "+params.inspect
    raise OpenTox::BadRequestError.new "dataset_uri missing" unless params[:dataset_uri]
    
    result = Validation::Util.train_test_dataset_split(params[:dataset_uri], params[:prediction_feature], params[:split_ratio], params[:random_seed])
    content_type "text/uri-list"
    result[:training_dataset_uri]+"\n"+result[:test_dataset_uri]+"\n"
end

post '/validate_datasets' do
  task = OpenTox::Task.create( "Perform dataset validation", url_for("/validate_datasets", :full) ) do |task| #, params
    LOGGER.info "validating values "+params.inspect
    raise OpenTox::BadRequestError.new "test_dataset_uri missing" unless params[:test_dataset_uri]
    raise OpenTox::BadRequestError.new "prediction_datset_uri missing" unless params[:prediction_dataset_uri]
    params[:validation_type] = "validate_datasets" 
    
    if params[:model_uri]
      v = Validation::Validation.new params
      v.subjectid = @subjectid
      v.compute_validation_stats_with_model(nil,false,task)
    else
      raise OpenTox::BadRequestError.new "please specify 'model_uri' or 'prediction_feature'" unless params[:prediction_feature]
      raise OpenTox::BadRequestError.new "please specify 'model_uri' or 'predicted_feature'" unless params[:predicted_feature]
      raise OpenTox::BadRequestError.new "please specify 'model_uri' or set either 'classification' or 'regression' flag" unless 
            params[:classification] or params[:regression]
      
      predicted_feature = params.delete("predicted_feature")
      feature_type = "classification" if params.delete("classification")!=nil
      feature_type = "regression" if params.delete("regression")!=nil
      v = Validation::Validation.new params  
      v.subjectid = @subjectid
      v.compute_validation_stats(feature_type,predicted_feature,nil,nil,false,task)
    end
    v.validation_uri
  end
  return_task(task)
end

get '/:id/predictions' do
  LOGGER.info "get validation predictions "+params.inspect
  begin
    #validation = Validation::Validation.find(params[:id])
    validation = Validation::Validation.get(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    raise OpenTox::NotFoundError.new "Validation '#{params[:id]}' not found."
  end
  raise OpenTox::BadRequestError.new "Validation '"+params[:id].to_s+"' not finished" unless validation.finished
  p = validation.compute_validation_stats_with_model(nil, true)
  case request.env['HTTP_ACCEPT'].to_s
  when /text\/html/
    content_type "text/html"
    description = 
      "The validation predictions as (yaml-)array."
    related_links = 
      "All validations:         "+url_for("/",:full)+"\n"+
      "Correspoding validation: "+url_for("/"+params[:id],:full)
    OpenTox.text_to_html p.to_array.to_yaml, related_links, description
  else
    content_type "text/x-yaml"
    p.to_array.to_yaml
  end
end 

#get '/:id/:attribute' do
#  LOGGER.info "access validation attribute "+params.inspect
#  begin
#    validation = Validation::Validation.find(params[:id])
#  rescue ActiveRecord::RecordNotFound => ex
#    raise OpenTox::NotFoundError.new "Validation '#{params[:id]}' not found."
#  end
#  begin
#    raise unless validation.attribute_loaded?(params[:attribute])
#  rescue
#    raise OpenTox::BadRequestError.new "Not a validation attribute: "+params[:attribute].to_s
#  end
#  content_type "text/plain"
#  return validation.send(params[:attribute])
#end

get '/:id' do
  LOGGER.info "get validation with id "+params[:id].to_s+" '"+request.env['HTTP_ACCEPT'].to_s+"'"
#  begin
    #validation = Validation::Validation.find(params[:id])
#  rescue ActiveRecord::RecordNotFound => ex
#    raise OpenTox::NotFoundError.new "Validation '#{params[:id]}' not found."
#  end
  validation = Validation::Validation.get(params[:id])
  raise OpenTox::NotFoundError.new "Validation '#{params[:id]}' not found." unless validation
  
  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    validation.to_rdf
  when /text\/html/
    content_type "text/html"
    description = 
      "A validation resource."
    related_links = 
      "Search for corresponding report: "+url_for("/report/validation?validation="+validation.validation_uri,:full)+"\n"+
      "Get validation predictions:      "+url_for("/"+params[:id]+"/predictions",:full)+"\n"+
      "All validations:                 "+url_for("/",:full)+"\n"+
      "All validation reports:          "+url_for("/report/validation",:full)
    OpenTox.text_to_html validation.to_yaml,related_links,description
  when /application\/x-yaml|\*\/\*/ 
    content_type "application/x-yaml"
    validation.to_yaml
  else
    raise OpenTox::BadRequestError.new "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported, valid Accept-Headers: \"application/rdf+xml\", \"application/x-yaml\", \"text/html\"."
  end
end

delete '/:id' do
  LOGGER.info "delete validation with id "+params[:id].to_s
#  begin
    #validation = Validation::Validation.find(params[:id])
#  rescue ActiveRecord::RecordNotFound => ex
#    raise OpenTox::NotFoundError.new "Validation '#{params[:id]}' not found."
#  end
  validation = Validation::Validation.get(params[:id])
  validation.subjectid = @subjectid
  raise OpenTox::NotFoundError.new "Validation '#{params[:id]}' not found." unless validation
  content_type "text/plain"
  validation.delete
end