
#DataObjects::Mysql.logger = DataObjects::Logger.new(STDOUT, 0) 

module Lib
  module DataMapperUtil 
    
    def self.check_params(model, params)
      prop_names = model.properties.collect{|p| p.name.to_s if p.is_a?DataMapper::Property::Object}
      params.keys.each do |k|
        key = k.to_s
        if (key == "subjectid")
          params.delete(k)
        else
          unless prop_names.include?(key)
            key = key.from_rdf_format
            unless prop_names.include?(key)
              key = key+"_uri"
              unless prop_names.include?(key)
                key = key+"s"
                unless prop_names.include?(key)
                  raise OpenTox::BadRequestError.new "no attribute found: '"+k.to_s+"'"
                end
              end
            end
          end
          params[key.to_sym] = params.delete(k)
        end
      end
      params
    end
    
    def self.all(model, filter_params)
      model.all(check_params(model,filter_params))
    end
    
  end 
end