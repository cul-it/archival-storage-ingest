# frozen_string_literal: true

require 'aws-sdk-s3'

# This class will handle S3 interaction.
# One of the things it will do is to retry a request up to 3 times.
class S3Manager
  MAX_RETRY = 3

  def initialize(s3_bucket, max_retry = :MAX_RETRY)
    @s3_bucket = s3_bucket
    @s3 = Aws::S3::Resource.new
    @max_retry = max_retry
  end

  def upload_file(s3_key, file_to_upload)
    retries ||= 0
    status = @s3.bucket(@s3_bucket).object(s3_key).upload_file(file_to_upload)
    raise Aws::S3::MultipartUploadError.new('Failed to upload file', 'Upload failed') unless status

    status
  rescue Aws::S3::MultipartUploadError
    retry if (retries += 1) < @max_retry
    raise IngestException, "S3 upload failures reached max retry (#{MAX_RETRY}) for #{file_to_upload}"
  end
end
