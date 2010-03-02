
# selected attributes of interest when generating the report for a train-/test-evaluation                      
VAL_ATTR_TRAIN_TEST = [ :model_uri, :training_dataset_uri, :test_dataset_uri, :prediction_feature ]
# selected attributes of interest when generating the crossvalidation report
VAL_ATTR_CV = [ :algorithm_uri, :dataset_uri, :num_folds, :crossvalidation_fold ]
# selected attributes of interest when performing classification
VAL_ATTR_CLASS = [ :area_under_roc, :percent_correct, :true_positive_rate, :true_negative_rate ]
VAL_ATTR_BAR_PLOT_CLASS = [ :area_under_roc, :accuracy, :true_positive_rate, :true_negative_rate ]
VAL_ATTR_REGR = [ :root_mean_squared_error, :mean_absolute_error, :r_square ]


# = Reports::ReportFactory 
#
# creates various reports (Reports::ReportContent) 
#
module Reports::ReportFactory
  
  RT_FASTTOX = "fasttox"
  RT_VALIDATION = "validation"
  RT_CV = "crossvalidation"
  RT_ALG_COMP = "algorithm_comparison"
  
  REPORT_TYPES = [RT_VALIDATION, RT_CV, RT_ALG_COMP ] #,RT_FASTTOX
  
  # creates a report of a certain type according to the validation data in validation_set 
  #
  # call-seq:
  #   self.create_report(type, validation_set) => Reports::ReportContent
  #
  def self.create_report(type, validation_set)
    case type
    when RT_FASTTOX
      raise "not yet implemented"
    when RT_VALIDATION
      create_report_validation(validation_set)
    when RT_CV
      create_report_crossvalidation(validation_set)
    when RT_ALG_COMP
      create_report_compare_algorithms(validation_set)
    else
      raise "unknown report type"
    end
  end
  
  private
  def self.create_report_validation(validation_set)
    
    raise Reports::BadRequest.new("num validations is not equal to 1") unless validation_set.size==1
    val = validation_set.validations[0]
    
    report = Reports::ReportContent.new("Validation report")
    
    if (val.classification?)
      report.add_section_result(validation_set, VAL_ATTR_TRAIN_TEST + VAL_ATTR_CLASS, "Results", "Results")
      report.add_section_roc_plot(validation_set, nil, nil, "roc-plot.svg")
      #val.get_prediction_feature_values.each do |class_value|
        #report.add_section_roc_plot(validation_set, class_value, nil, "roc-plot-"+class_value+".svg")
      #end
      report.add_section_confusion_matrix(validation_set.first)
    else #regression
      report.add_section_result(validation_set, VAL_ATTR_TRAIN_TEST + VAL_ATTR_REGR, "Results", "Results")
    end
    
    report.add_section_result(validation_set, Lib::ALL_PROPS, "All Results", "All Results")
    report.add_section_predictions( validation_set ) 
    return report
  end
  
  def self.create_report_crossvalidation(validation_set)
    
    raise Reports::BadRequest.new("num validations is not >1") unless validation_set.size>1
    raise Reports::BadRequest.new("crossvalidation-id not set in all validations") if validation_set.has_nil_values?(:crossvalidation_id)
    raise Reports::BadRequest.new("num different cross-validation-id's must be equal to 1") unless validation_set.num_different_values(:crossvalidation_id)==1
    validation_set.load_cv_attributes
    raise Reports::BadRequest.new("num validations ("+validation_set.size.to_s+") is not equal to num folds ("+validation_set.first.num_folds.to_s+")") unless validation_set.first.num_folds==validation_set.size
    raise Reports::BadRequest.new("num different folds is not equal to num validations") unless validation_set.num_different_values(:crossvalidation_fold)==validation_set.size
    raise Reports::BadRequest.new("validations must be either all regression, "+
      +"or all classification validations") unless validation_set.all_classification? or validation_set.all_regression?  
    
    merged = validation_set.merge([:crossvalidation_id])
    
    #puts merged.get_values(:percent_correct_variance, false).inspect
    report = Reports::ReportContent.new("Crossvalidation report")
    
    if (validation_set.first.classification?)
      report.add_section_result(merged, VAL_ATTR_CV+VAL_ATTR_CLASS-[:crossvalidation_fold],"Mean Results","Mean Results")
      
      report.add_section_roc_plot(validation_set, nil, nil, "roc-plot.svg")
      #validation_set.validations[0].get_prediction_feature_values.each do |class_value|
        #report.add_section_roc_plot(validation_set, class_value, nil, "roc-plot-"+class_value+".svg")
      #end
      report.add_section_confusion_matrix(merged.first)
      report.add_section_result(validation_set, VAL_ATTR_CV+VAL_ATTR_CLASS-[:num_folds], "Results","Results")
    else #regression
      report.add_section_result(merged, VAL_ATTR_CV+VAL_ATTR_REGR-[:crossvalidation_fold],"Mean Results","Mean Results")
      report.add_section_result(validation_set, VAL_ATTR_CV+VAL_ATTR_REGR-[:num_folds], "Results","Results")
    end
      
    report.add_section_result(validation_set, Lib::ALL_PROPS, "All Results", "All Results")
    report.add_section_predictions( validation_set, [:crossvalidation_fold] ) 
    return report
  end
  
  def self.create_report_compare_algorithms(validation_set)
    
    #validation_set.to_array([:fold, :test_dataset_uri, :model_uri]).each{|a| puts a.inspect}
    raise Reports::BadRequest.new("num validations is not >1") unless validation_set.size>1
    raise Reports::BadRequest.new("validations must be either all regression, "+
      +"or all classification validations") unless validation_set.all_classification? or validation_set.all_regression?
    raise Reports::BadRequest.new("number of different algorithms <2") if validation_set.num_different_values(:algorithm_uri)<2
      
    if validation_set.has_nil_values?(:crossvalidation_id)
      if validation_set.num_different_values(:test_dataset_uri)>1
        
        # groups results into sets with equal test and training dataset
        dataset_grouping = Reports::Util.group(validation_set.validations, [:test_dataset_uri, :training_dataset_uri])
        # check if the same algorithms exists for each test and training dataset
        Reports::Util.check_group_matching(dataset_grouping, [:algorithm_uri])
        
        #merged = validation_set.merge([:algorithm_uri, :dataset_uri])
        report = Reports::ReportContent.new("Algorithm comparison report Many datasets")
        
        if (validation_set.first.classification?)
          report.add_section_result(validation_set,[:algorithm_uri, :test_dataset_uri]+VAL_ATTR_CLASS,"Mean Results","Mean Results")
          report.add_section_ranking_plots(validation_set, :algorithm_uri, :test_dataset_uri,
            [:accuracy, :true_positive_rate, :true_negative_rate], "true")
        else # regression
          raise Reports::BadRequest.new("not implemented yet for regression")
        end
        return report
      else
        # this groups all validations in x different groups (arrays) according to there algorithm-uri
        algorithm_grouping = Reports::Util.group(validation_set.validations, [:algorithm_uri])
        # we check if there are corresponding validations in each group that have equal attributes (folds, num-folds,..)
        Reports::Util.check_group_matching(algorithm_grouping, [:training_dataset_uri, :test_dataset_uri, :prediction_feature])
        
        report = Reports::ReportContent.new("Algorithm comparison report")
        
        if (validation_set.first.classification?)
          report.add_section_bar_plot(validation_set,nil,:algorithm_uri,VAL_ATTR_BAR_PLOT_CLASS, "bar-plot.svg")   
          report.add_section_roc_plot(validation_set,nil, :algorithm_uri, "roc-plot.svg")
          #validation_set.validations[0].get_prediction_feature_values.each do |class_value|
            #report.add_section_bar_plot(validation_set,class_value,:algorithm_uri,VAL_ATTR_CLASS, "bar-plot-"+class_value+".svg")   
            #report.add_section_roc_plot(validation_set, class_value, :algorithm_uri, "roc-plot-"+class_value+".svg")
          #end
          report.add_section_result(validation_set,[:algorithm_uri]+VAL_ATTR_CLASS,"Results","Results")
        else #regression
          #report.add_section_result(merged, VAL_ATTR_CV+VAL_ATTR_REGR-[:crossvalidation_fold],"Mean Results","Mean Results")
          #report.add_section_result(validation_set, VAL_ATTR_CV+VAL_ATTR_REGR-[:num_folds], "Results","Results")
        end
        return report
      end
    else
      raise Reports::BadRequest.new("num different cross-validation-ids <2") if validation_set.num_different_values(:crossvalidation_id)<2
      validation_set.load_cv_attributes
      
      if validation_set.num_different_values(:dataset_uri)>1
        # groups results into sets with equal dataset 
        dataset_grouping = Reports::Util.group(validation_set.validations, [:dataset_uri])
        # check if equal values in each group exist
        Reports::Util.check_group_matching(dataset_grouping, [:algorithm_uri, :crossvalidation_fold, :num_folds, :stratified, :random_seed])
        # we only checked that equal validations exist in each dataset group, now check for each algorithm
        dataset_grouping.each do |validations|
          algorithm_grouping = Reports::Util.group(validations, [:algorithm_uri])
          Reports::Util.check_group_matching(algorithm_grouping, [:crossvalidation_fold, :num_folds, :stratified, :random_seed])
        end
        
        merged = validation_set.merge([:algorithm_uri, :dataset_uri])
        report = Reports::ReportContent.new("Algorithm comparison report - Many datasets")
        
        if (validation_set.first.classification?)
          report.add_section_result(merged,VAL_ATTR_CV+VAL_ATTR_CLASS-[:crossvalidation_fold],"Mean Results","Mean Results")
          report.add_section_ranking_plots(merged, :algorithm_uri, :dataset_uri, [:acc, :auc, :sens, :spec], "true")
        else # regression
          report.add_section_result(merged,VAL_ATTR_CV+VAL_ATTR_REGR-[:crossvalidation_fold],"Mean Results","Mean Results")
        end
        
        return report
      else
        # this groups all validations in x different groups (arrays) according to there algorithm-uri
        algorithm_grouping = Reports::Util.group(validation_set.validations, [:algorithm_uri])
        # we check if there are corresponding validations in each group that have equal attributes (folds, num-folds,..)
        Reports::Util.check_group_matching(algorithm_grouping, [:crossvalidation_fold, :num_folds, :dataset_uri, :stratified, :random_seed])
        merged = validation_set.merge([:algorithm_uri]) 
        
        report = Reports::ReportContent.new("Algorithm comparison report")
        
        if (validation_set.first.classification?)
          validation_set.validations[0].get_prediction_feature_values.each do |class_value|
            report.add_section_bar_plot(merged,class_value,:algorithm_uri,VAL_ATTR_CLASS, "bar-plot-"+class_value+".svg")   
            report.add_section_roc_plot(validation_set, class_value, :algorithm_uri, "roc-plot-"+class_value+".svg")
          end
          report.add_section_result(merged,VAL_ATTR_CV+VAL_ATTR_CLASS-[:crossvalidation_fold],"Mean Results","Mean Results")
          report.add_section_result(validation_set,VAL_ATTR_CV+VAL_ATTR_CLASS-[:num_folds],"Results","Results")
        else #regression
          report.add_section_result(merged, VAL_ATTR_CV+VAL_ATTR_REGR-[:crossvalidation_fold],"Mean Results","Mean Results")
          report.add_section_result(validation_set, VAL_ATTR_CV+VAL_ATTR_REGR-[:num_folds], "Results","Results")
        end
        
        return report
      end
    end
  end
  
