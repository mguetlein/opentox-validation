
ENV['REPORT_XSL'] = "docbook-xsl-1.75.2/html/docbook.xsl" unless ENV['REPORT_XSL'] 
ENV['JAVA_HOME'] = "/usr/bin" unless ENV['JAVA_HOME']
ENV['PATH'] = ENV['JAVA_HOME']+":"+ENV['PATH'] unless ENV['PATH'].split(":").index(ENV['JAVA_HOME'])
ENV['SAXON_JAR'] = "saxonhe9-2-0-3j/saxon9he.jar" unless ENV['SAXON_JAR']

# = Reports::ReportFormat
# 
# provides functions for converting reports from xml to other formats
#
module Reports::ReportFormat
  
  # returns report-format, according to header value
  def self.get_format(accept_header_value)
    
    case accept_header_value
    when /text\/html/
      "text/html"
    when /application\/rdf\+xml/
      "application/rdf+xml"
    when /text\/xml/
      "text/xml"
    when /application\/x-yaml|\*\/\*/
      "application/x-yaml"
    else
      raise Reports::BadRequest.new("Accept header '"+accept_header_value.to_s+
        "' not supported, supported types are "+
        "text/html"+", "+
        "application/rdf+xml"+", "+
        "text/xml"+", "+
        "application/x-yaml")
    end
  end
  
  def self.get_filename_extension(format)
    case format
    when "text/xml"
      "xml"
    when "text/html"
      "html"
    when "application/pdf"
      "pdf"
    else
      raise "invalid format type for file extensions: "+format.to_s
    end
  end
  
  # formats a report from xml into __format__
  # * xml report must be in __directory__ with filename __xml_filename__
  # * the new format can be found in __dest_filame__
  def self.format_report(directory, xml_filename, dest_filename, format, overwrite=false, params={})
    
    raise "cannot format to XML" if format=="text/xml"
    raise "directory does not exist: "+directory.to_s unless File.directory?directory.to_s
    xml_file = directory.to_s+"/"+xml_filename.to_s
    raise "xml file not found: "+xml_file unless File.exist?xml_file
    dest_file = directory.to_s+"/"+dest_filename.to_s
    raise "destination file already exists: "+dest_file if (File.exist?(dest_file) && !overwrite)
    
    case format
    when "text/html"
      format_report_to_html(directory, xml_filename, dest_filename, params[:css_style_sheet])
    when "application/pdf"
      raise "pdf conversion not supported yet"
    else
      raise "unknown format type"
    end
  end
  
  def self.format_report_to_html(directory, xml_filename, html_filename, css_style_sheet)
    css_style_sheet = "http://opentox.informatik.uni-freiburg.de/simple_ot_stylesheet.css" unless css_style_sheet
  
    css =  css_style_sheet ? "--stringparam html.stylesheet "+URI.encode(css_style_sheet.to_s) : nil
    cmd = "xsltproc "+css.to_s+" "+ENV['REPORT_XSL']+" "+File.join(directory,xml_filename.to_s)+" > "+File.join(directory,html_filename.to_s)
    #css = css_style_sheet ? " html.stylesheet=css_style_sheet?css_style_sheet="+URI.encode(css_style_sheet.to_s) : nil
    #cmd = "java -jar "+ENV['SAXON_JAR']+" -o:" + File.join(directory,html_filename.to_s)+
    #  " -s:"+File.join(directory,xml_filename.to_s)+" -xsl:"+ENV['REPORT_XSL']+" -versionmsg:off"+css.to_s
      
    LOGGER.debug "Converting report to html: '"+cmd+"'"
    IO.popen(cmd.to_s) do |f|
      while line = f.gets do
        LOGGER.info "xsltproc> "+line
        #LOGGER.info "saxon-xslt> "+line
      end
    end
    raise "error during conversion" unless $?==0
  end
  
end