
require "dm-validations"

DataMapper::Model.raise_on_save_failure = true

module REXML

  class Element
    def self.find_or_create(parent_node, name)
      if parent_node.elements[name]
        parent_node.elements[name]
      else
        node = Element.new(name)
        parent_node << node
        node
      end
    end
  end
  
  class TextElement < Element
    def initialize(name, text)
      super(name)
      self.text = text 
    end
    
    def self.find_or_create(parent_node, name, text)
      elem = Element.find_or_create(parent_node, name)
      elem.text = text
      elem
    end
  end
end


class Symbol
  
  XML_ALIAS = { 
    :qsar_identifier => "QSAR_identifier", :qsar_title => "QSAR_title", :qsar_software => "QSAR_software",
    :qsar_models => "QSAR_models", :qsar_general_information => "QSAR_General_information", 
    :qsar_endpoint => "QSAR_Endpoint", :qmrf_author => "qmrf_authors", :qsar_algorithm => "QSAR_Algorithm", 
    :qsar_applicability_domain => "QSAR_Applicability_domain", :qsar_robustness => "QSAR_Robustness", 
    :qsar_predictivity => "QSAR_Predictivity", :qsar_interpretation => "QSAR_Interpretation", 
    :qsar_miscelaneous => "QSAR_Miscelaneous", :qmrf_summary => "QMRF_Summary", :qmrf_number => "QMRF_number" }
  
  def xml_alias
    XML_ALIAS[self] ? XML_ALIAS[self] : self.to_s
  end
end

class DataMapper::Associations::OneToMany::Relationship
  def get_child_model
    @child_model
  end
end

module DataMapper::Resource
  
  def association_class( property )
    relationship = relationships[property]
    raise "no relationship found for "+property.to_s+" "+relationships.inspect unless relationship
    raise "not a many-to-one or one-to-one association for "+property.to_s+" "+relationship.inspect unless 
      relationship.is_a?(DataMapper::Associations::OneToMany::Relationship) or
      relationship.is_a?(DataMapper::Associations::OneToOne::Relationship)
    relationship.get_child_model
  end
  
  def from_xml(node)
    
    raise "node is nil ("+self.class.to_s+".from_xml)" unless node
    #puts "FROM xml: "+self.class.to_s #+", NODE: "+node.to_s
    
    dbg_check = { :attributes => Set.new(), :nodes => Set.new(), :subnodes => Set.new() }
    
    xml_infos.each do |xml_info|
    
      if xml_info.is_a?(ReachReports::TextNodeProperty)
         text_node = node.elements[ xml_info.xml_prop ]
         raise "node not found: "+ xml_info.xml_prop+"  ("+self.class.to_s+".from_xml)" unless text_node
         self.send( xml_info.prop.to_s+"=", text_node.text )
         dbg_check[:nodes] << text_node.name
    
      elsif xml_info.is_a?(ReachReports::CatalogReference)
        root_node = node.elements[ xml_info.xml_prop ]  
        raise "node not found: "+ xml_info.xml_prop+"  ("+self.class.to_s+".from_xml)" unless root_node
        dbg_check[:nodes] << root_node.name

        self.send(xml_info.prop).each{ |s| s.destroy } if self.send(xml_info.prop)
        self.send(xml_info.prop).clear() #otherwise the content is tmp still here  
        
        catalog_node = $catalogs_node.elements[xml_info.catalog_name]

        root_node.each_element(xml_info.catalog_element+"_ref") do |n|
          ref = nil
          catalog_node.each_element_with_attribute("id", n.attribute("idref").to_s) do |e|
            ref = e
            break
          end
          raise "referenced node not found for "+xml_info.xml_prop+" in catalog "+xml_info.catalog_name+" ref-node was "+n.to_s unless ref
          dbg_check[:subnodes] << n
          
          entry = self.association_class(xml_info.prop).new
          entry.from_xml( ref )
          self.send(xml_info.prop) << entry
        end
        
      elsif xml_info.is_a?(ReachReports::AttributeProperty)
        #puts "attr "+xml_info.prop.to_s
        self.send(xml_info.prop.to_s+"=", node.attribute(xml_info.xml_prop))
        dbg_check[:attributes] << xml_info.prop
        
      elsif xml_info.is_a?(ReachReports::TextSubnodeProperty)
        parent_node = node.elements[ xml_info.parent_prop.xml_alias ]
        raise "parent node not found: '"+ xml_info.parent_prop.xml_alias+"' ("+self.class.to_s+".from_xml)" unless parent_node
        text_node = parent_node.elements[ xml_info.xml_prop ]
        raise "node not found: "+ xml_info.xml_prop+"  ("+self.class.to_s+".from_xml)" unless text_node
        self.send( xml_info.prop.to_s+"=", text_node.text )
        dbg_check[:nodes] << parent_node.name
        dbg_check[:subnodes] << text_node
        
      elsif xml_info.is_a?(ReachReports::AttributeNodeProperty)
        attr_node = node.elements[ xml_info.xml_prop ]
        self.send(xml_info.prop.to_s+"=", attr_node.attribute(xml_info.attribute))
        dbg_check[:nodes] << attr_node.name
      
      elsif xml_info.is_a?(ReachReports::MultiAttributeNodeProperty)
        attr_node = node.elements[ xml_info.xml_prop ]
        entry = self.association_class( xml_info.prop ).new
        entry.from_xml(attr_node)
        self.send(xml_info.prop.to_s+"=",entry)
        dbg_check[:nodes] << attr_node.name
      
      else
        raise "type not supported yet: "+xml_info.inspect
      end
    end
      
    ##raise "not a qsar_identifier" unless qsar_identifier.is_a?(QsarIdentifier)

    #puts node.elements.inspect
    #puts "there we go: "+qsar_identifier.qsar_software.to_s
    #qsar_identifier.qsar_software = QsarSoftware.new
    #puts "there we go: "+qsar_identifier.qsar_software.to_s
    #exit
    
    #          if defined?(self.class.text_properties)
