
# = Reports::XMLReportUtil
#
# Utilities for XMLReport
#
module Reports::XMLReportUtil
  
  # creates a confusion matrix as array (to be used as input for Reports::XMLReport::add_table)
  #
  # call-seq:
  #   create_confusion_matrix( tp, fp, fn, tn ) => array
  #
  def self.create_confusion_matrix( tp, fp, fn, tn )
    
    confusion = []
    confusion.push([  "",           "",         "actual",     "",           ""])
    confusion.push([  "",           "",         "pos",        "neg",        "total"])
    confusion.push([  "predicted",  "pos'",     tp.to_s,      fp.to_s,      (tp+fp).to_s])
    confusion.push([  "",           "neg'",     fn.to_s,      tn.to_s,      (tn+fn).to_s])
    confusion.push([  "",           "total",    (tp+fn).to_s, (fp+tn).to_s, ""])
    return confusion;
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
  


