## SETUP
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'dm-core', 'dm-more', 'builder', 'opentox-ruby-api-wrapper' ].each do |lib|
	require lib
end

## MODELS

class CrossValidation
	include DataMapper::Resource
	property :id, Serial
	property :uri, String, :size => 255
	property :algorithm_uri, String, :size => 255
	property :dataset_uri, String, :size => 255
	has n, :validations

	def validation_folds
		# create folds from dataset_uri, return an array of validation objects with initialized training/test datasets
	end

end

class Validation
	include DataMapper::Resource
	property :id, Serial
	property :uri, String, :size => 255
	property :model_uri, String, :size => 255
	property :training_dataset_uri, String, :size => 255
	property :test_dataset_uri, String, :size => 255
	property :prediction_dataset_uri, String, :size => 255
	property :finished, Boolean, :default => false
	belongs_to :crossvalidation
end

sqlite = "#{File.expand_path(File.dirname(__FILE__))}/#{Sinatra::Base.environment}.sqlite3"
DataMapper.setup(:default, "sqlite3:///#{sqlite}")
DataMapper::Logger.new(STDOUT, 0)

unless FileTest.exists?("#{sqlite}")
	[CrossValidation, Validation].each do |model|
		model.auto_migrate!
	end
end

## REST API

get '/crossvalidations/?' do
	CrossValidation.all.collect{ |d| url_for("/", :full) + d.id.to_s }.join("\n")
end

get '/crossvalidation/:id' do
	halt 404, "CrossValidation #{params[:id]} not found." unless validation = CrossValidation.get(params[:id])
	halt 202, crossvalidation.to_yaml  unless crossvalidation.finished
	crossvalidation.to_yaml
end

post '/crossvalidation/?' do
	#protected!
	cv = CrossValidation.new( :algorithm_uri => params[:algorithm_uri], :dataset_uri => params[:dataset_uri] )
	Spork.spork do
		cv.validation_folds.each do |validation|
			model = OpenTox::Model.new(:algorithm_uri => cv.algorithm_uri, :dataset_uri => validation.training_dataset_uri)
			# wait until model is finished
			prediction_dataset = OpenTox::Dataset.new :name => "Validation #{validation.id} predictions"
			validation.training_set.compounds.each do |compound|
				prediction = model.predict compound
				# wait until prediction is finished
				feature = OpenTox::Feature.new :name => model.name, :values => {:prediction => prediction.classification, :confidence => prediction.confidence}
				prediction_dataset.add(:compound_uri => compound.uri, :feature_uri => feature.uri)
			end
			prediction_dataset.close
		end
	end
	cv.uri
end

get '/validations/?' do
	Validation.all.collect{ |d| url_for("/", :full) + d.id.to_s }.join("\n")
end

get '/validation/:id' do
	halt 404, "Validation #{params[:id]} not found." unless validation = Validation.get(params[:id])
	halt 202, validation.to_yaml  unless validation.finished
	validation.to_yaml
end

post '/validation/?' do
end
