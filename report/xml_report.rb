
require 'rexml/document'

ENV['REPORT_DTD'] = "docbook-xml-4.5/docbookx.dtd" unless ENV['REPORT_DTD']
#transfer to absolute path
ENV['REPORT_DTD'] = File.expand_path(ENV['REPORT_DTD']) if File.exist?(ENV['REPORT_DTD'])

# = XMLReport
# 
# uses REXML to generate an XML document in DocBook article format
#
# uses Env-Variable _XMLREPORT_DTD_ to specifiy the dtd
#  
class Reports::XMLReport
  include REXML
  
  # create new xmlreport
  def initialize(title, pubdate=nil, author_firstname = nil, author_surname = nil)
    
    @doc = Document.new
    decl = XMLDecl.new
    @doc << decl
    type = DocType.new('article PUBLIC "-//OASIS//DTD DocBook XML V4.5//EN" "'+ENV['REPORT_DTD']+'"')
    @doc << type

    @root = Element.new("article")
    @doc << @root

    article_info = Element.new("articleinfo")
    article_info << Reports::XMLReportUtil.text_element("title", title)
    author = Element.new("author")
    author << Reports::XMLReportUtil.text_element("firstname", author_firstname)
    author << Reports::XMLReportUtil.text_element("surname", author_surname)
    article_info << author
    article_info << Reports::XMLReportUtil.text_element("pubdate", pubdate)
    @root << article_info
    
    @resource_path_elements = {}
  end
  
  # 
  # returns the root element of the document
  # call-seq:
  #   get_root_element => REXML::Element
  #
  def get_root_element
    @root
  end
  
  # adds a new section to a REXML:Element, returns the section as element
  # call-seq:
  #   add_section(element, title) => REXML::Element
  #
  def add_section(element, title)
    
    section = Element.new("section")
    section << Reports::XMLReportUtil.text_element("title", title)
    element << section
    return section
  end
  
  # adds a new paragraph to a REXML:Element, returns the paragraph as element
  # call-seq:
  #   add_paragraph( element, text ) => REXML::Element
  #
  def add_paragraph( element, text )
    
    para = Reports::XMLReportUtil.text_element("para", text)
    element << para
    return para
  end
  
  # adds a new image to a REXML:Element, returns the figure as element
  # 
  # example: <tt>add_imagefigure( section2, "Nice graph", "/images/graph1.svg", "SVG", "This graph shows..." )</tt>
  #
  # call-seq:
  #   add_imagefigure( element, title, path, filetype, caption = nil ) => REXML::Element
  #
  def add_imagefigure( element, title, path, filetype, caption = nil )
    
    figure = Reports::XMLReportUtil.attribute_element("figure", {"float" => 0})
    figure << Reports::XMLReportUtil.text_element("title", title)
    media = Element.new("mediaobject")
    image = Element.new("imageobject")
    imagedata = Reports::XMLReportUtil.attribute_element("imagedata",{"contentwidth" => "75%", "fileref" => path, "format"=>filetype})
    #imagedata = Reports::XMLReportUtil.attribute_element("imagedata",{"width" => "6in", "fileref" => path, "format"=>filetype})
    @resource_path_elements[imagedata] = "fileref"
    image << imagedata
    media << image
    media << Reports::XMLReportUtil.text_element("caption", caption) if caption
    figure << media
    element << figure
    return figure    
  end
  
  # adds a table to a REXML:Element, _table_values_ should be a multi-dimensional-array, returns the table as element
  # 
  # call-seq:
  #   add_table( element, title, table_values, first_row_is_table_header=true ) => REXML::Element
  #
  def add_table( element, title, table_values, first_row_is_table_header=true, transpose=false )
    
    raise "table_values is not mulit-dimensional-array" unless table_values && table_values.is_a?(Array) && table_values[0].is_a?(Array) 
    
    values = transpose ? table_values.transpose : table_values
    
    table = Reports::XMLReportUtil.attribute_element("table",{"frame" => "top", "colsep" => 0, "rowsep" => 0})
    
    table << Reports::XMLReportUtil.text_element("title", title)
    
    raise "column count 0" if values.at(0).size < 1 
    
    tgroup = Reports::XMLReportUtil.attribute_element("tgroup",{"cols" => values.at(0).size})
    
    table_body_values = values
    
    if first_row_is_table_header
      table_head_values = values[0];
      table_body_values = values[1..-1];
      
      thead = Element.new("thead")
      row = Element.new("row")
      table_head_values.each{ |v| row << Reports::XMLReportUtil.text_element("entry", v.to_s) }
      thead << row
      tgroup << thead
    end
    
    tbody = Element.new("tbody") 
    table_body_values.each do |r|
      row = Element.new("row")
      r.each { |v| row << Reports::XMLReportUtil.text_element("entry", v.to_s) }
      tbody << row
    end
    tgroup << tbody 
    
    table << tgroup
    element << table
    return table
  end
  
  # adds a list to a REXML:Element, returns the list as element
  # 
  # call-seq:
  #   add_list( element, list_values ) => REXML::Element
  #
  def add_list( element, list_values )
    
    list = Element.new("itemizedlist")
    
    list_values.each do |l|
      listItem = Element.new("listitem")
      add_paragraph(listItem, l.to_s)
      list << listItem
    end
    
    element << list
    return list
  end
  
  # writes xml document
  def write_to( out = $stdout, resource_path=nil )
    
    #alternativly use base href in html-header
    if (resource_path)
      @resource_path_elements.each do |k,v|
        raise "attribute '"+v+"' not found in element '"+k+"'" unless k.attributes.has_key?(v)
        k.add_attribute( v, resource_path.to_s+"/"+k.attributes[v].to_s )
      end
    end
    
    @doc.write(out,2)
  end

  # call-seq:
  #   self.generate_demo_xml_report => Reports::XMLReport
  #
  def self.generate_demo_xml_report

    rep = Reports::XMLReport.new("Demo report", "subtitle" "Fistname", "Surname")
    section1 = rep.add_section(rep.get_root_element, "First Section")
    rep.add_paragraph(section1, "some text")
    rep.add_paragraph(section1, "even more text")
    rep.add_imagefigure(section1, "Figure", "http://upload.wikimedia.org/wikipedia/commons/thumb/e/eb/Siegel_der_Albert-Ludwigs-Universit%C3%A4t_Freiburg.svg/354px-Siegel_der_Albert-Ludwigs-Universit%C3%A4t_Freiburg.svg", "SVG", "this is the logo of freiburg university")
    section2 = rep.add_section(rep.get_root_element,"Second Section")
    rep.add_section(section2,"A Subsection")
    rep.add_section(section2,"Another Subsection")
    rep.add_section(rep.get_root_element,"Third Section")
    
    return rep
  end
  
end














  
