

require "rdf/redland"

require "lib/validation_db.rb"
require "lib/ot_predictions.rb"

require "validation/validation_format.rb"


class Array
  
  # cuts an array into <num-pieces> chunks
  def chunk(pieces)
    q, r = length.divmod(pieces)
    (0..pieces).map { |i| i * q + [r, i].min }.enum_cons(2) \
    .map { |a, b| slice(a...b) }
  end

  # shuffles the elements of an array
  def shuffle( seed=nil )
    srand seed.to_i if seed
    sort_by { rand }
  end

  # shuffels self
  def shuffle!( seed=nil )
    self.replace shuffle( seed )
  end

end

module Validation

  class Validation < Lib::Validation
      
    # constructs a validation object, Rsets id und uri
    def initialize( params={} )
      $sinatra.halt 500,"do not set id manually" if params[:id]
      $sinatra.halt 500,"do not set uri manually" if params[:uri]
      super params
      # hack to overcome datamapper bug: save to set id
      OpenTox.Utils.try_again do
        unless save
          raise "error saving validation "+errors.inspect
        end
        raise "internal error, validation-id not set "+to_yaml unless @id
      end
      update :uri => $sinatra.url_for("/"+@id.to_s, :full)
    end
    
    # deletes a validation
    # PENDING: model and referenced datasets are deleted as well, keep it that way?
    def delete
    
      model = OpenTox::Model::PredictionModel.find(@model_uri) if @model_uri
      model.destroy if model
      
      #[@test_dataset_uri, @training_dataset_uri, @prediction_dataset_uri].each do  |d|
        #dataset = OpenTox::Dataset.find(d) if d 
        #dataset.delete if dataset
      #end
      destroy
      "Successfully deleted validation "+@id.to_s+"."
    end
    
    # validates an algorithm by building a model and validating this model
    def validate_algorithm( algorithm_params=nil )
      
      $sinatra.halt 404, "no algorithm uri: '"+algorithm_uri.to_s+"'" if @algorithm_uri==nil or @algorithm_uri.to_s.size<1
      
      params = { :dataset_uri => @training_dataset_uri, :prediction_feature => @prediction_feature }
      if (algorithm_params!=nil)
        algorithm_params.split(";").each do |alg_params|
          alg_param = alg_params.split("=")
          #puts "param "+alg_param.to_s
          $sinatra.halt 404, "invalid algorithm param: '"+alg_params.to_s+"'" unless alg_param.size==2 or alg_param[0].to_s.size<1 or alg_param[1].to_s.size<1
          LOGGER.warn "algorihtm param contains empty space, encode? "+alg_param[1].to_s if alg_param[1] =~ /\s/
          params[alg_param[0].to_sym] = alg_param[1]
        end
      end
      LOGGER.debug "building model '"+algorithm_uri.to_s+"' "+params.inspect
      
      model = OpenTox::Model::PredictionModel.build(algorithm_uri, params)
      $sinatra.halt 500,"model building failed" unless model
      update :model_uri => model.uri
      
      $sinatra.halt 500,"error after building model: model.dependent_variable != validation.prediciton_feature ("+
        model.dependentVariables.to_s+" != "+@prediction_feature+")" if @prediction_feature!=model.dependentVariables
          
      validate_model
    end
    
    # validates a model
    # PENDING: a new dataset is created to store the predictions, this should be optional: delete predictions afterwards yes/no
    def validate_model
      
      LOGGER.debug "validating model '"+@model_uri+"'"
      
      #test_dataset = OpenTox::Dataset.find @test_dataset_uri
      #$sinatra.halt 400, "test dataset no found: "+@test_dataset_uri.to_s unless test_dataset
      
      model = OpenTox::Model::PredictionModel.find(@model_uri)
      $sinatra.halt 400, "model not found: "+@model_uri.to_s unless model
      
      unless @algorithm_uri
        update :algorithm_uri => model.algorithm
      end
      
      if @prediction_feature
        $sinatra.halt 400, "error validating model: model.dependent_variable != validation.prediciton_feature ("+
          model.dependentVariables+" != "+@prediction_feature+")" if @prediction_feature!=model.dependentVariables
      else
        $sinatra.halt 400, "model has no dependentVariables specified, please give prediction feature for model validation" unless model.dependentVariables
        update :prediction_feature => model.dependentVariables
      end
      
      prediction_dataset_uri = ""
      benchmark = Benchmark.measure do 
        prediction_dataset_uri = model.predict_dataset(@test_dataset_uri)
      end
      update :prediction_dataset_uri => prediction_dataset_uri,
             :real_runtime => benchmark.real
      
      compute_validation_stats(model)
    end
    
    def compute_validation_stats(model = nil)
      
      model = OpenTox::Model::PredictionModel.find(@model_uri) unless model
      $sinatra.halt 400, "model not found: "+@model_uri.to_s unless model
      
      update :prediction_feature => model.dependentVariables unless @prediction_feature
      update :algorithm_uri => model.algorithm unless @algorithm_uri
      
      LOGGER.debug "computing prediction stats"
      prediction = Lib::OTPredictions.new( model.classification?, 
        @test_dataset_uri, @test_target_dataset_uri, @prediction_feature, 
        @prediction_dataset_uri, model.predictedVariables )
      if prediction.classification?
        update :classification_statistics => prediction.compute_stats
      else
        update :regression_statistics => prediction.compute_stats
      end
      
      update :num_instances => prediction.num_instances,
             :num_without_class => prediction.num_without_class,
             :percent_without_class => prediction.percent_without_class,
             :num_unpredicted => prediction.num_unpredicted,
             :percent_unpredicted => prediction.percent_unpredicted
    end
  end
  
  class Crossvalidation < Lib::Crossvalidation
    
    # constructs a crossvalidation, id and uri are set
    def initialize( params={} )
      
      $sinatra.halt 500,"do not set id manually" if params[:id]
      $sinatra.halt 500,"do not set uri manually" if params[:uri]
      super params
      # hack to overcome datamapper bug: save to set id
      unless save
        raise "error saving crossvalidation "+errors.inspect
      end
      $sinatra.halt 500,"internal error, crossvalidation-id not set" unless @id
      update :uri => $sinatra.url_for("/crossvalidation/"+@id.to_s, :full)
    end
    
    # deletes a crossvalidation, all validations are deleted as well
    def delete
        Validation.all(:crossvalidation_id => @id).each{ |v| v.delete }
        destroy
        "Successfully deleted crossvalidation "+@id.to_s+"."
    end
    
    # creates the cv folds
    # PENDING copying datasets of an equal (same dataset, same params) crossvalidation is disabled for now 
    def create_cv_datasets( prediction_feature )
  
       create_new_cv_datasets( prediction_feature ) #unless copy_cv_datasets( prediction_feature )
    end
    
    # executes the cross-validation (build models and validates them)
    def perform_cv ( algorithm_params=nil )
      
      LOGGER.debug "perform cv validations"
      Validation.all( :crossvalidation_id => id ).each do |v|
        v.validate_algorithm( algorithm_params )
        #break
      end
    end
    
    private
    # copies datasets from an older crossvalidation on the same dataset and the same folds
    # returns true if successfull, false otherwise
    def copy_cv_datasets( prediction_feature )
      
      equal_cvs = Crossvalidation.all( { :dataset_uri => @dataset_uri, :num_folds => @num_folds, 
                                          :stratified => @stratified, :random_seed => @random_seed } ).reject{ |cv| cv.id == @id }
      return false if equal_cvs.size == 0 
      cv = equal_cvs[0]
      Validation.all( :crossvalidation_id => cv.id ).each do |v|
        
        if @stratified and v.prediction_feature != prediction_feature
          return false;
        end
        unless (OpenTox::Dataset.find(v.training_dataset_uri) and 
              OpenTox::Dataset.find(v.test_dataset_uri))
          LOGGER.debug "dataset uris obsolete, aborting copy of datasets"
          Validation.all( :crossvalidation_id => @id ).each{ |v| v.delete }
          return false
        end
        validation = Validation.new :crossvalidation_id => @id,
                                    :crossvalidation_fold => v.crossvalidation_fold,
                                    :training_dataset_uri => v.training_dataset_uri, 
                                    :test_dataset_uri => v.test_dataset_uri,
                                    :algorithm_uri => @algorithm_uri
      end
      LOGGER.debug "copyied dataset uris from cv "+cv.uri.to_s
      return true
    end
    
    # creates cv folds (training and testdatasets)
    # stores uris in validation objects 
    def create_new_cv_datasets( prediction_feature )
      
      LOGGER.debug "creating datasets for crossvalidation"
      orig_dataset = OpenTox::Dataset.find(@dataset_uri)
      $sinatra.halt 400, "Dataset not found: "+@dataset_uri.to_s unless orig_dataset
      
      shuffled_compounds = orig_dataset.compounds.shuffle( @random_seed )
      
      unless @stratified        
        split_compounds = shuffled_compounds.chunk( @num_folds )
      else
        class_compounds = {} # "inactive" => compounds[], "active" => compounds[] .. 
        shuffled_compounds.each do |c|
          orig_dataset.features(c).each do |a|
            value = OpenTox::Feature.new(:uri => a.uri).value(prediction_feature).to_s
            class_compounds[value] = [] unless class_compounds.has_key?(value)
            class_compounds[value].push(c)
          end
        end
        LOGGER.debug "stratified cv: different class values: "+class_compounds.keys.join(", ")
        LOGGER.debug "stratified cv: num instances for each class value: "+class_compounds.values.collect{|c| c.size}.join(", ")
      
        split_class_compounds = [] # inactive_compounds[fold_i][], active_compounds[fold_i][], ..
        class_compounds.values.each do |compounds|
          split_class_compounds.push( compounds.chunk( @num_folds ) )
        end
        LOGGER.debug "stratified cv: splits for class values: "+split_class_compounds.collect{ |c| c.collect{ |cc| cc.size }.join("/") }.join(", ")
        
        # we cannot just merge the splits of the different class_values of each fold
        # this could lead to folds, which sizes differ for more than 1 compound
        split_compounds = []
        split_class_compounds.each do |split_comp|
          # step 1: sort current split in ascending order
          split_comp.sort!{|x,y| x.size <=> y.size }
          # step 2: add splits
          (0..@num_folds-1).each do |i|
            unless split_compounds[i]
              split_compounds[i] = split_comp[i]
            else
              split_compounds[i] += split_comp[i]
            end
          end
          # step 3: sort (total) split in descending order
          split_compounds.sort!{|x,y| y.size <=> x.size }
        end
      end
      LOGGER.debug "cv: num instances for each fold: "+split_compounds.collect{|c| c.size}.join(", ")
      
      test_features = orig_dataset.features.dclone - [prediction_feature]
      
      (1..@num_folds).each do |n|
        
        datasetname = 'cv'+@id.to_s +
               #'_d'+orig_dataset.name.to_s +
               '_f'+n.to_s+'of'+@num_folds.to_s+
               '_r'+@random_seed.to_s+
               '_s'+@stratified.to_s 
        source = $sinatra.url_for('/crossvalidation',:full)
        
        test_compounds = []
        train_compounds = []
        
        (1..@num_folds).each do |nn|
          compounds = split_compounds.at(nn-1)
          
          if n == nn
            compounds.each{ |compound| test_compounds.push(compound)}
          else
            compounds.each{ |compound| train_compounds.push(compound)}
          end 
        end
        
        $sinatra.halt 500,"internal error, num test compounds not correct" unless (shuffled_compounds.size/@num_folds - test_compounds.size).abs <= 1 
        $sinatra.halt 500,"internal error, num train compounds not correct" unless shuffled_compounds.size - test_compounds.size == train_compounds.size
        
        LOGGER.debug "training set: "+datasetname+"_train, compounds: "+train_compounds.size.to_s
        train_dataset_uri = orig_dataset.create_new_dataset( train_compounds, orig_dataset.features, datasetname + '_train', source ) 
        
        LOGGER.debug "test set:     "+datasetname+"_test, compounds: "+test_compounds.size.to_s
        test_dataset_uri = orig_dataset.create_new_dataset( test_compounds, test_features, datasetname + '_test', source )
      
        validation = Validation.new :training_dataset_uri => train_dataset_uri, 
                                    :test_dataset_uri => test_dataset_uri,
                                    :test_target_dataset_uri => @dataset_uri,
                                    :crossvalidation_id => @id, :crossvalidation_fold => n,
                                    :prediction_feature => prediction_feature,
                                    :algorithm_uri => @algorithm_uri
      end
    end
  end
  
  
  module Util
    
    # splits a dataset into test and training dataset
    # returns map with training_dataset_uri and test_dataset_uri
    def self.train_test_dataset_split( orig_dataset_uri, prediction_feature, split_ratio=nil, random_seed=nil )
      
      split_ratio=0.67 unless split_ratio
      random_seed=1 unless random_seed
      
      orig_dataset = OpenTox::Dataset.find orig_dataset_uri
      $sinatra.halt 400, "Dataset not found: "+orig_dataset_uri.to_s unless orig_dataset
      $sinatra.halt 400, "Split ratio invalid: "+split_ratio.to_s unless split_ratio and split_ratio=split_ratio.to_f
      $sinatra.halt 400, "Split ratio not >0 and <1 :"+split_ratio.to_s unless split_ratio>0 && split_ratio<1
      if prediction_feature
        $sinatra.halt 400, "Prediction feature '"+prediction_feature.to_s+
          "' not found in dataset, features are: \n"+
          orig_dataset.features.inspect unless orig_dataset.features.include?(prediction_feature)
      else
        LOGGER.warn "no prediciton feature given, all features included in test dataset"
      end
      
      compounds = orig_dataset.compounds
      $sinatra.halt 400, "Cannot split datset, num compounds in dataset < 2 ("+compounds.size.to_s+")" if compounds.size<2
      split = (compounds.size*split_ratio).to_i
      split = [split,1].max
      split = [split,compounds.size-2].min
      
      LOGGER.debug "splitting dataset "+orig_dataset_uri+
                    " into train:0-"+split.to_s+" and test:"+(split+1).to_s+"-"+(compounds.size-1).to_s+
                    " (shuffled with seed "+random_seed.to_s+")"
      
      compounds.shuffle!( random_seed )
      train_compounds = compounds[0..split]
      test_compounds = compounds[(split+1)..-1]
      
      result = {}
      {:training_dataset_uri => train_compounds, :test_dataset_uri => test_compounds}.each do |sym, compound_array|
        
        if sym == :training_dataset_uri
          features = orig_dataset.features
          title = "Training dataset split of "+orig_dataset.title.to_s
        else
          features = orig_dataset.features.dclone - [prediction_feature]
          title = "Test dataset split of "+orig_dataset.title.to_s
        end
        source = $sinatra.url_for('/training_test_split',:full)
        
        result[sym] = orig_dataset.create_new_dataset( compound_array, features, title, source )
      end
      
      $sinatra.halt 400, "Training dataset not found: '"+result[:training_dataset_uri].to_s+"'" unless OpenTox::Dataset.find result[:training_dataset_uri]
      $sinatra.halt 400, "Test dataset not found: '"+result[:test_dataset_uri].to_s+"'" unless OpenTox::Dataset.find result[:test_dataset_uri]
      
      LOGGER.debug "split done, training dataset: '"+result[:training_dataset_uri].to_s+"', test dataset: '"+result[:test_dataset_uri].to_s+"'"
      
      return result
    end
  
  end

end

