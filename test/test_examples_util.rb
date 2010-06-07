
module ValidationExamples
  
  class Util

    @@dataset_uris = {}

    def self.upload_dataset(file, dataset_service=@@config[:services]["opentox-dataset"], file_type="text/x-yaml")
      raise "File not found: "+file.path.to_s unless File.exist?(file.path)
      if @@dataset_uris[file.path.to_s]==nil
        data = File.read(file.path)
        data_uri = OpenTox::RestClientWrapper.post(dataset_service,{:content_type => file_type},data).to_s.chomp
        @@dataset_uris[file.path.to_s] = data_uri
        LOGGER.debug "uploaded dataset: "+data_uri
      else
        LOGGER.debug "file already uploaded: "+@@dataset_uris[file.path.to_s]
      end
      return @@dataset_uris[file.path.to_s]
    end
    
    def self.build_compare_report(validation_examples)
      
      @comp = validation_examples[0].algorithm_uri==nil ? :model_uri : :algorithm_uri
      return nil if @comp == :model_uri
      to_compare = []
      validation_examples.each do |v|
        to_compare << v.validation_uri if v.validation_uri and v.validation_error==nil
      end
      return nil if to_compare.size < 2
      begin
        return validation_post "report/algorithm_comparison",{ :validation_uris => to_compare.join("\n") }
      rescue => ex
        return "error creating comparison report "+ex.message
      end
    end
    
    def self.validation_post(uri, params)
      if $test_case
        #puts "posting: "+uri+","+params.inspect
        $test_case.post uri,params 
        return wait($test_case.last_response.body)
      else
        return OpenTox::RestClientWrapper.post(File.join(@@config[:services]["opentox-validation"],uri),params)
      end
    end
    
    def self.wait(uri)
      if OpenTox::Utils.task_uri?(uri)
        task = OpenTox::Task.find(uri)
        task.wait_for_completion
        raise "task failed: "+uri.to_s+", error is:\n"+task.description if task.error?
        uri = task.resultURI
      end
      uri
    end
    
  end
  
  class ValidationExample
    
    #params
    attr_accessor :name,
                  :prediction_feature,
                  :algorithm_uri,
                  :model_uri,
                  :test_dataset_uri,
                  :test_dataset_file,
                  :test_target_dataset_uri,
                  :test_target_dataset_file,
                  :training_dataset_uri,
                  :training_dataset_file,
                  :dataset_uri,
                  :dataset_file,
                  :algorithm_params,
                  :split_ratio,
                  :random_seed,
                  :num_folds,
                  :stratified
    #results                  
    attr_accessor :validation_uri,
                  :report_uri,
                  :validation_error,
                  :report_error
    
    def upload_files
      [[:test_dataset_uri, :test_dataset_file], 
       [:test_target_dataset_uri, :test_target_dataset_file],
       [:training_dataset_uri, :training_dataset_file],
       [:dataset_uri, :dataset_file]].each do |a|
         uri = a[0]
         file = a[1]
         if send(uri)==nil and send(file)!=nil
            send("#{uri.to_s}=".to_sym, Util.upload_dataset(send(file)))
         end
      end
    end
      
    def check_requirements
      params.each do |r|
        raise "values not set: "+r.to_s if send(r)==nil
      end
    end
    
    def report
      begin
        @report_uri = Util.validation_post '/report/'+report_type,{:validation_uris => @validation_uri}
      rescue => ex
        @report_error = ex.message
      end
    end
    
    def validate
      begin
        @validation_uri = Util.validation_post '/'+validation_type, get_params
      rescue => ex
        @validation_error = ex.message
        LOGGER.error ex.message
      end
    end
    
    def title
      self.class.humanize
    end
    
    protected
    def report_type
      "validation"
    end
    
    def validation_type
      ""
    end
    
    def get_params
      p = {}
      ( params + opt_params ).each do |pp|
        p[pp] = send(pp) if send(pp)!=nil
      end
      return p
    end
  end
  
  class ModelValidation < ValidationExample
    
    def params
      [:model_uri, :test_dataset_uri]
    end
    
    def opt_params
      [ :prediction_feature, :test_target_dataset_uri ]
    end
  end
  
  class TrainingTestValidation < ValidationExample
    def params
      [:algorithm_uri, :training_dataset_uri, :test_dataset_uri, :prediction_feature]
    end
    
    def opt_params
      [ :algorithm_params, :test_target_dataset_uri ]
    end
  end
  
  class SplitTestValidation < ValidationExample
    def params
      [:algorithm_uri, :dataset_uri, :prediction_feature]
    end
    
    def opt_params
      [ :algorithm_params, :split_ratio, :random_seed ]
    end
    
    def validation_type
      "training_test_split"
    end
  end
  
  class CrossValidation < ValidationExample
    def params
      [:algorithm_uri, :dataset_uri, :prediction_feature]
    end
    
    def opt_params
      [ :algorithm_params, :num_folds, :stratified, :random_seed ]
    end
    
    def report_type
      "crossvalidation"
    end
    
    def validation_type
      "crossvalidation"
    end
  end
end