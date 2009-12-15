

require "rdf/redland"

load "lib/validation_db.rb"
load "lib/ot_predictions.rb"

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


class Validation < Lib::Validation
  
  # overwrite to_yaml, as the crossvalidation settings should have their own 'sub-section'
  def to_yaml
    h = {}
    OpenTox::Validation::VAL_PROPS.each{|p| h[p] = self.send(p)}
    if crossvalidation_id
      cv = {}
      OpenTox::Validation::VAL_CV_PROPS.each{ |p| cv[p] = self.send(p)}
      h[OpenTox::Validation::VAL_CV_PROP] = cv
    end
    if classification_statistics 
      clazz = {}
      OpenTox::Validation::VAL_CLASS_PROPS.each{ |p| clazz[p] = classification_statistics[p]}
      h[OpenTox::Validation::VAL_CLASS_PROP] = clazz
    elsif regression_statistics
      regr = {}
      OpenTox::Validation::VAL_REGR_PROPS.each{ |p| regr[p] = regression_statistics[p]}
      h[OpenTox::Validation::VAL_REGR_PROP] = regr
    end
    h.to_yaml  
  end
  
  def to_rdf
    
    raise "not yet implemented"
  end
  
  # constructs a validation object, sets id und uri
  def initialize( params={} )
    
    raise "do not set id manually" if params[:id]
    raise "do not set uri manually" if params[:uri]
    super params
    save unless attribute_dirty?("id")
    raise "internal error, id not set "+to_yaml unless @id
    update :uri => $sinatra.url_for("/validation/"+@id.to_s, :full)
  end
  
  # deletes a validation
  # PENDING: model and referenced datasets are deleted as well, keep it that way?
  def delete
  
    model = OpenTox::Model::PredictionModel.find(@model_uri) if @model_uri
    model.destroy if model
    
    [@test_dataset_uri, @training_dataset_uri, @prediction_dataset_uri].each do  |d|
      dataset = OpenTox::Dataset.find(:uri => d) if d 
      dataset.delete if dataset
    end
    destroy
    "Successfully deleted validation "+@id.to_s+"."
  end
  
  # validates an algorithm by building a model and validating this model
  # PENDING: so far, feature_service_uri is used to construct a second dataset (first is training-dataset)
  def validate_algorithm( algorithm_uri, feature_service_uri=nil )
    
    LOGGER.debug "building model "+algorithm_uri.to_s+" "+prediction_feature.to_s+" "+feature_service_uri.to_s
    # PENDING: use prediction_feature to build model
    params = {}
    if feature_service_uri
      params[:activity_dataset_uri] = @training_dataset_uri
      params[:feature_dataset_uri] = RestClient.post feature_service_uri, :dataset_uri => @training_dataset_uri
    else
      params[:dataset_uri] = @training_dataset_uri
    end
    model = OpenTox::Model::PredictionModel.create algorithm_uri, params
    update :model_uri => model.uri
    validate_model
  end
  
  # validates a model
  # PENDING: a new dataset is created to store the predictions, this should be optional: STORE predictions yes/no
  def validate_model
    
    LOGGER.debug "validating model"
    test_dataset = OpenTox::Dataset.find(:uri => @test_dataset_uri)
    $sinatra.halt 400, "test dataset no found" unless test_dataset
    compounds = test_dataset.compounds
    $sinatra.halt 400, "no compounds to predict" unless compounds && compounds.size>0
    model = OpenTox::Model::LazarClassificationModel.new(@model_uri)
    
    prediction_dataset = OpenTox::Dataset.create!
    
    count = 1
    benchmark = Benchmark.measure do 
      compounds.each do |c|
        
        prediction = model.predict(c)
        LOGGER.debug "prediction "+count.to_s+"/"+compounds.size.to_s+" class: "+prediction.classification.to_s+", confidence: "+prediction.confidence.to_s+", compound: "+c.uri.to_s
        pred_feature = OpenTox::Feature.new(:name => "prediction", 
          @prediction_feature.to_sym => prediction.classification,
          :confidence => prediction.confidence)
        prediction_dataset.add({c.uri => [pred_feature.uri]}.to_yaml)
        count += 1
      end
    end
    
    LOGGER.debug "computing prediction stats"
    prediction = Lib::OTPredictions.new( @prediction_feature, @test_dataset_uri, prediction_dataset.uri )
    if prediction.classification?
      update :classification_statistics => prediction.compute_stats
    else
      update :regression_statistics => prediction.compute_stats
    end
    update :prediction_dataset_uri => prediction_dataset.uri, 
           :finished => true, 
           :real_runtime => benchmark.real,
           :num_instances => count,
           :num_without_class => prediction.num_without_class,
           :percent_without_class => prediction.percent_without_class,
           :num_unpredicted => prediction.num_unpredicted,
           :percent_unpredicted => prediction.percent_unpredicted
  end  
end

