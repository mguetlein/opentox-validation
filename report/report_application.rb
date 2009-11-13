load "report/environment.rb"

def perform
  begin
    $rep = Reports::ReportService.new(url_for("", :full)) unless $rep
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

get '/report/?' do
  perform{ |rs| rs.get_report_types }
end

get '/report/:type' do
  perform{ |rs| rs.get_all_reports(params[:type]) }
end

get '/report/:type/:id' do
  perform do |rs| 
    #request.env['HTTP_ACCEPT'] = "application/pdf"
    result = body(File.new( rs.get_report(params[:type],params[:id],request.env['HTTP_ACCEPT']) ))
  end
end

get '/report/:type/:id/:resource' do
  #hack: using request.env['REQUEST_URI'].split("/")[-1] instead of params[:resource] because the file extension is lost 
  perform{ |rs| result = body(File.new(rs.get_report_resource(params[:type],params[:id],request.env['REQUEST_URI'].split("/")[-1]))) }
end

delete '/report/:type/:id' do
  perform{ |rs| rs.delete_report(params[:type],params[:id]) }
end

post '/report/:type' do
  perform{ |rs| rs.create_report(params[:type],params[:uri_list]?params[:uri_list].split("\n"):nil) }
end
