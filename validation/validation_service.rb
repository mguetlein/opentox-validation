

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
    sort_by { Kernel.rand }
  end

  # shuffels self
  def shuffle!( seed=nil )
    self.replace shuffle( seed )
  end

end

module Validation
  
  class Validation < Lib::Validation
      
    # constructs a validation object, Rsets id und uri
    #def initialize( params={} )
      #raise "do not set id manually" if params[:id]
      #params[:finished] = false
      #super params
      #self.save!
      #raise "internal error, validation-id not set "+to_yaml if self.id==nil
    #end
    
    # deletes a validation
    # PENDING: model and referenced datasets are deleted as well, keep it that way?
    def delete( delete_all=true )
      if (delete_all)
        to_delete = [:model_uri, :training_dataset_uri, :test_dataset_uri, :test_target_dataset_uri, :prediction_dataset_uri ]
        case self.validation_type
        when /test_set_validation/
          to_delete -= [ :model_uri, :training_dataset_uri, :test_dataset_uri, :test_target_dataset_uri ]
        when /bootstrapping/
          to_delete -= [ :test_target_dataset_uri ]
        when /training_test_validation/
          to_delete -=  [ :training_dataset_uri, :test_dataset_uri, :test_target_dataset_uri ]
        when /training_test_split/
          to_delete -= [ :test_target_dataset_uri ]
        when /validate_dataset/
          to_delete = []
        when /crossvalidation/
          to_delete -= [ :test_target_dataset_uri ]
        else
          raise "unknown dataset type"
        end
        to_delete.each do |attr|
          uri = self.send(attr)
          LOGGER.debug "also deleting "+attr.to_s+" : "+uri.to_s if uri
          begin
            OpenTox::RestClientWrapper.delete(uri, :subjectid => subjectid) if uri
          rescue => ex
            LOGGER.warn "could not delete "+uri.to_s+" : "+ex.message.to_s
          end
        end
      end
      self.destroy
      if (subjectid)
        begin
          res = OpenTox::Authorization.delete_policies_from_uri(validation_uri, subjectid)
          LOGGER.debug "Deleted validation policy: #{res}"
        rescue
          LOGGER.warn "Policy delete error for validation: #{validation_uri}"
        end
      end
      "Successfully deleted validation "+self.id.to_s+"."
    end
    
    # validates an algorithm by building a model and validating this model
    def validate_algorithm( algorithm_params=nil, task=nil )
      raise "validation_type missing" unless self.validation_type
      raise OpenTox::BadRequestError.new "no algorithm uri: '"+self.algorithm_uri.to_s+"'" if self.algorithm_uri==nil or self.algorithm_uri.to_s.size<1
      
      params = { :dataset_uri => self.training_dataset_uri, :prediction_feature => self.prediction_feature }
      if (algorithm_params!=nil)
        algorithm_params.split(";").each do |alg_params|
          alg_param = alg_params.split("=")
          raise OpenTox::BadRequestError.new "invalid algorithm param: '"+alg_params.to_s+"'" unless alg_param.size==2 or alg_param[0].to_s.size<1 or alg_param[1].to_s.size<1
          LOGGER.warn "algorihtm param contains empty space, encode? "+alg_param[1].to_s if alg_param[1] =~ /\s/
          params[alg_param[0].to_sym] = alg_param[1]
        end
      end
      LOGGER.debug "building model '"+algorithm_uri.to_s+"' "+params.inspect
      
      algorithm = OpenTox::Algorithm::Generic.new(algorithm_uri)
      params[:subjectid] = subjectid
      self.model_uri = algorithm.run(params, OpenTox::SubTask.create(task, 0, 33))
      
      #model = OpenTox::Model::PredictionModel.build(algorithm_uri, params, 
      #  OpenTox::SubTask.create(task, 0, 33) )
      
      raise "model building failed" unless model_uri
      #self.attributes = { :model_uri => model_uri }
      #self.save!
      
