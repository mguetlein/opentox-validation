
#gem "activerecord", "= 2.3.8"
#gem "ar-extensions", "= 0.9.2"
['rubygems', 'logger', 'active_record', 'opentox-ruby' ].each do |g| #'ar-extensions',
    require g
end

unless ActiveRecord::Base.connected?
  ActiveRecord::Base.establish_connection(  
     :adapter => CONFIG[:database][:adapter],
     :host => CONFIG[:database][:host],
     :database => CONFIG[:database][:database],
     :username => CONFIG[:database][:username],
     :password => CONFIG[:database][:password]
  )
  ActiveRecord::Base.logger = Logger.new("/dev/null")
end

class ActiveRecord::Base
  
  def self.find_like(filter_params)
    
    raise "find like removed"
    
    #puts "params before "+filter_params.inspect
    filter_params.keys.each do |k|
      key = k.to_s
      unless self.column_names.include?(key)
        key = key.from_rdf_format
        unless self.column_names.include?(key)
          key = key+"_uri"
          unless self.column_names.include?(key)
            key = key+"s"
            unless self.column_names.include?(key)
              err = "no attribute found: '"+k.to_s+"'"
#              if $sinatra
#                $sinatra.halt 400,err
#              else
                raise err
#              end
            end
          end
        end
      end
      filter_params[key+"_like"] = filter_params.delete(k)
    end
    #puts "params after "+filter_params.inspect
    self.find(:all, :conditions => filter_params)
  end
end