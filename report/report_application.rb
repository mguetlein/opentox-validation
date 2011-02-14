require "report/environment.rb"

def perform
  @@report_service = Reports::ReportService.instance( url_for("/report", :full) ) unless defined?@@report_service  
  yield( @@report_service )
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
        "All validations: "+url_for("/",:full)
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
        "Available report types: "+url_for("/report",:full)+"\n"+
        "Single validations:     "+url_for("/",:full)+"\n"+
        "Crossvalidations:       "+url_for("/crossvalidation",:full)
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
  perform do |rs| 
    rs.get_report(params[:type],params[:id],"text/html",true,params)
    content_type "text/uri-list"
    rs.get_uri(params[:type],params[:id])+"\n"
  end
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

  response.set_cookie("subjectid", @subjectid)
end

#OpenTox::Authorization.whitelist( Regexp.new("/report/.*/[0-9]+/.*"),"GET")

get '/report/:type/:id/:resource' do
  perform do |rs|
    filepath = rs.get_report_resource(params[:type],params[:id],params[:resource])
    types = MIME::Types.type_for(filepath)
    content_type(types[0].content_type) if types and types.size>0 and types[0]
    result = body(File.new(filepath))
  end
end

delete '/report/:type/:id' do
  perform do |rs|
    content_type "text/plain"
    rs.delete_report(params[:type],params[:id],@subjectid)
  end
end

post '/report/:type' do
  task = OpenTox::Task.create("Create report",url_for("/report/"+params[:type], :full)) do |task| #,params
    perform do |rs|
      rs.create_report(params[:type],params[:validation_uris]?params[:validation_uris].split(/\n|,/):nil,@subjectid,task)
    end
  end
  return_task(task)
end