#      self.save if self.new?
#      self.update :model_uri => model_uri
      
      #raise "error after building model: model.dependent_variable != validation.prediciton_feature ("+
      #  model.dependentVariables.to_s+" != "+self.prediction_feature+")" if self.prediction_feature!=model.dependentVariables
          
      validate_model OpenTox::SubTask.create(task, 33, 100)
    end
    
    # validates a model
    # PENDING: a new dataset is created to store the predictions, this should be optional: delete predictions afterwards yes/no
    def validate_model( task=nil )
      
      raise "validation_type missing" unless self.validation_type
      LOGGER.debug "validating model '"+self.model_uri+"'"
      
      #model = OpenTox::Model::PredictionModel.find(self.model_uri)
      #raise OpenTox::NotFoundError.new "model not found: "+self.model_uri.to_s unless model
      model = OpenTox::Model::Generic.find(self.model_uri, self.subjectid)
      
      unless self.algorithm_uri
#        self.attributes = { :algorithm_uri => model.algorithm }
#        self.save!
        #self.update :algorithm_uri => model.algorithm
        self.algorithm_uri = model.metadata[OT.algorithm]
      end
      
      if self.prediction_feature and model.uri=~/ambit2\/model/
        LOGGER.warn "REMOVE AMBIT HACK TO __NOT__ RELY ON DEPENDENT VARIABLE"        
      else
        dependentVariables = model.metadata[OT.dependentVariables]
        if self.prediction_feature
          raise OpenTox::NotFoundError.new "error validating model: model.dependent_variable != validation.prediction_feature ("+
            dependentVariables.to_s+" != "+self.prediction_feature+"), model-metadata is "+model.metadata.inspect if self.prediction_feature!=dependentVariables
        else
          raise OpenTox::NotFoundError.new "model has no dependentVariables specified, please give prediction feature for model validation" unless dependentVariables
          #self.attributes = { :prediction_feature => model.dependentVariables }
          #self.save!
          #self.update :prediction_feature => model.dependentVariables
          self.prediction_feature = model.metadata[OT.dependentVariables]
        end
      end
      
      prediction_dataset_uri = ""
      benchmark = Benchmark.measure do 
        #prediction_dataset_uri = model.predict_dataset(self.test_dataset_uri, OpenTox::SubTask.create(task, 0, 50))
        prediction_dataset_uri = model.run(
          {:dataset_uri => self.test_dataset_uri, :subjectid => self.subjectid},
          "text/uri-list",
          OpenTox::SubTask.create(task, 0, 50))
      end
#      self.attributes = { :prediction_dataset_uri => prediction_dataset_uri,
#             :real_runtime => benchmark.real }
#      self.save!
#      self.update :prediction_dataset_uri => prediction_dataset_uri,
#                  :real_runtime => benchmark.real
      self.prediction_dataset_uri = prediction_dataset_uri
      self.real_runtime = benchmark.real
             
      compute_validation_stats_with_model( model, false, OpenTox::SubTask.create(task, 50, 100) )
    end
      
    def compute_validation_stats_with_model( model=nil, dry_run=false, task=nil )
      
      #model = OpenTox::Model::PredictionModel.find(self.model_uri) if model==nil and self.model_uri
      #raise OpenTox::NotFoundError.new "model not found: "+self.model_uri.to_s unless model
      model = OpenTox::Model::Generic.find(self.model_uri, self.subjectid) if model==nil and self.model_uri
      raise OpenTox::NotFoundError.new "model not found: "+self.model_uri.to_s unless model
      
      dependentVariables = model.metadata[OT.dependentVariables]
      prediction_feature = self.prediction_feature ? nil : dependentVariables
      algorithm_uri = self.algorithm_uri ? nil : model.metadata[OT.algorithm]
      predictedVariables = model.metadata[OT.predictedVariables]
      compute_validation_stats( model.feature_type(self.subjectid), predictedVariables, 
        prediction_feature, algorithm_uri, dry_run, task )
    end
      
    def compute_validation_stats( feature_type, predicted_feature, prediction_feature=nil, 
        algorithm_uri=nil, dry_run=false, task=nil )
      