#            self.class.text_properties.each do |p|
#              puts "set "+p.to_s
#              raise "node not found: "+p.xml_alias.to_s+"  ("+self.class.to_s+".from_xml)" unless node.elements[p.xml_alias]
#              #puts "set "+p.to_s+" to: "+node.elements[p.xml_alias].text.to_s
#              self.send(p.to_s+"=", node.elements[p.xml_alias].text)
#              #qsar_identifier.qsar_models = node.elements["qsar_models".xml_alias].text
#              dbg_check[:nodes] << node.elements[p.xml_alias].name
#            end
#    
    
    
#    if defined?(self.class.subsection_properties)
#      self.class.subsection_properties.each do |section_p, subsection_p|
#        #puts "set "+p.to_s
#        #raise "node not found: "+p.xml_alias.to_s+"  ("+self.class.to_s+".from_xml)" unless node.elements[p.xml_alias]
#        #puts "set "+p.to_s+" to: "+node.elements[p.xml_alias].text.to_s
#        section = node.elements[section_p.xml_alias]
#        subsection = section.elements[subsection_p.xml_alias]
#        self.send(subsection_p.to_s+"=", subsection.text)
#        
#        dbg_check[:nodes] << section.name
#        dbg_check[:subnodes] << subsection
#        
#        #qsar_identifier.qsar_models = node.elements["qsar_models".xml_alias].text
#        #dbg_check[:text_nodes] << node.elements[p.xml_alias].name
#      end
#    end    
    
#    if defined?(self.class.attribute_properties)
#      self.class.attribute_properties.each do |p|
#        puts "read attribute "+p.to_s
#        #self.update(p => node.attribute(p.xml_alias))
#        self.send(p.to_s+"=", node.attribute(p.xml_alias))
#        dbg_check[:attributes] << p
#        #qsar_identifier.qsar_models = node.elements["qsar_models".xml_alias].text
#      end
#    end
    
    #qsar_identifier.qsar_title = node.elements["qsar_title".xml_alias].text
    #qsar_identifier.qsar_models = node.elements["qsar_models".xml_alias].text
    
    
    
    ignore_attribs =[ "id", "name", "help", "chapter" ]
    node.attributes.each do |a,v|
      unless (ignore_attribs.include?(a.to_s)) || dbg_check[:attributes].include?(a.to_sym)
          raise "not handled : attribute '"+a.to_s+"' -> '"+v.to_s+"'" +
           "\n("+self.class.to_s+".from_xml)" +
           "\nchecked:\n"+dbg_check[:attributes].to_yaml+
           "\nnode-attribtues:\n"+node.attributes.to_yaml
        end
    end
    
    node.each_element do |n|
#      if n.text!=nil and n.text.to_s.size>0 and
#         !dbg_check[:text_nodes].include?(n.name) and
#         (!dbg_check[:catalog_nodes].has_key?(n.name))
         
      valid = dbg_check[:nodes].include?(n.name)
      if (valid)
        refs = dbg_check[:subnodes]
        #puts "sub "+refs.inspect
        n.each_element do |nn|
          #puts "lookin for ref "+nn.to_s
          unless refs.include?(nn)
            valid = false
            break
          end
        end
      end
       
       unless valid
        raise puts "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\nXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX\nnot handled node : "+n.to_s+
        "\n("+self.class.to_s+".from_xml)"
#        raise "not handled node : "+n.to_s+
#           "\n("+self.class.to_s+".from_xml)" +
#           "\nchecked text nodes:\n"+dbg_check[:text_nodes].to_yaml+
#           "\nchecked catalog nodes:\n"+dbg_check[:catalog_nodes].to_yaml+
#           "\nnode-attribtues:\n"+n.attributes.to_yaml        
      end
    end
    
  
    #self.save!
    #self.reload
