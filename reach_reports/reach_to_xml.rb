
module ReachReports include REXML
  
  def self.reach_report_to_xml( report )
    
    @@info = {}
    if report.type=="QMRF"
      @@info[:type ] = "QMRF"
      @@info[:dtd_full ] = "http://ambit.sourceforge.net/qmrf/jws/qmrf.dtd"
      @@info[:dtd ] = "qmrf.dtd"
      @@info[:version ] = 1.2
      @@info[:schema_version] = 0.9
      @@info[:name ] = "(Q)SAR Model Reporting Format"
    elsif report.type=="QPRF"
      @@info[:type ] = "QPRF"
      @@info[:dtd_full ] = "not-yet-defined/qprf.dtd"
      @@info[:dtd ] = "qprf.dtd"
      @@info[:version ] = 0.1
      @@info[:schema_version] = 0.1
      @@info[:name ] = "(Q)SAR Prediction Reporting Format"
    end
    @@info[:author] ="Joint Research Centre, European Commission"
    @@info[:contact] ="Joint Research Centre, European Commission"
    @@info[:date ] = Time.new.to_s
    @@info[:email] ="qsardb@jrc.it"
    @@info[:schema_version] ="0.9"
    @@info[:url ] = "http://ecb.jrc.ec.europa.eu/qsar/"
    
    doc = Document.new
    decl = XMLDecl.new
    doc << decl
    type = DocType.new(@@info[:type]+' PUBLIC "'+@@info[:dtd_full]+'" "'+@@info[:dtd]+'"')
    doc << type
    
    main = Element.new(@@info[:type])
    main.add_attributes( Hash[*[:version, :schema_version, :name, :author, :contact,
      :date, :email, :schema_version, :url].collect { |v| [v.to_s, @@info[v]]}.flatten] )
    
    catalogs = Element.new("Catalogs")
    chapters = Element.new(@@info[:type]+"_chapters")
    
    QmrfProperties.chapters.each do |c|
      chapter = Element.new(c)
      chapter.add_attribute("chapter",QmrfProperties.chapter_number(c))
      QmrfProperties.chapter_properties(c).each do |p|
        chapter << QmrfProperties.to_xml(p, report.send(p), catalogs)
      end
      chapters << chapter
    end
    
    main << chapters
    main << catalogs
    doc << main
    
    s = ""
    doc.write(s, 2, false, false)
    return s
  end
  
end