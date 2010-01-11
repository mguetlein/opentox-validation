module OpenTox
  
  module Feature
    def self.range( feature_uri )
      #TODO
      ["true", "false"]
    end
  end
  
   module Model
    class PredictionModel
      
      def self.find( uri )
        begin
          RestClient.get uri,:accept => "application/rdf+xml"
          PredictionModel.new(uri)
        rescue #=> ex
          #puts "error "+ex.message.to_s
          nil
        end
      end
      
      def predict_dataset( dataset_uri )
        RestClientWrapper.post @uri,{:dataset_uri => dataset_uri}
      end
      
      def classification?
        #TODO
        return true
      end

      def destroy
        RestClientWrapper.delete @uri
      end
      
      protected
      def initialize(uri)
        @uri = uri
      end
    end
    
  end
  
  module RestClientWrapper
    
    def self.get(uri, params=nil)
      execute( "get", uri, params )
    end
    
    def self.post(uri, params=nil)
      execute( "post", uri, params )
    end

    def self.delete(uri, params=nil)
      execute( "delete", uri, params )
    end

    private
    def self.execute( rest_call, uri, params=nil )
      
      do_halt 400,"uri is null",uri,params unless uri
      begin
        RestClient.send(rest_call, uri, params)
      rescue RestClient::RequestFailed, RestClient::RequestTimeout => ex
        do_halt 502,ex.message,uri,params
      rescue SocketError, RestClient::ResourceNotFound => ex
        do_halt 400,ex.message,uri,params
      rescue Exception => ex
        do_halt 500,"add error '"+ex.class.to_s+"'' to rescue in OpenTox::RestClientWrapper::execute(), msg: '"+ex.message.to_s+"'",uri,params
      end
    end
    
    def self.do_halt(status, msg, uri=nil, params=nil)
      
      message = msg+""
      message += ", uri: '"+uri.to_s+"'" if uri
      message += ", params: '"+params.inspect+"'" if params
      
      if defined?(halt)
        halt(status,message)
      elsif defined?($sinatra)
        $sinatra.halt(status,message)
      else
        raise "halt '"+status.to_s+"' '"+message+"'"
      end
    end
  end
  
end