#    unless self.save
#      self.errors.each do |e|
#        puts "Error: "+e.to_s
#      end
#    end
    #puts "self id: "+self.id.to_s
    
#        qsar_identifier.qsar_software.each{ |s| s.destroy } if qsar_identifier.qsar_software
#        qsar_identifier.qsar_software.update({}) #otherwise the content is tmp still here  
#        
#        catalog_node = $catalogs_node.elements["software_catalog"]
#        
#        node.elements[:qsar_software.xml_alias].each_element do |n|
#          
#          puts "reading software ref "+n.to_s
#          ref = nil
#          catalog_node.each_element_with_attribute("id", n.attribute("idref").to_s) do |e|
#            ref = e
#            break
#          end
#          software = QsarSoftware.new
#          QsarSoftware.from_xml( software, ref )
#          qsar_identifier.qsar_software << software
#        end
#        #qsar_identifier.qsar_software = QsarSoftware.new unless qsar_identifier.qsar_software
#        #QsarSoftware.from_xml( qsar_identifier.qsar_software, node.elements["qsar_software".xml_alias] )

  end
  
  def to_XML(node, chapter=nil )
    
    xml_infos.each do |xml_info|
      if xml_info.is_a?(ReachReports::TextNodeProperty)
        new_node = REXML::TextElement.find_or_create(node, xml_info.xml_prop,self.send(xml_info.prop))
        
      elsif xml_info.is_a?(ReachReports::CatalogReference)
        
        new_node = REXML::Element.find_or_create( node, xml_info.xml_prop )
        catalog_node = $catalogs_node.elements[ xml_info.catalog_name ]
        
        self.send(xml_info.prop.to_s+"=",[self.association_class(xml_info.prop).new]) unless self.send(xml_info.prop) and self.send(xml_info.prop).size>0
        
        self.send( xml_info.prop ).each do |elem|
          elem_node = REXML::Element.new(xml_info.catalog_element )
          elem.to_XML( elem_node )
          # if not saved, i.e. the element was only created for a complete xml, count elements in catalog for id
          element_id = xml_info.catalog_element+"_"+(elem.id ? elem.id.to_s : (catalog_node.elements.size+1).to_s)
          elem_node.add_attribute("id",element_id)
          catalog_node << elem_node
          
          ref_node = REXML::Element.new(xml_info.catalog_element+"_ref" )
          ref_node.add_attributes("idref"=>element_id,"catalog"=>xml_info.catalog_name)
          new_node << ref_node
        end
        
      elsif xml_info.is_a?(ReachReports::AttributeProperty)
        node.add_attribute( xml_info.xml_prop, self.send(xml_info.prop).to_s )
        
      elsif xml_info.is_a?(ReachReports::TextSubnodeProperty)
        new_node = REXML::Element.find_or_create( node, xml_info.parent_prop.xml_alias)
        REXML::TextElement.find_or_create( new_node, xml_info.xml_prop,self.send(xml_info.prop))

      elsif xml_info.is_a?(ReachReports::AttributeNodeProperty)
        new_node = REXML::Element.find_or_create(node, xml_info.xml_prop)
        new_node.add_attribute(xml_info.attribute, self.send(xml_info.prop).to_s) 
      
      elsif xml_info.is_a?(ReachReports::MultiAttributeNodeProperty)
        new_node = REXML::Element.find_or_create(node, xml_info.xml_prop)
        self.send(xml_info.prop.to_s+"=",self.association_class(xml_info.prop).new) unless self.send(xml_info.prop)
        self.send(xml_info.prop).to_XML(new_node)
        
      else
        raise "type not supported yet: "+xml_info.inspect
      end
      
      new_node.add_attribute("chapter", chapter.to_s+"."+node.elements.size.to_s) if chapter and new_node and new_node.attribute("chapter")==nil
    end
      
#      if defined?(self.class.text_properties)
#        self.class.text_properties.each do |p|
#          node << REXML::TextElement.new(p.xml_alias,self.send(p))
#        end
#      end
      #node << REXML::TextElement.new(:qsar_title.xml_alias,qsar_title)
      #node << REXML::TextElement.new(:qsar_models.xml_alias,qsar_models)
      
