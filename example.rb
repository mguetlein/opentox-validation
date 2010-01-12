
class Example
  
  @@file=File.new("data/hamster_carcinogenicity.owl","r")
  @@model=File.join @@config[:services]["opentox-model"],"1"
  @@feature="http://www.epa.gov/NCCT/dsstox/CentralFieldDef.html#ActivityOutcome_CPDBAS_Hamster"
  @@alg = File.join @@config[:services]["opentox-algorithm"],"lazar"
  @@alg_params = "feature_generation_uri="+File.join(@@config[:services]["opentox-algorithm"],"fminer")
  @@data=File.join @@config[:services]["opentox-dataset"],"1"
  @@train_data=File.join @@config[:services]["opentox-dataset"],"2"
  @@test_data=File.join @@config[:services]["opentox-dataset"],"3"
  
  @@summary=""
  
  def self.transform_example
  
    file = File.new("EXAMPLES", "r")
    res = ""
    while (line = file.gets) 
      res += line
    end
    file.close
    
    sub = { "validation_service" => @@config[:services]["opentox-validation"].chomp("/"), 
            "validation_id" => "1",
            "model_uri" => @@model,
            "dataset_uri" => @@data,
            "training_dataset_uri" => @@train_data,
            "test_dataset_uri" => @@test_data,
            "prediction_feature" => @@feature,
            "algorithm_uri" => @@alg,
            "algorithm_params" => @@alg_params,
            "crossvalidation_id" => "1",
            "validation_report_id" => "1",
            "crossvalidation_report_id" => "1",
            }
    
    sub.each do |k,v|
      res.gsub!(/<#{k}>/,v)
    end
    res
  end
  
  def self.delete_all(uri_list_service)
    uri_list = OpenTox::RestClientWrapper.get(uri_list_service)
    uri_list.split("\n").each do |uri|
      OpenTox::RestClientWrapper.delete(uri)
    end
  end
  
  def self.log(log_string)
    LOGGER.debug log_string
    @@summary += log_string+"\n"
  end
  
  def self.prepare_example_resources
    
    @@summary = ""
    delete_all(@@config[:services]["opentox-dataset"])
    
    data = File.read(@@file.path)
    data_uri = OpenTox::RestClientWrapper.post @@config[:services]["opentox-dataset"], data, :content_type => "application/rdf+xml"
    log "uploaded dataset "+data_uri
    raise "failed to prepare demo" unless data_uri==@@data
    
    Lib::Validation.auto_migrate!
    delete_all(@@config[:services]["opentox-model"])
    vali_uri = OpenTox::RestClientWrapper.post File.join(@@config[:services]["opentox-validation"],'/training_test_split'), { :dataset_uri => data_uri,
                                                         :algorithm_uri => @@alg,
                                                         :prediction_feature => @@feature,
                                                         :algorithm_params => @@alg_params }
    log "created validation via training test split "+vali_uri
    raise "failed to prepare demo" unless vali_uri==File.join(@@config[:services]["opentox-validation"],'/1')
    
    Lib::Crossvalidation.auto_migrate!
    cv_uri = OpenTox::RestClientWrapper.post File.join(@@config[:services]["opentox-validation"],'/crossvalidation'), { :dataset_uri => data_uri,
                                                         :algorithm_uri => @@alg,
                                                         :prediction_feature => @@feature,
                                                         :algorithm_params => @@alg_params,
                                                         :num_folds => 5, :stratified => false }
    log "created crossvalidation "+cv_uri
    raise "failed to prepare demo" unless cv_uri==File.join(@@config[:services]["opentox-validation"],'/crossvalidation/1')
    
    delete_all(File.join(@@config[:services]["opentox-validation"],"/report/validation"))
    val_report_uri = OpenTox::RestClientWrapper.post File.join(@@config[:services]["opentox-validation"],'/report/validation'), { :validation_uris => vali_uri }
    log "created validation report: "+val_report_uri
    raise "failed to prepare demo" unless val_report_uri==File.join(@@config[:services]["opentox-validation"],'/report/validation/1')
    
    delete_all(File.join(@@config[:services]["opentox-validation"],"/report/crossvalidation"))
    cv_report_uri = OpenTox::RestClientWrapper.post File.join(@@config[:services]["opentox-validation"],'/report/crossvalidation'), { :validation_uris => cv_uri }
    log "created crossvalidation report: "+cv_report_uri
    raise "failed to prepare demo" unless cv_report_uri==File.join(@@config[:services]["opentox-validation"],'/report/crossvalidation/1')
    log "done"

    @@summary
  end
  
  
  def self.test_examples
    lines = transform_example.split("\n")
    curl_call = false
    curl_calls = []
    
    lines.each do |line|
      if line =~ /^\s*>>>\s*.*/
        line.gsub!(/^\s*>>>\s*/,"")
        if line =~ /.*\s*\\s*$/
          curl_call = true
          line.gsub!(/\s*\\s*$/," ")
        else
          curl_call = false
        end
        curl_calls.push( line )
      elsif curl_call
        if line =~ /.*\s*\\s*$/
          curl_call = true
          line.gsub!(/\s*\\s*$/," ")
        else
          curl_call = false
        end
        curl_calls[-1] = curl_calls[-1]+line
      end
    end
    
    @@summary = ""
    curl_calls.each do |cmd|
      log "testing: "+cmd
      IO.popen(cmd.to_s+" 2> /dev/null") do |f| 
        while line = f.gets
          #response += indent.to_s+line
        end
      end
      log ($?==0)?"ok":"failed"
    end
    @@summary  
  end
  
end
