ENV['JAVA_HOME'] = "/usr/bin" unless ENV['JAVA_HOME']
ENV['PATH'] = ENV['JAVA_HOME']+":"+ENV['PATH'] unless ENV['PATH'].split(":").index(ENV['JAVA_HOME'])
ENV['RANK_PLOTTER_JAR'] = "RankPlotter/RankPlotter.jar" unless ENV['RANK_PLOTTER_JAR']

module Reports
  
  module PlotFactory 
  
    def self.create_ranking_plot( svg_out_file, validation_set, compare_attribute, equal_attribute, rank_attribute )

      #compute ranks
      rank_set = validation_set.compute_ranking([equal_attribute],rank_attribute)
      #puts rank_set.to_array([:algorithm_uri, :dataset_uri, :acc, :acc_ranking]).collect{|a| a.inspect}.join("\n")

      #compute avg ranks
      merge_set = rank_set.merge([compare_attribute])
      #puts merge_set.to_array([:algorithm_uri, :dataset_uri, :acc, :acc_ranking]).collect{|a| a.inspect}.join("\n")
      
      comparables = merge_set.get_values(compare_attribute)
      ranks = merge_set.get_values((rank_attribute.to_s+"_ranking").to_sym)
      
      plot_ranking( rank_attribute.to_s+" ranking",
                    comparables, 
                    ranks, 
                    0.1, 
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
      
      res = ""
      IO.popen(cmd) do |f|
          while line = f.gets do
            res += line 
          end
      end
      if svg_out_file
        f = File.new(svg_out_file, "w")
        f.puts res
      end
        
      svg_out_file ? svg_out_file : res
    end
    
    def self.demo_ranking_plot
      puts plot_ranking( nil, ["naive bayes", "svm", "decision tree"], [1.9, 3, 1.5], 0.1, 50) #, "/home/martin/tmp/test.svg")
    end
    
    
  end
end
   
#Reports::PlotFactory::demo_ranking_plot
