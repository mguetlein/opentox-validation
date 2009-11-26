
# selected attributes of interest when generating the report for a train-/test-evaluation                      
VAL_ATTR_TRAIN_TEST = [ :model_uri, :training_dataset_uri, :test_dataset_uri ]
# selected attributes of interest when generating the crossvalidation report
VAL_ATTR_CV = [ :algorithm_uri, :dataset_uri, :num_folds, :crossvalidation_fold ]
# selected attributes of interest when performing classification
VAL_ATTR_CLASS = [ :auc, :acc, :sens, :spec ]


# = Reports::ReportFactory 
#
# creates various reports (Reports::ReportContent) 
#
module Reports::ReportFactory
  
  RT_FASTTOX = "fasttox"
  RT_VALIDATION = "validation"
  RT_CV = "crossvalidation"
  RT_ALG_COMP = "algorithm_comparison"
  
  REPORT_TYPES = [RT_FASTTOX, RT_VALIDATION, RT_CV, RT_ALG_COMP ]
  
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

    report = Reports::ReportContent.new("Validation report")
    report.add_section_result(validation_set, VAL_ATTR_TRAIN_TEST + VAL_ATTR_CLASS, "Results", "Results")
    report.add_section_roc_plot(validation_set)
    report.add_section_confusion_matrix(validation_set.first)
    report.add_section_result(validation_set, OpenTox::Validation::ALL_PROPS, "All Results", "All Results")
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
    merged = validation_set.merge([:crossvalidation_id])
    
    puts merged.get_values(:acc_variance, false).inspect
     
    report = Reports::ReportContent.new("Crossvalidation report")
    report.add_section_result(merged, VAL_ATTR_CV+VAL_ATTR_CLASS-["crossvalidation_fold"],"Mean Results","Mean Results")
    report.add_section_roc_plot(validation_set)
    report.add_section_confusion_matrix(merged.first)
    report.add_section_result(validation_set, VAL_ATTR_CV+VAL_ATTR_CLASS-[:num_folds], "Results","Results")
    report.add_section_result(validation_set, OpenTox::Validation::ALL_PROPS, "All Results", "All Results")
    report.add_section_predictions( validation_set, [:crossvalidation_fold] ) 
    return report
  end
  
  def self.create_report_compare_algorithms(validation_set)
    
    #validation_set.to_array([:fold, :test_dataset_uri, :model_uri]).each{|a| puts a.inspect}
    raise Reports::BadRequest.new("num validations is not >1") unless validation_set.size>1

    if validation_set.has_nil_values?(:crossvalidation_id)
      raise Reports::BadRequest.new("so far, algorithm comparison is only supported for crossvalidation results")
    else
      raise Reports::BadRequest.new("num different cross-validation-ids <2") if validation_set.num_different_values(:crossvalidation_id)<2
      validation_set.load_cv_attributes
      raise Reports::BadRequest.new("number of different algorithms <2") if validation_set.num_different_values(:algorithm_uri)<2
      
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
        report.add_section_result(merged,VAL_ATTR_CV+VAL_ATTR_CLASS-[:crossvalidation_fold],"Mean Results","Mean Results")
        report.add_section_ranking_plots(merged, :algorithm_uri, :dataset_uri, [:acc, :auc, :sens, :spec])
        return report
      else
        # this groups all validations in x different groups (arrays) according to there algorithm-uri
        algorithm_grouping = Reports::Util.group(validation_set.validations, [:algorithm_uri])
        # we check if there are corresponding validations in each group that have equal attributes (folds, num-folds,..)
        Reports::Util.check_group_matching(algorithm_grouping, [:crossvalidation_fold, :num_folds, :dataset_uri, :stratified, :random_seed])
        merged = validation_set.merge([:algorithm_uri]) 
        
        report = Reports::ReportContent.new("Algorithm comparison report")
        report.add_section_bar_plot(merged,:algorithm_uri,VAL_ATTR_CLASS)   
        report.add_section_roc_plot(validation_set, :algorithm_uri)
        report.add_section_result(merged,VAL_ATTR_CV+VAL_ATTR_CLASS-[:crossvalidation_fold],"Mean Results","Mean Results")
        report.add_section_result(validation_set,VAL_ATTR_CV+VAL_ATTR_CLASS-[:num_folds],"Results","Results")
        
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
    #transpose values if there more than 8 columns
    transpose = vals[0].size>8 && vals[0].size>vals.size
    @xml_report.add_table(section_table, table_title, vals, !transpose, transpose)   
  end
  
  def add_section_confusion_matrix(  validation, 
                                section_title="Confusion Matrix",
                                section_text="This section contains the confusion matrix.",
                                table_title="Confusion Matrix")
                                
    section_confusion = @xml_report.add_section(xml_report.get_root_element, section_title)
    @xml_report.add_paragraph(section_confusion, section_text) if section_text
    @xml_report.add_table(section_confusion, table_title, Reports::XMLReportUtil::create_confusion_matrix(
      validation.tp, validation.fp, validation.tn, validation.fn), false)

  end

  def add_section_roc_plot( validation_set,
                            split_set_attribute = nil,
                            plot_file_name="roc-plot.svg", 
                            section_title="Roc Plot",
                            section_text="This section contains the roc plot.",
                            image_title="Roc Plot",
                            image_caption=nil)
    
    section_roc = @xml_report.add_section(@xml_report.get_root_element, section_title)
    if validation_set.first.get_predictions
      @xml_report.add_paragraph(section_roc, section_text) if section_text

      plot_file_path = add_tmp_file(plot_file_name)
      Reports::RPlotFactory.create_roc_plot( plot_file_path, validation_set, split_set_attribute, validation_set.size>1 )
      @xml_report.add_imagefigure(section_roc, image_title, plot_file_name, "SVG", image_caption)
    else
      @xml_report.add_paragraph(section_roc, "No prediction info for roc plot available.")
    end
    
  end
  
  def add_section_ranking_plots( validation_set,
                            compare_attribute,
                            equal_attribute,
                            rank_attributes,
                            section_title="Ranking Plots",
                            section_text="This section contains the ranking plots.")
    
    section_rank = @xml_report.add_section(@xml_report.get_root_element, section_title)
    @xml_report.add_paragraph(section_rank, section_text) if section_text

    rank_attributes.each{|a| add_ranking_plot(section_rank, validation_set, compare_attribute, equal_attribute, a, a.to_s+"-ranking.svg")}
  end
  
  def add_ranking_plot( report_section, 
                        validation_set,
                        compare_attribute,
                        equal_attribute,
                        rank_attribute,
                        plot_file_name="ranking.svg", 
                        image_title="Ranking Plot",
                        image_caption=nil)
    
    plot_file_path = add_tmp_file(plot_file_name)
    Reports::PlotFactory::create_ranking_plot(plot_file_path, validation_set, compare_attribute, equal_attribute, rank_attribute)
    @xml_report.add_imagefigure(report_section, image_title, plot_file_name, "SVG", image_caption)
    
  end
  
  def add_section_bar_plot(validation_set, 
                            title_attribute,
                            value_attributes,
                            plot_file_name="bar-plot.svg", 
                            section_title="Bar Plot",
                            section_text="This section contains the bar plot.",
                            image_title="Bar Plot",
                            image_caption=nil)
  
    section_bar = @xml_report.add_section(@xml_report.get_root_element, section_title)
    @xml_report.add_paragraph(section_bar, section_text) if section_text
    
    plot_file_path = add_tmp_file(plot_file_name)
    Reports::RPlotFactory.create_bar_plot(plot_file_path, validation_set, title_attribute, value_attributes )
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
  
end