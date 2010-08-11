
module ReachReports
  
  class QmrfProperties

    private
    PROPS = {
      "QSAR_title" => "1.1", "QSAR_models" => "1.2", "QSAR_software" => "1.3",
      "QMRF_date" => "2.1", "QMRF_authors" => "2.2", "QMRF_date_revision" => "2.3", "QMRF_revision" => "2.4", 
      "model_authors" => "2.5", "model_date" => "2.6", "references" => "2.7", "info_availability" => "2.8", 
      "related_models" => "2.9",
      "model_species" => "3.1", "model_endpoint" => "3.2", "endpoint_comments" => "3.3", "endpoint_units" => "3.4",
      "endpoint_variable" => "3.5", "endpoint_protocol" => "3.6", "endpoint_data_quality" => "3.7",
      "algorithm_type" => "4.1", "algorithm_explicit" => "4.2", "algorithms_descriptors" => "4.3", 
      "descriptors_selection" => "4.4", "descriptors_generation" => "4.5", "descriptors_generation_software" => "4.6",
      "descriptors_chemicals_ratio" => "4.7", 
      "app_domain_description" => "5.1", "app_domain_method" => "5.2", "app_domain_software" => "5.3",
      "applicability_limits" => "5.4",
      "training_set_availability" => "6.1", "training_set_data" => "6.2","training_set_descriptors" => "6.3", 
      "dependent_var_availability" => "6.4", "other_info" => "6.5", "preprocessing" => "6.6", "goodness_of_fit" => "6.7", 
      "loo" => "6.8", "lmo" => "6.9", "yscrambling" => "6.10", "bootstrap" => "6.11", "other_statistics" => "6.12", 
      "validation_set_availability" => "7.1", "validation_set_data" => "7.2", "validation_set_descriptors" => "7.3", 
      "validation_dependent_var_availability" => "7.4", "validation_other_info" => "7.5", "experimental_design" => "7.6", 
      "validation_predictivity" => "7.7", "validation_assessment" => "7.8", "validation_comments" => "7.9", 
      "mechanistic_basis" => "8.1", "mechanistic_basis_comments" => "8.2", "mechanistic_basis_info" => "8.3",
      "comments" => "9.1", "bibliography" => "9.2", "attachments" => "9.3",
      "QMRF_number" => "10.1", "date_publication" => "10.2", "keywords" => "10.3", "summary_comments" => "10.4", 
      }
      
    CHAPTER = { 
      "QSAR_identifier" => 1, 
      "QSAR_General_information" => 2, 
      "QSAR_Endpoint" => 3,
      "QSAR_Algorithm" => 4,
      "QSAR_Applicability_domain" => 5,
      "QSAR_Robustness" => 6,
      "QSAR_Predictivity" => 7,
      "QSAR_Interpretation" => 8,
      "QSAR_Miscelaneous" => 9,
      "QMRF_Summary" => 10 }
    
    CATALOGS = {
      "software_catalog" =>
        { :element => "software",
          :fields => ["contact", "description", "name", "number", "url"] },
      "authors_catalog" => {
        :element => "author",
        :fields => ["affiliation", "contact", "email", "name", "number", "url"]},
      "algorithms_catalog" => {
        :element => "algorithm",
        :fields => ["definition", "description", "publication_ref"] },
      "descriptors_catalog" => {
        :element => "descriptor",
        :fields => [ "description", "name", "publication_ref", "units"] },
      "endpoints_catalog" => {
        :element => "endpoint",
        :fields => [ "group", "name", "subgroup" ]},
      "publications_catalog" => {
        :element => "publication",
        :fields => [ "title", "url"]},  
      }
    
    CATALOG_REFERENCES = {
      "QSAR_software" => "software_catalog",
      "references" => "publications_catalog",
      "QMRF_authors" => "authors_catalog", 
      "algorithm_explicit" => "algorithms_catalog",
      "descriptors_generation_software" => "descriptors_catalog",
      "model_endpoint" => "endpoints_catalog",
      "bibliography" => "publications_catalog",
      }
      
    SUBSUBSECTIONS = {
      "algorithm_explicit" => [ "equation" ]
    }
        
    #"attachment_training_data", "attachment_validation_data, "attachment_documents", 

    public
    def self.serialized_properties
      return CATALOG_REFERENCES.keys | SUBSUBSECTIONS.keys
    end

    def self.properties
      return PROPS.keys
    end
    
    def self.chapter_number( chapter )
      CHAPTER[chapter]
    end
  
    def self.chapter_properties( chapter )
      chapter_number = CHAPTER[chapter]
      unsorted_chapter_props = []
      PROPS.each do |k,v|
        chapter_nr = v.split(".")[0].to_i
        next unless chapter_number == chapter_nr
        unsorted_chapter_props << [ k, v.split(".")[1].to_i ]
      end
      unsorted_chapter_props.sort{|a,b| a[1]<=>b[1]}.collect{ |a| a[0] } 
    end
    
    def self.chapters()
      #h = { "a" => 20, "b" => 30, "c" => 10  }
      # h.sort {|a,b| a[1]<=>b[1]}   #=> [["c", 10], ["a", 20], ["b", 30]]
      CHAPTER.sort{|a,b| a[1]<=>b[1]}.collect{ |a| a[0] } 
    end
    
    def self.to_xml(property, content, catalogs_node)
      node = REXML::Element.new(property)
      node.add_attribute "chapter",PROPS[property]
      
      return node unless content
      
      unless serialized_properties.include?(property)
        node.text = content
      else
        if content[:text]
          node.text = content.text
        end
        if SUBSUBSECTIONS.has_key?(property)
          SUBSUBSECTIONS[property].each do |p|
            subsubsection_node = REXML::Element.new(p)
            subsubsection_node.text = content[p]
            node << subsubsection_node
          end
        end
        if CATALOG_REFERENCES.has_key?(property) and content[CATALOG_REFERENCES[property]]
          catalog_prop = CATALOG_REFERENCES[property]
          catalog_content = content[catalog_prop]
          catalog_attributes = CATALOGS[catalog_prop]
          catalog_node = REXML::Element.new(catalog_prop)
          
          catalog_content.each do |element|
            ref_node = REXML::Element.new(catalog_attributes[:element]+"_ref")
            id = catalog_attributes[:element]+"_"+(catalog_content.index(element)+1).to_s
            ref_node.add_attribute "idref",id
            ref_node.add_attribute "catalog",catalog_prop
            node << ref_node
            element_node = REXML::Element.new(catalog_attributes[:element])
            element_node.add_attribute "id",id
            catalog_attributes[:fields].each do |k|
              element_node.add_attribute k,element[k.to_sym]
            end
            catalog_node << element_node
          end
          catalogs_node << catalog_node
        end
      end
      
      node
    end
  end

end



