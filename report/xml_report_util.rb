
# = Reports::XMLReportUtil
#
# Utilities for XMLReport
#
module Reports::XMLReportUtil
  
  # creates a confusion matrix as array (to be used as input for Reports::XMLReport::add_table)
  # input is confusion matrix as returned by Lib::Predictions.confusion_matrix
  #
  # call-seq:
  #   create_confusion_matrix( confusion_matrix ) => array
  #
  def self.create_confusion_matrix( confusion_matrix )
    
    num_classes = Math.sqrt(confusion_matrix.size)
    class_values = []
    confusion_matrix.each{ |key_map,value| class_values.push(key_map[:confusion_matrix_actual]) if class_values.index(key_map[:confusion_matrix_actual])==nil }
    raise "confusion matrix invalid "+confusion_matrix.inspect unless num_classes.to_i == num_classes and class_values.size == num_classes 

    sum_predicted = {}
    sum_actual = {}
    class_values.each do |class_value|
      sum_pred = 0
      sum_act = 0
      confusion_matrix.each do |key_map,value|
        sum_pred += value if key_map[:confusion_matrix_predicted]==class_value
        sum_act += value if key_map[:confusion_matrix_actual]==class_value
      end
      sum_predicted[class_value] = sum_pred
      sum_actual[class_value] = sum_act
    end
    
    confusion = []
    confusion.push( [ "", "", "actual" ] + [""] * num_classes )
    confusion.push( [ "", "" ] + class_values +  [ "total"])
    
    class_values.each do |predicted|
      row =  [ (confusion.size==2 ? "predicted" : ""), predicted ]
      class_values.each do |actual|
        row.push( confusion_matrix[{:confusion_matrix_actual => actual, :confusion_matrix_predicted => predicted}].to_nice_s )   
      end
      row.push( sum_predicted[predicted].to_nice_s )
      confusion.push( row )  
    end
    last_row = [ "", "total" ] 
    class_values.each do |actual|
        last_row.push( sum_actual[actual].to_nice_s )  
    end
    confusion.push( last_row )
    
    return confusion
  end
  
  def self.text_element(name, text)
    node = Element.new(name)
    node.text = text
    return node
  end
  
  def self.attribute_element(name, attributes)
    node = Element.new(name)
    node.add_attributes(attributes)
    return node
  end  

end
  