#      self.attributes = { :prediction_feature => prediction_feature } if self.prediction_feature==nil && prediction_feature
#      self.attributes = { :algorithm_uri => algorithm_uri } if self.algorithm_uri==nil && algorithm_uri
#      self.save!
#      self.update :prediction_feature => prediction_feature if self.prediction_feature==nil && prediction_feature
#      self.update :algorithm_uri => algorithm_uri if self.algorithm_uri==nil && algorithm_uri
      self.prediction_feature = prediction_feature if self.prediction_feature==nil && prediction_feature
      self.algorithm_uri = algorithm_uri if self.algorithm_uri==nil && algorithm_uri
      
      LOGGER.debug "computing prediction stats"
      prediction = Lib::OTPredictions.new( feature_type, 
        self.test_dataset_uri, self.test_target_dataset_uri, self.prediction_feature, 
        self.prediction_dataset_uri, predicted_feature, self.subjectid, OpenTox::SubTask.create(task, 0, 80) )
      #reading datasets and computing the main stats is 80% the work 
      
      unless dry_run
        case feature_type
        when "classification"
          #self.attributes = { :classification_statistics => prediction.compute_stats }
          #self.update :classification_statistics => prediction.compute_stats 
          self.classification_statistics = prediction.compute_stats
        when "regression"
          #self.attributes = { :regression_statistics => prediction.compute_stats }
          self.regression_statistics = prediction.compute_stats
        end
#        self.attributes = { :num_instances => prediction.num_instances,
#               :num_without_class => prediction.num_without_class,
#               :percent_without_class => prediction.percent_without_class,
#               :num_unpredicted => prediction.num_unpredicted,
#               :percent_unpredicted => prediction.percent_unpredicted,
#               :finished => true}
#        self.save!
        self.attributes= {:num_instances => prediction.num_instances,
               :num_without_class => prediction.num_without_class,
               :percent_without_class => prediction.percent_without_class,
               :num_unpredicted => prediction.num_unpredicted,
               :percent_unpredicted => prediction.percent_unpredicted,
               :finished => true}
        begin 
          self.save
        rescue DataMapper::SaveFailureError => e
           raise "could not save validation: "+e.resource.errors.inspect
        end
      end
      
      task.progress(100) if task
      prediction
    end
  end
  
  class Crossvalidation < Lib::Crossvalidation
    
    # constructs a crossvalidation, id and uri are set
    #def initialize( params={} )
    #  
    #  raise "do not set id manually" if params[:id]
    #  params[:num_folds] = 10 if params[:num_folds]==nil
    #  params[:random_seed] = 1 if params[:random_seed]==nil
    #  params[:stratified] = false if params[:stratified]==nil
    #  params[:finished] = false
    #  super params
    #  self.save!
    #  raise "internal error, crossvalidation-id not set" if self.id==nil
    #end
    
    def perform_cv ( prediction_feature, algorithm_params=nil, task=nil )
      
      create_cv_datasets( prediction_feature, OpenTox::SubTask.create(task, 0, 33) )
      perform_cv_validations( algorithm_params, OpenTox::SubTask.create(task, 33, 100) )
    end
    
    # deletes a crossvalidation, all validations are deleted as well
    def delete
        Validation.all(:crossvalidation_id => self.id).each do |v|
          v.subjectid = self.subjectid
          v.delete
        end
        self.destroy
        if (subjectid)
          begin
            res = OpenTox::Authorization.delete_policies_from_uri(crossvalidation_uri, subjectid)
            LOGGER.debug "Deleted crossvalidation policy: #{res}"
          rescue
            LOGGER.warn "Policy delete error for crossvalidation: #{crossvalidation_uri}"
          end
        end
        "Successfully deleted crossvalidation "+self.id.to_s+"."
    end
    
    # creates the cv folds
    def create_cv_datasets( prediction_feature, task=nil )
      if copy_cv_datasets( prediction_feature )
        # dataset folds of a previous crossvalidaiton could be used 
        task.progress(100) if task
      else
        create_new_cv_datasets( prediction_feature, task )
      end
    end
    
    # executes the cross-validation (build models and validates them)
    def perform_cv_validations( algorithm_params, task=nil )
      
      LOGGER.debug "perform cv validations "+algorithm_params.inspect
      i = 0
      task_step = 100 / self.num_folds.to_f;
      @tmp_validations.each do | val |
        validation = Validation.new val
        validation.subjectid = self.subjectid
        validation.validate_algorithm( algorithm_params, 
          OpenTox::SubTask.create(task, i * task_step, ( i + 1 ) * task_step) )
        raise "validation '"+validation.validation_uri+"' for crossvaldation could not be finished" unless 
          validation.finished
        i += 1
      end
      
