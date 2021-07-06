# frozen_string_literal: true

require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/preingest/base_env_initializer'
require 'archival_storage_ingest/preingest/ingest_env_initializer'
require 'archival_storage_ingest/work_queuer/work_queuer'
require 'archival_storage_ingest/workers/worker'
require 'fileutils'
require 'find'
require 'json'
require 'pathname'
require 'zip'

class M2MInitiateWorker < Workers::Worker # rubocop:disable Metrics/ClassLength
  attr_reader :s3_manager, :package_zip_dir, :package_extract_dir,
              :ingest_root, :sfs_root, :queuer

  def initialize(named_params)
    super(_name)
    @s3_manager = named_params.fetch(:s3_manager) { ArchivalStorageIngest.configuration.s3_manager }
    @package_zip_dir = named_params.fetch(:package_zip_dir)
    @package_extract_dir = named_params.fetch(:package_extract_dir)
    @ingest_root = named_params.fetch(:ingest_root)
    @sfs_root = named_params.fetch(:sfs_root)
    @queuer = named_params.fetch(:queuer, WorkQueuer::M2MIngestQueuer.new(confirm: false))
  end

  def _name
    'M2M Ingest Initiator'
  end

  def work(msg)
    path = prepare_package(msg: msg)
    if validate_msg(_msg: msg, _path: path)
      queue_ingest(msg: msg, path: path)
    else
      report_error(_msg: msg)
    end

    true
  end

  def prepare_package(msg:)
    zip_dest_path = File.join(package_zip_dir, msg.package)
    s3_manager.download_m2m_file(s3_key: msg.package, dest_path: zip_dest_path)
    extract_dest_path = File.join(package_extract_dir, msg.package, msg.depositor, msg.collection)
    FileUtils.mkdir_p(extract_dest_path)
    extract_package(zip_dest_path: zip_dest_path, extract_dest_path: extract_dest_path)
    extract_dest_path
  end

  def extract_package(zip_dest_path:, extract_dest_path:)
    Zip::File.open(zip_dest_path) do |zip_file|
      zip_file.each do |f|
        f_path = File.join(extract_dest_path, f.name)
        FileUtils.mkdir_p(File.dirname(f_path))
        zip_file.extract(f, f_path) unless File.exist?(f_path)
      end
    end
  end

  def validate_msg(_msg:, _path:)
    true
  end

  def report_error(_msg:); end

  def queue_ingest(msg:, path:)
    im = ingest_manifest(msg: msg, path: path)
    im_path = create_ingest_manifest_file(msg: msg, manifest: im)
    cm = collection_manifest(msg: msg) # filename or none

    env_initializer = Preingest::IngestEnvInitializer.new(ingest_root: ingest_root, sfs_root: sfs_root)
    env_initializer.initialize_ingest_env(data: path, cmf: cm, imf: im_path,
                                          sfs_location: sfs_root, ticket_id: 'NO_REPORT',
                                          depositor: im.depositor, collection_id: im.collection_id)

    ic = ingest_config(env_initializer: env_initializer, msg: msg)
    queuer.queue_ingest(ic)
  end

  def ingest_config(env_initializer:, msg:)
    ingest_config = YAML.load_file(env_initializer.config_path)
    msg.dest_path = ingest_config[:dest_path]
    msg.ingest_manifest = ingest_config[:ingest_manifest]
    ingest_config
  end

  # :package_id, :source_path, :bibid, :local_id, :number_files, :files
  def ingest_manifest(msg:, path:)
    manifest = base_ingest_manifest(msg: msg)
    package_args = { package_id: '?', source_path: '?', bibid: '?', local_id: '?', files: [] }
    package = Manifests::Package.new(package: package_args)
    populate_files(path: path).each do |file|
      package.add_file(file: file)
    end
    manifest.add_package(package: package)
    manifest
  end

  def base_ingest_manifest(msg:)
    base_hash = {
      depositor: msg.depositor, collection_id: msg.collection,
      steward: '?', documentation: '?',
      locations: ['?']
    }
    Manifests::Manifest.new(json_text: base_hash.to_json.to_s)
  end

  def create_ingest_manifest_file(msg:, manifest:)
    manifest_path = File.join(ingest_root, msg.package)
    FileUtils.mkdir(manifest_path)
    manifest_file = File.join(manifest_path, 'ingest_manifest.json')
    json_to_store = JSON.pretty_generate(manifest.to_json_ingest_hash).to_s
    File.open(manifest_file, 'w') { |file| file.write(json_to_store) }
    manifest_file
  end

  # :filepath, :sha1, :md5, :size, :ingest_date
  # do we get sha1, size from ecommons metadata?
  def populate_files(path:)
    files = list_files(path: path)
    populated = []
    files.each do |file|
      filepath = Pathname.new(file).relative_path_from(path).to_s
      f = Manifests::FileEntry.new(file: { filepath: filepath })
      populated << f
    end
    populated
  end

  def list_files(path:)
    paths = []
    Find.find(path) do |p|
      paths << p unless FileTest.directory?(p)
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

  def clean_up(zip_path:, extract_dir_path:)
    File.delete(zip_path)
    FileUtils.remove_dir(extract_dir_path)
  end
end
