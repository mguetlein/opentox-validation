
require 'test/unit'

module Lib
  # test utitily, to be included rack unit tests
  module TestUtil
    
    # updloads a dataset
    def upload_data(ws, name, file)
      begin
        data_uri = RestClient.post ws, :name => name
        puts "created dataset "+data_uri.to_s
        assert data_uri==ext("curl -X PUT -F 'file=@"+file.path+";type=text/csv' -F compound_format=smiles "+data_uri+"/import",nil)
      rescue RestClient::RequestFailed => ex
        raise "could not upload dataset "+ex.message unless ex.message =~ /.*403.*/
        data_uri = File.join(ws,name)
        puts "already uploaded "+data_uri.to_s
      end
        
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
