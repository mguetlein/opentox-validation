ENV['JAVA_HOME'] = "/usr/bin" unless ENV['JAVA_HOME']
ENV['PATH'] = ENV['JAVA_HOME']+":"+ENV['PATH'] unless ENV['PATH'].split(":").index(ENV['JAVA_HOME'])
ENV['RANK_PLOTTER_JAR'] = "RankPlotter/RankPlotter.jar" unless ENV['RANK_PLOTTER_JAR']

class Array
  def swap!(i,j)
    tmp = self[i]
    self[i] = self[j]
    self[j] = tmp
  end
end


module Reports
  
  module PlotFactory 
    
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
      
      if split_set_attribute
        attribute_values = validation_set.get_values(split_set_attribute)
        
        names = []
        fp_rates = []
        tp_rates = []
        attribute_values.each do |value|
          data = transform_predictions(validation_set.filter({split_set_attribute => value}), class_value, false)
          names << value
          fp_rates << data[:fp_rate][0]
          tp_rates << data[:tp_rate][0]
        end
        RubyPlot::plot_lines(out_file, "ROC-Plot", "False positive rate", "True Positive Rate", names, fp_rates, tp_rates )
      else
        data = transform_predictions(validation_set, class_value, show_single_curves)
        RubyPlot::plot_lines(out_file, "ROC-Plot", "False positive rate", "True Positive Rate", data[:names], data[:fp_rate], data[:tp_rate], data[:faint] )
      end  
    end
    
    def self.create_bar_plot( out_file, validation_set, class_value, title_attribute, value_attributes )
  
      LOGGER.debug "creating bar plot, out-file:"+out_file.to_s
      
      data = []
      titles = []
      
      validation_set.validations.each do |v|
        values = []
        value_attributes.each do |a|
          value = v.send(a)
          if value.is_a?(Hash)
            if class_value==nil
              avg_value = 0
              value.values.each{ |val| avg_value+=val }
              value = avg_value/value.values.size.to_f
            else
              raise "bar plot value is hash, but no entry for class-value ("+class_value.to_s+"); value for "+a.to_s+" -> "+value.inspect unless value.key?(class_value)
              value = value[class_value]
            end
          end
          values.push(value)
        end
        
        titles << v.send(title_attribute).to_s
        data << values
      end
      
      titles = titles.remove_common_prefix
      (0..titles.size-1).each do |i|
        data[i] = [titles[i]] + data[i]
      end
      
      labels = value_attributes.collect{|a| a.to_s.gsub("_","-")}
      
      LOGGER.debug "bar plot labels: "+labels.inspect 
      LOGGER.debug "bar plot data: "+data.inspect
      
      RubyPlot::plot_bars('Bar plot', labels, data, out_file)
    end
    
    
    def self.create_ranking_plot( svg_out_file, validation_set, compare_attribute, equal_attribute, rank_attribute, class_value=nil )

      #compute ranks
      #puts "rank attibute is "+rank_attribute.to_s
      
      rank_set = validation_set.compute_ranking([equal_attribute],rank_attribute,class_value)
      #puts compare_attribute
      #puts rank_set.to_array([:algorithm_uri, :dataset_uri, :percent_correct, :percent_correct_ranking]).collect{|a| a.inspect}.join("\n")
      #puts "\n"
      
      #compute avg ranks
      merge_set = rank_set.merge([compare_attribute])
      #puts merge_set.to_array([:algorithm_uri, :dataset_uri, :percent_correct, :percent_correct_ranking]).collect{|a| a.inspect}.join("\n")
      
      
      comparables = merge_set.get_values(compare_attribute)
      ranks = merge_set.get_values((rank_attribute.to_s+"_ranking").to_sym,false)
      
      plot_ranking( rank_attribute.to_s+" ranking",
                    comparables, 
                    ranks, 
                    nil, #0.1, 
                    validation_set.num_different_values(equal_attribute), 
                    svg_out_file) 
    end
  
    protected
    def self.plot_ranking( title, comparables_array, ranks_array, confidence = nil, numdatasets = nil, svg_out_file = nil )
      
      (confidence and numdatasets) ? conf = "-q "+confidence.to_s+" -k "+numdatasets.to_s : conf = ""
      svg_out_file ? show = "-o" : show = ""  
      (title and title.length > 0) ? tit = '-t "'+title+'"' : tit = ""  
      #title = "-t \""+ranking_value_prop+"-Ranking ("+comparables.size.to_s+" "+comparable_prop+"s, "+num_groups.to_s+" "+ranking_group_prop+"s, p < "+p.to_s+")\" "
      
      cmd = "java -jar "+ENV['RANK_PLOTTER_JAR']+" "+tit+" -c '"+
        comparables_array.join(",")+"' -r '"+ranks_array.join(",")+"' "+conf+" "+show #+" > /home/martin/tmp/test.svg" 
      #puts "\nplotting: "+cmd
      LOGGER.debug "Plotting ranks: "+cmd.to_s
      
      res = ""
      IO.popen(cmd) do |f|
          while line = f.gets do
            res += line 
          end
      end
      raise "rank plot failed" unless $?==0
      
      if svg_out_file
        f = File.new(svg_out_file, "w")
        f.puts res
      end
        
      svg_out_file ? svg_out_file : res
    end
    
    def self.demo_ranking_plot
      puts plot_ranking( nil, ["naive bayes", "svm", "decision tree"], [1.9, 3, 1.5], 0.1, 50) #, "/home/martin/tmp/test.svg")
    end
    
    private
    def self.transform_predictions(validation_set, class_value, add_single_folds=false)
      
      if (validation_set.size > 1)
        
        names = []; fp_rate = []; tp_rate = []; faint = []
        sum_roc_values = { :predicted_values => [], :actual_values => [], :confidence_values => []}
        
        (0..validation_set.size-1).each do |i|
          roc_values = validation_set.get(i).get_predictions.get_roc_values(class_value)
          sum_roc_values[:predicted_values] += roc_values[:predicted_values]
          sum_roc_values[:confidence_values] += roc_values[:confidence_values]
          sum_roc_values[:actual_values] += roc_values[:actual_values]
          if add_single_folds
            tp_fp_rates = get_tp_fp_rates(roc_values)
            names << "fold "+i.to_s
            fp_rate << tp_fp_rates[:fp_rate]
            tp_rate << tp_fp_rates[:tp_rate]
            faint << true
          end
        end
        tp_fp_rates = get_tp_fp_rates(sum_roc_values)
        names << "all"
        fp_rate << tp_fp_rates[:fp_rate]
        tp_rate << tp_fp_rates[:tp_rate]
        faint << false
        return { :names => names, :fp_rate => fp_rate, :tp_rate => tp_rate, :faint => faint }
      else
        roc_values = validation_set.validations[0].get_predictions.get_roc_values(class_value)
        tp_fp_rates = get_tp_fp_rates(roc_values)
        return { :names => ["default"], :fp_rate => [tp_fp_rates[:fp_rate]], :tp_rate => [tp_fp_rates[:tp_rate]] }
      end
    end
    
    def self.get_tp_fp_rates(roc_values)
      
      c = roc_values[:confidence_values]
      p = roc_values[:predicted_values]
      a = roc_values[:actual_values]
      raise "no prediction values for roc-plot" if p.size==0
      
      (0..p.size-2).each do |i|
        ((i+1)..p.size-1).each do |j|
          if c[i]<c[j]
            c.swap!(i,j)
            a.swap!(i,j)
            p.swap!(i,j)
          end
        end
      end
      #puts c.inspect+"\n"+a.inspect+"\n"+p.inspect+"\n\n"
     
      tp_rate = [0]
      fp_rate = [0]
      (0..p.size-1).each do |i|
        if a[i]==p[i]
          tp_rate << tp_rate[-1]+1
          fp_rate << fp_rate[-1]
        else
          fp_rate << fp_rate[-1]+1
          tp_rate << tp_rate[-1]
        end
      end
      #puts tp_rate.inspect+"\n"+fp_rate.inspect+"\n\n"
      
      (0..tp_rate.size-1).each do |i|
        tp_rate[i] = tp_rate[-1]>0 ? tp_rate[i]/tp_rate[-1].to_f*100 : 100
        fp_rate[i] = fp_rate[-1]>0 ? fp_rate[i]/fp_rate[-1].to_f*100 : 100
      end
      #puts tp_rate.inspect+"\n"+fp_rate.inspect+"\n\n"
      
      return {:tp_rate => tp_rate,:fp_rate => fp_rate}
    end
  end
end
   
#Reports::PlotFactory::demo_ranking_plot
