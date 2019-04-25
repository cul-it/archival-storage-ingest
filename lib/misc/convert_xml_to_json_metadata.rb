# frozen_string_literal: true

require 'json'
require 'nokogiri'

module ConvertXmlToJsonMetadata
  IPP_DEPOSITOR_COLLECTION = 'RMC/RMA/RMA03487_Cornell_University_Facilities_Construction_Records'
  IPP_PHYSICAL_COLLECTION_ID = 'RMA02471'
  IPP_STEWARD = 'eef46'
  class ConvertXmlToJsonMetadata
    def convert_xml_to_json_metadata(xml)
      json_data = generate_skeleton_json_data
      walk_xml(xml) do |node|
        add_to_json_data(json_data[IPP_DEPOSITOR_COLLECTION]['items'], node)
      end
      JSON.pretty_generate(json_data)
    end

    def add_to_json_data(items, node)
      item = locate_item(items, node)
      item['size'] = node.at_css('filesize').content.to_s.to_i
      node.css('hashdigest').each do |hashdigest|
        item[hashdigest['type'].downcase] = hashdigest.content
      end
    end

    def walk_xml(xml)
      doc = File.open(xml) { |f| Nokogiri::XML(f) }
      doc.css('dfxml fileobject').each do |node|
        yield(node)
      end
    end

    def generate_skeleton_json_data
      {
        IPP_DEPOSITOR_COLLECTION => {
          'phys_coll_id' => IPP_PHYSICAL_COLLECTION_ID,
          'steward' => IPP_STEWARD,
          'items' => {}
        }
      }
    end

    def locate_item(items, node)
      paths = break_path(node.at_css('filename').content)

      current_position = items
      paths.each do |dir|
        current_position[dir] = {} unless current_position[dir]

        current_position = current_position[dir]
      end

      current_position
    end

    def break_path(path)
      path = path[1..-1] if path[0] == '\\'

      paths = path.split('\\')
      paths
    end

    def add_checksum(item, hash_type, hash_data)
      item[hash_type.downcase] = hash_data
    end
  end
end
