

class String
  
  # :prediction_feature -> predictionFeature
  # :test_dataset_uri -> testDataset
  # :validation_uris -> validation
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
  
  DC_KEYS = [ "title", "creator", "date", "format" ]
  RDF_KEYS = [ "type" ]
  
  def to_owl_uri
    if DC_KEYS.include?(self)
      return DC.send(self)
    elsif RDF_KEYS.include?(self)
      return RDF.send(self)
    else
      return OT.send(self)
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
  
  def keys_to_owl_uris
    res = {}
    keys.each do |k|
      v = self[k]
      if v.is_a?(Hash)
        v = v.keys_to_owl_uris
      elsif v.is_a?(Array)
        v = v.collect{ |vv| vv.is_a?(Hash) ? vv.keys_to_owl_uris : vv }
      end
      res[k.to_s.to_owl_uri] = v
    end
    return res
  end
  
end

