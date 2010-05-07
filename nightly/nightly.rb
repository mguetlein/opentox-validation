

class Nightly
  
  NIGHTLY_REP_DIR = File.join(FileUtils.pwd,"nightly")
  NIGHTLY_REPORT_XML = "nightly_report.xml"
  NIGHTLY_REPORT_HTML = "nightly_report.html"
  
  def self.get_nightly
    LOGGER.info("Accessing nightly report.")
    if File.exist?(File.join(NIGHTLY_REP_DIR,NIGHTLY_REPORT_HTML))
      return File.new(File.join(NIGHTLY_REP_DIR,NIGHTLY_REPORT_HTML))
    else
      return "Nightly report not available, try again later"
    end
  end
  
  def self.build_nightly
    task_uri = OpenTox::Task.as_task() do
      LOGGER.info("Building nightly report")
      
      benchmarks = [ HamsterTrainingTestBenchmark.new, 
                     MiniRegressionBenchmark.new,
                     #FatheadRegressionBenchmark.new,
                     ]
      
      running = []
      report = Reports::XMLReport.new("Nightly Validation", Time.now.strftime("Created at %m.%d.%Y - %H:%M"))
      benchmarks.each do |b|
        running << b.class.to_s.gsub(/Nightly::/, "")+b.object_id.to_s
        Thread.new do
          begin
            b.build
          ensure
            running.delete(b.class.to_s.gsub(/Nightly::/, "")+b.object_id.to_s)
          end
        end
      end
      wait = 0
      while running.size>0
        LOGGER.debug "Nighlty report waiting for "+running.inspect if wait%60==0
        wait += 1
        sleep 1
      end
      
      section_about = report.add_section(report.get_root_element, "About this report")
      report.add_paragraph(section_about,
        "This a opentox internal test report. Its purpose is to maintain interoperability between the OT validation web service "+
        "and other OT web services. If you have any comments, remarks, or wish your service/test-case to be added, please email "+
        "to guetlein@informatik.uni-freiburg.de or use the issue tracker at http://opentox.informatik.uni-freiburg.de/simple_ot_stylesheet.css")
      
      benchmarks.each do |b|  
         section = report.add_section(report.get_root_element, b.title)
         
         section_info = report.add_section(section, "Info")
         b.info.each{|i| report.add_paragraph(section_info,i)}
         info_table = b.info_table
         report.add_table(section_info, b.info_table_title, info_table) if info_table
         
         section_results = report.add_section(section, "Results")
         report.add_table(section_results, b.result_table_title, b.result_table)
         
         if (b.comparison_report)
           report.add_table(section_results, b.comparison_report_title, [[b.comparison_report]], false)
         end
         
         section_errors = report.add_section(section, "Errors")
         
         if b.errors and b.errors.size>0
           b.errors.each do |k,v|
             elem = report.add_section(section_errors,k)
             report.add_paragraph(elem,v,true)
           end
         else
           report.add_paragraph(section_errors,"no errors occured")
         end
       
      end
      
      report.write_to(File.new(File.join(NIGHTLY_REP_DIR,NIGHTLY_REPORT_XML), "w"))
      Reports::ReportFormat.format_report_to_html(NIGHTLY_REP_DIR,
        NIGHTLY_REPORT_XML, 
        NIGHTLY_REPORT_HTML, 
        nil)
        #"http://www.opentox.org/portal_css/Opentox%20Theme/base-cachekey7442.css")
        #"http://apps.ideaconsult.net:8080/ToxPredict/style/global.css")
      
      LOGGER.info("Nightly report completed")
      return "Nightly report completed"
    end
    if defined?(halt)
      halt 202,task_uri
    else
      return task_uri
    end
  end
  
  class ValidationBenchmark
    
    def info_table_title
      return title
    end
    
    def info_table
      return nil
    end
    
    def result_table_title
      return "Validation results"
    end
    
    def result_table
      raise "no comparables" unless @comparables
      raise "no validations" unless @validations
      raise "no reports" unless @reports
      t = []
      row = [comparable_nice_name, "validation", "report"]
      t << row
      (0..@comparables.size-1).each do |i|
        row = [ @comparables[i], @validations[i], @reports[i] ]
        t << row
      end
      t
    end
    
    def comparison_report_title
      "algorithm comparison report"
    end
    
    def comparison_report
      @comparison_report
    end
    
  end
  
  class TrainingTestValidationBenchmark < ValidationBenchmark
    
    def info
      [ training_test_info ]
    end
    
    def training_test_info
      "This is a training test set validation. It builds a model with an algorithm and the training dataset. "+
      "The model is used to predict the test dataset. Evaluation is done by comparing the model predictions "+
      "to the actual test values (in the test target dataset)."
    end
    
    def info_table_title
      "Validation params"
    end
    
    def comparable_nice_name
      return "algorithm"
    end
    
    def info_table
      t = []
      t << ["param", "uri"]
      t << ["training_dataset_uri", @train_data]
      t << ["test_dataset_uri", @test_data]
      t << ["test_target_dataset_uri", @test_class_data] if @test_class_data
      t << ["prediction_feature", @pred_feature]
      count = 1
      @algs.each do |alg|
        t << ["algorithm_uri"+" ["+count.to_s+"]", alg]
        count += 1
      end
      t
    end
    
    def errors
      @errors
    end
    
    
    def build()
      raise "no algs" unless @algs
      raise "no train data" unless @train_data
      raise "no test data" unless @test_data
      raise "no pred feature" unless @pred_feature
      
      @comparables = @algs
      @validations = Array.new(@comparables.size)
      @reports = Array.new(@comparables.size)
      @errors = {}
      to_compare = []
