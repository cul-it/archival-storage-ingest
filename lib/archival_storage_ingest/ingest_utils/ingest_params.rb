# frozen_string_literal: true

require 'inifile'
require 'archival_storage_ingest/preingest/base_env_initializer'

module IngestUtils
  class IngestParams
    attr_reader :depositor, :collection, :sfsbucket, :ticketid, :ingest_manifest,
                :asset_source, :doc_source, :existing_storage_manifest

    SOURCE_NOT_APPLICABLE = 'NA'
    NO_COLLECTION_MANIFEST = 'none'

    def initialize(config_file)
      config = IniFile.load(config_file)
      cularingest_section = config['cularingest']
      @depositor = cularingest_section['depositor']
      @collection = cularingest_section['collection']
      @sfsbucket = cularingest_section['sfsbucket']
      @ticketid = cularingest_section['ticketid']
      @ingest_manifest = cularingest_section['ingest_manifest']
      @asset_source = cularingest_section['asset_source']
      @doc_source = cularingest_section['doc_source'] || SOURCE_NOT_APPLICABLE
      @existing_storage_manifest = cularingest_section['existing_storage_manifest'] || NO_COLLECTION_MANIFEST
    end

    def process_asset?
      @asset_source != SOURCE_NOT_APPLICABLE
    end

    def process_doc?
      @doc_source != SOURCE_NOT_APPLICABLE
    end

    def new_collection?
      @existing_storage_manifest == NO_COLLECTION_MANIFEST
    end
  end

  # Soon to be obsolete
  class PeriodicFixityParams
    attr_reader :sfsbucket, :ticketid, :storage_manifest, :relay_queue_name, :ingest_manifest

    def initialize(storage_manifest:, sfsbucket:, ticketid:, relay_queue_name:)
      @sfsbucket = sfsbucket
      @ticketid = ticketid
      @storage_manifest = storage_manifest
      @relay_queue_name = relay_queue_name
      @ingest_manifest = storage_manifest # alias
    end
  end
end
