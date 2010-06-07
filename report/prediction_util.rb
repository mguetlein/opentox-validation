

module Reports::PredictionUtil

  # creates an Array for a table
  # * first row: header values
  # * other rows: the prediction values
  # additional attribute values of the validation that should be added to the table can be defined via validation_attributes
  # 
  # call-seq:
  #   predictions_to_array(validation_set, validation_attributes=[]) => Array
  #
  def self.predictions_to_array(validation_set, validation_attributes=[])
  
      res = []
      
      validation_set.validations.each do |v|
        (0..v.get_predictions.num_instances-1).each do |i|
          a = []
          validation_attributes.each{ |att| a.push(v.send(att).to_s) }
          
          #PENDING!
          a.push( "http://ambit.uni-plovdiv.bg:8080/ambit2/depict/cdk?search="+URI.encode(OpenTox::Compound.new(:uri=>v.get_predictions.identifier(i)).smiles) )
          
          a.push(v.get_predictions.actual_value(i).to_nice_s) 
          a.push(v.get_predictions.predicted_value(i).to_nice_s)
          a.push(v.get_predictions.classification_miss?(i)?"X":"") if validation_set.all_classification?
          a.push(v.get_predictions.confidence_value(i).to_nice_s) if v.get_predictions.confidence_values_available?
          a.push(v.get_predictions.identifier(i)) #.gsub(/[-(),=]/, '')[0,10])
          res.push(a)
        end
      end
        
      #res = res.sort{|x,y| y[3] <=> x[3] }
      header = [ "compound", "actual value", "predicted value"]
      header.push "missclassified" if validation_set.all_classification?
      header.push "confidence value" if validation_set.validations[0].get_predictions.confidence_values_available?
      header << "compound-uri"
      res.insert(0, validation_attributes + header)
      #puts res.collect{|c| c.inspect}.join("\n")
      
      return res
  end

end
