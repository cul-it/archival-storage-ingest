# frozen_string_literal: true

module M2MWorker
  class BasePackageHandler
    attr_reader :ingest_root, :sfs_root, :queuer, :file_identifier, :manifest_validator

    def initialize(ingest_root:, sfs_root:, queuer:, file_identifier:, manifest_validator:)
      @ingest_root = ingest_root
      @sfs_root = sfs_root
      @queuer = queuer
      @file_identifier = file_identifier
      @manifest_validator = manifest_validator
    end

    def queue_ingest(msg:, path:)
      im = ingest_manifest(msg:, path:)
      im_path = create_ingest_manifest_file(msg:, manifest: im)
      cm = collection_manifest(msg:) # filename or none

      env_initializer = Preingest::IngestEnvInitializer.new(ingest_root:, sfs_root:,
                                                            manifest_validator:,
                                                            file_identifier:)
      env_initializer.initialize_ingest_env(cmf: cm, imf: im_path, sfs_location: sfs_root, ticket_id: 'NO_REPORT',
                                            data: path, depositor: im.depositor, collection_id: im.collection_id)

      ic = ingest_config(env_initializer:, msg:)
      queuer.queue_ingest(ic)
    end

    def ingest_config(env_initializer:, msg:)
      ingest_config = YAML.load_file(env_initializer.config_path)
      msg.dest_path = ingest_config[:dest_path]
      msg.ingest_manifest = ingest_config[:ingest_manifest]
      ingest_config
    end

    def ingest_manifest(_msg:, _path:); end

    def package_id(path:); end

    def bibid(path:); end

    def local_id(path:); end

    def base_ingest_manifest(msg:)
      base_hash = {
        depositor: msg.depositor, collection_id: msg.collection,
        steward: msg.steward, documentation: 'ignore_me'
      }
      Manifests::Manifest.new(json_text: base_hash.to_json.to_s)
    end

    def create_ingest_manifest_file(msg:, manifest:)
      manifest_path = File.join(ingest_root, msg.package)
      FileUtils.mkdir(manifest_path)
      manifest_file = File.join(manifest_path, 'ingest_manifest.json')
      json_to_store = JSON.pretty_generate(manifest.to_json_ingest_hash).to_s
      File.write(manifest_file, json_to_store)
      manifest_file
    end

    # :filepath, :sha1, :md5, :size, :ingest_date
    # do we get sha1, size from ecommons metadata?
    def populate_files(path:)
      files = list_files(path:)
      files.map do |file|
        Manifests::FileEntry.new(file: { filepath: IngestUtils.relative_path(file, path) })
      end
    end

    def list_files(path:)
      paths = []
      Find.find(path) do |p|
        paths << p if FileTest.file?(p)
      end
      paths
    end

    # The lambda function will fill in correct depositor/collection information depending on which s3 bucket
    # the package originated from.
    def collection_manifest(msg:)
      cm = File.join(sfs_root, msg.depositor, msg.collection,
                     "_EM_#{msg.depositor}_#{msg.collection}.json")
      File.exist?(cm) ? cm : 'none'
    end
  end
end
