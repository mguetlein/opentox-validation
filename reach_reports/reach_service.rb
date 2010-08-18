module ReachReports
  
  def self.list_reports(type)
    case type
    when /(?i)QMRF/
      ReachReports::QmrfReport.all.collect{ |r| r.report_uri }.join("\n")
    when /(?i)QPRF/
      ReachReports::QprfReport.all.collect{ |r| r.report_uri }.join("\n")
    end
  end 
  
  def self.create_report( type, params, xml_data=nil )
    
    #content_type "text/uri-list"
    #task_uri = OpenTox::Task.as_task do |task|
    
    case type
    when /(?i)QMRF/
      if params[:model_uri]
        report = ReachReports::QmrfReport.new :model_uri => params[:model_uri]
        build_qmrf_report(report)
      elsif xml_data
        input = xml_data.read
        report = ReachReports::QmrfReport.new
        ReachReports::QmrfReport.from_xml(report,input)
      else
        $sinatra.halt 400, "illegal parameters for qmrf-report, use either\n"+
          "* model_uri\n"+ 
          "params given: "+params.inspect
      end
    when /(?i)QPRF/
      $sinatra.halt 400,"qprf report creation not yet implemented"
      if params[:compound_uri]
        report = ReachReports::QprfReport.new :compound_uri => params[:compound_uri]
      else
        $sinatra.halt 400, "illegal parameters for qprf-report, use either\n"+
          "* compound-uri\n"+ 
          "params given: "+params.inspect
      end
    end
    
    report.report_uri
    
    #end
    #halt 202,task_uri
  end
  
  def self.build_qmrf_report(r)

    model = OpenTox::Model::Generic.find(r.model_uri)
     
    # chapter 1
    #r.QSAR_title = model.title
    r.qsar_identifier = QsarIdentifier.new
    r.qsar_identifier.qsar_title = model.title

    # TODO
    # QSAR_models -> sparql same endpoint     
    r.qsar_identifier.qsar_software << QsarSoftware.new( :url => model.uri, :name => model.title, :contact => model.creator )
    algorithm = OpenTox::Algorithm::Generic.find(model.algorithm) if model.algorithm
    r.qsar_identifier.qsar_software << QsarSoftware.new( :url => algorithm.uri, :name => algorithm.title )

    #chpater 2
    r.qsar_general_information = QsarGeneralInformation.new
    r.qsar_general_information.qmrf_date = DateTime.now.to_s
    # EMPTY: qmrf_authors, qmrf_date_revision, qmrf_revision
    # TODO: model_authors ?
    r.qsar_general_information.model_date = model.date.to_s
    # TODO: references?
    # EMPTY: info_availablity
    # TODO: related_models = find qmrf reports for QSAR_models 
     
    # chapter 3
    # TODO "model_species" ?
    r.qsar_endpoint = QsarEndpoint.new
    
    model.predictedVariables.each do |p|
      r.qsar_endpoint.model_endpoint << ModelEndpoint.new( :name => p )
    end
    # TODO "endpoint_comments" => "3.3", "endpoint_units" => "3.4",
    r.qsar_endpoint.endpoint_variable = model.dependentVariables
    # TODO "endpoint_protocol" => "3.6", "endpoint_data_quality" => "3.7",

    # chapter 4
    # TODO algorithm_type (='type of model')
    # TODO algorithm_explicit.equation
    # TODO algorithm_explicit.algorithms_catalog
    # TODO algorithms_descriptors, descriptors_selection, descriptors_generation, descriptors_generation_software, descriptors_chemicals_ratio

    # chapter 5
    # TODO app_domain_description, app_domain_method, app_domain_software, applicability_limits

    # chapter 6
    # "training_set_availability" => "6.1", "training_set_data" => "6.2","training_set_descriptors" => "6.3", 
    # "dependent_var_availability" => "6.4", "other_info" => "6.5", "preprocessing" => "6.6", "goodness_of_fit" => "6.7", 
    # "loo" => "6.8", "lmo" => "6.9", "yscrambling" => "6.10", "bootstrap" => "6.11", "other_statistics" => "6.12",

    # chapter 7 
    # "validation_set_availability" => "7.1", "validation_set_data" => "7.2", "validation_set_descriptors" => "7.3", 
    # "validation_dependent_var_availability" => "7.4", "validation_other_info" => "7.5", "experimental_design" => "7.6", 
    # "validation_predictivity" => "7.7", "validation_assessment" => "7.8", "validation_comments" => "7.9", 

    # chapter 8
    # "mechanistic_basis" => "8.1", "mechanistic_basis_comments" => "8.2", "mechanistic_basis_info" => "8.3",

    # chapter 9
    # "comments" => "9.1", "bibliography" => "9.2", "attachments" => "9.3",
     
    r.save
  end
  
#  def self.get_report_content(type, id, *keys)
#    
#    report_content = get_report(type, id).get_content
#    keys.each do |k|
#      $sinatra.halt 400, type+" unknown report property '#{key}'" unless report_content.is_a?(Hash) and report_content.has_key?(k)
#      report_content = report_content[k]
#    end
#    report_content    
#  end
  
  def self.get_report(type, id)
    
    case type
    when /(?i)QMRF/
      report = ReachReports::QmrfReport.get(id)
    when /(?i)QPRF/
      report = ReachReports::QprfReport.get(id)
    end
    $sinatra.halt 404, type+" report with id '#{id}' not found." unless report
    return report
  end
end 
