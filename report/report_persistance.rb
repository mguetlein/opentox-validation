
# = Reports::ReportPersistance
#
# service that stores reports (Reports::ReportConent), and provides access in various formats
#
class Reports::ReportPersistance
  
  # lists all stored report ID-s of a certain type
  #
  # call-seq:
  #   list_reports(type) => Array
  #
  def list_reports(type, filter_params)
    raise "not implemented"
  end
  
  # stores content of a report (Reports::ReportContent) and returns id
  #
  # call-seq:
  #   new_report(report_content) => string
  #
  def new_report(report_content)
    raise "not implemented"
  end
  
  # returns a already created report (file path on server) in a certain format (converts to this format if it does not exist yet)
  #
  # call-seq:
  #   get_report(type, id, format) => string
  #
  def get_report(type, id, format, force_formating, params)
    raise "not implemented"
  end
  
  # returns file path on server of a resource (i.e. image) of a report 
  #
  # call-seq:
  #   get_report_resource(type, id, resource) => string
  #
  def get_report_resource(type, id, resource)
    raise "not implemented"
  end
  
  # deletes a report
  # * returns true if deleting successfull
  # * returns false if report not found
  # * raises exception if error occurs
  #
  # call-seq:
  #   delete_report(type, id) => boolean
  #
  def delete_report(type, id)
    raise "not implemented"
  end
  
  # raises exception if not valid id format
  def check_report_id_format(id)
    raise "not implemented"
  end
  
end

# = Reports::FileReportPersistance
#
# type of Reports::ReportPersistance, stores reports in file-system, see Reports::ReportPersistance for API documentation
#
class Reports::FileReportPersistance < Reports::ReportPersistance
  
  def initialize()
    raise "pls specify report-directory (:reports -> :report_dir) in config file" unless @@config[:reports] and @@config[:reports][:report_dir]
    @report_dir = @@config[:reports][:report_dir]
    FileUtils.mkdir @report_dir.to_s unless File.directory?(@report_dir)
    raise "report cannot be found nor created" unless File.directory?(@report_dir)
    LOGGER.debug "reports are stored in "+@report_dir.to_s 
  end
  
  def list_reports(type, filter_params=nil)
    raise "filter params not supported" if filter_params
    (Dir.new(type_directory(type)).entries - [".", ".."]).sort{|x,y| x.to_i <=> y.to_i}
  end
  
  def get_report(type, id, format, force_formating, params)
    
    report_dir = report_directory(type, id)
    raise_report_not_found(type, id) unless File.directory?(report_dir)
    
    filename = "report."+Reports::ReportFormat.get_filename_extension(format)
    file_path = report_dir+"/"+filename
    
    return file_path if File.exist?(file_path) && !force_formating
      
    Reports::ReportFormat.format_report(report_dir, "report.xml", filename, format, force_formating, params)
    raise "formated file not found '"+file_path+"'" unless File.exist?(file_path)
    return file_path
  end
  
  def get_report_resource(type, id, resource)
    
    report_dir = report_directory(type, id)
    raise_report_not_found(type, id) unless File.directory?(report_dir)
    file_path = report_dir+"/"+resource.to_s
    raise Reports::NotFound.new("resource not found, resource: '"+resource.to_s+"', type:'"+type.to_s+"', id:'"+id.to_s+"'") unless File.exist?(file_path)
    return file_path
  end
  
  def delete_report(type, id)
    
    report_dir = report_directory(type, id)
    raise_report_not_found(type, id) unless File.directory?(report_dir)
    
    entries = (Dir.new(report_dir).entries-[".", ".."]).collect{|f| report_dir+"/"+f.to_s}
    FileUtils.rm(entries)
    FileUtils.rmdir report_dir
    raise "could not delete report directory '"+report_dir+"'" if File.directory?(report_dir)
    return true
  end
  
  def check_report_id_format(id)
    raise "not valid report id format" unless id.to_s =~ /[0-9]+/
  end
  
  def new_report(report_content, type, meta_data=nil, uri_provider=nil)
    new_report_with_id(report_content, type)
  end
  
  protected
  def new_report_with_id(report_content, type, force_id=nil)
    LOGGER.debug "storing new report of type "+type.to_s 
    
    type_dir = type_directory(type)
    raise "type dir '"+type_dir+"' cannot be found nor created" unless File.directory?(type_dir)
    
    if (force_id==nil)
      id = 1
      while File.exist?( type_dir+"/"+id.to_s )
        id += 1
      end
    else
      raise "report with id '"+force_id.to_s+"' already exists, file system not consistent with db" if File.exist?( type_dir+"/"+force_id.to_s )
      id = force_id      
    end
    report_dir = type_dir+"/"+id.to_s
    FileUtils.mkdir(report_dir)
    raise "report dir '"+report_dir+"' cannot be created" unless File.directory?(report_dir)
    
    xml_filename = report_dir+"/report.xml"
    xml_file = File.new(xml_filename, "w")
    report_content.xml_report.write_to(xml_file, id)
    xml_file.close
    if (report_content.tmp_files)
      report_content.tmp_files.each do |k,v|
        tmp_filename = report_dir+"/"+k
        raise "tmp-file '"+tmp_filename.to_s+"' already exists" if File.exist?(tmp_filename)
        raise "tmp-file '"+v.to_s+"' not found" unless File.exist?(v)
        FileUtils.mv(v.to_s,tmp_filename)
        raise "could not move tmp-file to '"+tmp_filename.to_s+"'" unless File.exist?(tmp_filename)
      end
    end
    return id
  end
  
  private
  def raise_report_not_found(type, id)
    raise Reports::NotFound.new("report not found, type:'"+type.to_s+"', id:'"+id.to_s+"'")
  end
  
  def type_directory(type)
    dir = @report_dir+"/"+type
    FileUtils.mkdir dir.to_s unless (File.directory?(dir))
    return dir
  end
  
  def report_directory(type, id)
    type_dir = type_directory(type)
    raise "type dir '"+type_dir+"' cannot be found nor created" unless File.directory?(type_dir)
    return type_dir+"/"+id.to_s
  end
  