#      self.attributes = { :finished => true }
#      self.save!
      #self.save if self.new?
      self.finished = true
      self.save
    end
    
    private
    # copies datasets from an older crossvalidation on the same dataset and the same folds
    # returns true if successfull, false otherwise
    def copy_cv_datasets( prediction_feature )
      
      cvs = Crossvalidation.all( { 
        :dataset_uri => self.dataset_uri, 
        :num_folds => self.num_folds, 
        :stratified => self.stratified, 
        :random_seed => self.random_seed,
        :finished => true} ).reject{ |cv| cv.id == self.id }
      cvs.each do |cv|
        next if AA_SERVER and !OpenTox::Authorization.authorized?(cv.crossvalidation_uri,"GET",self.subjectid)
        tmp_val = []
        Validation.all( :crossvalidation_id => cv.id ).each do |v|
          break unless 
            v.prediction_feature == prediction_feature and
            OpenTox::Dataset.exist?(v.training_dataset_uri,self.subjectid) and 
            OpenTox::Dataset.exist?(v.test_dataset_uri,self.subjectid)
          #make sure self.id is set
          self.save if self.new?
          tmp_val << { :validation_type => "crossvalidation",
                       :training_dataset_uri => v.training_dataset_uri, 
                       :test_dataset_uri => v.test_dataset_uri,
                       :test_target_dataset_uri => self.dataset_uri,
                       :crossvalidation_id => self.id,
                       :crossvalidation_fold => v.crossvalidation_fold,
                       :prediction_feature => prediction_feature,
                       :algorithm_uri => self.algorithm_uri }
        end
        if tmp_val.size == self.num_folds
          @tmp_validations = tmp_val
          LOGGER.debug "copied dataset uris from cv "+cv.crossvalidation_uri.to_s #+":\n"+tmp_val.inspect
          return true
        end
      end
      false
    end
    
    # creates cv folds (training and testdatasets)
    # stores uris in validation objects 
    def create_new_cv_datasets( prediction_feature, task = nil )
      
      raise "random seed not set "+self.inspect unless self.random_seed
      LOGGER.debug "creating datasets for crossvalidation"
      orig_dataset = OpenTox::Dataset.find(self.dataset_uri,self.subjectid)
      raise OpenTox::NotFoundError.new "Dataset not found: "+self.dataset_uri.to_s unless orig_dataset
      
      shuffled_compounds = orig_dataset.compounds.shuffle( self.random_seed )
      
      unless self.stratified        
        split_compounds = shuffled_compounds.chunk( self.num_folds )
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
          split_class_compounds.push( compounds.chunk( self.num_folds ) )
        end
        LOGGER.debug "stratified cv: splits for class values: "+split_class_compounds.collect{ |c| c.collect{ |cc| cc.size }.join("/") }.join(", ")
        
        # we cannot just merge the splits of the different class_values of each fold
        # this could lead to folds, which sizes differ for more than 1 compound
        split_compounds = []
        split_class_compounds.each do |split_comp|
          # step 1: sort current split in ascending order
          split_comp.sort!{|x,y| x.size <=> y.size }
          # step 2: add splits
          (0..self.num_folds-1).each do |i|
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
      
      test_features = orig_dataset.features.keys.dclone - [prediction_feature]
      
      @tmp_validations = []
      
      (1..self.num_folds).each do |n|
        
        datasetname = 'cv'+self.id.to_s +
               #'_d'+orig_dataset.name.to_s +
               '_f'+n.to_s+'of'+self.num_folds.to_s+
               '_r'+self.random_seed.to_s+
               '_s'+self.stratified.to_s 
        source = $url_provider.url_for('/crossvalidation',:full)
        
        test_compounds = []
        train_compounds = []
        
        (1..self.num_folds).each do |nn|
          compounds = split_compounds.at(nn-1)
          
          if n == nn
            compounds.each{ |compound| test_compounds.push(compound)}
          else
            compounds.each{ |compound| train_compounds.push(compound)}
          end 
        end
        
        raise "internal error, num test compounds not correct" unless (shuffled_compounds.size/self.num_folds - test_compounds.size).abs <= 1 
        raise "internal error, num train compounds not correct" unless shuffled_compounds.size - test_compounds.size == train_compounds.size
        
        LOGGER.debug "training set: "+datasetname+"_train, compounds: "+train_compounds.size.to_s
        #train_dataset_uri = orig_dataset.create_new_dataset( train_compounds, orig_dataset.features, datasetname + '_train', source ) 
        train_dataset_uri = orig_dataset.split( train_compounds, orig_dataset.features.keys, 
          { DC.title => datasetname + '_train', DC.creator => source }, self.subjectid ).uri
        
        LOGGER.debug "test set:     "+datasetname+"_test, compounds: "+test_compounds.size.to_s
        #test_dataset_uri = orig_dataset.create_new_dataset( test_compounds, test_features, datasetname + '_test', source )
        test_dataset_uri = orig_dataset.split( test_compounds, test_features, 
          { DC.title => datasetname + '_test', DC.creator => source }, self.subjectid ).uri
        
        #make sure self.id is set
        self.save if self.new?
        tmp_validation = { :validation_type => "crossvalidation",
                           :training_dataset_uri => train_dataset_uri, 
                           :test_dataset_uri => test_dataset_uri,
                           :test_target_dataset_uri => self.dataset_uri,
                           :crossvalidation_id => self.id, :crossvalidation_fold => n,
                           :prediction_feature => prediction_feature,
                           :algorithm_uri => self.algorithm_uri }
        @tmp_validations << tmp_validation
        
        task.progress( n / self.num_folds.to_f * 100 ) if task
      end
    end
  end
  
  
  module Util
    
    # splits a dataset into test and training dataset via bootstrapping
    # (training dataset-size is n, sampling from orig dataset with replacement)
    # returns map with training_dataset_uri and test_dataset_uri
    def self.bootstrapping( orig_dataset_uri, prediction_feature, subjectid, random_seed=nil, task=nil )
      
      random_seed=1 unless random_seed
      
      orig_dataset = OpenTox::Dataset.find orig_dataset_uri,subjectid
      orig_dataset.load_all
      raise OpenTox::NotFoundError.new "Dataset not found: "+orig_dataset_uri.to_s unless orig_dataset
      if prediction_feature
        raise OpenTox::NotFoundError.new "Prediction feature '"+prediction_feature.to_s+
          "' not found in dataset, features are: \n"+
          orig_dataset.features.inspect unless orig_dataset.features.include?(prediction_feature)
      else
        LOGGER.warn "no prediciton feature given, all features included in test dataset"
      end
      
      compounds = orig_dataset.compounds
      raise OpenTox::NotFoundError.new "Cannot split datset, num compounds in dataset < 2 ("+compounds.size.to_s+")" if compounds.size<2
      
      compounds.each do |c|
        raise OpenTox::NotFoundError.new "Bootstrapping not yet implemented for duplicate compounds" if
          orig_dataset.data_entries[c][prediction_feature].size > 1
      end
      
      srand random_seed.to_i
      while true
        training_compounds = []
        compounds.size.times do
          training_compounds << compounds[rand(compounds.size)]
        end
        test_compounds = []
        compounds.each do |c|
          test_compounds << c unless training_compounds.include?(c)
        end
        if test_compounds.size > 0
          break
        else
          srand rand(10000)
        end
      end
      
      LOGGER.debug "bootstrapping on dataset "+orig_dataset_uri+
                    " into training ("+training_compounds.size.to_s+") and test ("+test_compounds.size.to_s+")"+
                    ", duplicates in training dataset: "+test_compounds.size.to_s
      task.progress(33) if task
      
      result = {}
