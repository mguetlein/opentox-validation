
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'sinatra/respond_to', 'opentox-ruby-api-wrapper', 'logger' ].each do |lib|
  require lib
end

require 'validation/validation_service.rb'


# hack: store self in $sinatra to make url_for method accessible in validation_service
# (before is executed in every rest call, problem is that the request object is not set, until the first rest-call )
before {$sinatra = self unless $sinatra}
unless(defined? LOGGER)
  LOGGER = Logger.new(STDOUT)
  LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "
end

class Sinatra::Base
  # logging halts (!= 202)
  def halt(status,msg)
    LOGGER.error "halt "+status.to_s+" "+msg.to_s if (status != 202)
    throw :halt, [status, msg] 
  end
end

## REST API
get '/crossvalidation/?' do
  LOGGER.info "list all crossvalidations"
  Validation::Crossvalidation.all.collect{ |d| url_for("/crossvalidation/", :full) + d.id.to_s }.join("\n")
end

get '/crossvalidation/:id' do
  LOGGER.info "get crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Validation::Crossvalidation.get(params[:id])
  
  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    result = crossvalidation.to_rdf
  when /text\/x-yaml|\*\/\*|/ # matches 'text/x-yaml', '*/*', ''
    result = crossvalidation.to_yaml
  else
    halt 400, "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported."
  end
  
  halt 202, result unless crossvalidation.finished
  result
end

delete '/crossvalidation/:id/?' do
  LOGGER.info "delete crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Validation::Crossvalidation.get(params[:id])
  crossvalidation.delete
end

get '/crossvalidation/:id/validations' do
  LOGGER.info "get all validations for crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Validation::Crossvalidation.get(params[:id])
  Validation::Validation.all(:crossvalidation_id => params[:id]).collect{ |v| v.uri.to_s }.join("\n")+"\n"
end

post '/crossvalidation/?' do
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
  cv.uri
end

get '/?' do
  LOGGER.info "list all validations"
  Validation::Validation.all.collect{ |d| url_for("/", :full) + d.id.to_s }.join("\n")
end

get '/:id' do
  LOGGER.info "get validation with id "+params[:id].to_s+" '"+request.env['HTTP_ACCEPT'].to_s+"'"
  halt 404, "Validation '#{params[:id]}' not found." unless validation = Validation::Validation.get(params[:id])
  
  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    result = validation.to_rdf
  when /text\/x-yaml|\*\/\*|/ # matches 'text/x-yaml', '*/*', ''
    result = validation.to_yaml
  else
    halt 400, "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported."
  end
  
  halt 202, result unless validation.finished
  result
end

post '/?' do
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
  
  v.uri
end

post '/training_test_split' do
  LOGGER.info "creating training test split "+params.inspect
  halt 400, "dataset_uri missing" unless params[:dataset_uri]
  halt 400, "algorithm_uri missing" unless params[:algorithm_uri]
  halt 400, "prediction_feature missing" unless params[:prediction_feature]
  
  params.merge!(Validation::Util.train_test_dataset_split(params[:dataset_uri], params[:split_ratio], params[:random_seed]))
  v = Validation::Validation.new :training_dataset_uri => params[:training_dataset_uri], 
                   :test_dataset_uri => params[:test_dataset_uri],
                   :prediction_feature => params[:prediction_feature]
  v.validate_algorithm( params[:algorithm_uri], params[:algorithm_params]) 
  v.uri
end

get '/:id/:attribute' do
  LOGGER.info "access validation attribute "+params.inspect
  halt 404, "Validation #{params[:id]} not found." unless validation = Validation::Validation.get(params[:id])
  begin
    raise unless validation.attribute_loaded?(params[:attribute])
  rescue
    halt 400, "Not a validation attribute: "+params[:attribute].to_s
  end
  return validation.send(params[:attribute])
end

delete '/:id' do
  LOGGER.info "delete validation with id "+params[:id].to_s
  halt 404, "Validation #{params[:id]} not found." unless validation = Validation::Validation.get(params[:id])
  validation.delete
end