class Crossvalidation < Lib::Crossvalidation
  
  # constructs a crossvalidation, id and uri are set
  def initialize( params={} )
    
    raise "do not set id manually" if params[:id]
    raise "do not set uri manually" if params[:uri]
    super params
    save unless attribute_dirty?("id")
    raise "internal error, id not set" unless @id
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
  def perform_cv ( feature_service_uri=nil )
    
    LOGGER.debug "perform cv validations"
    Validation.all( :crossvalidation_id => id ).each do |v|
      v.validate_algorithm( @algorithm_uri, feature_service_uri )
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
      unless (OpenTox::Dataset.find(:uri => v.training_dataset_uri) and 
            OpenTox::Dataset.find(:uri => v.test_dataset_uri))
        LOGGER.debug "dataset uris obsolete, aborting copy of datasets"
        Validation.all( :crossvalidation_id => @id ).each{ |v| v.delete }
        return false
      end
      validation = Validation.new :crossvalidation_id => @id,
                                  :crossvalidation_fold => v.crossvalidation_fold,
                                  :training_dataset_uri => v.training_dataset_uri, 
                                  :test_dataset_uri => v.test_dataset_uri
    end
    LOGGER.debug "copyied dataset uris from cv "+cv.uri.to_s
    return true
  end
  
  # creates cv folds (training and testdatasets)
  # stores uris in validation objects 
  def create_new_cv_datasets( prediction_feature )
    
    LOGGER.debug "creating datasets for crossvalidation"
    orig_dataset = OpenTox::Dataset.find :uri => @dataset_uri
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
    
    (1..@num_folds).each do |n|
      
      datasetname = 'cv'+@id.to_s +
             #'_d'+orig_dataset.name.to_s +
             '_f'+n.to_s+'of'+@num_folds.to_s+
             '_r'+@random_seed.to_s+
             '_s'+@stratified.to_s 
      
      test_data = {}
      train_data = {}
      
      (1..@num_folds).each do |nn|
        compounds = split_compounds.at(nn-1)
        
        if n == nn
          compounds.each{ |compound| test_data[compound.uri] = orig_dataset.feature_uris(compound)}
        else
          compounds.each{ |compound| train_data[compound.uri] = orig_dataset.feature_uris(compound)}
        end 
      end
      
      raise "internal error, num test compounds not correct" unless (shuffled_compounds.size/@num_folds - test_data.size).abs <= 1 
      raise "internal error, num train compounds not correct" unless shuffled_compounds.size - test_data.size == train_data.size
      
      LOGGER.debug "training set: "+datasetname+"_train"
      train_dataset = OpenTox::Dataset.create(:name => datasetname + '_train')
      train_dataset.add_compounds(train_data.to_yaml)
      
      LOGGER.debug "test set:     "+datasetname+"_test"
      test_dataset = OpenTox::Dataset.create(:name => datasetname + '_test')
      test_dataset.add_compounds(test_data.to_yaml)
    
      validation = Validation.new :training_dataset_uri => train_dataset.uri.to_s, 
                                  :test_dataset_uri => test_dataset.uri.to_s,
                                  :crossvalidation_id => @id, :crossvalidation_fold => n,
                                  :prediction_feature => prediction_feature
    end
  end
end


module ValidationUtil

  # splits a dataset into test and training dataset
  # returns map with training_dataset_uri and test_dataset_uri
  def self.train_test_dataset_split( orig_dataset_uri, split_ratio=nil, random_seed=nil )
    
    split_ratio=0.67 unless split_ratio
    random_seed=1 unless random_seed
    
    orig_dataset = OpenTox::Dataset.find :uri => orig_dataset_uri
    $sinatra.halt 400, "Dataset not found: "+orig_dataset_uri.to_s unless orig_dataset
    $sinatra.halt 400, "split ratio invalid: "+split_ratio unless split_ratio and split_ratio=split_ratio.to_f
    $sinatra.halt 400, "split ratio not >0 and <1" unless split_ratio>0 && split_ratio<1
    
    compounds = orig_dataset.compounds
    $sinatra.halt 400, "Dataset size < 2" if compounds.size<2
    split = (compounds.size*split_ratio).to_i
    split = [split,1].max
    split = [split,compounds.size-2].min
    
    LOGGER.debug "splitting shuffled "+orig_dataset_uri+
                  " into train:0-"+split.to_s+" and test:"+(split+1).to_s+"-"+(compounds.size-1).to_s+
                  " (seed "+random_seed.to_s+")"
    
    compounds.shuffle!( random_seed )
    train_compounds = compounds[0..split]
    test_compounds = compounds[(split+1)..-1]
    
    result = {}
    {"training_dataset_uri" => train_compounds, "test_dataset_uri" => test_compounds}.each do |sym, cc|
      
      data = {} 
      cc.each do |c|
        data[c.uri] = orig_dataset.feature_uris(c)
      end
      dataset = OpenTox::Dataset.create!
      dataset.add_compounds(data.to_yaml)
      result[sym] = dataset.uri
    end
    return result
  end

end



