# frozen_string_literal: true

require 'json'

module MergeManifest
  DEPO_COLL = 'RMC/RMA/RMA03487_Cornell_University_Facilities_Construction_Records'
  NUMBER_FILES = 'number_files'
  ITEMS = 'items'

  class MergeManifest
    def merge_manifest(ingest_manifest, collection_manifest)
      im = parse_json(ingest_manifest)
      im_items = im[DEPO_COLL][ITEMS]
      cm = parse_json(collection_manifest)
      cm_items = cm[DEPO_COLL][ITEMS]

      merge(im_items, cm_items)
      update_item_count(cm)
      JSON.pretty_generate(cm)
    end

    def merge(im_obj, cm_obj)
      im_obj.each_key do |im_key|
        if cm_obj[im_key]
          handle_collision(im_key, im_obj, cm_obj)
        else
          cm_obj[im_key] = im_obj[im_key]
        end
      end
    end

    def handle_collision(im_key, im_obj, cm_obj)
      if dir?(im_obj[im_key])
        merge(im_obj[im_key], cm_obj[im_key])
      else
        cm_obj[im_key] = im_obj[im_key]
        puts "#{im_key} is duplicate file!"
      end
    end

    def update_item_count(collection_manifest)
      item_count = count_items(collection_manifest[DEPO_COLL][ITEMS])
      collection_manifest[DEPO_COLL][NUMBER_FILES] = item_count
    end

    def count_items(cm_items)
      count = 0
      cm_items.each_key do |key|
        count += dir?(cm_items[key]) ? count_items(cm_items[key]) : 1
      end
      count
    end

    def dir?(obj)
      obj['sha1'].nil?
    end

    def parse_json(json)
      contents = File.read(json)
      JSON.parse(contents)
    end
  end
end
