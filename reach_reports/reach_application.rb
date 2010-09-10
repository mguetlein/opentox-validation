
[ 'rubygems', 'sinatra', 'sinatra/url_for', 'opentox-ruby-api-wrapper' ].each do |lib|
  require lib
end

require 'reach_reports/reach_persistance.rb'
require 'reach_reports/reach_service.rb'

require "lib/format_util.rb"

def extract_type(params)
  halt 400, "illegal type, neither QMRF nor QPRF: "+params[:type] unless params[:type] && params[:type] =~ /(?i)Q(M|P)RF/
  params.delete("type")
end

get '/reach_report' do
  content_type "text/uri-list"
  url_for('/reach_report/QMRF', :full)+"\n"+url_for('/reach_report/QPRF', :full)+"\n"
end

get '/reach_report/:type' do
  content_type "text/uri-list"
  type = extract_type(params)
  LOGGER.info "list all "+type+" reports"
  ReachReports.list_reports(type)
end

post '/reach_report/:type' do
  
  type = extract_type(params)
  content_type "text/uri-list"
  task_uri = OpenTox::Task.as_task( "Create "+type+" report", url_for("/reach_report/"+type, :full), params ) do
  
    LOGGER.info "creating "+type+" report "+params.inspect
    ReachReports.create_report(type,params,request.env["rack.input"])
  end
  halt 202,task_uri
  
end

get '/reach_report/:type/:id' do
  
  type = extract_type(params)
  LOGGER.info "get "+type+" report with id '"+params[:id].to_s+"' "+request.env['HTTP_ACCEPT'].to_s+"'"
  rep = ReachReports.get_report(type, params[:id])

  case request.env['HTTP_ACCEPT'].to_s
  when "application/rdf+xml"
    halt 400, "application/rdf+xml not yet supported"
    owl = OpenTox::Owl.create(type+"Report",rep.report_uri)
    owl.set_data( rep.get_content.keys_to_rdf_format )
    result = owl.rdf
  when "application/qmrf-xml"
    content_type "application/qmrf-xml"
    result = rep.to_xml
    #f = File.new("/home/martin/info_home/.public_html/qmrf.out.xml","w")
    #f.puts result
  when /application\/x-yaml|\*\/\*|^$/ # matches 'application/x-yaml', '*/*', ''
    content_type "application/x-yaml"
    result = rep.to_yaml
  else
    halt 400, "MIME type '"+request.env['HTTP_ACCEPT'].to_s+"' not supported, valid Accept-Headers are \"application/rdf+xml\", \"application/x-yaml\", \"application/qmrf-xml\"."
  end
  
  result
end

post '/reach_report/:type/:id' do
  
  type = extract_type(params)
  LOGGER.info "Post to "+type+" report with id "+params[:id].to_s+"' "+request.env['HTTP_ACCEPT'].to_s+"'"
  rep = ReachReports.get_report(type, params[:id])

  input = request.env["rack.input"].read
  halt 400, "no xml data specified" unless input && input.to_s.size>0
  LOGGER.debug "size of posted data: "+input.to_s.size.to_s
  
  ReachReports::QmrfReport.from_xml(rep,input)
  
  #f = File.new("/home/martin/info_home/.public_html/qmrf.out.xml","w")
  #f.puts rep.to_xml
end



#get '/reach_report/:type/:id/:section' do
#  
#  type = extract_type(params)
#  LOGGER.info "get "+type+" report section '"+params[:section].to_s+"', with id "+params[:id].to_s+"' "+request.env['HTTP_ACCEPT'].to_s+"'"
#  ReachReports.get_report(type, params[:id], params[:section]).to_yaml
#end
#
#get '/reach_report/:type/:id/:section/:subsection' do
#  
#  type = extract_type(params)
#  LOGGER.info "get "+type+" report subsection '"+params[:subsection].to_s+"', section '"+params[:section].to_s+"', with id "+params[:id].to_s+"' "+request.env['HTTP_ACCEPT'].to_s+"'"
#  ReachReports.get_report(type, params[:id], params[:section], params[:subsection]).to_yaml
#end

get '/reach_report/:type/:id/editor' do
  
  type = extract_type(params)
  LOGGER.info "editor for "+type+" report with id '"+params[:id].to_s+"' "+params.inspect

  jnlp = <<EOF
<?xml version ="1.0" encoding="utf-8"?>                                                                                                                                                                     
<jnlp spec="1.0+" codebase="http://opentox.informatik.uni-freiburg.de/" href="qmrfedit2/OT_QMRFEditor.jnlp" >                                                                                               
<information>                                                                                                                                                                                               
<title>QMRF Editor</title>                                                                                                                                                                                  
<vendor>www.opentox.org</vendor>                                                                                                                                                                            
<description>(Q)SAR Model Reporting Format Editor</description>
<description kind="short">(Q)SAR Model Reporting Format Editor</description>
<icon href="qmrfedit2/OTLogo.png" />
</information>
<resources>
<j2se version="1.6+" java-vm-args="-Xincgc"/>

<jar href="qmrfedit2/OT_QMRFEditor.jar" download="eager" main="true"/>
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-applications.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-builder3d.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-charges.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-core.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-datadebug.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-data.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-experimental.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-extra.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-forcefield.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-interfaces.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-io.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-jchempaint.applet.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-jchempaint.application.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-jchempaint.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-libio-cml.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-libio-weka.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-nonotify.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-pdb-cml.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-pdb.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-qsar-cml.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-qsar.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/cdk-qsar-pdb.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/commons-cli-1.0.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/commons-io-1.1.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/commons-logging-1.0.4.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/fop.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/jai_codec.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/jai_core.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/jgrapht-0.6.0.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/jh.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/l2fprod-common-all.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/libfonts-0.1.4.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/log4j-1.2.8.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/log4j.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/mysql-connector-java-5.0.5-bin.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/naming-factory-dbcp.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/naming-factory.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/naming-resources.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/opsin-big-0.1.0.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/org.restlet.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/swing-layout-1.0.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/xmlgraphics-commons-1.1.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/xom-1.1b2.jar" download="lazy" />
<jar href="qmrfedit2/OT_QMRFEditor_lib/xom-1.1.jar" download="lazy" />


</resources>
<application-desc main-class="ambit.applications.qmrf.QMRFEditor">
<argument>-x http://opentox.informatik.uni-freiburg.de/validation/reach_report/QMRF/
EOF
  jnlp.chomp!
  jnlp += params[:id].to_s

  jnlp += <<EOF 
</argument>
<argument>-d http://opentox.informatik.uni-freiburg.de/qmrfedit2/qmrf.dtd</argument>
<argument>-t http://opentox.informatik.uni-freiburg.de/qmrfedit2/verdana.ttf</argument>

</application-desc> 
<security>
    <all-permissions/>
</security>
</jnlp>
EOF
  
  content_type "application/x-java-jnlp-file"
  jnlp
end

