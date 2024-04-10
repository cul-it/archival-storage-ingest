# frozen_string_literal: true

require 'fileutils'

TYPE_ASIF = 'asif'
TYPE_ASIF_ARCHIVE_SIZE = 'asif_archive_size'
TYPE_S3 = 's3'
TYPE_S3_WEST = 's3_west'
TYPE_WASABI = 'wasabi'
TYPE_M2M = 'm2m'
TYPE_VERSIONED_MANIFEST = 'manifest'

class LocalManager
  def initialize(local_root:, type:)
    @working_dir = File.join(local_root, type)
    @asif_dir = File.join(local_root, TYPE_ASIF)
    @asif_archive_size_dir = File.join(local_root, TYPE_ASIF_ARCHIVE_SIZE)
    @m2m_dir = File.join(local_root, TYPE_M2M)
    [@working_dir, @asif_dir, @asif_archive_size_dir, @m2m_dir].each do |dir|
      FileUtils.mkdir dir unless File.directory? dir
    end
  end

  def _copy_file(source, target)
    dest_dir = File.dirname(target)
    FileUtils.mkdir_p(dest_dir) unless File.directory? dest_dir
    FileUtils.copy_file(source, target)
  end

  def upload_file(s3_key, file_to_upload)
    dest_path = File.join(@working_dir, s3_key)
    _copy_file(file_to_upload, dest_path)
  end

  def upload_asif_manifest(s3_key:, manifest_file:)
    dest_path = File.join(@asif_dir, s3_key)
    _copy_file(manifest_file, dest_path)
  end

  def upload_asif_archive_size(s3_key:, data:)
    dest_path = File.join(@asif_dir, s3_key)
    _upload_string(dest_path, data)
  end

  def upload_string(s3_key, data)
    dest_path = File.join(@working_dir, s3_key)
    _upload_string(dest_path, data)
  end

  def _upload_string(dest_path, data)
    dest_dir = File.dirname(dest_path)
    FileUtils.mkdir_p dest_dir unless File.directory? dest_dir
    File.write(dest_path, data)
  end

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#list_objects_v2-instance_method
  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Types/ListObjectsV2Output.html#next_continuation_token-instance_method
  def list_object_keys(prefix)
    search_path = prefix.nil? ? @working_dir : File.join(@working_dir, prefix)
    Dir.glob("#{search_path}/**/*")
  end

  # https://aws.amazon.com/blogs/developer/downloading-objects-from-amazon-s3-using-the-aws-sdk-for-ruby/
  # Please note, when using blocks to downloading objects,
  # the Ruby SDK will NOT retry failed requests after the first chunk of data has been yielded.
  # Doing so could cause file corruption on the client end by starting over mid-stream.
  #
  # We will need to put a retry mechanism for this function.
  def calculate_checksum(s3_key, algorithm = IngestUtils::ALGORITHM_SHA1)
    IngestUtils.calculate_checksum(filepath: File.join(@working_dir, s3_key), algorithm:)
  end

  def manifest_key(job_id, type)
    ".manifest/#{job_id}_#{type}.json"
  end

  def retrieve_file(s3_key)
    File.new(File.join(@working_dir, s3_key))
  end

  def download_file(s3_key:, dest_path:)
    upload_file(s3_key, dest_path)
  end

  # used to download m2m zip package
  def download_m2m_file(s3_key:, dest_path:)
    # Download not allowed for now
  end

  def delete_object(s3_key:)
    File.delete(File.join(@working_dir, s3_key))
  end

  def delete_objects(s3_keys:)
    to_delete = s3_keys.map { |key| File.join(@working_dir, key) }
    File.delete(to_delete)
  end

  def cleanup
    [@working_dir, @asif_dir, @asif_archive_size_dir, @m2m_dir].each do |dir|
      FileUtils.rm_rf(dir, secure: true) if File.directory? dir
    end
  end
end
