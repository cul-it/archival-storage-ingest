# frozen_string_literal: true

require 'archival_storage_ingest/ingest_utils/ingest_utils'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_of_manifests'
require 'archival_storage_ingest/manifests/manifest_merger'
require 'archival_storage_ingest/manifests/deploy_collection_manifest'
require 'fileutils'
require 'find'
require 'json'
require 'zip'

module Manifests
  # collection manifest is old term for storage manifest
  # in the future, we may refactor reference to collection manifest to storage manifest
  def self.resolve_storage_manifest_name(depositor:, collection:)
    depositor = depositor.gsub('/', '_') if depositor.start_with?('RMC')

    "_EM_#{depositor}_#{collection}.json"
  end

  class M2MCollectionManifestDeployer < CollectionManifestDeployer
    def initialize(manifests_path:, s3_manager:, file_identifier:, sfs_prefix:, manifest_validator: nil)
      super(manifests_path:, s3_manager:, file_identifier:,
            sfs_prefix:, manifest_validator:)
    end

    # def m2m_deploy_collection_manifest(m2m_manifest_parameters:)
    #   # This step will update the storage manifest object and file pointed by the manifest parameter.
    #   prepare_collection_manifest(manifest_parameters: m2m_manifest_parameters)
    #   deploy_collection_manifest(manifest_def: manifest_definition,
    #                              collection_manifest: m2m_manifest_parameters.storage_manifest_path)
    # end

    def generate_populate_date(date:)
      yester_month = date.month.strftime('%m')
      yester_day = date.month.strftime('%d')
      "#{date.year}#{yester_month}#{yester_day}"
    end
  end

  # storage_manifest_path:, ingest_manifest_path:, sfs: nil, ingest_date: nil, skip_data_addition: false
  # s3_manager, depositor, collection, local_manifest_store, populate_date
  class M2MManifestParameters < ManifestParameters
    attr_reader :s3_manager, :depositor, :collection, :local_manifest_store, :populate_date

    def initialize(named_params)
      super(named_params)
      @s3_manager = named_params.fetch(:s3_manager)
      @depositor = named_params.fetch(:depositor)
      @collection = named_params.fetch(:collection)
      @local_manifest_store = named_params.fetch(:local_manifest_store)
      @populate_date = named_params.fetch(:populate_date)
    end

    # resolve_ingest_manifest_path should point to ingest_manifest_store set in M2MManifestHandler
    # file id should already have been populated
    def resolve_ingest_manifest(source:)
      manifest_merger = Manifests::M2MManifestMerger.new
      manifest_merger.merge_all_ingest_manifests(ingest_manifest_store: source)
    end
  end

  class M2MManifestBackupHandler
    attr_reader :s3_manager, :local_manifest_store, :storage_manifest_store, :ingest_manifest_store,
                :backup_store, :m2m_s3_helper, :storage_manifest_path, :ingest_manifest_path

    def initialize(s3_manager:, local_manifest_store:)
      @s3_manager = s3_manager
      @m2m_s3_helper = M2MS3Helper.new(s3_manager:)
      @local_manifest_store = local_manifest_store
      @storage_manifest_store = "#{local_manifest_store}/storage_manifest"
      @ingest_manifest_store = "#{local_manifest_store}/ingest_manifest"
      @backup_store = "#{local_manifest_store}/backup"
    end

    def backup_manifests(depositor:, collection:, populate_date:)
      local_cleanup(depositor:, collection:, populate_date:)

      @storage_manifest_path = download_storage_manifest(depositor:, collection:)
      @ingest_manifest_path, ims = m2m_s3_helper.download_ingest_manifests(depositor:, collection:,
                                                                           dest_root: ingest_manifest_store,
                                                                           populate_date:)
      return false unless ims.any?

      zip_and_upload(depositor:, collection:, storage_manifest_path:)

      cleanup(depositor:, collection:, populate_date:)
      true
    end

    def download_storage_manifest(depositor:, collection:)
      manifest_name = "_EM_#{depositor}_#{collection}.json"
      s3_key = "#{depositor}/#{collection}/#{manifest_name}"
      dest_path = "#{storage_manifest_store}/#{depositor}/#{collection}/#{manifest_name}"
      s3_manager.download_file(s3_key:, dest_path:)

      dest_path
    end

    def download_ingest_manifests(depositor:, collection:, populate_date:)
      m2m_s3_helper.download_ingest_manifests(depositor:, collection:,
                                              dest_root: ingest_manifest_store,
                                              populate_date:)
    end

    def zip_and_upload(depositor:, collection:, storage_manifest_path:)
      now = Date.today
      month = now.strftime('%m')
      day = now.strftime('%d')
      zip_path = "#{backup_store}/#{depositor}_#{collection}_#{now.year}#{month}#{day}.zip"
      ingest_manifest_loc = "#{ingest_manifest_store}/#{depositor}/#{collection}"
      zip_manifests(zip_path:, storage_manifest_path:,
                    ingest_manifest_loc:)
      s3_key = ".m2m/manifest_backup/#{File.basename(zip_path)}"
      s3_manager.upload_file(s3_key, zip_path)
    end

    def zip_manifests(zip_path:, storage_manifest_path:, ingest_manifest_loc:)
      Zip::File.open(zip_path, create: true) do |zip_file|
        zip_file.add(File.basename(storage_manifest_path), storage_manifest_path)
        Dir[ingest_manifest_loc].each do |ingest_manifest_path|
          zip_file.add(File.basename(ingest_manifest_path), ingest_manifest_path)
        end
      end

      zip_path
    end

    def cleanup(depositor:, collection:, populate_date:)
      s3_cleanup(depositor:, collection:, populate_date:)
      local_cleanup(depositor:, collection:, populate_date:)
    end

    def local_cleanup(depositor:, collection:, populate_date:)
      FileUtils.rm_f Dir["#{storage_manifest_store}/#{depositor}/#{collection}/*"]
      FileUtils.rm_f Dir["#{ingest_manifest_store}/#{depositor}/#{collection}/#{populate_date}/*"]
      FileUtils.rm_f Dir["#{backup_store}/#{depositor}/#{collection}/*"]
    end

    def s3_cleanup(depositor:, collection:, populate_date:)
      m2m_s3_helper.delete_ingest_manifests(ingest_manifest_store:,
                                            depositor:, collection:,
                                            populate_date:)
    end
  end

  class M2MS3Helper
    attr_reader :s3_manager

    INGEST_MANIFEST_PREFIX = '.m2m/ingest_manifest'

    def initialize(s3_manager:)
      @s3_manager = s3_manager
    end

    def download_storage_manifest(depositor:, collection:)
      manifest_name = resolve_storage_manifest_name(depositor:, collection:)
      s3_key = "#{depositor}/#{collection}/#{manifest_name}"
      dest_path = "#{storage_manifest_store}/#{depositor}/#{collection}/#{manifest_name}"
      s3_manager.download_file(s3_key:, dest_path:)

      dest_path
    end

    def download_ingest_manifests(depositor:, collection:, dest_root:, populate_date:)
      ims = s3_manager.list_object_keys("#{INGEST_MANIFEST_PREFIX}/#{depositor}/#{collection}/#{populate_date}/")
      this_dest_root = File.join(dest_root, depositor, collection, populate_date)
      FileUtils.mkdir_p(this_dest_root)
      downloaded = []
      ims.each do |s3_key|
        dest_path = "#{this_dest_root}/#{File.basename(s3_key)}"
        s3_manager.download_file(s3_key:, dest_path:)
        downloaded << dest_path
      end

      [this_dest_root, downloaded]
    end

    def delete_ingest_manifests(ingest_manifest_store:, depositor:, collection:, populate_date:)
      s3_keys = Dir["#{ingest_manifest_store}/#{depositor}/#{collection}/#{populate_date}/"].map do |key|
        "#{INGEST_MANIFEST_PREFIX}/#{IngestUtils.relative_path(key, ingest_manifest_store)}"
      end
      s3_manager.delete_objects(s3_keys:)
    end
  end
end