#      if defined?(self.class.catalog_entries)
#        self.class.catalog_entries.each do |p| #,associatedClass|
#        
#          assoc_node = REXML::Element.new( p.xml_alias )
#          self.send(p).each{ |s| s.to_XML( assoc_node ) }
#          node << assoc_node
#        end
#      end
#    
#      if defined?(self.class.catalog_name)
#        catalog_node = $catalogs_node.elements[self.class.catalog_name]
#        node_ref = REXML::Element.new(self.class.catalog_element+"_ref")
#        
#        raise "id is nil" if self.id==nil || self.id.to_s.size==0
#        element_id = self.class.catalog_element+"_"+self.id.to_s
#        node_ref.add_attributes("idref"=>element_id,"catalog"=>self.class.catalog_name)
#        
#        content_node = REXML::Element.new(self.class.catalog_element)
#        content_node.add_attribute("id",element_id)
#        self.class.attribute_properties.each do |p|
#          content_node.add_attribute p.xml_alias,send(p)
#        end
#        catalog_node << content_node
#        node << node_ref
#        
##        def catalog_to_xml(node, catalog_name, element_name, attributes)
##          catalog_node = $catalogs_node.elements[catalog_name]
##          node_ref = REXML::Element.new(element_name+"_ref")
##          attributes["id"] = element_name+"_"+attributes.delete("id").to_s
##          node_ref.add_attributes("idref"=>attributes["id"],"catalog"=>catalog_name)
##          content_node = REXML::Element.new(element_name)
##          #puts "my attribts: "+attributes.inspect
##          attributes.each do |k,v|
##            content_node.add_attribute k,v.to_s
##          end
##          catalog_node << content_node
##          node << node_ref     
##        end
#      end
    
      
#      node << REXML::TextElement.new(:qsar_title.xml_alias,qsar_title)
#      node << REXML::TextElement.new(:qsar_models.xml_alias,qsar_models)
#      qsar_software_node = REXML::Element.new(:qsar_software.xml_alias)
#      qsar_software.each{ |s| s.to_xml( qsar_software_node ) }
#      node << qsar_software_node
    end
  
end


module ReachReports
  
  def self.get_uri( report )
    raise "internal error, id not set "+to_yaml if report.id==nil
    return $sinatra.url_for("/"+File.join(report.type,report.id.to_s), :full).to_s
  end
  
  
  

#  module CatalogEntry
#    
#    def catalog_to_xml(node, catalog_name, element_name, attributes)
#      catalog_node = $catalogs_node.elements[catalog_name]
#      node_ref = REXML::Element.new(element_name+"_ref")
#      attributes["id"] = element_name+"_"+attributes.delete("id").to_s
#      node_ref.add_attributes("idref"=>attributes["id"],"catalog"=>catalog_name)
#      content_node = REXML::Element.new(element_name)
#      #puts "my attribts: "+attributes.inspect
#      attributes.each do |k,v|
#        content_node.add_attribute k,v.to_s
#      end
#      catalog_node << content_node
#      node << node_ref      
#    end
#  end