#      result[:training_dataset_uri] = orig_dataset.create_new_dataset( training_compounds,
#        orig_dataset.features, 
#        "Bootstrapping training dataset of "+orig_dataset.title.to_s, 
#        $sinatra.url_for('/bootstrapping',:full) )
      result[:training_dataset_uri] = orig_dataset.split( training_compounds,
        orig_dataset.features.keys, 
        { DC.title => "Bootstrapping training dataset of "+orig_dataset.title.to_s,
          DC.creator => $url_provider.url_for('/bootstrapping',:full) },
        subjectid ).uri
      task.progress(66) if task

#      result[:test_dataset_uri] = orig_dataset.create_new_dataset( test_compounds,
#        orig_dataset.features.dclone - [prediction_feature], 
#        "Bootstrapping test dataset of "+orig_dataset.title.to_s, 
#        $sinatra.url_for('/bootstrapping',:full) )
      result[:test_dataset_uri] = orig_dataset.split( test_compounds,
        orig_dataset.features.keys.dclone - [prediction_feature],
        { DC.title => "Bootstrapping test dataset of "+orig_dataset.title.to_s,
          DC.creator => $url_provider.url_for('/bootstrapping',:full)} ,
        subjectid ).uri
      task.progress(100) if task
      
      if ENV['RACK_ENV'] =~ /test|debug/
        training_dataset = OpenTox::Dataset.find result[:training_dataset_uri],subjectid
        raise OpenTox::NotFoundError.new "Training dataset not found: '"+result[:training_dataset_uri].to_s+"'" unless training_dataset
        training_dataset.load_all
        value_count = 0
        training_dataset.compounds.each do |c|
          value_count += training_dataset.data_entries[c][prediction_feature].size
        end
        raise  "training compounds error" unless value_count==training_compounds.size
        raise OpenTox::NotFoundError.new "Test dataset not found: '"+result[:test_dataset_uri].to_s+"'" unless 
          OpenTox::Dataset.find result[:test_dataset_uri], subjectid
      end
      LOGGER.debug "bootstrapping done, training dataset: '"+result[:training_dataset_uri].to_s+"', test dataset: '"+result[:test_dataset_uri].to_s+"'"
      
      return result
    end    
    
    # splits a dataset into test and training dataset
    # returns map with training_dataset_uri and test_dataset_uri
    def self.train_test_dataset_split( orig_dataset_uri, prediction_feature, subjectid, split_ratio=nil, random_seed=nil, task=nil )
      
      split_ratio=0.67 unless split_ratio
      random_seed=1 unless random_seed
      
      orig_dataset = OpenTox::Dataset.find orig_dataset_uri, subjectid
      orig_dataset.load_all subjectid
      raise OpenTox::NotFoundError.new "Dataset not found: "+orig_dataset_uri.to_s unless orig_dataset
      raise OpenTox::NotFoundError.new "Split ratio invalid: "+split_ratio.to_s unless split_ratio and split_ratio=split_ratio.to_f
      raise OpenTox::NotFoundError.new "Split ratio not >0 and <1 :"+split_ratio.to_s unless split_ratio>0 && split_ratio<1
      if prediction_feature
        raise OpenTox::NotFoundError.new "Prediction feature '"+prediction_feature.to_s+
          "' not found in dataset, features are: \n"+
          orig_dataset.features.keys.inspect unless orig_dataset.features.include?(prediction_feature)
      else
        LOGGER.warn "no prediciton feature given, all features included in test dataset"
      end
      
      compounds = orig_dataset.compounds
      raise OpenTox::BadRequestError.new "Cannot split datset, num compounds in dataset < 2 ("+compounds.size.to_s+")" if compounds.size<2
      split = (compounds.size*split_ratio).to_i
      split = [split,1].max
      split = [split,compounds.size-2].min
      
      LOGGER.debug "splitting dataset "+orig_dataset_uri+
                    " into train:0-"+split.to_s+" and test:"+(split+1).to_s+"-"+(compounds.size-1).to_s+
                    " (shuffled with seed "+random_seed.to_s+")"
      compounds.shuffle!( random_seed )
      task.progress(33) if task
      
      result = {}
