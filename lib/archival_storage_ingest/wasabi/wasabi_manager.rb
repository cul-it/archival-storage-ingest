# frozen_string_literal: true

require 'archival_storage_ingest/s3/s3_manager'
require 'aws-sdk-s3'
require 'aws-sdk-ssm'

##
# Subclasses S3Manager to create a similar interface for Wasabi.
#
# Since Wasabi uses the same API as S3, operations on the remote cloud objects are essentially the same.
# Of course, the actual S3 client has to be defined using different parameters.
#
# params:
# * +s3_bucket+ [String] name of bucket to use on Wasabi
# * +asif_s3_bucket+ [String] [optional]
# * +asif_archive_size_s3_bucket+ [String] [optional]
# * +m2m_bucket+ [String] [optional]
# * +max_retry+ [Int] [optional]
class WasabiManager < S3Manager
  def s3
    return @s3 unless @s3.nil?

    stage = if ENV['asi_develop'] || ENV['asi_ingest_transfer_wasabi_develop']
              'dev' # should be either prod or dev, and sandbox not supported for now
            else
              'prod'
            end
    ssm_client = Aws::SSM::Client.new
    access_key = ssm_client.get_parameter({ name: "/cular/archivalstorage/#{stage}/ingest/wasabi/access_key_id", with_decryption: true }).parameter.value
    secret_key = ssm_client.get_parameter({ name: "/cular/archivalstorage/#{stage}/ingest/wasabi/secret_access_key", with_decryption: true }).parameter.value
    region = 'us-east-1' # fixed value
    endpoint = 'https://s3.wasabisys.com' # fixed value

    s3_client = Aws::S3::Client.new(region: region, access_key_id: access_key, secret_access_key: secret_key, endpoint: endpoint)

    @s3 = Aws::S3::Resource.new(client: s3_client)
  end
end
