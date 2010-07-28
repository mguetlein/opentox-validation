
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'active_record', 'ar-extensions', 'opentox-ruby-api-wrapper' ].each do |lib|
  require lib
end

require 'validation/validation_service.rb'
require 'lib/merge.rb'

get '/crossvalidation/?' do
  LOGGER.info "list all crossvalidations"
  content_type "text/uri-list"
  params.each{ |k,v| halt 400,"no crossvalidation-attribute: "+k.to_s unless Validation::Crossvalidation.column_names.include?(k.gsub(/_like$/,""))  }
  Validation::Crossvalidation.find(:all, :conditions => params).collect{ |d| url_for("/crossvalidation/", :full) + d.id.to_s }.join("\n")
end

post '/crossvalidation/loo/?' do
  halt 500, "not yet implemented"
end

get '/crossvalidation/loo/?' do
  halt 400, "GET operation not supported, use POST for performing a loo-crossvalidation, see "+url_for("/crossvalidation", :full)+" for crossvalidation results"
end

get '/crossvalidation/:id' do
  LOGGER.info "get crossvalidation with id "+params[:id].to_s
  begin
    crossvalidation = Validation::Crossvalidation.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    halt 404, "Crossvalidation '#{params[:id]}' not found."
  end
  
  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    result = crossvalidation.to_rdf
  when /application\/x-yaml|\*\/\*|/ # matches 'text/x-yaml', '*/*', ''
    content_type "application/x-yaml"
    result = crossvalidation.to_yaml
  else
    halt 400, "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported."
  end
  result
end

delete '/crossvalidation/:id/?' do
  LOGGER.info "delete crossvalidation with id "+params[:id].to_s
  content_type "text/plain"
  begin
    crossvalidation = Validation::Crossvalidation.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    halt 404, "Crossvalidation '#{params[:id]}' not found."
  end
  Validation::Crossvalidation.delete(params[:id])
end

get '/crossvalidation/:id/validations' do
  LOGGER.info "get all validations for crossvalidation with id "+params[:id].to_s
  begin
    crossvalidation = Validation::Crossvalidation.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    halt 404, "Crossvalidation '#{params[:id]}' not found."
  end
  content_type "text/uri-list"
  Validation::Validation.find( :all, :conditions => { :crossvalidation_id => params[:id] } ).collect{ |v| v.validation_uri.to_s }.join("\n")+"\n"
end


get '/crossvalidation/:id/statistics' do
  LOGGER.info "get merged validation-result for crossvalidation with id "+params[:id].to_s
  begin
    crossvalidation = Validation::Crossvalidation.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    halt 404, "Crossvalidation '#{params[:id]}' not found."
  end
  
  Lib::MergeObjects.register_merge_attributes( Validation::Validation,
    Lib::VAL_MERGE_AVG,Lib::VAL_MERGE_SUM,Lib::VAL_MERGE_GENERAL-[:validation_uri]) unless 
      Lib::MergeObjects.merge_attributes_registered?(Validation::Validation)
  
  v = Lib::MergeObjects.merge_array_objects( Validation::Validation.find( :all, :conditions => { :crossvalidation_id => params[:id] } ) )
  v.validation_uri = nil
  v.date = nil
  v.id = nil
  content_type "application/x-yaml"
  v.to_yaml
end


post '/crossvalidation/?' do
  content_type "text/uri-list"
  task_uri = OpenTox::Task.as_task do
    LOGGER.info "creating crossvalidation "+params.inspect
    halt 400, "dataset_uri missing" unless params[:dataset_uri]
    halt 400, "algorithm_uri missing" unless params[:algorithm_uri]
    halt 400, "prediction_feature missing" unless params[:prediction_feature]
    halt 400, "illegal param-value num_folds: '"+params[:num_folds].to_s+"', must be integer >1" unless params[:num_folds]==nil or 
      params[:num_folds].to_i>1
    
    cv_params = { :dataset_uri => params[:dataset_uri],  
                  :algorithm_uri => params[:algorithm_uri] }
    [ :num_folds, :random_seed, :stratified ].each{ |sym| cv_params[sym] = params[sym] if params[sym] }
    cv = Validation::Crossvalidation.new cv_params
    cv.create_cv_datasets( params[:prediction_feature] )
    cv.perform_cv( params[:algorithm_params])
    content_type "text/uri-list"
    cv.crossvalidation_uri
  end
  halt 202,task_uri
end

get '/training_test_split' do
  halt 400, "GET operation not supported, use POST to perform a training_test_split, see "+url_for("/", :full)+" for validation results"
end

get '/?' do
  LOGGER.info "list all validations"
  content_type "text/uri-list"
  params.each{ |k,v| halt 400,"no validation-attribute: "+k.to_s unless Validation::Validation.column_names.include?(k.gsub(/_like$/,""))  }
  Validation::Validation.find(:all, :conditions => params).collect{ |d| url_for("/", :full) + d.id.to_s }.join("\n")
end