#  class QsarSoftware
#    include DataMapper::Resource #, CatalogEntry
#    
#    property :id, Serial
#    property :contact, String, :length => 255
#    property :description, String, :length => 255
#    property :name, String, :length => 255
#    property :number, String, :length => 255
#    property :url, String, :length => 255
#    
#    def self.attribute_properties
#      [ :contact, :description, :name, :number, :url ]
#    end
#    
#    def self.catalog_name
#      "software_catalog"
#    end
#    
#    def self.catalog_element
#      "software"
#    end
#
#    belongs_to :qsar_identifier
#  end  
  
  class Software
    include DataMapper::Resource #, CatalogEntry
    
    property :id, Serial
    property :contact, String, :length => 255
    property :description, String, :length => 255
    property :name, String, :length => 255
    property :number, String, :length => 255
    property :url, String, :length => 255
    
    def xml_infos
      [ AttributeProperty.new(:contact),
        AttributeProperty.new(:description),
        AttributeProperty.new(:name),
        AttributeProperty.new(:number),
        AttributeProperty.new(:url) ]
    end
  end  
  
  class QsarSoftware < Software
    #belongs_to :qsar_identifier, :key => false
    property :qsar_identifier_id, Integer
  end
  
  class XmlInfo
    
    attr_accessor :prop
    
    protected 
    def initialize( prop )
      @prop = prop
    end
    
    public
    def xml_prop
      @prop.xml_alias
    end
  end
  
  class TextNodeProperty < XmlInfo
    
  end
  
  class TextSubnodeProperty < XmlInfo
    attr_accessor :parent_prop
    
    def initialize( prop, parent_prop )
      super(prop)
      @parent_prop = parent_prop
    end
  end
  
  class AttributeProperty < XmlInfo
    
  end
  
  class MultiAttributeNodeProperty < XmlInfo
    
  end
  
  class AttributeNodeProperty < XmlInfo
    attr_accessor :attribute
    
    def initialize( prop, attribute )
      super(prop)
      @attribute = attribute
    end
  end 

  class CatalogReference < XmlInfo
    attr_accessor :catalog_name, :catalog_element
    
    def initialize( prop, catalog_name, catalog_element )
      super(prop)
      @catalog_name = catalog_name
      @catalog_element = catalog_element
    end
  end
  
  
  class QsarIdentifier 
    include DataMapper::Resource
    
    property :id, Serial
    property :qsar_title, Text 
    property :qsar_models, Text
    
    has n, :qsar_software
    
    def xml_infos
      [ TextNodeProperty.new(:qsar_title), 
        TextNodeProperty.new(:qsar_models), 
        CatalogReference.new(:qsar_software, "software_catalog", "software") ]
    end
    
    belongs_to :qmrf_report
  end
  
  class Author
    include DataMapper::Resource
    
    property :id, Serial
    property :affiliation, String, :length => 255
    property :contact, String, :length => 255
    property :email, String, :length => 255
    property :name, String, :length => 255
    property :number, String, :length => 255
    property :url, String, :length => 255
    
    def xml_infos
      [ AttributeProperty.new(:affiliation),
        AttributeProperty.new(:contact),
        AttributeProperty.new(:email),
        AttributeProperty.new(:name),
        AttributeProperty.new(:number),
        AttributeProperty.new(:url) ]
    end
  end  
  
  class QmrfAuthor < Author
    belongs_to :qsar_general_information
  end 
  
  class ModelAuthor < Author
    belongs_to :qsar_general_information
  end 
  
  class Publication
    include DataMapper::Resource
    
    property :id, Serial
    property :title, Text
    property :url, String, :length => 255
    
    def xml_infos
      [ AttributeProperty.new(:title),
        AttributeProperty.new(:url) ]
    end
  end
    
  class Reference < Publication
    #belongs_to :qsar_general_information
    property :qsar_general_information_id, Integer
  end 

  
  class QsarGeneralInformation
    include DataMapper::Resource
    
    property :id, Serial
    property :qmrf_date, Text #String, :length => 255 #PENDING -> datetime
    property :model_date, Text #String, :length => 255 #PENDING -> datetime 
    property :qmrf_date_revision, Text #String, :length => 255 #PENDING -> datetime
    property :qmrf_revision, Text
    property :model_date, Text
    property :info_availability, Text 
    property :related_models, Text
    
    has n, :qmrf_authors
    has n, :model_authors
    has n, :references
    
    def xml_infos
      [ TextNodeProperty.new(:qmrf_date), 
        CatalogReference.new(:qmrf_authors, "authors_catalog", "author"),
        TextNodeProperty.new(:qmrf_date_revision),
        TextNodeProperty.new(:qmrf_revision),
        CatalogReference.new(:model_authors, "authors_catalog", "author"),
        TextNodeProperty.new(:model_date),
        CatalogReference.new(:references, "publications_catalog", "publication"),
        TextNodeProperty.new(:info_availability),
        TextNodeProperty.new(:related_models) ]
    end
    
    belongs_to :qmrf_report
  end
  
  class ModelEndpoint
    include DataMapper::Resource
    
    property :id, Serial
    property :group, String, :length => 255
    property :name, String, :length => 255
    property :subgroup, String, :length => 255
    
    def xml_infos
      [ AttributeProperty.new(:group),
        AttributeProperty.new(:name),
        AttributeProperty.new(:subgroup)  ]
    end

    belongs_to :qsar_endpoint
  end
  
  class QsarEndpoint
    include DataMapper::Resource
    
    property :id, Serial
    property :endpoint_variable, Text
    property :model_species, Text
    property :endpoint_comments, Text
    property :endpoint_units, Text
    property :endpoint_protocol, Text
    property :endpoint_data_quality, Text
    
    has n, :model_endpoint
    
    def xml_infos
      [ TextNodeProperty.new(:model_species),
        CatalogReference.new(:model_endpoint, "endpoints_catalog", "endpoint"),
        TextNodeProperty.new(:endpoint_comments),
        TextNodeProperty.new(:endpoint_units),
        TextNodeProperty.new(:endpoint_variable), 
        TextNodeProperty.new(:endpoint_protocol),
        TextNodeProperty.new(:endpoint_data_quality) ]
    end
    
    belongs_to :qmrf_report
  end
  
  class AlgorithmExplicit
    include DataMapper::Resource
    
    property :id, Serial
    property :definition, Text
    property :description, Text
    property :publication_ref, Text
    
    def xml_infos
      [ AttributeProperty.new(:definition),
        AttributeProperty.new(:description),
        AttributeProperty.new(:publication_ref) ]
    end
    
    belongs_to :qsar_algorithm
  end
  
  class AlgorithmsDescriptor
    include DataMapper::Resource
    
    property :id, Serial
    property :description, Text
    property :name, Text
    property :publication_ref, Text
    property :units, Text
    
    def xml_infos
      [ AttributeProperty.new(:description),
        AttributeProperty.new(:name),
        AttributeProperty.new(:publication_ref),
        AttributeProperty.new(:units) ]
    end

    belongs_to :qsar_algorithm
  end  
  
  class DescriptorsGenerationSoftware < Software

    #belongs_to :qsar_algorithm, :key => false
    property :qsar_algorithm_id, Integer
  end 
  
  class QsarAlgorithm
    include DataMapper::Resource
    
    property :id, Serial
    
    property :algorithm_type, Text
    property :descriptors_selection, Text
    property :descriptors_generation, Text
    property :descriptors_chemicals_ratio, Text
    property :equation, Text
    
    has n, :algorithm_explicit
    has n, :algorithms_descriptors
    has n, :descriptors_generation_software
    
    def xml_infos
      [ TextNodeProperty.new(:algorithm_type), 
        CatalogReference.new(:algorithm_explicit, "algorithms_catalog", "algorithm"),
        TextSubnodeProperty.new(:equation, :algorithm_explicit),
        CatalogReference.new(:algorithms_descriptors, "descriptors_catalog", "descriptor"),
        TextNodeProperty.new(:descriptors_selection),
        TextNodeProperty.new(:descriptors_generation),
        CatalogReference.new(:descriptors_generation_software,  "software_catalog", "software"),
        TextNodeProperty.new(:descriptors_chemicals_ratio),
         ]
    end
    
    belongs_to :qmrf_report
  end
  
  class AppDomainSoftware < Software

    #belongs_to :qsar_algorithm, :key => false
    property :qsar_applicability_domain_id, Integer
  end   
  
  class QsarApplicabilityDomain
    include DataMapper::Resource
    
    property :id, Serial
    property :app_domain_description, Text
    property :app_domain_method, Text
    property :applicability_limits, Text
    
    has n,:app_domain_software 
      
    def xml_infos
      [ TextNodeProperty.new(:app_domain_description), 
        TextNodeProperty.new(:app_domain_method),
        CatalogReference.new(:app_domain_software,  "software_catalog", "software"),
        TextNodeProperty.new(:applicability_limits), ]
    end      
    
    belongs_to :qmrf_report
    
  end  
  
  class DatasetData
    include DataMapper::Resource
    
    property :id, Serial
    property :chemname, String, :default => "No" 
    property :cas, String, :default => "No"
    property :smiles, String, :default => "No"
    property :inchi, String, :default => "No"
    property :mol, String, :default => "No"
    property :formula, String, :default => "No"
    
    def xml_infos
      [ AttributeProperty.new(:chemname),
        AttributeProperty.new(:cas),
        AttributeProperty.new(:smiles),
        AttributeProperty.new(:inchi),
        AttributeProperty.new(:mol),
        AttributeProperty.new(:formula) ]
    end
  
  end

  class TrainingSetData < DatasetData
    
     #belongs_to :qsar_robustness
     property :qsar_robustness_id, Integer
  end

  
  class QsarRobustness
    include DataMapper::Resource
    
    property :id, Serial
    property :training_set_availability, String, :default => "No"
    property :training_set_descriptors, String, :default => "No"
    property :dependent_var_availability, String, :default => "No"
    property :other_info, Text
    property :preprocessing, Text
    property :goodness_of_fit, Text
    property :loo, Text
    property :lmo, Text
    property :yscrambling, Text
    property :bootstrap, Text
    property :other_statistics, Text
    
    has 1, :training_set_data
    
    def xml_infos
      [ AttributeNodeProperty.new(:training_set_availability, "answer"),
        MultiAttributeNodeProperty.new(:training_set_data),
        AttributeNodeProperty.new(:training_set_descriptors, "answer"),
        AttributeNodeProperty.new(:dependent_var_availability, "answer"),
        TextNodeProperty.new(:other_info),
        TextNodeProperty.new(:preprocessing),
        TextNodeProperty.new(:goodness_of_fit),
        TextNodeProperty.new(:loo),
        TextNodeProperty.new(:lmo),
        TextNodeProperty.new(:yscrambling),
        TextNodeProperty.new(:bootstrap),
        TextNodeProperty.new(:other_statistics),
        ]
    end
    
    belongs_to :qmrf_report
    
  end  
  
  
  class ValidationSetData < DatasetData
    
     #belongs_to :qsar_predictivity
     property :qsar_predictivity_id, Integer
  end
  
  class QsarPredictivity
    include DataMapper::Resource
    
    property :id, Serial
    
    property :validation_set_availability, String, :default => "No"
    property :validation_set_descriptors, String, :default => "No"
    property :validation_dependent_var_availability, String, :default => "No"
    property :validation_other_info, Text
    property :experimental_design, Text
    property :validation_predictivity, Text
    property :validation_assessment, Text
    property :validation_comments, Text
    
    has 1, :validation_set_data
    
    def xml_infos
      [ AttributeNodeProperty.new(:validation_set_availability, "answer"),
        MultiAttributeNodeProperty.new(:validation_set_data),
        AttributeNodeProperty.new(:validation_set_descriptors, "answer"),
        AttributeNodeProperty.new(:validation_dependent_var_availability, "answer"),
        TextNodeProperty.new(:validation_other_info),
        TextNodeProperty.new(:experimental_design),
        TextNodeProperty.new(:validation_predictivity),
        TextNodeProperty.new(:validation_assessment),
        TextNodeProperty.new(:validation_comments),
        ]
    end
    
    belongs_to :qmrf_report
  end    
    
  class QsarInterpretation
    include DataMapper::Resource
    
    property :id, Serial
    property :mechanistic_basis, Text
    property :mechanistic_basis_comments, Text
    property :mechanistic_basis_info, Text
    
    def xml_infos
      [ TextNodeProperty.new(:mechanistic_basis),
        TextNodeProperty.new(:mechanistic_basis_comments),
        TextNodeProperty.new(:mechanistic_basis_info),
        ]
    end
    
    belongs_to :qmrf_report
  end
  
  class Bibliography < Publication
    
    #belongs_to :qsar_miscelaneous
    property :qsar_miscelaneous_id, Integer
  end 

  class QsarMiscelaneous
    include DataMapper::Resource
    
    property :id, Serial
    property :comments, Text
    property :attachment_training_data, Text
    property :attachment_validation_data, Text
    property :attachment_documents, Text
    
    has n, :bibliography, Text
    
    def xml_infos
      [ TextNodeProperty.new(:comments),
        CatalogReference.new(:bibliography,"publications_catalog", "publication"),
        TextSubnodeProperty.new(:attachment_training_data, :attachments),
        TextSubnodeProperty.new(:attachment_validation_data, :attachments),
        TextSubnodeProperty.new(:attachment_documents, :attachments),
        ]
    end
    
    belongs_to :qmrf_report
  end  
  
  class QmrfSummary
    include DataMapper::Resource
    
    property :id, Serial
    property :qmrf_number, Text
    property :date_publication, Text
    property :keywords, Text
    property :summary_comments, Text
    
    def xml_infos
      [ TextNodeProperty.new(:qmrf_number),
        TextNodeProperty.new(:date_publication),
        TextNodeProperty.new(:keywords),
        TextNodeProperty.new(:summary_comments),
        ]
    end
    
    belongs_to :qmrf_report
  end  
  
  class QmrfReport
    include DataMapper::Resource, REXML
    
    property :id, Serial
    property :model_uri, String, :length => 255
    
    CHAPTERS = [ :qsar_identifier, :qsar_general_information, :qsar_endpoint, :qsar_algorithm, 
                 :qsar_applicability_domain, :qsar_robustness, :qsar_predictivity, :qsar_interpretation, 
                 :qsar_miscelaneous, :qmrf_summary ]
               
    CHAPTERS.each{ |c,clazz| has 1, c }
    
    def to_yaml
      super(:methods => CHAPTERS)
    end
    
    def report_uri
      return $sinatra.url_for("/QMRF/"+@id.to_s, :full).to_s
    end
    
    def self.from_xml(report, xml_data)
      
      # DEBUG: REMOVE THIS
      #xml_data = File.new("qmrf-report.xml").read
      #puts xml_data
      # DEBUG: REMOVE THIS
      
      doc = Document.new xml_data
      
      root = doc.elements["QMRF"]
      raise "no QMRF node found" unless root
      chapters = root.elements["QMRF_chapters"]
      raise "no chapter node found" unless chapters
      $catalogs_node = root.elements["Catalogs"]
      raise "catalogs not found" unless $catalogs_node
      
      CHAPTERS.each do |p| #, chapterClass|
        #unless report.send(p)
          report.send(p).destroy if report.send(p)
          c = report.association_class(p).new #chapterClass.new
          #c.save
          report.send(p.to_s+"=",c)
        #end
        report.send(p).from_xml( chapters.elements[p.xml_alias] )
      end
      
      #raise "already exists" if report.qsar_identifier
      #report.qsar_general_information.destroy if report.qsar_general_information
      #report.qsar_identifier.clear
      #report.qsar_general_information = QsarGeneralInformation.new
      #report.qsar_general_information.qmrf_date = "DateTime.now"
      #report.qsar_general_information.model_authors << ModelAuthor.new
      #report.qsar_general_information.qmrf_authors << QmrfAuthor.new
      
      #report.qsar_identifier = QsarIdentifier.new unless report.qsar_identifier
      #report.qsar_identifier.from_xml( chapters.elements[:qsar_identifier.xml_alias] )
      
      #report.qsar_general_information = QsarGeneralInformation.new unless report.qsar_general_information
      #report.qsar_general_information.from_xml( chapters.elements[:qsar_general_information.xml_alias] )
      
      
      #QsarGeneralInformation.from_xml( report.qsar_general_information, chapters.elements["qsar_general_information".xml_alias] )
      
      #puts "set qsar_identifier to "+report.qsar_identifier.class.to_s
      
