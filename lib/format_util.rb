

class String
  
  # :prediction_feature -> predictionFeature
  # :test_dataset_uri -> testDataset
  def to_rdf_format
    s = gsub(/_uri(s|)$/,"")
    s.gsub(/_./) do |m|
      m.gsub!(/^_/,"")
      m.upcase
    end
  end
  
  def from_rdf_format
    gsub(/[A-Z]/) do |m|
      "_"+m.downcase
    end
  end
  
end

class Hash
  
  # applies to_rdf_format to all keys
  def keys_to_rdf_format
    res = {}
    keys.each do |k|
      v = self[k]
      if v.is_a?(Hash)
        v = v.keys_to_rdf_format
      elsif v.is_a?(Array)
        v = v.collect{ |vv| vv.is_a?(Hash) ? vv.keys_to_rdf_format : vv }
      end
      res[k.to_s.to_rdf_format] = v
    end
    return res
  end
end

