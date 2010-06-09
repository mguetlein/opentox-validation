
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
    
    def self.validation_get(uri, accept_header='application/rdf+xml')
      if $test_case
        #puts "getting "+uri+","+accept_header
        $test_case.get uri,nil,'HTTP_ACCEPT' => accept_header 
        return wait($test_case.last_response.body)
      else
        return OpenTox::RestClientWrapper.get(File.join(@@config[:services]["opentox-validation"],uri),{:accept => accept_header})
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
    
    def self.verify_crossvalidation(val_yaml)
      
      val = YAML.load(val_yaml)
      puts val.inspect
      
      assert_integer val["random_seed".to_sym],nil,nil,"random_seed"
      assert_boolean val["stratified".to_sym],"stratified"
      assert_integer val["num_folds".to_sym],0,1000,"num_folds"
      num_folds = val["num_folds".to_sym].to_i
      
      validations = val["validations".to_sym]
      assert_int_equal(num_folds, validations.size, "num_folds != validations.size")
    end
    
    def self.verify_validation(val_yaml)
    
      val = YAML.load(val_yaml)
  
      puts val.inspect
      assert_integer val["num_instances".to_sym],0,1000,"num_instances"
      num_instances = val["num_instances".to_sym].to_i
      
      assert_integer val["num_unpredicted".to_sym],0,num_instances,"num_unpredicted"
      num_unpredicted = val["num_unpredicted".to_sym].to_i
      assert_float val["percent_unpredicted".to_sym],0,100
      assert_float_equal(val["percent_unpredicted".to_sym].to_f,100*num_unpredicted/num_instances.to_f,"percent_unpredicted")
      
      assert_integer val["num_without_class".to_sym],0,num_instances,"num_without_class"
      num_without_class = val["num_without_class".to_sym].to_i
      assert_float val["percent_without_class".to_sym],0,100
      assert_float_equal(val["percent_without_class".to_sym].to_f,100*num_without_class/num_instances.to_f,"percent_without_class")
      
      class_stats = val["classification_statistics".to_sym]
      if class_stats
        class_value_stats = class_stats["class_value_statistics".to_sym]
        class_values = []
        class_value_stats.each do |cvs|
          class_values << cvs["class_value".to_sym]
        end
        puts class_values.inspect
        
        confusion_matrix = class_stats["confusion_matrix".to_sym]
        confusion_matrix_cells = confusion_matrix["confusion_matrix_cell".to_sym]
        predictions = 0
        confusion_matrix_cells.each do |confusion_matrix_cell|
          predictions += confusion_matrix_cell["confusion_matrix_value".to_sym].to_i
        end
        assert_int_equal(predictions, num_instances-num_unpredicted)
      else
        regr_stats = val["regression_statistics".to_sym]
        assert regr_stats!=nil
      end
    end
    
    private 
    def self.assert_int_equal(val1,val2,msg_suffix=nil)
      raise msg_suffix.to_s+" not equal: "+val1.to_s+" != "+val2.to_s unless val1==val2
    end
    
    def self.assert_float_equal(val1,val2,msg_suffix=nil,epsilon=0.0001)
      raise msg_suffix.to_s+" not equal: "+val1.to_s+" != "+val2.to_s+", diff:"+(val1-val2).abs.to_s unless (val1-val2).abs<epsilon
    end
    
    def self.assert_boolean(bool_val,prop=nil)
     raise "'"+bool_val.to_s+"' not an boolean "+prop.to_s unless bool_val.to_s=="true" or bool_val.to_s=="false"
    end
    
    def self.assert_integer(string_val, min=nil, max=nil, prop=nil)
      raise "'"+string_val.to_s+"' not an integer "+prop.to_s unless string_val.to_i.to_s==string_val.to_s
      raise unless string_val.to_i>=min if min!=nil
      raise unless string_val.to_i<=max if max!=nil
    end
    
    def self.assert_float(string_val, min=nil, max=nil)
      raise string_val.to_s+" not a float (!="+string_val.to_f.to_s+")" unless (string_val.to_f.to_s==string_val.to_s || (string_val.to_f.to_s==(string_val.to_s+".0")))
      raise unless string_val.to_f>=min if min!=nil
      raise unless string_val.to_f<=max if max!=nil
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
    
    def verify_yaml
      if @validation_uri =~ /crossvalidation/
        Util.verify_crossvalidation(Util.validation_get("crossvalidation/"+@validation_uri.split("/")[-1],'text/x-yaml'))
        Util.validation_get("crossvalidation/"+@validation_uri.split("/")[-1]+"/statistics",'text/x-yaml')
        Util.verify_validation(Util.validation_get("crossvalidation/"+@validation_uri.split("/")[-1]+"/statistics",'text/x-yaml'))
      else
        Util.verify_validation(Util.validation_get(@validation_uri.split("/")[-1],'text/x-yaml'))
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