
# the r-path has to be added for the rinruby plugin
if ENV['R_HOME']
  ENV['PATH'] = ENV['R_HOME']+":"+ENV['PATH'] unless ENV['PATH'].split(":").index(ENV['R_HOME'])
else
  LOGGER.warn "Environment variable R_HOME not set"
end
require "rinruby"

# colors for r-plots
R_PLOT_COLORS = ["red", "blue", "green", "yellow"]

# = Reports::RPlotFactory 
#
# creates plots from validation-sets using rinruby
#
module Reports::RPlotFactory 

  # creates a bar plot (result is plotted into out_file), 
  # one category for each attribute in value_attributes, title_attribute is used for the legend
  #
  def self.create_bar_plot( out_file, validation_set, class_value, title_attribute, value_attributes )
  
    LOGGER.debug "creating bar plot, out-file:"+out_file.to_s
    b = Reports::BarPlot.new( out_file )
    validation_set.validations.each do |v|
      values = []
      value_attributes.collect do |a|
        value = v.send(a)
        if value.is_a?(Hash)
          raise "bar plat value is hash, but no entry for class-value ("+class_value.to_s+")" unless value.key?(class_value)
          value = value[class_value]
        end
        values.push(value)
      end
      b.add_data(v.send(title_attribute), values)
    end
    b.build_plot(value_attributes.collect{|a| a.to_s})
  end
  
  # creates a roc plot (result is plotted into out_file)
  # * if (split_set_attributes == nil?)
  #   * the predictions of all validations in the validation set are plotted as one average roc-curve
  #   * if (show_single_curves == true) -> the single predictions of each validation are plotted as well   
  # * if (split_set_attributes != nil?)
  #   * the validation set is splitted into sets of validation_sets with equal attribute values
  #   * each of theses validation sets is plotted as a roc-curve  
  #
  def self.create_roc_plot( out_file, validation_set, class_value, split_set_attribute=nil, show_single_curves=false )
    
    LOGGER.debug "creating roc plot, out-file:"+out_file.to_s
    r = Reports::RocPlot.new( out_file )
    if split_set_attribute
        attribute_values = validation_set.get_values(split_set_attribute)
        attribute_values.each do |value|
        p = transform_predictions(validation_set.filter({split_set_attribute => value}), class_value)
        r.plot_predictions(value, p[0], p[1], false)
      end
      r.add_legend
    else
      p = transform_predictions(validation_set, class_value)
      r.plot_predictions("", p[0], p[1], show_single_curves)
    end  
  end
  
  def self.demo_roc_plot(file = nil)
    r = Reports::RocPlot.new(file)
    r.plot_predictions("Test1",[0.612547843, 0.364270971, 0.432136142, 0.140291078, 0.384895941, 0.244415489],[1, 1, 0, 0, 0, 1])
    r.plot_predictions("Test2",[0.612547843, 0.364270971, 0.432136142, 0.140291078, 0.384895941, 0.244415489],[0, 0, 1, 0, 1, 1])
    r.add_legend
    unless file
      puts "press ENTER to end program"
      gets
      puts "program ended"
    end
  end
  
  def self.demo_bar_plot(file = nil)
    r = Reports::BarPlot.new(file)
    r.add_data("Alg1",[0.9, 0.3, 0.2, 0.75, 0.5])
    r.add_data("Alg2",[0.8, 0.4, 0.2, 0.77, 0.6])
    r.add_data("Alg3",[0.4, 0.2, 0.1, 0.9, 0.55])
    r.add_data("Alg4",[0.9, 0.3, 0.2, 0.75, 0.5])
    r.build_plot(["val1", "val2", "val3", "val4", "high-val"])
    unless(file)
      puts "press ENTER to end program"
      gets
      puts "program ended"
    end
  end
  
  private
  def self.transform_predictions(validation_set, class_value)

    predict_array = Array.new
    actual_array = Array.new
    if (validation_set.size > 1)
      (0..validation_set.size-1).each do |i|
        predict_array.push(validation_set.get(i).get_predictions.roc_confidence_values(class_value))
        actual_array.push(validation_set.get(i).get_predictions.roc_actual_values(class_value))
      end
    else
      predict_array = validation_set.first.get_predictions.roc_confidence_values(class_value)
      actual_array = validation_set.first.get_predictions.roc_actual_values(class_value)
    end
    return [ predict_array, actual_array ]
  end

