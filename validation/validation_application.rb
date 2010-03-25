
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'sinatra/respond_to', 'opentox-ruby-api-wrapper', 'logger' ].each do |lib|
  require lib
end

require 'validation/validation_service.rb'
require 'lib/merge.rb'

# hack: store self in $sinatra to make url_for method accessible in validation_service
# (before is executed in every rest call, problem is that the request object is not set, until the first rest-call )
before {$sinatra = self unless $sinatra}

class Sinatra::Base
  # overwriting halt to log halts (!= 202)
  def halt(status,msg)
    LOGGER.error "halt "+status.to_s+" "+msg.to_s if (status != 202)
    throw :halt, [status, msg] 
  end
end

get '/crossvalidation/?' do
  LOGGER.info "list all crossvalidations"
  
  content_type "text/uri-list"
  Validation::Crossvalidation.all.collect{ |d| url_for("/crossvalidation/", :full) + d.id.to_s }.join("\n")
end

post '/crossvalidation/loo/?' do
  halt 500, "not yet implemented"
end

get '/crossvalidation/loo/?' do
  halt 400, "GET operation not supported, use POST for performing a loo-crossvalidation, see "+url_for("/crossvalidation", :full)+" for crossvalidation results"
end

get '/crossvalidation/:id' do
  LOGGER.info "get crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Validation::Crossvalidation.get(params[:id])
  
  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    result = crossvalidation.to_rdf
  when /text\/x-yaml|\*\/\*|/ # matches 'text/x-yaml', '*/*', ''
    content_type "text/x-yaml"
    result = crossvalidation.to_yaml
  else
    halt 400, "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported."
  end
  result
end

delete '/crossvalidation/:id/?' do
  LOGGER.info "delete crossvalidation with id "+params[:id].to_s
  content_type "text/plain"
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Validation::Crossvalidation.get(params[:id])
  crossvalidation.delete
end

get '/crossvalidation/:id/validations' do
  LOGGER.info "get all validations for crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Validation::Crossvalidation.get(params[:id])
  content_type "text/uri-list"
  Validation::Validation.all(:crossvalidation_id => params[:id]).collect{ |v| v.uri.to_s }.join("\n")+"\n"
end


get '/crossvalidation/:id/statistics' do
  LOGGER.info "get merged validation-result for crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Validation::Crossvalidation.get(params[:id])
  
  Lib::MergeObjects.register_merge_attributes( Validation::Validation,
    Lib::VAL_MERGE_AVG,Lib::VAL_MERGE_SUM,Lib::VAL_MERGE_GENERAL) unless 
      Lib::MergeObjects.merge_attributes_registered?(Validation::Validation)
  
  v = Lib::MergeObjects.merge_array_objects( Validation::Validation.all(:crossvalidation_id => params[:id]) )
  v.uri = nil
  v.created_at = nil
  v.id = nil
  content_type "text/x-yaml"
  v.to_yaml
end


post '/crossvalidation/?' do
  OpenTox::Task.as_task do
    LOGGER.info "creating crossvalidation "+params.inspect
    halt 400, "dataset_uri missing" unless params[:dataset_uri]
    halt 400, "algorithm_uri missing" unless params[:algorithm_uri]
    halt 400, "prediction_feature missing" unless params[:prediction_feature]
    cv_params = { :dataset_uri => params[:dataset_uri],  
                  :algorithm_uri => params[:algorithm_uri] }
    [ :num_folds, :random_seed, :stratified ].each{ |sym| cv_params[sym] = params[sym] if params[sym] }
    cv = Validation::Crossvalidation.new cv_params
    cv.create_cv_datasets( params[:prediction_feature] )
    cv.perform_cv( params[:algorithm_params])
    content_type "text/uri-list"
    cv.uri
  end
end

get '/training_test_split' do
  halt 400, "GET operation not supported, use POST to perform a training_test_split, see "+url_for("/", :full)+" for validation results"
end

get '/?' do
  LOGGER.info "list all validations"
  content_type "text/uri-list"
  Validation::Validation.all.collect{ |d| url_for("/", :full) + d.id.to_s }.join("\n")
end

get '/:id' do
  LOGGER.info "get validation with id "+params[:id].to_s+" '"+request.env['HTTP_ACCEPT'].to_s+"'"
  halt 404, "Validation '#{params[:id]}' not found." unless validation = Validation::Validation.get(params[:id])
  
  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    content_type "application/rdf+xml"
    result = validation.to_rdf
  when /text\/x-yaml|\*\/\*|/ # matches 'text/x-yaml', '*/*', ''
    content_type "text/x-yaml"
    result = validation.to_yaml
  else
    halt 400, "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported."
  end
  result
end

post '/?' do
  OpenTox::Task.as_task do
    LOGGER.info "creating validation "+params.inspect
    if params[:model_uri] and params[:test_dataset_uri] and !params[:training_dataset_uri] and !params[:algorithm_uri] and params[:prediction_feature]
      v = Validation::Validation.new :model_uri => params[:model_uri], 
                       :test_dataset_uri => params[:test_dataset_uri],
                       :prediction_feature => params[:prediction_feature]
      v.validate_model
    elsif params[:algorithm_uri] and params[:training_dataset_uri] and params[:test_dataset_uri] and params[:prediction_feature] and !params[:model_uri]
     v = Validation::Validation.new :training_dataset_uri => params[:training_dataset_uri], 
                        :test_dataset_uri => params[:test_dataset_uri],
                        :prediction_feature => params[:prediction_feature]
     v.validate_algorithm( params[:algorithm_uri], params[:algorithm_params]) 
    else
      halt 400, "illegal parameter combination for validation, use either\n"+
        "* model_uri, test_dataset_uri, prediction_feature\n"+ 
        "* algorithm_uri, training_dataset_uri, test_dataset_uri, prediction_feature\n"
        "params given: "+params.inspect
    end
    content_type "text/uri-list"
    v.uri
  end
end

post '/training_test_split' do
  OpenTox::Task.as_task do
    LOGGER.info "creating training test split "+params.inspect
    halt 400, "dataset_uri missing" unless params[:dataset_uri]
    halt 400, "algorithm_uri missing" unless params[:algorithm_uri]
    halt 400, "prediction_feature missing" unless params[:prediction_feature]
    
    params.merge!(Validation::Util.train_test_dataset_split(params[:dataset_uri], params[:split_ratio], params[:random_seed]))
    v = Validation::Validation.new :training_dataset_uri => params[:training_dataset_uri], 
                     :test_dataset_uri => params[:test_dataset_uri],
                     :prediction_feature => params[:prediction_feature]
    content_type "text/uri-list"
    v.validate_algorithm( params[:algorithm_uri], params[:algorithm_params])
    content_type "text/uri-list"
    v.uri
  end
end

get '/:id/:attribute' do
  LOGGER.info "access validation attribute "+params.inspect
  halt 404, "Validation #{params[:id]} not found." unless validation = Validation::Validation.get(params[:id])
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
  halt 404, "Validation #{params[:id]} not found." unless validation = Validation::Validation.get(params[:id])
  content_type "text/plain"
  validation.delete
end