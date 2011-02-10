
module ValidationExamples
  
  class Util

    @@dataset_uris = {}
    @@prediction_features = {}

    def self.upload_dataset(file, subjectid=nil, dataset_service=CONFIG[:services]["opentox-dataset"]) #, file_type="application/x-yaml")
      raise "File not found: "+file.path.to_s unless File.exist?(file.path)
      if @@dataset_uris[file.path.to_s]==nil
        LOGGER.debug "uploading file: "+file.path.to_s
        if (file.path =~ /yaml$/)
          data = File.read(file.path)
          #data_uri = OpenTox::RestClientWrapper.post(dataset_service,{:content_type => file_type},data).to_s.chomp
          #@@dataset_uris[file.path.to_s] = data_uri
          #LOGGER.debug "uploaded dataset: "+data_uri
          d = OpenTox::Dataset.create(CONFIG[:services]["opentox-dataset"], subjectid)
          d.load_yaml(data)
          d.save( subjectid )
          @@dataset_uris[file.path.to_s] = d.uri
        elsif (file.path =~ /csv$/)
          d = OpenTox::Dataset.create_from_csv_file(file.path, subjectid)
          raise "num features not 1 (="+d.features.keys.size.to_s+"), what to predict??" if d.features.keys.size != 1
          @@prediction_features[file.path.to_s] = d.features.keys[0]
          @@dataset_uris[file.path.to_s] = d.uri
        else
          raise "unknown file type: "+file.path.to_s
        end
        LOGGER.debug "uploaded dataset: "+d.uri
      else
        LOGGER.debug "file already uploaded: "+@@dataset_uris[file.path.to_s]
      end
      return @@dataset_uris[file.path.to_s]
    end
    
    def self.prediction_feature_for_file(file)
      @@prediction_features[file.path.to_s]
    end
    
    def self.build_compare_report(validation_examples, subjectid)
      
      @comp = validation_examples[0].algorithm_uri==nil ? :model_uri : :algorithm_uri
      return nil if @comp == :model_uri
      to_compare = []
      validation_examples.each do |v|
        to_compare << v.validation_uri if v.validation_uri and v.validation_error==nil
      end
      return nil if to_compare.size < 2
      #begin
        return validation_post "report/algorithm_comparison",{ :validation_uris => to_compare.join("\n") }, subjectid
      #rescue => ex
        #return "error creating comparison report "+ex.message
      #end
    end
    
    def self.validation_post(uri, params, subjectid, waiting_task=nil )
      
      params[:subjectid] = subjectid if subjectid
      if $test_case
        $test_case.post uri,params
        return wait($test_case.last_response.body)
      else
        return OpenTox::RestClientWrapper.post(File.join(CONFIG[:services]["opentox-validation"],uri),params,nil,waiting_task).to_s
      end
    end
    
    def self.validation_get(uri, subjectid, accept_header='application/rdf+xml')
      params = {}
      params[:subjectid] = subjectid if subjectid
      if $test_case
        #puts "getting "+uri+","+accept_header
        $test_case.get uri,params,'HTTP_ACCEPT' => accept_header 
        return wait($test_case.last_response.body)
      else
        params[:accept] = accept_header
        return OpenTox::RestClientWrapper.get(File.join(CONFIG[:services]["opentox-validation"],uri),params)
      end
    end

    def self.validation_delete(uri, accept_header='application/rdf+xml')
      
      if $test_case
        $test_case.delete uri,{:subjectid => SUBJECTID},'HTTP_ACCEPT' => accept_header 
        return wait($test_case.last_response.body)
      else
        return OpenTox::RestClientWrapper.delete(File.join(CONFIG[:services]["opentox-validation"],uri),{:accept => accept_header,:subjectid => SUBJECTID})
      end
    end
    
    
    def self.wait(uri)
      if uri.task_uri?
        task = OpenTox::Task.find(uri.to_s.chomp)
        task.wait_for_completion
        #raise "task failed: "+uri.to_s+", description: '"+task.description.to_s+"'" if task.error?
        LOGGER.error "task failed :\n"+task.to_yaml if task.error?
        uri = task.result_uri
      end
      uri
    end
    
    def self.verify_crossvalidation(val_yaml)
      
      val = YAML.load(val_yaml)
      #puts val.inspect
      
      assert_integer val["random_seed".to_sym],nil,nil,"random_seed"
      assert_boolean val["stratified".to_sym],"stratified"
      assert_integer val["num_folds".to_sym],0,1000,"num_folds"
      num_folds = val["num_folds".to_sym].to_i
      
      validations = val["validation_uris".to_sym]
      assert_int_equal(num_folds, validations.size, "num_folds != validations.size")
    end
    
    def self.verify_validation(val_yaml)
    
      val = YAML.load(val_yaml)
  
      #puts val.inspect
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
        #puts class_values.inspect
        
        confusion_matrix = class_stats["confusion_matrix".to_sym]
        confusion_matrix_cells = confusion_matrix["confusion_matrix_cell".to_sym]
        predictions = 0
        confusion_matrix_cells.each do |confusion_matrix_cell|
          predictions += confusion_matrix_cell["confusion_matrix_value".to_sym].to_i
        end
        assert_int_equal(predictions, num_instances-num_unpredicted)
      else
        regr_stats = val["regression_statistics".to_sym]
        assert_not_nil regr_stats
      end
    end
    
    def self.compare_yaml_and_owl(hash, owl, nested_params=[] )
      
      hash.each do |k,v|
        p = nested_params + [ k.to_s.to_rdf_format ]
        if (v.is_a?(Hash))
          compare_yaml_and_owl( v, owl, p )
        elsif (v.is_a?(Array))
          v.each do |vv|
            compare_yaml_and_owl( vv, owl, p )
          end
        else
          owl_value = owl.get_nested( p )
          if owl_value.size == 0
            raise "owl_value is nil, yaml value is '"+v.to_s+"'" unless v==nil or v.to_s.size==0
          elsif owl_value.size == 1
            assert_equal(v, owl_value[0], p.join(".")+" (yaml != rdf)")
          else
            raise p.join(".")+" yaml value '"+v.to_s+"' not included in rdf values '"+
              owl_value.inspect+"'" unless owl_value.include?(v)
          end
        end
      end
    end
    
    private
    def self.assert_not_nil(val,msg_suffix=nil)
      raise msg_suffix.to_s+" is nil" if val==nil
    end
    
    def self.assert_int_equal(val1,val2,msg_suffix=nil)
      assert_equal(val1, val2, msg_suffix)
    end
    
    def self.assert_equal(val1,val2,msg_suffix=nil)
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
                  :stratified,
                  :subjectid
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
            dataset_uri = Util.upload_dataset(send(file), @subjectid)
            send("#{uri.to_s}=".to_sym, dataset_uri)
            @uploaded_datasets = [] unless @uploaded_datasets
            @uploaded_datasets << dataset_uri
         end
      end
     
      if (params.include?(:prediction_feature) and @prediction_feature==nil and @dataset_uri and @dataset_file)
        @prediction_feature = Util.prediction_feature_for_file(@dataset_file)
      end
    end
      
    def check_requirements
      params.each do |r|
        raise "values not set: "+r.to_s if send(r)==nil
      end
    end
    
    def delete
      #begin
        if @validation_uri =~ /crossvalidation/
          cv = "crossvalidation/"
        else
          cv = ""
        end
        Util.validation_delete '/'+cv+@validation_uri.split('/')[-1] if @validation_uri
      #rescue => ex
        #puts "Could not delete validation: "+ex.message
      #end
      #begin
        Util.validation_delete '/report/'+report_type+'/'+@report_uri.split('/')[-1] if @report_uri
      #rescue => ex
        #puts "Could not delete report:' "+@report_uri+" "+ex.message
      #end
      @uploaded_datasets.each do |d|
       # begin
          puts "deleting dataset "+d
          OpenTox::RestClientWrapper.delete(d,{:subjectid => SUBJECTID})
