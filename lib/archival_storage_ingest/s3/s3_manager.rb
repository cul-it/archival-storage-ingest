# frozen_string_literal: true

require 'aws-sdk-s3'

# This class will handle S3 interaction.
# https://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Client.html
# Above documentation states that the client has retry feature built in.
# Only ~ 500 level server errors and certain ~ 400 level client errors are retried.
# Generally, these are throttling errors, data checksum errors, networking errors,
#   timeout errors and auth errors from expired credentials.
# See Plugins::RetryErrors for more details.
class S3Manager
  def initialize(s3_bucket)
    @s3_bucket = s3_bucket
    @s3 = Aws::S3::Resource.new
  end

  def upload_file(s3_key, file_to_upload)
    @s3.bucket(@s3_bucket).object(s3_key).upload_file(file_to_upload)
  end

  def upload_string(s3_key, data)
    @s3.bucket(@s3_bucket).object(s3_key).put(data)
  end

  def manifest_key(ingest_id, type)
    ".manifest/#{ingest_id}_#{type}.json"
  end
end
