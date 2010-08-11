
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'active_record', 'ar-extensions', 'opentox-ruby-api-wrapper' ].each do |lib|
  require lib
end

require 'reach_reports/reach_properties.rb'
require 'reach_reports/reach_persistance.rb'
require 'reach_reports/reach_service.rb'
require 'reach_reports/reach_to_xml.rb'


require "lib/format_util.rb"

def extract_type(params)
  halt 400, "illegal type, neither QMRF nor QPRF: "+params[:type] unless params[:type] && params[:type] =~ /(?i)Q(M|P)RF/
  params.delete("type")
end

get '/reach_report/:type' do
  content_type "text/uri-list"
  type = extract_type(params)
  LOGGER.info "list all "+type+" reports"
  ReachReports.list_reports(type)
end

post '/reach_report/:type' do
  content_type "text/uri-list"
  type = extract_type(params)
  LOGGER.info "creating "+type+" report "+params.inspect
  ReachReports.create_report(type,params)
end

get '/reach_report/:type/:id' do
  
  type = extract_type(params)
  LOGGER.info "get "+type+" report with id "+params[:id].to_s+"' "+request.env['HTTP_ACCEPT'].to_s+"'"
  rep = ReachReports.get_report(type, params[:id])

  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    owl = OpenTox::Owl.create(rep.type+"Report",rep.report_uri)
    owl.set_data( rep.get_content.keys_to_rdf_format )
    result = owl.rdf
  when "application/qmrf-xml"
    content_type "application/qmrf-xml"
    result = ReachReports.reach_report_to_xml(rep)
  when /application\/x-yaml|\*\/\*|^$/ # matches 'application/x-yaml', '*/*', ''
    content_type "application/x-yaml"
    result = rep.get_content.to_yaml
  else
    halt 400, "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported, valid Accept-Headers are \"application/rdf+xml\", \"application/x-yaml\", \"application/qmrf-xml\"."
  end
  result
end

get '/reach_report/:type/:id/:section' do
  
  type = extract_type(params)
  LOGGER.info "get "+type+" report section '"+params[:section].to_s+"', with id "+params[:id].to_s+"' "+request.env['HTTP_ACCEPT'].to_s+"'"
  ReachReports.get_report(type, params[:id], params[:section]).to_yaml
end

get '/reach_report/:type/:id/:section/:subsection' do
  
  type = extract_type(params)
  LOGGER.info "get "+type+" report subsection '"+params[:subsection].to_s+"', section '"+params[:section].to_s+"', with id "+params[:id].to_s+"' "+request.env['HTTP_ACCEPT'].to_s+"'"
  ReachReports.get_report(type, params[:id], params[:section], params[:subsection]).to_yaml
end

