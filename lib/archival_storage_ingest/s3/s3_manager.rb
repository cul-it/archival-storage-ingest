# frozen_string_literal: true

require 'archival_storage_ingest/logs/archival_storage_ingest_logger'
require 'aws-sdk-s3'
require 'archival_storage_ingest/ingest_utils/ingest_utils'

# This class will handle S3 interaction.
# https://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html
# Above documentation states that the client has retry feature built in.
# Only ~ 500 level server errors and certain ~ 400 level client errors are retried.
# Generally, these are throttling errors, data checksum errors, networking errors,
#   timeout errors and auth errors from expired credentials.
# See Plugins::RetryErrors for more details.
class S3Manager # rubocop:disable Metrics/ClassLength
  MAX_RETRY = 3
  RETRY_INTERVAL = 120
  MAX_DELETE_SIZE = 1000 # set by AWS

  attr_writer :s3

  def s3
    @s3 ||= Aws::S3::Resource.new
  end

  # rubocop:disable Metrics/ParameterLists
  def initialize(s3_bucket, asif_s3_bucket = 's3-cular-invalid',
                 asif_archive_size_s3_bucket = 's3-cular-invalid',
                 m2m_bucket = 's3-cular-invalid', max_retry = MAX_RETRY)
    @s3_bucket = s3_bucket
    @asif_s3_bucket = asif_s3_bucket
    @asif_archive_size_s3_bucket = asif_archive_size_s3_bucket
    @m2m_bucket = m2m_bucket
    @max_retry = max_retry
  end
  # rubocop:enable Metrics/ParameterLists

  # def if_nil(val, replacement)
  #   val.nil? ? replacement : val
  # end

  def parse_s3_error(error)
    "Code: #{error.code}\nContext: #{error.context}\nMessage: #{error.message}"
  end

  def _upload_file(bucket:, s3_key:, file:)
    s3.bucket(bucket).object(s3_key).upload_file(file)
  rescue Aws::S3::Errors::ServiceError => e
    raise IngestException, "S3 upload file failed for #{file}!\n" + parse_s3_error(e)
  end

  def upload_file(s3_key, file_to_upload)
    _upload_file(bucket: @s3_bucket, s3_key: s3_key, file: file_to_upload)
  end

  def upload_asif_manifest(s3_key:, manifest_file:)
    _upload_file(bucket: @asif_s3_bucket, s3_key: s3_key, file: manifest_file)
  end

  def upload_asif_archive_size(s3_key:, data:)
    s3.bucket(@asif_archive_size_s3_bucket).object(s3_key).put(body: data)
  rescue Aws::S3::Errors::ServiceError => e
    raise IngestException, "Archive Size S3 upload data stream failed!\n#{parse_s3_error(e)}"
  end

  def upload_string(s3_key, data)
    s3.bucket(@s3_bucket).object(s3_key).put(body: data)
  rescue Aws::S3::Errors::ServiceError => e
    raise IngestException, "S3 upload data stream failed!\n#{parse_s3_error(e)}"
  end

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#list_objects_v2-instance_method
  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Types/ListObjectsV2Output.html#next_continuation_token-instance_method
  def list_object_keys(prefix)
    resp = _list_object(prefix, nil)
    object_keys = resp.contents.map(&:key)
    while resp.is_truncated
      resp = _list_object(prefix, resp.next_continuation_token)
      object_keys.concat(resp.contents.map(&:key))
    end

    object_keys
  rescue Aws::S3::Errors::ServiceError => e
    raise IngestException, "S3 list_object_keys failed for #{prefix}!\n" + parse_s3_error(e)
  end

  def _list_object(prefix, continuation_token)
    s3.client.list_objects_v2(bucket: @s3_bucket, prefix: prefix, continuation_token: continuation_token)
  end

  # https://aws.amazon.com/blogs/developer/downloading-objects-from-amazon-s3-using-the-aws-sdk-for-ruby/
  # Please note, when using blocks to downloading objects,
  # the Ruby SDK will NOT retry failed requests after the first chunk of data has been yielded.
  # Doing so could cause file corruption on the client end by starting over mid-stream.
  #
  # We will need to put a retry mechanism for this function.
  def calculate_checksum(s3_key, algorithm = IngestUtils::ALGORITHM_SHA1)
    s3_obj = s3.bucket(@s3_bucket).object(s3_key)
    errors = []
    @max_retry.times do
      dig, size = _calculate_checksum(s3_key, algorithm)
      return [dig, size, errors] if s3_obj.content_length == size

      sleep(RETRY_INTERVAL)
      errors << "Size mismatch: #{s3_obj.content_length}, #{size}!"
    end
    raise IngestException, "S3 calculate_checksum failed for #{s3_key}:\n".errors.join("\n")
  end

  def _calculate_checksum(s3_key, algorithm)
    size = 0
    dig = IngestUtils.digest(algorithm)
    s3.client.get_object(bucket: @s3_bucket, key: s3_key) do |chunk|
      dig.update(chunk)
      size += chunk.length
    end

    [dig, size]
  end

  def manifest_key(ingest_id, type)
    ".manifest/#{ingest_id}_#{type}.json"
  end

  def retrieve_file(s3_key)
    s3.bucket(@s3_bucket).object(s3_key).get.body
  end

  def _download_file(bucket:, s3_key:, dest_path:)
    s3.client.get_object({ bucket: bucket, key: s3_key }, target: dest_path)
  end

  def download_file(s3_key:, dest_path:)
    _download_file(bucket: @s3_bucket, s3_key: s3_key, dest_path: dest_path)
  end

  # used to download m2m zip package
  def download_m2m_file(s3_key:, dest_path:)
    _download_file(bucket: @m2m_bucket, s3_key: s3_key, dest_path: dest_path)
  end

  def delete_object(s3_key:)
    s3.client.delete_object(bucket: @s3_bucket, key: s3_key)
  end

  def delete_objects(s3_keys:)
    num_deleted = 0
    s3_keys.each_slice(MAX_DELETE_SIZE) do |s3_keys_chunk|
      req = { bucket: @s3_bucket, delete: { objects: [] } }
      s3_keys_chunk.each do |s3_key|
        req[:delete][:objects] << { key: s3_key }
      end
      resp = s3.client.delete_objects(req).to_h
      num_deleted += resp[:deleted][:delete][:objects].size
    end

    num_deleted
  end
end
