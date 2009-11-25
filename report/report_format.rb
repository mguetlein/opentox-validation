
ENV['REPORT_XSL'] = "docbook-xsl-1.75.2/html/docbook.xsl" unless ENV['REPORT_XSL'] 
ENV['JAVA_HOME'] = "/usr/bin" unless ENV['JAVA_HOME']
ENV['PATH'] = ENV['JAVA_HOME']+":"+ENV['PATH'] unless ENV['PATH'].split(":").index(ENV['JAVA_HOME'])
ENV['SAXON_JAR'] = "saxonhe9-2-0-3j/saxon9he.jar" unless ENV['SAXON_JAR']

# = Reports::ReportFormat
# 
# provides functions for converting reports from xml to other formats
#
module Reports::ReportFormat
  
  RF_XML = "xml"
  RF_HTML = "html"
  RF_PDF = "pdf"
  REPORT_FORMATS = [RF_XML, RF_HTML, RF_PDF]
  CONTENT_TYPES = {"text/xml"=>RF_XML,"text/html"=>RF_HTML,"application/pdf"=>RF_PDF}
  
  # returns report-format, according to header value
  def self.get_format(accept_header_value)

    begin
      content_type =  MIMEParse::best_match(CONTENT_TYPES.keys, accept_header_value)
      raise RuntimeException.new unless content_type
    rescue
      raise Reports::BadRequest.new("Accept header '"+accept_header_value.to_s+"' not supported, supported types are "+CONTENT_TYPES.keys.join(", "))
    end
    return CONTENT_TYPES[content_type]
  end
  
  # formats a report from xml into __format__
  # * xml report must be in __directory__ with filename __xml_filename__
  # * the new format can be found in __dest_filame__
  def self.format_report(directory, xml_filename, dest_filename, format)
    
    raise "cannot format to XML" if format==RF_XML
    raise "directory does not exist: "+directory.to_s unless File.directory?directory.to_s
    xml_file = directory.to_s+"/"+xml_filename.to_s
    raise "xml file not found: "+xml_file unless File.exist?xml_file
    dest_file = directory.to_s+"/"+dest_filename.to_s
    raise "destination file already exists: "+dest_file if File.exist?dest_file
    
    case format
    when RF_HTML
      format_report_to_html(directory, xml_filename, dest_filename)
    else
      raise "unknown format type"
    end
  end
  
  private
  def self.format_report_to_html(directory, xml_filename, html_filename)
    
    cmd = "java -jar "+ENV['SAXON_JAR']+" -o:" + File.join(directory,html_filename.to_s)+
      " -s:"+File.join(directory,xml_filename.to_s)+" -xsl:"+ENV['REPORT_XSL']+" -versionmsg:off"
    LOGGER.debug "converting report to html: '"+cmd+"'"
    IO.popen(cmd.to_s) do |f|
      while line = f.gets do
        LOGGER.info "saxon-xslt> "+line 
      end
    end
    raise "error during conversion" unless $?==0
  end
  
end