
module ReachReports
  
  def self.get_uri( report )
    raise "internal error, id not set "+to_yaml if report.id==nil
    return $sinatra.url_for("/"+File.join(report.type,report.id.to_s), :full).to_s
  end
  
  class QmrfReport < ActiveRecord::Base
  
    alias_attribute :date, :created_at
    
    QmrfProperties.serialized_properties.each do |p|
      serialize p
    end
    
    def type
      "QMRF"
    end
    
    def report_uri
      ReachReports.get_uri(self)
    end
    
    def get_content
      hash = {}
      [ :model_uri, :date ].each{ |p| hash[p] = self.send(p) }
      QmrfProperties.properties.each{ |p| hash[p] = self.send(p) }
      return hash
    end
  end
  

  class QprfReport < ActiveRecord::Base
    
    alias_attribute :date, :created_at

    def report_uri
      ReachReports.get_uri(self)
    end

    def type
      "QPRF"
    end
  end
  
end  