
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

