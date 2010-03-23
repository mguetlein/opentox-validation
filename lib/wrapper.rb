
class String
  
  def is_uri?
    begin
      URI::parse(self)
    rescue URI::InvalidURIError
      false
    end
  end
  
end

module OpenTox
  
  class AmbitTask
    include Owl
    
    
#    def wait_for_completion
#      until self.completed? or self.failed?
#        sleep 1
#      end
#    end
    
    def running?
      me = @model.subject(RDF['type'],OT["Task"])
      status = @model.object(me, OT['hasStatus']).literal.value.to_s
      puts status
      status=="Running"
    end
    
    def reload
      data = ""
      IO.popen("curl -i -X GET "+uri.to_s+" 2> /dev/null") do |f| 
        while line = f.gets
          data += line
          end
      end
      #data = OpenTox::RestClientWrapper.get uri
      
      puts "reload "+data.to_s
      self.rdf = data
    end
    
    def wait_while_running
     while running?
       sleep 1
       reload
     end
    end
    
    def self.from_uri(uri)
       
       begin
          t = AmbitTask.new #(uri)
          t.uri = uri
          data = OpenTox::RestClientWrapper.get uri
          puts "loaded ambit task "+data.to_s
          t.rdf = data
          #t.running?
          t
        rescue => ex
          raise ex
          #=> ex
          #puts "error "+ex.message.to_s
          nil
      end
      
    end
    
  end
  
  class Task
    
    
    def self.as_task
  
      task = OpenTox::Task.create
      pid = Spork.spork(:logger => LOGGER) do
        task.started
        LOGGER.debug "task #{task.uri} started #{Time.now}"
        begin
          result = yield
        rescue => ex
          raise ex
          LOGGER.error ex.message
          task.failed
          break
        end
        task.completed(result)
      end  
      LOGGER.debug "task PID: " + pid.to_s
      task.pid = pid
      task.uri
      
    end

    
    def wait_for_resource
      wait_for_completion
      if failed?
        LOGGER.error "task failed "+uri.to_s
        return nil
      end
      return resource
    end

  end

  module Feature
    def self.range( feature_uri )
      if feature_uri =~ /ambit/
        return nil
      else
        return ["true", "false"]
      end
    end
  end
  
   module Model
    class PredictionModel
      include Owl
      
      #attr_reader :uri
      
      def self.build( algorithm_uri, algorithm_parms )
        model_task_uri = OpenTox::RestClientWrapper.post algorithm_uri,algorithm_parms
        model_uri = OpenTox::Task.find(model_task_uri).wait_for_resource.to_s
        if model_uri
          return PredictionModel.find(model_uri)
        else
          return nil
        end
      end
      
      def self.find( uri )
        begin
          #RestClient.get(uri,:accept => "application/rdf+xml")
          #PredictionModel.new(uri)
          
          model = PredictionModel.new #(uri)
          model.uri= uri
          data = RestClient.get(uri,:accept => "application/rdf+xml")
          #LOGGER.debug "creating model from data: "+data.to_s
          model.rdf = data
          raise "uri not set: '"+model.uri+"'" unless model.uri.to_s.size>5 
          model
          
        rescue => ex
          LOGGER.error "could not get model with uri: '"+uri+"', error-msg: "+ex.message.to_s
          raise ex
          #=> ex
          #puts "error "+ex.message.to_s
          nil
        end
      end
      
      def predict_dataset( dataset_uri )
        LOGGER.debug "model "+@uri.to_s+" predicts dataset: "+dataset_uri.to_s
        #prediction_task_uri = RestClientWrapper.post @uri,{:dataset_uri => dataset_uri}
        #puts prediction_task_uri
        #return OpenTox::Task.find(prediction_task_uri).wait_for_resource
        
        #res = RestClientWrapper.post @uri,{:dataset_uri => dataset_uri}
        
        res = ""
        IO.popen("curl -X POST -d dataset_uri='"+dataset_uri+"' "+@uri.to_s+" 2> /dev/null") do |f| 
          while line = f.gets
            res += line
          end
        end
        puts "done "+res.to_s
        
        raise "neither prediction-dataset or task-uri: "+res.to_s unless res.to_s.is_uri?
        
        #HACK
        if res.to_s =~ /dataset.*\/[0-9]+$/ # lazar
          return res
        elsif res.to_s  =~ /\/task\// #pantelis
          ambitTask = OpenTox::AmbitTask.from_uri(res.to_s)
          ambitTask.wait_while_running
          raise "done"
        else
          raise "not sure about prediction result: "+res.to_s
        end
      end
      
      def classification?
        #TODO
        return true
      end
      
      def predictedVariables
        
