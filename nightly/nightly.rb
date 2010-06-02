
require 'test/test_examples.rb'

class Nightly
  
  NIGHTLY_REP_DIR = File.join(FileUtils.pwd,"nightly")
  NIGHTLY_REPORT_XML = "nightly_report.xml"
  NIGHTLY_REPORT_HTML = "nightly_report.html"
  
  def self.get_nightly
    LOGGER.info("Accessing nightly report.")
    if File.exist?(File.join(NIGHTLY_REP_DIR,NIGHTLY_REPORT_HTML))
      return File.new(File.join(NIGHTLY_REP_DIR,NIGHTLY_REPORT_HTML))
    else
      return "Nightly report not available, try again later"
    end
  end
  
  def self.build_nightly(select=nil, dry_run=false)
    
    validationExamples = ValidationExamples.select(select)
    return "please \"select\" validation examples:\n"+ValidationExamples.list if validationExamples.size==0
    
    task_uri = OpenTox::Task.as_task() do
      LOGGER.info("Building nightly report")
      
      benchmarks = validationExamples.collect{ |e| ValidationBenchmark.new(e) }
      
      running = []
      report = Reports::XMLReport.new("Nightly Validation", Time.now.strftime("Created at %m.%d.%Y - %H:%M"))
      count = 1
      benchmarks.each do |b|
        id = "["+count.to_s+"]-"+b.title
        count += 1
        running << id
        Thread.new do
          begin
            b.build
          rescue => ex
            LOGGER.error "uncaught nightly build error: "+ex.message
          ensure
            running.delete id
          end
        end
      end
      wait = 0
      while running.size>0
        LOGGER.debug "Nightly report waiting for "+running.inspect if wait%60==0
        wait += 1
        sleep 1
      end
      LOGGER.debug "Nightly report, all benchmarks done "+running.inspect
      
      section_about = report.add_section(report.get_root_element, "About this report")
      report.add_paragraph(section_about,
        "This a opentox internal test report. Its purpose is to maintain interoperability between the OT validation web service "+
        "and other OT web services. If you have any comments, remarks, or wish your service/test-case to be added, please email "+
        "to guetlein@informatik.uni-freiburg.de or use the issue tracker at http://opentox.informatik.uni-freiburg.de/simple_ot_stylesheet.css")
      
      benchmarks.each do |b|  
         section = report.add_section(report.get_root_element, b.title)
         
         section_info = report.add_section(section, "Info")
         info_table = b.info_table
         report.add_table(section_info, "Validation info", info_table) if info_table
         
         section_results = report.add_section(section, "Results")
         report.add_table(section_results, "Valdation results", b.result_table)
         
         if (b.comparison_report)
           report.add_table(section_results, "Validation comparison report", [[b.comparison_report]], false)
         end
         
         section_errors = report.add_section(section, "Errors")
         
         if b.errors and b.errors.size>0
           b.errors.each do |k,v|
             elem = report.add_section(section_errors,k)
             report.add_paragraph(elem,v,true)
           end
         else
           report.add_paragraph(section_errors,"no errors occured")
         end
       
      end
      
      unless dry_run
        report.write_to(File.new(File.join(NIGHTLY_REP_DIR,NIGHTLY_REPORT_XML), "w"))
        Reports::ReportFormat.format_report_to_html(NIGHTLY_REP_DIR,
          NIGHTLY_REPORT_XML, 
          NIGHTLY_REPORT_HTML, 
          nil)
          #"http://www.opentox.org/portal_css/Opentox%20Theme/base-cachekey7442.css")
          #"http://apps.ideaconsult.net:8080/ToxPredict/style/global.css")
        LOGGER.info("Nightly report completed")
      else
        LOGGER.info("Nightly report completed - DRY RUN, no report creation")
      end
      benchmarks.collect{|b| b.uris}.join(",")
    end
    if defined?(halt)
      halt 202,task_uri
    else
      return task_uri
    end
  end
  
  class ValidationBenchmark
  
    attr_accessor :errors, :comparison_report

    def comparable
      if @comp == nil
        @comp = @validation_examples[0].algorithm_uri==nil ? :model_uri : :algorithm_uri 
      end
      @comp
    end
    
    def uris
      @validation_examples.collect{|v| v.validation_uri}.join(",")
    end

    def initialize(validationExamples)
      @validation_examples = []
      validationExamples.each do |v|
        example = v.new
        @validation_examples << example
      end
    end
    
    def title
      if @validation_examples.size==0
        @validation_examples[0].class.humanize
      else
        @validation_examples[0].class.superclass.humanize  
      end
    end
    
    def result_table
      t = []
      row = [comparable.to_s, "validation", "report"]
      t << row
      @validation_examples.each do |e|
        row = [ e.send(comparable), 
                (e.validation_error!=nil ? "error, see below" : e.validation_uri),
                (e.report_error!=nil ? "error, see below" : e.report_uri) ]
        t << row
      end
      t
    end

    def info_table
      t = []
      t << ["param", "uri"]
      
      (@validation_examples[0].params+@validation_examples[0].opt_params).each do |p|
        map = {}
        @validation_examples.each{|e| map[e.send(p).to_s]=nil }
        
        if map.size==1 && map.keys[0].size==0
          #omit
        elsif map.size==1 #values equal
          t << [p.to_s, map.keys[0]]
        else
          count = 1
          @validation_examples.each do |e|
            t << [p.to_s+" ["+count.to_s+"]", e.send(p)]
            count += 1
          end
        end
      end
      t
    end
    
    def build()
      
      @errors = {}
      
      running = []
      count = 1
      
      @validation_examples.each do |v|

        id = "["+count.to_s+"]-"+v.title
        count += 1
        running << id
        LOGGER.debug "Uploading datasets: "+v.title
        v.upload_files
        v.check_requirements

        Thread.new do 
          
          LOGGER.debug "Validate: "+v.title
          v.validate
          if v.validation_error!=nil
            @errors["Error validating "+v.title] = v.validation_error
          else
            LOGGER.debug "Building report: "+v.title
            v.report
            if v.report_error!=nil
              @errors["Error building report for "+v.title] = v.report_error
            end
          end
          running.delete(id)
        end
      end

      wait = 0
      while running.size>0
        LOGGER.debug self.title+" waiting for "+running.inspect if wait%20==0
        wait += 1
        sleep 1
      end
      
      LOGGER.debug self.class.to_s.gsub(/Nightly::/, "")+": build comparison report"
      @comparison_report = ValidationExamples::Util.build_compare_report(@validation_examples)
    end
  end
  
end