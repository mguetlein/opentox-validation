
# = Reports::ReportContent
#
# wraps an xml-report, adds functionality for adding sections, adds a hash for tmp files
#
class Reports::ReportContent
  
  attr_accessor :xml_report, :tmp_files
  
  def initialize(title)
    @xml_report = Reports::XMLReport.new(title, Time.now.strftime("Created at %m.%d.%Y - %H:%M"))
    @tmp_file_count = 0
    @current_section = @xml_report.get_root_element
  end
  
  def add_section( section_title, section_text=nil )
    @current_section = @xml_report.add_section(@xml_report.get_root_element, section_title)
    @xml_report.add_paragraph(@current_section, section_text) if section_text
  end
  
  def end_section()
    @current_section = @xml_report.get_root_element
  end
  
  def add_paired_ttest_table( validation_set,
                       group_attribute, 
                       test_attribute,
                       section_title = "Paired t-test",
                       section_text = nil)
                       
    level = 0.90                       
    test_matrix = Reports::ReportStatisticalTest.test_matrix( validation_set.validations, 
      group_attribute, test_attribute, "paired_ttest", level )
    puts test_matrix.inspect
    titles = test_matrix[:titles]
    matrix = test_matrix[:matrix]
    table = []
    puts titles.inspect
    table << [""] + titles
    titles.size.times do |i|
      table << [titles[i]] + matrix[i].collect{|v| (v==nil || v==0) ? "" : (v<0 ? "-" : "+") }
    end
    
    section_test = @xml_report.add_section(@current_section, section_title)
    @xml_report.add_paragraph(section_test, section_text) if section_text
    @xml_report.add_table(section_test, test_attribute.to_s+", significance-level: "+level.to_s, table, true, true)  
  end
  
  def add_predictions( validation_set, 
                              validation_attributes=[],
                              section_title="Predictions",
                              section_text=nil,
                              table_title="Predictions")

    #PENING
    raise "validation attributes not implemented in get prediction array" if  validation_attributes.size>0
    
    section_table = @xml_report.add_section(@current_section, section_title)
    if validation_set.validations[0].get_predictions
      @xml_report.add_paragraph(section_table, section_text) if section_text
      @xml_report.add_table(section_table, table_title, Lib::OTPredictions.to_array(validation_set.validations.collect{|v| v.get_predictions}, 
        true, false, true))
    else
      @xml_report.add_paragraph(section_table, "No prediction info available.")
    end
  end


  def add_result_overview( validation_set,
                        attribute_col,
                        attribute_row, 
                        attribute_values,
                        table_titles=nil,
                        section_title="Result overview",
                        section_text=nil )
    
    
    section_table = @xml_report.add_section(@current_section, section_title)
    @xml_report.add_paragraph(section_table, section_text) if section_text
    
    attribute_values.size.times do |i|
      attribute_val = attribute_values[i]
      table_title = table_titles ? table_titles[i] : "Result overview for "+attribute_val.to_s
      vals = validation_set.to_table( attribute_col, attribute_row, attribute_val)
      @xml_report.add_table(section_table, table_title, vals, true, true)  
    end
  end

  # result (could be transposed)
  #
  #  attr1      | attr2     | attr3
  #  ===========|===========|===========
  #  val1-attr1 |val1-attr2 |val1-attr3 
  #  val2-attr1 |val2-attr2 |val2-attr3
  #  val3-attr1 |val3-attr2 |val3-attr3
  #
  def add_result( validation_set, 
                        validation_attributes,
                        table_title,
                        section_title="Results",
                        section_text=nil,
                        #rem_equal_vals_attr=[],
                        search_for_existing_report_type=nil)

    section_table = @xml_report.add_section(@current_section, section_title)
    @xml_report.add_paragraph(section_table, section_text) if section_text
    vals = validation_set.to_array(validation_attributes, true)
    vals = vals.collect{|a| a.collect{|v| v.to_s }}
    
    if (search_for_existing_report_type)
      vals.size.times do |i|
        puts i
        if (i==0)
          vals[i] = [ "Reports" ] + vals[i]
          puts vals[i].inspect
        else
          if search_for_existing_report_type=="validation"
            vals[i] = [ validation_set.validations[i-1].validation_report_uri() ] + vals[i]
          elsif search_for_existing_report_type=="crossvalidation"
            vals[i] = [ validation_set.validations[i-1].cv_report_uri() ] + vals[i]
          else
            raise "illegal report type: "+search_for_existing_report_type.to_s
          end
        end
      end
    end
    #PENDING transpose values if there more than 4 columns, and there are more than columns than rows
    transpose = vals[0].size>4 && vals[0].size>vals.size
    @xml_report.add_table(section_table, table_title, vals, !transpose, transpose, transpose)
  end
  
  def add_confusion_matrix(  validation, 
                                section_title="Confusion Matrix",
                                section_text=nil,
                                table_title="Confusion Matrix")
    section_confusion = @xml_report.add_section(@current_section, section_title)
    @xml_report.add_paragraph(section_confusion, section_text) if section_text
    @xml_report.add_table(section_confusion, table_title, 
      Reports::XMLReportUtil::create_confusion_matrix( validation.confusion_matrix ), true, true)
  end
  
  def add_regression_plot( validation_set,
                            name_attribute,
                            section_title="Regression Plot",
                            section_text=nil,
                            image_title=nil,
                            image_caption=nil)
                            
    image_title = "Regression plot" unless image_title
    
    section_regr = @xml_report.add_section(@current_section, section_title)
    prediction_set = validation_set.collect{ |v| v.get_predictions }
        
    if prediction_set.size>0
      
      section_text += "\nWARNING: regression plot information not available for all validation results" if prediction_set.size!=validation_set.size
      @xml_report.add_paragraph(section_regr, section_text) if section_text
      plot_file_name = "regr_plot"+@tmp_file_count.to_s+".svg"
      @tmp_file_count += 1
      begin
        plot_file_path = add_tmp_file(plot_file_name)
        Reports::PlotFactory.create_regression_plot( plot_file_path, prediction_set, name_attribute )
        @xml_report.add_imagefigure(section_regr, image_title, plot_file_name, "SVG", image_caption)
      rescue RuntimeError => ex
        LOGGER.error("Could not create regression plot: "+ex.message)
        rm_tmp_file(plot_file_name)
        @xml_report.add_paragraph(section_regr, "could not create regression plot: "+ex.message)
      end  
    else
      @xml_report.add_paragraph(section_regr, "No prediction info for regression available.")
    end
  end

  def add_roc_plot( validation_set,
                            split_set_attribute = nil,
                            section_title="ROC Plots",
                            section_text=nil,
                            image_titles=nil,
                            image_captions=nil)
                            
    section_roc = @xml_report.add_section(@current_section, section_title)
    prediction_set = validation_set.collect{ |v| v.get_predictions && v.get_predictions.confidence_values_available? }
        
    if prediction_set.size>0
      if prediction_set.size!=validation_set.size
        section_text += "\nWARNING: roc plot information not available for all validation results"
        LOGGER.error "WARNING: roc plot information not available for all validation results:\n"+
          "validation set size: "+validation_set.size.to_s+", prediction set size: "+prediction_set.size.to_s
      end
      @xml_report.add_paragraph(section_roc, section_text) if section_text

      class_domain = validation_set.get_class_domain
      class_domain.size.times do |i|
        class_value = class_domain[i]
        image_title = image_titles ? image_titles[i] : "ROC Plot for class-value '"+class_value+"'"
        image_caption = image_captions ? image_captions[i] : nil
        plot_file_name = "roc_plot"+@tmp_file_count.to_s+".svg"
        @tmp_file_count += 1
        begin
          plot_file_path = add_tmp_file(plot_file_name)
          Reports::PlotFactory.create_roc_plot( plot_file_path, prediction_set, class_value, split_set_attribute, false )#prediction_set.size>1 )
          @xml_report.add_imagefigure(section_roc, image_title, plot_file_name, "SVG", image_caption)
        rescue RuntimeError => ex
          msg = "WARNING could not create roc plot for class value '"+class_value+"': "+ex.message
          LOGGER.error(msg)
          rm_tmp_file(plot_file_name)
          @xml_report.add_paragraph(section_roc, msg)
        end  
      end
    else
      @xml_report.add_paragraph(section_roc, "No prediction-confidence info for roc plot available.")
    end
    
  end
  
  def add_ranking_plots( validation_set,
                            compare_attribute,
                            equal_attribute,
                            rank_attributes,
                            section_title="Ranking Plots",
                            section_text="This section contains the ranking plots.")
    
    section_rank = @xml_report.add_section(@current_section, section_title)
    @xml_report.add_paragraph(section_rank, section_text) if section_text
    
    rank_attributes.each do |a|
      add_ranking_plot(section_rank, validation_set, compare_attribute, equal_attribute, a)
    end
  end
  
  def add_ranking_plot( report_section, 
                        validation_set,
                        compare_attribute,
                        equal_attribute,
                        rank_attribute,
                        image_titles=nil,
                        image_captions=nil)

    class_domain = validation_set.get_domain_for_attr(rank_attribute)
    puts "ranking plot for "+rank_attribute.to_s+", class values: "+class_domain.to_s
    
    class_domain.size.times do |i|  
      class_value = class_domain[i]
      if image_titles
        image_title = image_titles[i]
      else
        if class_value!=nil
          image_title = rank_attribute.to_s+" Ranking Plot for class-value '"+class_value+"'"
        else 
          image_title = rank_attribute.to_s+" Ranking Plot"
        end
      end
      image_caption = image_captions ? image_captions[i] : nil
      plot_file_name = "ranking_plot"+@tmp_file_count.to_s+".svg"
      @tmp_file_count += 1
      plot_file_path = add_tmp_file(plot_file_name)
      Reports::PlotFactory::create_ranking_plot(plot_file_path, validation_set, compare_attribute, equal_attribute, rank_attribute, class_value)
      @xml_report.add_imagefigure(report_section, image_title, plot_file_name, "SVG", image_caption)
    end
  end
  
  def add_bar_plot(validation_set,
                            title_attribute,
                            value_attributes,
                            section_title="Bar Plot",
                            section_text=nil,
                            image_title="Bar Plot",
                            image_caption=nil)
    
    section_bar = @xml_report.add_section(@current_section, section_title)
    @xml_report.add_paragraph(section_bar, section_text) if section_text
    
    plot_file_name = "bar_plot"+@tmp_file_count.to_s+".svg"
    @tmp_file_count += 1
    plot_file_path = add_tmp_file(plot_file_name)
    Reports::PlotFactory.create_bar_plot(plot_file_path, validation_set, title_attribute, value_attributes )
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