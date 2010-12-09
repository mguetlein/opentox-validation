#require "rubygems"
#require "rinruby"
#R.quit

module LIB
  class StatisticalTest
  
    @@r = RinRuby.new(true,false)
    
    # -1 -> array1 < array2
    # 0 -> not difference
    # 1 -> array2 > array1
    #
    def self.pairedTTest(array1, array2, significance_level=0.95)
      @@r.assign "v1",array1
      @@r.assign "v2",array2
      @@r.eval "ttest = t.test(v1,v2,paired=T)"
      t = @@r.pull "ttest$statistic"
      p = @@r.pull "ttest$p.value"
      #@@r.quit
      if (1-significance_level > p)
        t
      else
        0
      end
    end
  end
end

module Reports
 
  class ReportStatisticalTest
    
    # __grouped_validations__ : array of validation arrays
    def self.test_matrix( validations, group_attribute, test_attribute, test_method="paired_ttest", significance_level=0.95 )
      
      raise "statistical-test: '"+test_method+"' does not exist" unless ReportStatisticalTest.respond_to?(test_method)
      grouped_validations = Reports::Util.group(validations, [group_attribute])
      LOGGER.debug "perfom test '"+test_method.to_s+"' for '"+test_attribute.to_s+"' for #"+grouped_validations.size.to_s+" "+group_attribute.to_s
      
      titles = []
      matrix = []
      grouped_validations.size.times do |i|
        
        validations1 = grouped_validations[i]
        title1 = validations1[0].send(group_attribute)
        titles << title1
        matrix[i] = [] unless matrix[i]
        
        grouped_validations.size.times do |j|
          if (i == j)
            matrix[i][j] = nil
          else
            validations2 = grouped_validations[j]
            title2 = validations2[0].send(group_attribute)
            matrix[i][j] = ReportStatisticalTest.send(test_method,validations1,validations2,
              test_attribute, significance_level)
          end
        end
      end
      {:titles => titles, :matrix => matrix}
    end
    
    def self.paired_ttest( validations1, validations2, attribute, significance_level=0.95 )
      
      array1 = validations1.collect{ |v| v.send(attribute) }
      array2 = validations2.collect{ |v| v.send(attribute) }
      LOGGER.debug "paired-t-testing "+attribute.to_s+" "+array1.inspect+" vs "+array2.inspect
      LIB::StatisticalTest.pairedTTest(array1, array2, significance_level)
    end
  end

end

#puts LIB::StatisticalTest.pairedTTest([1,2,3],[2,3,3])

