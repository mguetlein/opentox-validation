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
        RestClient.post @uri,{:dataset_uri => dataset_uri}
      end
      
      def classification?
        #TODO
        return true
      end

      def destroy
        RestClient.delete @uri
      end
      
      protected
      def initialize(uri)
        @uri = uri
      end
    end
    
  end
end