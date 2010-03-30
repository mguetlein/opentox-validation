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
    LOGGER.error(ex.message)
    #raise ex # sinatra returns 501
    halt 500, ex.message 
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

get '/report/:type' do
  perform do |rs|
    content_type "text/uri-list"
    rs.get_all_reports(params[:type])
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
    
    content_type Reports::ReportFormat.get_format(accept_header)
    result = body(File.new( rs.get_report(params[:type],params[:id],accept_header) ))
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
  perform do |rs|
    content_type "text/uri-list"
    rs.create_report(params[:type],params[:validation_uris]?params[:validation_uris].split(/\n|,/):nil)
  end
end