get '/:id' do
  LOGGER.info "get validation with id "+params[:id].to_s+" '"+request.env['HTTP_ACCEPT'].to_s+"'"
  begin
    validation = Validation::Validation.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    halt 404, "Validation '#{params[:id]}' not found."
  end

  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    result = validation.to_rdf
  when /application\/x-yaml|\*\/\*|^$/ # matches 'application/x-yaml', '*/*', ''
    content_type "application/x-yaml"
    result = validation.to_yaml
  else
    halt 400, "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported, valid Accept-Headers are \"application/rdf+xml\" and \"application/x-yaml\"."
  end
  result
end

post '/?' do
  content_type "text/uri-list"
  task_uri = OpenTox::Task.as_task do |task|
    LOGGER.info "creating validation "+params.inspect
    if params[:model_uri] and params[:test_dataset_uri] and !params[:training_dataset_uri] and !params[:algorithm_uri]
      v = Validation::Validation.new :model_uri => params[:model_uri], 
                       :test_dataset_uri => params[:test_dataset_uri],
                       :test_target_dataset_uri => params[:test_target_dataset_uri],
                       :prediction_feature => params[:prediction_feature]
      v.validate_model
    elsif params[:algorithm_uri] and params[:training_dataset_uri] and params[:test_dataset_uri] and params[:prediction_feature] and !params[:model_uri]
     v = Validation::Validation.new :algorithm_uri => params[:algorithm_uri],
                        :training_dataset_uri => params[:training_dataset_uri], 
                        :test_dataset_uri => params[:test_dataset_uri],
                        :test_target_dataset_uri => params[:test_target_dataset_uri],
                        :prediction_feature => params[:prediction_feature]
     v.validate_algorithm( params[:algorithm_params]) 
    else
      halt 400, "illegal parameter combination for validation, use either\n"+
        "* model_uri, test_dataset_uri\n"+ 
        "* algorithm_uri, training_dataset_uri, test_dataset_uri, prediction_feature\n"+
        "params given: "+params.inspect
    end
    content_type "text/uri-list"
    v.validation_uri
  end
  halt 202,task_uri
end

post '/training_test_split' do
  content_type "text/uri-list"
  task_uri = OpenTox::Task.as_task do
    LOGGER.info "creating training test split "+params.inspect
    halt 400, "dataset_uri missing" unless params[:dataset_uri]
    halt 400, "algorithm_uri missing" unless params[:algorithm_uri]
    halt 400, "prediction_feature missing" unless params[:prediction_feature]
    
    params.merge!(Validation::Util.train_test_dataset_split(params[:dataset_uri], params[:prediction_feature], params[:split_ratio], params[:random_seed]))
    v = Validation::Validation.new :training_dataset_uri => params[:training_dataset_uri], 
                     :test_dataset_uri => params[:test_dataset_uri],
                     :test_target_dataset_uri => params[:dataset_uri],
                     :prediction_feature => params[:prediction_feature],
                     :algorithm_uri => params[:algorithm_uri]
    v.validate_algorithm( params[:algorithm_params])
    content_type "text/uri-list"
    v.validation_uri
  end
  halt 202,task_uri
end


post '/plain_training_test_split' do
    LOGGER.info "creating pure training test split "+params.inspect
    halt 400, "dataset_uri missing" unless params[:dataset_uri]
    
    result = Validation::Util.train_test_dataset_split(params[:dataset_uri], params[:prediction_feature], params[:split_ratio], params[:random_seed])
    content_type "text/uri-list"
    result[:training_dataset_uri]+"\n"+result[:test_dataset_uri]+"\n"
end

post '/validate_datasets' do
  content_type "text/uri-list"
  task_uri = OpenTox::Task.as_task do
    LOGGER.info "validating values "+params.inspect
    halt 400, "test_dataset_uri missing" unless params[:test_dataset_uri]
    halt 400, "prediction_datset_uri missing" unless params[:prediction_dataset_uri]
    
    if params[:model_uri]
      v = Validation::Validation.new params
      v.compute_validation_stats_with_model()
    else
      halt 400, "please specify 'model_uri' or 'prediction_feature'" unless params[:prediction_feature]
      halt 400, "please specify 'model_uri' or 'predicted_feature'" unless params[:predicted_feature]
      halt 400, "please specify 'model_uri' or set either 'classification' or 'regression' flag" unless 
            params[:classification] or params[:regression]
      
      predicted_feature = params.delete("predicted_feature")
      clazz = params.delete("classification")!=nil
      regr = params.delete("regression")!=nil
      v = Validation::Validation.new params            
      v.compute_validation_stats((clazz and !regr),predicted_feature)
    end
    content_type "text/uri-list"
    v.validation_uri
  end
  halt 202,task_uri
end

get '/:id/:attribute' do
  LOGGER.info "access validation attribute "+params.inspect
  begin
    validation = Validation::Validation.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    halt 404, "Validation '#{params[:id]}' not found."
  end
  begin
    raise unless validation.attribute_loaded?(params[:attribute])
  rescue
    halt 400, "Not a validation attribute: "+params[:attribute].to_s
  end
  content_type "text/plain"
  return validation.send(params[:attribute])
end

delete '/:id' do
  LOGGER.info "delete validation with id "+params[:id].to_s
  begin
    validation = Validation::Validation.find(params[:id])
  rescue ActiveRecord::RecordNotFound => ex
    halt 404, "Validation '#{params[:id]}' not found."
  end
  content_type "text/plain"
  Validation::Validation.delete(params[:id])
end