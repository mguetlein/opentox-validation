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


get '/report/:type/css_style_sheet/?' do
  perform do |rs|
    "@import \""+params[:css_style_sheet]+"\";"
  end
end


get '/report/?' do
  perform do |rs|
    content_type "text/uri-list"
    rs.get_report_types
  end
end

get '/report/:report_type' do
  perform do |rs|
    content_type "text/uri-list"
    rs.get_all_reports(params[:report_type], params)
  end
end

post '/report/:type/:id/format_html' do
  
  perform do |rs| 
    rs.get_report(params[:type],params[:id],"text/html",true,params)
    content_type "text/uri-list"
    rs.get_uri(params[:type],params[:id])
  end
end


get '/report/:type/:id' do
  
  perform do |rs| 
    
    accept_header = request.env['HTTP_ACCEPT']
    if accept_header =~ /MSIE/
      LOGGER.info "Changing MSIE accept-header to text/html"
      accept_header = "text/html"
    end
    #request.env['HTTP_ACCEPT'] = "application/pdf"
    
    #QMRF-STUB
    if params[:type] == Reports::ReportFactory::RT_QMRF
      #raise Reports::BadRequest.new("only 'application/qmrf-xml' provided so far") if accept_header != "application/qmrf-xml"
      content_type "application/qmrf-xml"
      result = body(OpenTox::RestClientWrapper.get("http://ecb.jrc.ec.europa.eu/qsar/qsar-tools/qrf/QMRF_v1.2_FishTox.xml"))
    else
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
  task_uri = OpenTox::Task.as_task("Create report",url_for("/report/"+params[:type], :full), params) do
    perform do |rs|
      content_type "text/uri-list"
      rs.create_report(params[:type],params[:validation_uris]?params[:validation_uris].split(/\n|,/):nil)
    end
  end
  halt 202,task_uri
end


post '/report/:type/:id' do
  perform do |rs|
   #QMRF-STUB
    if params[:type] == Reports::ReportFactory::RT_QMRF
      #raise Reports::BadRequest.new("only 'application/qmrf-xml' provided so far") if request.content_type != "application/qmrf-xml"
      input = request.env["rack.input"].read
      "save qmrf would have been successfull, received data with "+input.to_s.size.to_s+" characters, this is just a stub, changes discarded"
    else
      "operation not supported yet"
    end
  end
end
