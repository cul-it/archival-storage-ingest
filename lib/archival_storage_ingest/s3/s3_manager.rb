# frozen_string_literal: true

require 'archival_storage_ingest/logs/archival_storage_ingest_logger'
require 'aws-sdk-s3'
require 'digest/sha1'

# This class will handle S3 interaction.
# https://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html
# Above documentation states that the client has retry feature built in.
# Only ~ 500 level server errors and certain ~ 400 level client errors are retried.
# Generally, these are throttling errors, data checksum errors, networking errors,
#   timeout errors and auth errors from expired credentials.
# See Plugins::RetryErrors for more details.
class S3Manager
  MAX_RETRY = 3
  RETRY_INTERVAL = 60

  attr_writer :s3

  def s3
    @s3 ||= Aws::S3::Resource.new
  end

  def initialize(s3_bucket, max_retry = MAX_RETRY)
    @s3_bucket = s3_bucket
    @max_retry = max_retry
  end

  def parse_s3_error(error)
    "Code: #{error.code}\nContext: #{error.context}\nMessage: #{error.message}"
  end

  def upload_file(s3_key, file_to_upload)
    s3.bucket(@s3_bucket).object(s3_key).upload_file(file_to_upload)
  rescue Aws::S3::Errors::ServiceError => e
    raise IngestException, "S3 upload file failed for #{file_to_upload}!\n" + parse_s3_error(e)
  end

  def upload_string(s3_key, data)
    s3.bucket(@s3_bucket).object(s3_key).put(body: data)
  rescue Aws::S3::Errors::ServiceError => e
    raise IngestException, "S3 upload data stream failed!\n" + parse_s3_error(e)
  end

  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#list_objects_v2-instance_method
  # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Types/ListObjectsV2Output.html#next_continuation_token-instance_method
  # RubyMine can't recognize any of the attributes of the response!
  def list_object_keys(prefix)
    resp = _list_object(prefix, nil)
    object_keys = _list_keys(resp)
    while resp.is_truncated
      resp = _list_object(prefix, resp.next_continuation_token)
      object_keys.concat(_list_keys(resp))
    end

    object_keys
  rescue Aws::S3::Errors::ServiceError => e
    raise IngestException, "S3 list_object_keys failed for #{prefix}!\n" + parse_s3_error(e)
  end

  def _list_object(prefix, continuation_token)
    s3.client.list_objects_v2(bucket: @s3_bucket, prefix: prefix, continuation_token: continuation_token)
  end

  def _list_keys(list_object_resp)
    list_object_resp.contents.map(&:key)
  end

  # https://aws.amazon.com/blogs/developer/downloading-objects-from-amazon-s3-using-the-aws-sdk-for-ruby/
  # Please note, when using blocks to downloading objects,
  # the Ruby SDK will NOT retry failed requests after the first chunk of data has been yielded.
  # Doing so could cause file corruption on the client end by starting over mid-stream.
  #
  # We will need to put a retry mechanism for this function.
  def calculate_checksum(s3_key)
    retries ||= 0
    _calculate_checksum(s3_key)
  rescue Aws::S3::Errors::ServiceError => e
    retries += 1
    raise IngestException, "S3 calculate_checksum failed for #{s3_key}!\n" + parse_s3_error(e) if retries >= @max_retry

    sleep(RETRY_INTERVAL)
    retry
  end

  def _calculate_checksum(s3_key)
    size = 0

    dig = Digest::SHA1.new
    s3.client.get_object(bucket: @s3_bucket, key: s3_key) do |chunk|
      dig.update(chunk)
      size += chunk.length
    end
    s3_obj = s3.bucket(@s3_bucket).object(s3_key)
    raise Aws::S3::Errors::ServiceError, "File size mismatch! expected size: #{s3_obj.content_length}, got size: #{size}" unless
      s3_obj.content_length == size

    [dig, size]
  end

  def manifest_key(ingest_id, type)
    ".manifest/#{ingest_id}_#{type}.json"
  end

  def retrieve_file(s3_key)
    s3.bucket(@s3_bucket).object(s3_key).get.body
  end

  def download_file(s3_key:, dest_path:)
    s3.get_object({ bucket: @s3_bucket, key: s3_key }, target: dest_path)
  end
end