end


class Reports::RPlot
  
  def initialize( out_file = nil )
    if out_file
      raise "non-svg files not supported yet" unless out_file.to_s.upcase =~ /.*\.SVG.*/
      R.eval 'library("RSVGTipsDevice")'
      R.eval 'devSVGTips(file = "'+out_file+'")'
    end
  end
  
end

class Reports::BarPlot < Reports::RPlot
  
  def initialize( out_file = nil )
    super(out_file)
    @titles = Array.new
    @rows = Array.new
  end
  
  def add_data(title, values)
    
    row = "row"+(@rows.size+1).to_s 
    R.assign row, values
    @rows.push(row)
    @titles.push(title)
  end

  def build_plot(value_names, y_axis_scale=[0,1])
    
    raise "not enough colors defined" if @titles.size >  R_PLOT_COLORS.size
    @cols = R_PLOT_COLORS[0, @titles.size]
    R.assign "titles", @titles
    R.assign "cols", @cols
    R.eval "m <-rbind("+@rows.join(",")+")"
    R.assign "my_names", value_names
    R.assign "my_ylim", y_axis_scale
    R.eval 'barplot(m, beside = TRUE, col = cols, names=my_names, legend=titles, ylim = my_ylim)'
  end
end

class Reports::RocPlot < Reports::RPlot
  
  def initialize( out_file = nil )
    super(out_file)
    @titles = Array.new
  end

  def add_legend
    
    @cols = R_PLOT_COLORS[0, @titles.size]
    R.assign "titles", @titles
    R.assign "cols", @cols
    R.eval "legend(0.60,0.20,titles,col=cols,lwd=3)"
  end

  def plot_predictions(title, predict_array, actual_array, show_single_curves = false)
  
    puts "predict "+predict_array.to_nice_s
    puts "actual  "+actual_array.to_nice_s
  
    if (predict_array[0].is_a?(Array)) #multi-dim-arrays
      
      # PENDING: very in-efficient, add new type to r-in-ruby 
      preds = ""
      actual = ""
      (0..predict_array.size-1).each do |i|
        R.assign "prediction_values"+i.to_s, predict_array[i]
        preds += "prediction_values"+i.to_s + ","
        R.assign "actual_values"+i.to_s, actual_array[i]
        actual += "actual_values"+i.to_s + ","
      end
      R.eval "prediction_values <- list("+preds.chop+")"
      R.eval "actual_values <- list("+actual.chop+")"
    else
      R.assign "prediction_values", predict_array
      R.assign "actual_values", actual_array
    end
    
    R.eval("library(ROCR)", false)
    R.eval("pred <- prediction(prediction_values,actual_values)")
    R.eval 'perf <- performance(pred,"tpr","fpr")'
    begin 
      # WORKAROUND to check weather the r calls worked out so far 
      R.pull "perf@x.name"
    rescue => ex
      raise "error while creating roc plot ("+ex.message.to_s+")"
    end
    
    add_plot = @titles.size > 0 ? "add=TRUE" : "add=FALSE"
    avg = predict_array[0].is_a?(Array) ? 'avg="threshold",' : 'avg="none",' 
    #puts "avg: "+avg
    raise "not enough colors defined" if @titles.size >=  R_PLOT_COLORS.size
    
    R.eval 'plot(perf, '+avg+' col="'+R_PLOT_COLORS[@titles.size]+'", '+add_plot+')'
    R.eval 'plot(perf, ,col="grey82", add=TRUE)' if show_single_curves
    @titles.push(title)
    
    R.eval "prediction_values <- NULL"
    R.eval "actual_values <- NULL"
    R.eval "pred <- NULL"
    R.eval "perf <- NULL"
  end
  
end