end

# = Reports::ReportContent
#
# wraps an xml-report, adds functionality for adding sections, adds a hash for tmp files
#
class Reports::ReportContent
  
  attr_accessor :xml_report, :tmp_files
  
  def initialize(title)
    @xml_report = Reports::XMLReport.new(title, Time.now.strftime("Created at %m.%d.%Y - %H:%M"))
  end
  
  def add_section_predictions( validation_set, 
                              validation_attributes=[],
                              section_title="Predictions",
                              section_text="This section contains predictions.",
                              table_title="Predictions")
                                
    section_table = @xml_report.add_section(@xml_report.get_root_element, section_title)
    if validation_set.first.get_predictions
      @xml_report.add_paragraph(section_table, section_text) if section_text
      @xml_report.add_table(section_table, table_title, Reports::PredictionUtil.predictions_to_array(validation_set, validation_attributes))
    else
      @xml_report.add_paragraph(section_table, "No prediction info available.")
    end
  end
  
  def add_section_result( validation_set, 
                        validation_attributes,
                        table_title,
                        section_title="Results",
                        section_text="This section contains results.")
                                
    section_table = @xml_report.add_section(xml_report.get_root_element, section_title)
    @xml_report.add_paragraph(section_table, section_text) if section_text
    vals = validation_set.to_array(validation_attributes)
    #PENDING rexml strings in tables not working when >66  
    vals = vals.collect{|a| a.collect{|v| v.to_s[0,66] }}
    #PENDING transpose values if there more than 4 columns, and there are more than columns than rows
    transpose = vals[0].size>4 && vals[0].size>vals.size
    @xml_report.add_table(section_table, table_title, vals, !transpose, transpose)
  end
  
  def add_section_confusion_matrix(  validation, 
                                section_title="Confusion Matrix",
                                section_text="This section contains the confusion matrix.",
                                table_title="Confusion Matrix")
    section_confusion = @xml_report.add_section(xml_report.get_root_element, section_title)
    @xml_report.add_paragraph(section_confusion, section_text) if section_text
    @xml_report.add_table(section_confusion, table_title, 
      Reports::XMLReportUtil::create_confusion_matrix( validation.confusion_matrix ), false)
  end

  def add_section_roc_plot( validation_set,
                            class_value = nil,
                            split_set_attribute = nil,
                            plot_file_name="roc-plot.svg", 
                            section_title="Roc Plot",
                            section_text=nil,
                            image_title=nil,
                            image_caption=nil)
    
    if class_value
      section_text = "This section contains the roc plot for class '"+class_value+"'." unless section_text
      image_title = "Roc Plot for class-value '"+class_value+"'" unless image_title
    else
      section_text = "This section contains the roc plot." unless section_text
      image_title = "Roc Plot for all classes" unless image_title
    end
    
    section_roc = @xml_report.add_section(@xml_report.get_root_element, section_title)
    
    prediction_set = validation_set.collect{ |v| v.get_predictions && v.get_predictions.confidence_values_available? }
        
    if prediction_set.size>0
      
      section_text += "\nWARNING: roc plot information not available for all validation results" if prediction_set.size!=validation_set.size
      @xml_report.add_paragraph(section_roc, section_text) if section_text
      begin
        plot_file_path = add_tmp_file(plot_file_name)
        Reports::PlotFactory.create_roc_plot( plot_file_path, prediction_set, class_value, split_set_attribute, prediction_set.size>1 )
        @xml_report.add_imagefigure(section_roc, image_title, plot_file_name, "SVG", image_caption)
      rescue RuntimeError => ex
        LOGGER.error("could not create roc plot: "+ex.message)
        rm_tmp_file(plot_file_name)
        @xml_report.add_paragraph(section_roc, "could not create roc plot: "+ex.message)
      end  
    else
      @xml_report.add_paragraph(section_roc, "No prediction-confidence info for roc plot available.")
    end
    
  end
  
  def add_section_ranking_plots( validation_set,
                            compare_attribute,
                            equal_attribute,
                            rank_attributes,
                            class_value,
                            section_title="Ranking Plots",
                            section_text="This section contains the ranking plots.")
    
    section_rank = @xml_report.add_section(@xml_report.get_root_element, section_title)
    @xml_report.add_paragraph(section_rank, section_text) if section_text

    rank_attributes.each{|a| add_ranking_plot(section_rank, validation_set, compare_attribute, equal_attribute, a, class_value, a.to_s+"-ranking.svg")}
  end
  
  def add_ranking_plot( report_section, 
                        validation_set,
                        compare_attribute,
                        equal_attribute,
                        rank_attribute,
                        class_value=nil,
                        plot_file_name="ranking.svg", 
                        image_title="Ranking Plot",
                        image_caption=nil)
    
    plot_file_path = add_tmp_file(plot_file_name)
    Reports::PlotFactory::create_ranking_plot(plot_file_path, validation_set, compare_attribute, equal_attribute, rank_attribute, class_value)
    @xml_report.add_imagefigure(report_section, image_title, plot_file_name, "SVG", image_caption)
    
  end
  
  def add_section_bar_plot(validation_set,
                            class_value,
                            title_attribute,
                            value_attributes,
                            plot_file_name="bar-plot.svg", 
                            section_title="Bar Plot",
                            section_text=nil,
                            image_title=nil,
                            image_caption=nil)
    if class_value
      section_text = "This section contains the bar plot for class '"+class_value+"'." unless section_text
      image_title = "Bar Plot for class-value '"+class_value+"'" unless image_title
    else
      section_text = "This section contains the bar plot." unless section_text
      image_title = "Bar Plot for all classes" unless image_title
    end                            
    section_bar = @xml_report.add_section(@xml_report.get_root_element, section_title)
    @xml_report.add_paragraph(section_bar, section_text) if section_text
    
    plot_file_path = add_tmp_file(plot_file_name)
    Reports::PlotFactory.create_bar_plot(plot_file_path, validation_set, class_value, title_attribute, value_attributes )
    @xml_report.add_imagefigure(section_bar, image_title, plot_file_name, "SVG", image_caption)
  end  
  
  private
  def add_tmp_file(tmp_file_name)
    
    @tmp_files = {} unless @tmp_files
    raise "file name already exits" if @tmp_files[tmp_file_name] || (@text_files && @text_files[tmp_file_name])  
    tmp_file_path = Reports::Util.create_tmp_file(tmp_file_name)
    @tmp_files[tmp_file_name] = tmp_file_path
    return tmp_file_path
  end
  
  def rm_tmp_file(tmp_file_name)
    @tmp_files.delete(tmp_file_name) if @tmp_files.has_key?(tmp_file_name)
  end
  
end