#      result[:training_dataset_uri] = orig_dataset.create_new_dataset( compounds[0..split],
#        orig_dataset.features, 
#        "Training dataset split of "+orig_dataset.title.to_s, 
#        $sinatra.url_for('/training_test_split',:full) )

#      orig_dataset.data_entries.each do |k,v|
#        puts k.inspect+" =>"+v.inspect
#        puts v.values[0].to_s+" "+v.values[0].class.to_s
#      end

      result[:training_dataset_uri] = orig_dataset.split( compounds[0..split],
        orig_dataset.features.keys, 
        { DC.title => "Training dataset split of "+orig_dataset.title.to_s, 
          DC.creator => $url_provider.url_for('/training_test_split',:full) },
        subjectid ).uri
      task.progress(66) if task

#      d = OpenTox::Dataset.find(result[:training_dataset_uri])
#      d.data_entries.values.each do |v|
#        puts v.inspect
#        puts v.values[0].to_s+" "+v.values[0].class.to_s
#      end
#      raise "stop here"
      
#      result[:test_dataset_uri] = orig_dataset.create_new_dataset( compounds[(split+1)..-1],
#        orig_dataset.features.dclone - [prediction_feature], 
#        "Test dataset split of "+orig_dataset.title.to_s, 
#        $sinatra.url_for('/training_test_split',:full) )
      result[:test_dataset_uri] = orig_dataset.split( compounds[(split+1)..-1],
        orig_dataset.features.keys.dclone - [prediction_feature], 
        { DC.title => "Test dataset split of "+orig_dataset.title.to_s, 
          DC.creator => $url_provider.url_for('/training_test_split',:full) },
        subjectid ).uri
      task.progress(100) if task  
      
      if ENV['RACK_ENV'] =~ /test|debug/
        raise OpenTox::NotFoundError.new "Training dataset not found: '"+result[:training_dataset_uri].to_s+"'" unless 
          OpenTox::Dataset.find(result[:training_dataset_uri],subjectid)
        test_data = OpenTox::Dataset.find result[:test_dataset_uri],subjectid
        raise OpenTox::NotFoundError.new "Test dataset not found: '"+result[:test_dataset_uri].to_s+"'" unless test_data 
        test_data.load_compounds subjectid
        raise "Test dataset num coumpounds != "+(compounds.size-split-1).to_s+", instead: "+
          test_data.compounds.size.to_s+"\n"+test_data.to_yaml unless test_data.compounds.size==(compounds.size-1-split)
      end
      
      LOGGER.debug "split done, training dataset: '"+result[:training_dataset_uri].to_s+"', test dataset: '"+result[:test_dataset_uri].to_s+"'"
      return result
    end
  
  end

end

