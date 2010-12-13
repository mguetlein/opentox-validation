
# selected attributes of interest when generating the report for a train-/test-evaluation                      
VAL_ATTR_TRAIN_TEST = [ :model_uri, :training_dataset_uri, :test_dataset_uri, :prediction_feature ]
# selected attributes of interest when generating the crossvalidation report
VAL_ATTR_CV = [ :algorithm_uri, :dataset_uri, :num_folds, :crossvalidation_fold ]

# selected attributes of interest when performing classification
VAL_ATTR_CLASS = [ :percent_correct, :weighted_area_under_roc, 
  :area_under_roc, :f_measure, :true_positive_rate, :true_negative_rate ]
VAL_ATTR_REGR = [ :root_mean_squared_error, :mean_absolute_error, :r_square ]

VAL_ATTR_BAR_PLOT_CLASS = [ :accuracy, :weighted_area_under_roc, 
  :area_under_roc, :f_measure, :true_positive_rate, :true_negative_rate ]
VAL_ATTR_BAR_PLOT_REGR = [ :root_mean_squared_error, :mean_absolute_error, :r_square ]


# = Reports::ReportFactory 
#
# creates various reports (Reports::ReportContent) 
#
module Reports::ReportFactory
  
  RT_VALIDATION = "validation"
  RT_CV = "crossvalidation"
  RT_ALG_COMP = "algorithm_comparison"
  
  REPORT_TYPES = [RT_VALIDATION, RT_CV, RT_ALG_COMP ]
  
  # creates a report of a certain type according to the validation data in validation_set 
  #
  # call-seq:
  #   self.create_report(type, validation_set) => Reports::ReportContent
  #
  def self.create_report(type, validation_set, task=nil)
    case type
    when RT_VALIDATION
      create_report_validation(validation_set, task)
    when RT_CV
      create_report_crossvalidation(validation_set, task)
    when RT_ALG_COMP
      create_report_compare_algorithms(validation_set, task)
    else
      raise "unknown report type "+type.to_s
    end
  end
  
  private
  # this function is only to set task progress accordingly
  # loading predicitons is time consuming, and is done dynamically ->  
  # pre-load and set task progress
  def self.pre_load_predictions( validation_set, task=nil)
    i = 0
    task_step = 100 / validation_set.size.to_f
    validation_set.validations.each do |v|
      v.get_predictions( OpenTox::SubTask.create(task, i*task_step, (i+1)*task_step ) )
      i += 1
    end
  end
  
  def self.create_report_validation(validation_set, task=nil)
    
    raise Reports::BadRequest.new("num validations is not equal to 1") unless validation_set.size==1
    val = validation_set.validations[0]
    pre_load_predictions( validation_set, OpenTox::SubTask.create(task,0,80) )

    report = Reports::ReportContent.new("Validation report")
    
    if (val.classification?)
      report.add_result(validation_set, [:validation_uri] + VAL_ATTR_TRAIN_TEST + VAL_ATTR_CLASS, "Results", "Results")
      report.add_roc_plot(validation_set)
      report.add_confusion_matrix(val)
    else #regression
      report.add_result(validation_set, [:validation_uri] + VAL_ATTR_TRAIN_TEST + VAL_ATTR_REGR, "Results", "Results")
      report.add_regression_plot(validation_set, :model_uri)
    end
    task.progress(90) if task
    
    report.add_result(validation_set, Lib::ALL_PROPS, "All Results", "All Results")
    report.add_predictions( validation_set )
    task.progress(100) if task
    report
  end
  
  def self.create_report_crossvalidation(validation_set, task=nil)
    
    raise Reports::BadRequest.new("num validations is not >1") unless validation_set.size>1
    raise Reports::BadRequest.new("crossvalidation-id not unique and != nil: "+
      validation_set.get_values(:crossvalidation_id,false).inspect) if validation_set.unique_value(:crossvalidation_id)==nil
    validation_set.load_cv_attributes
    raise Reports::BadRequest.new("num validations ("+validation_set.size.to_s+") is not equal to num folds ("+
      validation_set.unique_value(:num_folds).to_s+")") unless validation_set.unique_value(:num_folds)==validation_set.size
    raise Reports::BadRequest.new("num different folds is not equal to num validations") unless validation_set.num_different_values(:crossvalidation_fold)==validation_set.size
    raise Reports::BadRequest.new("validations must be either all regression, "+
      +"or all classification validations") unless validation_set.all_classification? or validation_set.all_regression?  
    pre_load_predictions( validation_set, OpenTox::SubTask.create(task,0,80) )
    
    merged = validation_set.merge([:crossvalidation_id])
    raise unless merged.size==1
    
    #puts merged.get_values(:percent_correct_variance, false).inspect
    report = Reports::ReportContent.new("Crossvalidation report")
    
    if (validation_set.all_classification?)
      report.add_result(merged, [:crossvalidation_uri]+VAL_ATTR_CV+VAL_ATTR_CLASS-[:crossvalidation_fold],"Mean Results","Mean Results")
      report.add_roc_plot(validation_set, nil, "ROC Plots over all folds")
      report.add_roc_plot(validation_set, :crossvalidation_fold)
      report.add_confusion_matrix(merged.validations[0])
      report.add_result(validation_set, VAL_ATTR_CV+VAL_ATTR_CLASS-[:num_folds],
        "Results","Results",nil,"validation")
    else #regression
      report.add_result(merged, [:crossvalidation_uri]+VAL_ATTR_CV+VAL_ATTR_REGR-[:crossvalidation_fold],"Mean Results","Mean Results")
      report.add_regression_plot(validation_set, :crossvalidation_fold)
      report.add_result(validation_set, VAL_ATTR_CV+VAL_ATTR_REGR-[:num_folds], "Results","Results")
    end
    task.progress(90) if task
      
    report.add_result(validation_set, Lib::ALL_PROPS, "All Results", "All Results")
    report.add_predictions( validation_set ) #, [:crossvalidation_fold] )
    task.progress(100) if task
    report
  end
  
  def self.create_report_compare_algorithms(validation_set, task=nil)
    
    #validation_set.to_array([:test_dataset_uri, :model_uri, :algorithm_uri], false).each{|a| puts a.inspect}
    raise Reports::BadRequest.new("num validations is not >1") unless validation_set.size>1
    raise Reports::BadRequest.new("validations must be either all regression, "+
      "or all classification validations") unless validation_set.all_classification? or validation_set.all_regression?
    raise Reports::BadRequest.new("number of different algorithms <2: "+
      validation_set.get_values(:algorithm_uri).inspect) if validation_set.num_different_values(:algorithm_uri)<2
      
    if validation_set.has_nil_values?(:crossvalidation_id)
      raise Reports::BadRequest.new("algorithm comparison for non crossvalidation not yet implemented")
    else
      raise Reports::BadRequest.new("num different cross-validation-ids <2") if validation_set.num_different_values(:crossvalidation_id)<2
      validation_set.load_cv_attributes
      compare_algorithms_crossvalidation(validation_set, task)
    end
  end  
  
  # create Algorithm Comparison report
  # crossvalidations, 1-n datasets, 2-n algorithms
  def self.compare_algorithms_crossvalidation(validation_set, task=nil)
    
    # groups results into sets with equal dataset 
    if (validation_set.num_different_values(:dataset_uri)>1)
      dataset_grouping = Reports::Util.group(validation_set.validations, [:dataset_uri])
      # check if equal values in each group exist
      Reports::Util.check_group_matching(dataset_grouping, [:algorithm_uri, :crossvalidation_fold, :num_folds, :stratified, :random_seed])
    else
      dataset_grouping = [ validation_set.validations ]
    end
    
    # we only checked that equal validations exist in each dataset group, now check for each algorithm
    dataset_grouping.each do |validations|
      algorithm_grouping = Reports::Util.group(validations, [:algorithm_uri])
      Reports::Util.check_group_matching(algorithm_grouping, [:crossvalidation_fold, :num_folds, :stratified, :random_seed])
    end
    
    pre_load_predictions( validation_set, OpenTox::SubTask.create(task,0,80) )
    report = Reports::ReportContent.new("Algorithm comparison report - Many datasets")
    
    if (validation_set.num_different_values(:dataset_uri)>1)
      all_merged = validation_set.merge([:algorithm_uri, :dataset_uri, :crossvalidation_id, :crossvalidation_uri])
      report.add_ranking_plots(all_merged, :algorithm_uri, :dataset_uri,
        [:percent_correct, :weighted_area_under_roc, :true_positive_rate, :true_negative_rate] )
      report.add_result_overview(all_merged, :algorithm_uri, :dataset_uri, [:percent_correct, :weighted_area_under_roc, :true_positive_rate, :true_negative_rate])
      
    end

    if (validation_set.all_classification?)
      attributes = VAL_ATTR_CV+VAL_ATTR_CLASS-[:crossvalidation_fold]
      attributes = ([ :dataset_uri ] + attributes).uniq
      
      dataset_grouping.each do |validations|
      
        set = Reports::ValidationSet.create(validations)
        
        dataset = validations[0].dataset_uri
        merged = set.merge([:algorithm_uri, :dataset_uri, :crossvalidation_id, :crossvalidation_uri])
        merged.sort(:dataset_uri)
        
        report.add_section("Dataset: "+dataset)
        report.add_result(merged,attributes,
          "Mean Results","Mean Results",nil,"crossvalidation")
        report.add_paired_ttest_table(set, :algorithm_uri, :percent_correct)
        
        report.add_bar_plot(merged, :algorithm_uri, VAL_ATTR_BAR_PLOT_CLASS)
        report.add_roc_plot(set, :algorithm_uri)
        report.end_section
      end
      
    else # regression
      raise Reports::BadRequest.new("algorithm comparison for regression not yet implemented")
    end
    task.progress(100) if task
    report
  end

end

