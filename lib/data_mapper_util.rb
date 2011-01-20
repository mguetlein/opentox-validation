
#DataObjects::Mysql.logger = DataObjects::Logger.new(STDOUT, 0) 

module Lib
  module DataMapperUtil 
    
    def self.check_params(model, params)
      prop_names = model.properties.collect{|p| p.name.to_s if p.is_a?DataMapper::Property::Object}
      params.keys.each do |k|
        key = k.to_s
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
      params
    end
    
#    def self.all(model, filter_params)
#      prop_names = model.properties.collect{|p| p.name.to_s if p.is_a?DataMapper::Property::Object}
#      puts prop_names.inspect
#      
#      filter_params.keys.each do |k|
#        key = k.to_s
#        unless prop_names.include?(key)
#          key = key.from_rdf_format
#          unless prop_names.include?(key)
#            key = key+"_uri"
#            unless prop_names.include?(key)
#              key = key+"s"
#              unless prop_names.include?(key)
#                err = "no attribute found: '"+k.to_s+"'"
#                if $sinatra
#                  $sinatra.halt 400,err
#                else
#                  raise err
#                end
#              end
#            end
#          end
#        end
#        filter_params[key.to_sym] = filter_params.delete(k)
#      end
#      puts filter_params.inspect
#      
#      #model.all(filter_params)
#      model.all(:model_uris.like => "%")
#    end
    
  end 
end