#      begin
        report.save
#      rescue DataObjects::SQLError => e
#        puts e.message
#        exit
#      rescue DataObjects::DataError => e
#        puts e.message
#        exit
#      rescue DataMapper::SaveFailureError => e
#        puts e.resource.errors.inspect
#        exit
#      end
    end
    
    def to_xml
      #puts "now qsar_identifier is "+self.qsar_identifier.class.to_s
      
      doc = Document.new
      decl = XMLDecl.new
      decl.encoding = "UTF-8"
      doc << decl
      type = DocType.new('QMRF SYSTEM "http://ambit.sourceforge.net/qmrf/jws/qmrf.dtd"')
      doc << type
      
      root = Element.new("QMRF")
      root.add_attributes( "version" => 1.2, "schema_version" => 1.0, "name" => "(Q)SAR Model Reporting Format", 
        "author" => "Joint Research Centre, European Commission", "contact" => "Joint Research Centre, European Commission",
        "date" => "July 2007", "email" => "qsardb@jrc.it", "url" => "http://ecb.jrc.ec.europa.eu/qsar/" )
      
      catalogs = Element.new("Catalogs")
      [ "software_catalog", "algorithms_catalog", "descriptors_catalog", 
        "endpoints_catalog", "publications_catalog", "authors_catalog"].each do |c|
        catalogs << Element.new(c)
      end
      $catalogs_node = catalogs
      
      chapters = Element.new("QMRF_chapters")
      chapter_count = 1
      
      CHAPTERS.each do |p|
        node = Element.new( p.xml_alias )
        node.add_attribute("chapter",chapter_count)
        self.send(p.to_s+"=", self.association_class(p).new) unless self.send(p) # create empy chapter, as xml must be complete
        self.send(p).to_XML( node, chapter_count )
        chapters << node
        chapter_count += 1
      end
      
