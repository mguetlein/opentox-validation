
require 'lib/test_util.rb'

class Example
  
  @@file=File.new("data/hamster_carcinogenicity.yaml","r")
  @@file_type="text/x-yaml"
  @@model=File.join CONFIG[:services]["opentox-model"],"1"
  #@@feature= URI.encode("http://local-ot/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)")
  @@feature= File.join CONFIG[:services]["opentox-dataset"],"1/feature/hamster_carcinogenicity"
  #@@predicted_feature= URI.encode("http://local-ot/toxmodel/feature#Hamster%20Carcinogenicity%20(DSSTOX/CPDB)_lazar_classification")
  @@alg = File.join CONFIG[:services]["opentox-algorithm"],"lazar"
  @@alg_params = "feature_generation_uri="+File.join(CONFIG[:services]["opentox-algorithm"],"fminer/bbrc")
  @@data=File.join CONFIG[:services]["opentox-dataset"],"1"
  @@train_data=File.join CONFIG[:services]["opentox-dataset"],"2"
  @@test_data=File.join CONFIG[:services]["opentox-dataset"],"3"
  @@prediction_data=File.join CONFIG[:services]["opentox-dataset"],"5"
  @@css_file="http://apps.ideaconsult.net:8080/ToxPredict/style/global.css"
  
  @@summary=""
  
  # replaces placeholdes ( in <> brackets ) in EXAMPLE file with uris and ids
  def self.transform_example
  
    file = File.new("EXAMPLES", "r")
    res = ""
    while (line = file.gets) 
      res += line
    end
    file.close
    
    sub = { "validation_service" => CONFIG[:services]["opentox-validation"].chomp("/"), 
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
            "crossvalidation_report_id" => "2",
            "css_file" => @@css_file,
            "prediction_dataset_uri" => @@prediction_data,
            #"predicted_feature" => @@predicted_feature,
            "qmrf_id" => "1"}
    
    sub.each do |k,v|
      res.gsub!(/<#{k}>/,v)
    end
    res
  end
  
  # creates the resources that are requested by the examples
  def self.prepare_example_resources
    
    #TODO
    subjectid = nil
    
    task = OpenTox::Task.create("prepare examples", "n/a") do |task|
      @@summary = ""
      #delete validations
      log "delete validations"
      Lib::Validation.auto_migrate!
      Lib::Crossvalidation.auto_migrate!
      #ActiveRecord::Base.logger = Logger.new("/dev/null")
      #ActiveRecord::Migrator.migrate('db/migrate', 0 )
      #ActiveRecord::Migrator.migrate('db/migrate', 1 )
      #ActiveRecord::Migrator.migrate('db/migrate', 2 )
      
      #delete all qmrf reports
      ReachReports::QmrfReport.auto_migrate!
      
      #delete_all(CONFIG[:services]["opentox-dataset"])
      log OpenTox::RestClientWrapper.delete CONFIG[:services]["opentox-dataset"]
      task.progress(10)
      
      log "upload dataset"
      halt 400,"File not found: "+@@file.path.to_s unless File.exist?(@@file.path)
      #data = File.read(@@file.path)
      #data_uri = OpenTox::RestClientWrapper.post(CONFIG[:services]["opentox-dataset"],{:content_type => @@file_type},data).chomp("\n")
      data = File.read(@@file.path)
      dataset = OpenTox::Dataset.create
      dataset.load_yaml(data)
      dataset.save
      data_uri = dataset.uri
      log "-> "+data_uri
      task.progress(20)
      
      log "train-test-validation"
      #delete_all(CONFIG[:services]["opentox-model"])
      OpenTox::RestClientWrapper.delete CONFIG[:services]["opentox-model"]
      
      split_params = Validation::Util.train_test_dataset_split(data_uri, URI.decode(@@feature), 0.9, 1)
      v = Validation::Validation.new :training_dataset_uri => split_params[:training_dataset_uri], 
                     :validation_type => "test_set_validation",
                     :test_dataset_uri => split_params[:test_dataset_uri],
                     :test_target_dataset_uri => data_uri,
                     :prediction_feature => URI.decode(@@feature),
                     :algorithm_uri => @@alg
      v.validate_algorithm( @@alg_params, OpenTox::SubTask.new(task, 20, 40) ) 
      
      log "crossvalidation"
      cv = Validation::Crossvalidation.new({ :dataset_uri => data_uri, :algorithm_uri => @@alg, :num_folds => 5, :stratified => false })
      cv.perform_cv( URI.decode(@@feature), @@alg_params, OpenTox::SubTask.new(task, 40, 70) )
      
      log "create validation report"
      rep = Reports::ReportService.instance(File.join(CONFIG[:services]["opentox-validation"],"report"))
      rep.delete_all_reports("validation", subjectid)
      rep.create_report("validation",v.validation_uri)
      task.progress(80)
      
      log "create crossvalidation report"
      rep.delete_all_reports("crossvalidation", subjectid)
      rep.create_report("crossvalidation",cv.crossvalidation_uri)
      task.progress(90)
      
      log "build qmrf"
      t = ReachReports.create_report("QMRF",{:model_uri=>@@model})
      Lib::TestUtil.wait_for_task(t)
      task.progress(100)
      
      log "done"
      @@summary
    end
    task.uri
  end
  
  # performs all curl calls listed in examples after ">>>", next line is added if line ends with "\"
  def self.test_examples(example_uri=nil)
    
    if (example_uri)
      examples = OpenTox::RestClientWrapper.get(example_uri)
    else
      examples = transform_example # use local examples
    end
    
    lines = examples.split("\n")
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
    
    Spork.spork(:logger => LOGGER) do
      @@summary = ""
      num = 0
      suc = 0
      curl_calls.each do |cmd|
        num += 1
        log "testing: "+cmd
        result = ""
        IO.popen(cmd.to_s+" 2> /dev/null") do |f| 
          while line = f.gets
            result += line if result.size<50
          end
        end
        result.chomp!
        result.gsub!(/\n/, " \\n ")
        if ($?==0)
          if result.task_uri?
            log "wait for task: "+result
            result = Lib::TestUtil.wait_for_task(result)
          end
          log "ok ( " +result.to_s[0,50]+" )"
          suc += 1
        else
          log "failed ( " +result.to_s[0,50]+" )"
        end
      end
      log suc.to_s+"/"+num.to_s+" curls succeeded"
      @@summary
    end
    "testing in background, check log for results"
  end
  
  private
  # deletes resources listed by service
  def self.delete_all(uri_list_service)
    uri_list = OpenTox::RestClientWrapper.get(uri_list_service)
    LOGGER.debug "deleting: "+uri_list.inspect
    uri_list.split("\n").each do |uri|
      OpenTox::RestClientWrapper.delete(uri)
    end
  end
  
  # logs string and and adds to summary
  def self.log(log_string)
    LOGGER.info "EXAMPLE: "+log_string
    @@summary += log_string+"\n"
  end
  
end
