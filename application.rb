
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'dm-core', 'opentox-ruby-api-wrapper', 'datamapper', 'logger', 'opentox-validation-lib' ].each do |lib|
  require lib
end

load 'validation_service.rb'


# hack: store self in $sinatra to make url_for method accessible in validation_service
# (before is executed in every rest call, problem is that the request object is not set, until the first rest-call )
before {$sinatra = self unless $sinatra}
LOGGER = Logger.new(STDOUT)
LOGGER.datetime_format = "%Y-%m-%d %H:%M:%S "

class Sinatra::Base
  # logging halts (!= 202)
  def halt(status,msg)
    LOGGER.error "halt "+status.to_s+" "+msg.to_s if (status != 202)
    throw :halt, [status, msg] 
  end
end


## REST API
get '/crossvalidations/?' do
  LOGGER.info "list all crossvalidations"
  Crossvalidation.all.collect{ |d| url_for("/crossvalidation/", :full) + d.id.to_s }.join("\n")
end

get '/crossvalidation/:id' do
  LOGGER.info "get crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Crossvalidation.get(params[:id])
  halt 202, crossvalidation.to_yaml  unless crossvalidation.finished
  crossvalidation.to_yaml
end

delete '/crossvalidation/:id/?' do
  LOGGER.info "delete crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Crossvalidation.get(params[:id])
  crossvalidation.delete
end

get '/crossvalidation/:id/validations' do
  LOGGER.info "get all validations for crossvalidation with id "+params[:id].to_s
  halt 404, "Crossvalidation #{params[:id]} not found." unless crossvalidation = Crossvalidation.get(params[:id])
  Validation.all(:crossvalidation_id => params[:id]).collect{ |v| v.uri.to_s }.join("\n")+"\n"
end

post '/crossvalidation/?' do
  LOGGER.info "creating crossvalidation "+params.inspect
  halt 400, "alogrithm_uri and/or dataset_uri missing: "+params.inspect unless params[:dataset_uri] and params[:algorithm_uri]
  cv_params = { :dataset_uri => params[:dataset_uri],  
                :algorithm_uri => params[:algorithm_uri] }
  [ :num_folds, :random_seed, :stratified ].each{ |sym| cv_params[sym] = params[sym] if params[sym] }
  cv = Crossvalidation.new cv_params
  cv.create_cv_datasets
  cv.perform_cv params[:feature_service_uri]
  cv.uri
end

get '/validations/?' do
  LOGGER.info "list all validations"
  Validation.all.collect{ |d| url_for("/validation/", :full) + d.id.to_s }.join("\n")
end

get '/validation/:id' do
  LOGGER.info "get validation with id "+params[:id].to_s
  halt 404, "Validation #{params[:id]} not found." unless validation = Validation.get(params[:id])
  halt 202, validation.to_yaml  unless validation.finished
  validation.to_yaml
end

post '/validation/?' do
  LOGGER.info "creating validation "+params.inspect
  if params[:model_uri] and params[:test_dataset_uri] and !params[:training_dataset_uri] and !params[:algorithm_uri]
    v = Validation.new :model_uri => params[:model_uri], 
                     :test_dataset_uri => params[:test_dataset_uri]
    v.validate_model
  elsif params[:algorithm_uri] and params[:training_dataset_uri] and params[:test_dataset_uri] and !params[:model_uri]
   v = Validation.new :training_dataset_uri => params[:training_dataset_uri], 
                     :test_dataset_uri => params[:test_dataset_uri]
   v.validate_algorithm( params[:algorithm_uri], params[:feature_service_uri]) 
  else
    halt 400, "illegal param combination, use either (model_uri and test_dataset_uri) OR (algorithm_uri and training_dataset_uri and test_dataset_uri): "+params.inspect
  end
  
  v.uri
end

post '/validation/training_test_split' do
  LOGGER.info "creating training test split "+params.inspect
  halt 400, "dataset_uri missing" unless params[:dataset_uri]
  params.merge!(ValidationUtil.train_test_dataset_split(params[:dataset_uri], params[:split_ratio], params[:random_seed]))
  if (params[:algorithm_uri])
     v = Validation.new :training_dataset_uri => params[:training_dataset_uri], 
                     :test_dataset_uri => params[:test_dataset_uri]
     v.validate_algorithm( params[:algorithm_uri], params[:feature_service_uri]) 
  else
    v = Validation.new :training_dataset_uri => params[:training_dataset_uri], :test_dataset_uri => params[:test_dataset_uri] 
  end
  v.uri
end

get '/validation/:id/:attribute' do
  LOGGER.info "access validation attribute "+params.inspect
  halt 404, "Validation #{params[:id]} not found." unless validation = Validation.get(params[:id])
  begin
    raise unless validation.attribute_loaded?(params[:attribute])
  rescue
    halt 400, "Not a validation attribute: "+params[:attribute].to_s
  end
  return validation.send(params[:attribute])
end

delete '/validation/:id' do
  LOGGER.info "delete validation with id "+params[:id].to_s
  halt 404, "Validation #{params[:id]} not found." unless validation = Validation.get(params[:id])
  validation.delete
end



