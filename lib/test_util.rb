
require 'test/unit'

module Lib
  # test utitily, to be included rack unit tests
  module TestUtil
    
    def wait_for_task(uri)
      return TestUtil.wait_for_task(uri)
    end
    
    def self.wait_for_task(uri)
      if OpenTox::Utils.task_uri?(uri)
        task = OpenTox::Task.find(uri)
        task.wait_for_completion
        raise "task failed: "+uri.to_s if task.error?
        uri = task.resultURI
      end
      return uri
    end
    
    # updloads a dataset
    def upload_data(ws, file)
        
      case file.path  
      when /yaml$/
        type = "text/x-yaml"
      when /owl$/
        type = "application/rdf+xml"
      else
        raise "unknown type for file: "+file.path.to_s
      end
         
      data = File.read(file.path)
      task_uri = RestClient.post ws, data, :content_type => type 
      data_uri = task_uri
      puts "done: "+data_uri.to_s
      add_resource(data_uri)
      return data_uri
    end

    # adds a resource to delete it later on
    def add_resource(res)
      @to_delete = [] unless @to_delete
      @to_delete.push(res)
    end

    # deletes all resources
    def delete_resources
      if @to_delete
        @to_delete.each do |d|
          puts "deleting "+d.to_s
          if d.to_s =~ /^http.*/
            ext("curl -X DELETE "+d.to_s)
          else
            delete d.to_s
          end
        end
      end
    end
    
    # execute an external program like curl
    def ext(call, indent="  ")
      response = "" 
      IO.popen(call.to_s+" 2> /dev/null") do |f| 
        while line = f.gets
          response += indent.to_s+line
        end
      end
      assert $?==0, "returns error "+call+" "+response
      return response
    end

  end
end