#      LOGGER.info "train-data: "+@train_data.to_s
#      LOGGER.info "test-data: "+@test_data.to_s
#      LOGGER.info "test-class-data: "+@test_class_data.to_s
      
      running = []
      (0..@comparables.size-1).each do |i|
        
        Thread.new do 
          running << @comparables[i]+i.to_s
          begin
            LOGGER.debug "Validate: "+@algs[i].to_s
            @validations[i] = Util.validate_alg(@train_data, @test_data, @test_class_data,
              @algs[i], URI.decode(@pred_feature), @alg_params[i]).to_s
            to_compare << @validations[i] if OpenTox::Utils.is_uri?(@validations[i])
              
            begin
              LOGGER.debug "Building validation-report for "+@validations[i].to_s+" ("+@algs[i].to_s+")"
              @reports[i] = Util.create_report(@validations[i])
            rescue => ex
              LOGGER.error "validation-report error: "+ex.message
              @reports[i] = "error"
            end
            
          rescue => ex
            LOGGER.error "validation error: "+ex.message
            key = "Error validating "+@comparables[i].to_s
            @validations[i] = key+" (see below)"
            @errors[key] = ex.message
          ensure
            running.delete(@comparables[i]+i.to_s)
          end
        end
      end
      wait = 0
      while running.size>0
        LOGGER.debug self.class.to_s.gsub(/Nightly::/, "")+" waiting for "+running.inspect if wait%20==0
        wait += 1
        sleep 1
      end
      
      if to_compare.size>1
        LOGGER.debug self.class.to_s.gsub(/Nightly::/, "")+": build algorithm comparison report"
        @comparison_report = Util.create_alg_comparison_report(to_compare)
      else
        LOGGER.debug self.class.to_s.gsub(/Nightly::/, "")+": nothing to compare"
      end
    end
  end
  
  class MiniRegressionBenchmark < TrainingTestValidationBenchmark
    
    def title
      "Training test set validation, small regression dataset"
    end
    
    def info
      res = [ "A very small regression task, using the training dataset as test set." ] + super
      return res
    end
    
    def build()
      @algs = [ "http://opentox.ntua.gr:3003/algorithm/mlr", 
        "http://opentox.informatik.tu-muenchen.de:8080/OpenTox-dev/algorithm/kNNregression",
        File.join(@@config[:services]["opentox-majority"],["/regr/algorithm"])
        ]
      @alg_params = [nil, "dataset_service=http://ambit.uni-plovdiv.bg:8080/ambit2/dataset", nil]
      @train_data = "http://ambit.uni-plovdiv.bg:8080/ambit2/dataset/342"
      @test_data = "http://ambit.uni-plovdiv.bg:8080/ambit2/dataset/342"
      @pred_feature = "http://ambit.uni-plovdiv.bg:8080/ambit2/feature/103141"
      super
    end
  end
  
  class FatheadRegressionBenchmark < TrainingTestValidationBenchmark
    
    def title
      "Training test set validation, regression with fathead minnow dataset"
    end
    
    def info
      res = [ "This is the regression use case used in D2.2. "+
              "The task is to predict LC50 values of the well known Fathead Minnow Acute Toxicity dataset. "+
              "JOELIB was used to compute numerical descriptors as features." ] + super
      return res
    end
    
    def build()
      @algs = [ 
        "http://opentox.informatik.tu-muenchen.de:8080/OpenTox-dev/algorithm/kNNregression",
        "http://opentox.informatik.tu-muenchen.de:8080/OpenTox-dev/algorithm/M5P",
        "http://opentox.informatik.tu-muenchen.de:8080/OpenTox-dev/algorithm/GaussP"
        ]
      @alg_params = [nil, nil, nil]
      @train_data = "http://ambit.uni-plovdiv.bg:8080/ambit2/dataset/639"
      @test_data = "http://ambit.uni-plovdiv.bg:8080/ambit2/dataset/640"
      @pred_feature = "http://ambit.uni-plovdiv.bg:8080/ambit2/feature/264185"
      super
    end
  end
 
  class HamsterTrainingTestBenchmark < TrainingTestValidationBenchmark
    
    @@dataset_service = @@config[:services]["opentox-dataset"]
    @@file=File.new("data/hamster_carcinogenicity.yaml","r")
    @@file_type="text/x-yaml"
    @@lazar_server = @@config[:services]["opentox-algorithm"]
    
    def title()
      "Training test set validation, binary classification"
    end
    
    def info
      res = [ "A simple binary classification task using the hamster carcinogenicity dataset." ] + super
      return res
    end
    
    def build()
      @algs = [File.join(@@lazar_server,"lazar"), File.join(@@config[:services]["opentox-majority"],["/class/algorithm"]) ]
      @alg_params = ["feature_generation_uri="+File.join(@@lazar_server,"fminer"),nil]
      @pred_feature = "http://localhost/toxmodel/feature#Hamster Carcinogenicity (DSSTOX/CPDB)"

      LOGGER.debug "pepare hamster datasets"
      @test_class_data = Util.upload_dataset(@@dataset_service, @@file, @@file_type).chomp("\n")
      split = Util.split_dataset(@test_class_data, URI.decode(@pred_feature), 0.9, 1)
      @train_data = split[0].to_s
      @test_data = split[1].to_s
      super
    end
  end


  class Util
    @@validation_service = @@config[:services]["opentox-validation"]
    
    def self.upload_dataset(dataset_service, file, file_type)
      raise "File not found: "+file.path.to_s unless File.exist?(file.path)
      data = File.read(file.path)
      data_uri = OpenTox::RestClientWrapper.post dataset_service, {:content_type => file_type}, data
      #data_uri = OpenTox::Task.find(data_uri).wait_for_resource.to_s if OpenTox::Utils.task_uri?(data_uri)
      return data_uri
    end
    
    def self.split_dataset(data_uri, feature, split_ratio, random_seed)
      res = OpenTox::RestClientWrapper.post File.join(@@validation_service,'plain_training_test_split'), { :dataset_uri => data_uri, :prediction_feature=>feature, :split_ratio=>split_ratio, :random_seed=>random_seed}
      return res.split("\n")
    end
    
    def self.validate_alg(train_data, test_data, test_class_data, alg, feature, alg_params)
      uri = OpenTox::RestClientWrapper.post @@validation_service, { :training_dataset_uri => train_data, :test_dataset_uri => test_data, 
        :test_target_dataset_uri => test_class_data,
        :algorithm_uri => alg, :prediction_feature => feature, :algorithm_params => alg_params }
      #LOGGER.info "waiting for validation "+uri.to_s
      #uri = OpenTox::Task.find(uri).wait_for_resource.to_s if OpenTox::Utils.task_uri?(uri)
      #LOGGER.info "validaiton done "+uri.to_s
      return uri
    end
    
    def self.create_report(validation)
      uri = OpenTox::RestClientWrapper.post File.join(@@validation_service,"report/validation"), { :validation_uris => validation }
      #uri = OpenTox::Task.find(uri).wait_for_resource.to_s if OpenTox::Utils.task_uri?(uri)
      return uri
    end
    
    def self.create_alg_comparison_report(validations)
      uri = OpenTox::RestClientWrapper.post File.join(@@validation_service,"report/algorithm_comparison"), { :validation_uris => validations.join("\n") }
      #uri = OpenTox::Task.find(uri).wait_for_resource.to_s if OpenTox::Utils.task_uri?(uri)
      return uri
    end
    
  end
  
end