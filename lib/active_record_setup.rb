
gem "activerecord", "= 2.3.8"
gem "ar-extensions", "= 0.9.2"
['rubygems', 'logger', 'active_record', 'ar-extensions', 'opentox-ruby-api-wrapper' ].each do |g|
    require g
end

unless ActiveRecord::Base.connected?
  ActiveRecord::Base.establish_connection(  
     :adapter => @@config[:database][:adapter],
     :host => @@config[:database][:host],
     :database => @@config[:database][:database],
     :username => @@config[:database][:username],
     :password => @@config[:database][:password]
  )
  ActiveRecord::Base.logger = Logger.new("/dev/null")
end

class ActiveRecord::Base
  
  def self.find_like(filter_params)
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
              if $sinatra
                $sinatra.halt 400,err
              else
                raise err
              end
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