end

module Reports
  
  class ReportData < ActiveRecord::Base
    include Lib::RDFProvider
  
    def get_content_as_hash
      map = {}
      map[:created_at] = created_at
      map[:report_uri] = report_uri
      map[:report_type] = report_type
      map[:validation_uris] = validation_uris
      map[:crossvalidation_uris] = crossvalidation_uris
      map[:algorithm_uris] = algorithm_uris
      map[:model_uris] = model_uris
      map
    end
    
    def rdf_title
      "ValidationReport"
    end
    
    def uri
      report_uri
    end
    
    LITERALS = [ :created_at, :report_type ]
    LITERAL_NAMES = {:created_at => OT["date"] }
    OBJECT_PROPERTIES = { :crossvalidation_uris => OT['reportCrossvalidation'], :algorithm_uris => OT['reportAlgorithm'],
                           :validation_uris => OT['reportValidation'], :model_uris => OT['reportModel'] }
    CLASSES = {}               
    IGNORE = [ :id, :report_uri ]
    
    serialize :validation_uris
    serialize :crossvalidation_uris
    serialize :algorithm_uris
    serialize :model_uris
  end
  
  class ExtendedFileReportPersistance < FileReportPersistance
    
    def new_report(report_content, type, meta_data, uri_provider)
      raise "report meta data missing" unless meta_data
      report = ReportData.new(meta_data)
      report.save #to set id
      report.attributes = { :report_type => type, :report_uri => uri_provider.get_uri(type, report.id) }
      report.save
      new_report_with_id(report_content, type, report.id)
    end
    
    def list_reports(type, filter_params=nil)
      filter_params = {} unless filter_params
      filter_params.each{ |k,v| raise Reports::BadRequest.new("no report-attribute: "+k.to_s) unless ReportData.column_names.include?(k.gsub(/_like$/,"")) }
      filter_params[:report_type] = type
      ReportData.find(:all, :conditions => filter_params).collect{ |r| r.id }
    end
    
    def get_report(type, id, format, force_formating, params)
      
      begin
        report = ReportData.find(:first, :conditions => {:id => id, :report_type => type})
      rescue ActiveRecord::RecordNotFound
        raise Reports::NotFound.new("Report with id='"+id.to_s+"' and type='"+type.to_s+"' not found.")
      end
  
      case format
      when "application/rdf+xml"
        report.to_rdf
      when "text/x-yaml"
        report.to_yaml
      else
        super
      end
    end
    
    def delete_report(type, id)
      begin
        report = ReportData.find(:first, :conditions => {:id => id, :report_type => type})
      rescue ActiveRecord::RecordNotFound
        raise Reports::NotFound.new("Report with id='"+id.to_s+"' and type='"+type.to_s+"' not found.")
      end
      ReportData.delete(id)
      super      
    end
  end
end
