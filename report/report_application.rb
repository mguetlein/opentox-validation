require "report/environment.rb"

def perform
  begin
    $rep = Reports::ReportService.new(url_for("/report", :full)) unless $rep
    yield( $rep )
  rescue Reports::NotFound => ex
    halt 404, ex.message
  rescue Reports::BadRequest => ex
    halt 400, ex.message
  rescue Exception => ex
    #LOGGER.error(ex.message)
    LOGGER.error "report error: "+ex.message
    LOGGER.error ": "+ex.backtrace.join("\n")
    raise ex # sinatra returns 501
    #halt 500, ex.message 
  end
end

def get_docbook_resource(filepath)
  perform do |rs|
    halt 404,"not found: "+filepath unless File.exist?(filepath)
    types = MIME::Types.type_for(filepath)
    content_type(types[0].content_type) if types and types.size>0 and types[0]
    result = body(File.new(filepath))
  end
end

get '/'+ENV['DOCBOOK_DIRECTORY']+'/:subdir/:resource' do
  path_array = request.env['REQUEST_URI'].split("/")
  get_docbook_resource ENV['DOCBOOK_DIRECTORY']+"/"+path_array[-2]+"/"+path_array[-1]
end

get '/'+ENV['DOCBOOK_DIRECTORY']+'/:resource' do
  get_docbook_resource ENV['DOCBOOK_DIRECTORY']+"/"+request.env['REQUEST_URI'].split("/")[-1]
end

get '/report/:type/css_style_sheet/?' do
  perform do |rs|
    "@import \""+params[:css_style_sheet]+"\";"
  end
end

get '/report/?' do
  perform do |rs|
    case request.env['HTTP_ACCEPT'].to_s
    when  /text\/html/
      related_links =
        "All validations: "+$sinatra.url_for("/",:full)
      description = 
        "A list of all report types."
      content_type "text/html"
      OpenTox.text_to_html rs.get_report_types,related_links,description
    else
      content_type "text/uri-list"
      rs.get_report_types
    end
  end
end

get '/report/:report_type' do
  perform do |rs|
    case request.env['HTTP_ACCEPT'].to_s
    when  /text\/html/
      related_links =
        "Available report types: "+$sinatra.url_for("/report",:full)+"\n"+
        "Single validations:     "+$sinatra.url_for("/",:full)+"\n"+
        "Crossvalidations:       "+$sinatra.url_for("/crossvalidation",:full)
      description = 
        "A list of all "+params[:report_type]+" reports. To create a report, use the POST method."
      post_params = [[:validation_uris]]
      content_type "text/html"
      OpenTox.text_to_html rs.get_all_reports(params[:report_type], params),related_links,description,post_params
    else
      content_type "text/uri-list"
      rs.get_all_reports(params[:report_type], params)
    end
  end
end

post '/report/:type/:id/format_html' do
  
  rs.get_report(params[:type],params[:id],"text/html",true,params)
  content_type "text/uri-list"
  rs.get_uri(params[:type],params[:id])+"\n"
end


get '/report/:type/:id' do
  
  perform do |rs| 
    
    accept_header = request.env['HTTP_ACCEPT']
    report = rs.get_report(params[:type],params[:id],accept_header)
    format = Reports::ReportFormat.get_format(accept_header)
    content_type format
    #PENDING: get_report should return file or string, check for result.is_file instead of format
    if format=="application/x-yaml" or format=="application/rdf+xml"
      report
    else
      result = body(File.new(report))
    end
  end
end

get '/report/:type/:id/:resource' do
  #hack: using request.env['REQUEST_URI'].split("/")[-1] instead of params[:resource] because the file extension is lost

  perform do |rs|
    filepath = rs.get_report_resource(params[:type],params[:id],request.env['REQUEST_URI'].split("/")[-1])
    types = MIME::Types.type_for(filepath)
    content_type(types[0].content_type) if types and types.size>0 and types[0]
    result = body(File.new(filepath))
  end
end

delete '/report/:type/:id' do
  perform do |rs|
    content_type "text/plain"
    rs.delete_report(params[:type],params[:id])
  end
end

post '/report/:type' do
  task_uri = OpenTox::Task.as_task("Create report",url_for("/report/"+params[:type], :full), params) do |task|
    perform do |rs|
      rs.create_report(params[:type],params[:validation_uris]?params[:validation_uris].split(/\n|,/):nil,task)
    end
  end
  content_type "text/uri-list"
  halt 202,task_uri+"\n"
end