#        puts OT[self.owl_class]
#        puts @model.subject(RDF['type'],OT[self.owl_class])
        
        
#        me = @model.subject(RDF['type'],OT[self.owl_class])
#        puts "title "+@model.object(me, DC['title']).to_s
#        puts "pred "+@model.object(me, DC['predictedVariables']).to_s
#        puts "rights "+@model.object(me, DC['rights']).to_s
#
#        puts "title "+@model.object(me, OT['title']).to_s
#        puts "pred "+@model.object(me, OT['predictedVariables']).to_s
#        puts "rights "+@model.object(me, OT['rights']).to_s
#
#
#        puts "1 "+@model.subjects(RDF['type'], OT['Feature']).each{|s| s.inspect.to_s}.join("\n")
#        puts "f "+@model.subjects(RDF['type'], OT['predictedVariables']).each{|s| s.inspect.to_s}.join("\n")
#        puts @model.object(me, OT['Feature']).to_s
#        
#        puts @model.subjects(RDF['type'],OT[self.owl_class])
#        puts identifier
#        puts title
#        puts @model.to_s
#        puts @uri
#        puts @model.get_resource(@uri)
#        puts "XXX"
#        
#        @model.subjects(RDF['type'], OT['Feature']).each do |s|
#          puts "s "+s.to_s
#          puts "o "+@model.object(s, RDF['type']).to_s
#          @model.subjects(OT['independentVariables'],s).each do |s2|
#            puts "s2a "+s2.to_s
#          end
#          @model.subjects(OT['dependentVariables'],s).each do |s2|
#            puts "s2b "+s2.to_s
#          end
#          @model.subjects(OT['predictedVariables'],s).each do |s2|
#            puts "s2c "+s2.to_s
#          end
#        end
        
        me = @model.subject(RDF['type'],OT[self.owl_class])
        return @model.object(me, OT['predictedVariables']).uri.to_s
        
        #LOGGER.debug "getting lazar model"
        #m = OpenTox::Model::Lazar.find(@uri)
        #LOGGER.debug "getting lazar model DONE"
        #LOGGER.debug "getting predict values"
        #p = m.predictedVariables
        #LOGGER.debug "getting predict values DONE"
        #return p
      end
      
      def destroy
        RestClientWrapper.delete @uri
      end
      
      #protected
      #def initialize(uri)
      #  @uri = uri
      #end
    end
    
  end
  
  module RestClientWrapper
    
    def self.get(uri, headers=nil)
      execute( "get", uri, nil, headers )
    end
    
    def self.post(uri, payload=nil, headers=nil)
      execute( "post", uri, payload, headers )
    end

    def self.delete(uri, headers=nil)
      execute( "delete", uri, nil, headers )
    end

    private
    def self.execute( rest_call, uri, payload, headers )
      
      do_halt 400,"uri is null",uri,payload,headers unless uri
      begin
        if payload
          RestClient.send(rest_call, uri, payload, headers)
        else
          RestClient.send(rest_call, uri, headers)
        end
      rescue RestClient::RequestFailed, RestClient::RequestTimeout => ex
        do_halt 502,ex.message,uri,payload,headers
      rescue SocketError, RestClient::ResourceNotFound => ex
        do_halt 400,ex.message,uri,payload,headers
      rescue Exception => ex
        do_halt 500,"add error '"+ex.class.to_s+"'' to rescue in OpenTox::RestClientWrapper::execute(), msg: '"+ex.message.to_s+"'",uri,payload,headers
      end
    end
    
    def self.do_halt(status, msg, uri, payload, headers)
      
      message = msg+""
      message += ", uri: '"+uri.to_s+"'" if uri
      message += ", payload: '"+payload.inspect+"'" if payload
      message += ", headers: '"+headers.inspect+"'" if headers
      
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