#      qsar_identifier_node = Element.new(:qsar_identifier.xml_alias)
#      self.qsar_identifier.to_XML( qsar_identifier_node )
#      chapters << qsar_identifier_node
#      
#      qsar_general_information_node = Element.new(:qsar_general_information.xml_alias)
#      self.qsar_general_information.to_XML( qsar_general_information_node )
#      chapters << qsar_general_information_node
      
      
      
#      [ @qsar_identifier, @qsar_general_information, @qsar_endpoint ].each do |c|
#        n = c.to_xml
#        raise "no node "+n.to_s+" "+n.class.to_s unless n.is_a?(Element)
#        chapters << n
#      end
  
      root << chapters
      root << catalogs
      doc << root
      
      s = ""
      doc.write(s, 2, false, false)
      return s      
      
    end
  end  

#Profile2.auto_upgrade!
  
#  class QmrfReport < ActiveRecord::Base
#  
#    alias_attribute :date, :created_at
#    
#    QmrfProperties.serialized_properties.each do |p|
#      serialize p
#    end
#    
#    def type
#      "QMRF"
#    end
#    
#    def report_uri
#      ReachReports.get_uri(self)
#    end
#    
#    def get_content
#      hash = {}
#      [ :model_uri, :date ].each{ |p| hash[p] = self.send(p) }
#      QmrfProperties.properties.each{ |p| hash[p] = self.send(p) }
#      return hash
#    end
#  end
#  
#
#  class QprfReport < ActiveRecord::Base
#    
#    alias_attribute :date, :created_at
#
#    def report_uri
#      ReachReports.get_uri(self)
#    end
#
#    def type
#      "QPRF"
#    end
#  end

  QsarSoftware.auto_upgrade!  
  QsarIdentifier.auto_upgrade!
  
  QmrfAuthor.auto_upgrade!
  ModelAuthor.auto_upgrade!
  Reference.auto_upgrade!
  QsarGeneralInformation.auto_upgrade!
  
  ModelEndpoint.auto_upgrade!
  QsarEndpoint.auto_upgrade!
  
  AlgorithmExplicit.auto_upgrade!
  AlgorithmsDescriptor.auto_upgrade!
  DescriptorsGenerationSoftware.auto_upgrade!
  QsarAlgorithm.auto_upgrade!
  
  AppDomainSoftware.auto_upgrade!
  QsarApplicabilityDomain.auto_upgrade!
  
  TrainingSetData.auto_upgrade!
  QsarRobustness.auto_upgrade!
  
  ValidationSetData.auto_upgrade!
  QsarPredictivity.auto_upgrade!
  
  QsarInterpretation.auto_upgrade!
  
  Bibliography.auto_upgrade!
  QsarMiscelaneous.auto_upgrade!
  
  QmrfSummary.auto_upgrade!
  
  QmrfReport.auto_upgrade!
  
end