#        rescue => ex
          #puts "Could not delete dataset:' "+d+" "+ex.message
        #end
      end
    end
    
    def report( waiting_task=nil )
      #begin
        @report_uri = Util.validation_post '/report/'+report_type,{:validation_uris => @validation_uri},@subjectid,waiting_task if @validation_uri
        Util.validation_get "/report/"+report_uri.split("/")[-2]+"/"+report_uri.split("/")[-1], @subjectid if @report_uri
      #rescue => ex
        #puts "could not create report: "+ex.message
        #raise ex
        #@report_error = ex.message
      #end
    end
    
    def validate( waiting_task=nil )
      #begin
        @validation_uri = Util.validation_post '/'+validation_type, get_params, @subjectid, waiting_task
      #rescue => ex
        #puts "could not validate: "+ex.message
        #@validation_error = ex.message
        #LOGGER.error ex.message
      #end
    end
    
    def compare_yaml_vs_rdf
      if @validation_uri
        yaml = YAML.load(Util.validation_get(@validation_uri.split("/")[-1],@subjectid,'application/x-yaml'))
        owl = OpenTox::Owl.from_data(Util.validation_get(@validation_uri.split("/")[-1],@subjectid),@validation_uri,"Validation")
        Util.compare_yaml_and_owl(yaml,owl)
      end
      if @report_uri
        yaml = YAML.load(Util.validation_get(@report_uri.split("/")[-3..-1].join("/"),@subjectid,'application/x-yaml'))
        owl = OpenTox::Owl.from_data(Util.validation_get(@report_uri.split("/")[-3..-1].join("/"),@subjectid),@report_uri,"ValidationReport")
        Util.compare_yaml_and_owl(yaml,owl)
        Util.validation_get(@report_uri.split("/")[-3..-1].join("/"),@subjectid,'text/html')
      else
        puts "no report"
      end
    end
    
    
    def verify_yaml
      raise "cannot very validation, validation_uri is null" unless @validation_uri
      if @validation_uri =~ /crossvalidation/
        Util.verify_crossvalidation(Util.validation_get("crossvalidation/"+@validation_uri.split("/")[-1],'application/x-yaml'))
        Util.validation_get("crossvalidation/"+@validation_uri.split("/")[-1]+"/statistics",'application/x-yaml')
        Util.verify_validation(Util.validation_get("crossvalidation/"+@validation_uri.split("/")[-1]+"/statistics",'application/x-yaml'))
      else
        Util.verify_validation(Util.validation_get(@validation_uri.split("/")[-1],@subjectid,'application/x-yaml'))
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
    
    def validation_type
      "test_set_validation"
    end    
  end
  
  class TrainingTestValidation < ValidationExample
    def params
      [:algorithm_uri, :training_dataset_uri, :test_dataset_uri, :prediction_feature]
    end
    
    def opt_params
      [ :algorithm_params, :test_target_dataset_uri ]
    end
    
    def validation_type
      "training_test_validation"
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
  
  class BootstrappingValidation < ValidationExample
    def params
      [:algorithm_uri, :dataset_uri, :prediction_feature]
    end
    
    def opt_params
      [ :algorithm_params, :random_seed ]
    end
    
    def validation_type
      "bootstrapping"
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