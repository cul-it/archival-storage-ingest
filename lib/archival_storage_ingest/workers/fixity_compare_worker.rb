# frozen_string_literal: true

require 'archival_storage_ingest/workers/worker'
require 'archival_storage_ingest/manifests/manifests'
require 'archival_storage_ingest/manifests/manifest_of_manifests'
require 'archival_storage_ingest/messages/ingest_message'
require 'archival_storage_ingest/messages/queues'
require 'archival_storage_ingest/preingest/periodic_fixity_env_initializer'
require 'archival_storage_ingest/work_queuer/work_queuer'
# require 'archival_storage_ingest/workers/worker'
require 'date'
require 'yaml'

module FixityCompareWorker
  class ManifestComparator < Workers::Worker
    attr_reader :s3_manager

    # Pass s3_manager only for tests.
    def initialize(application_logger, s3_manager = nil)
      super(application_logger)
      @s3_manager = s3_manager || ArchivalStorageIngest.configuration.s3_manager
    end

    def _work(msg)
      # ignore collection manifest as itself is not part of the manifest
      compare_fixity_report(msg)

      @application_logger.log({ job_id: msg.job_id,
                                log: "Fixity comparison for #{msg.depositor}/#{msg.collection} is successful." })
      true
    rescue Aws::S3::Errors::NoSuchKey
      @application_logger.log({ job_id: msg.job_id,
                                log: "Fixity comparison for #{msg.depositor}/#{msg.collection} is skipped." })
      false
    end

    def compare_fixity_report(msg)
      ingest_manifest, sfs_manifest, s3_manifest = retrieve_manifests(msg)

      cm_filename = Manifests.collection_manifest_filename(depositor: msg.depositor, collection: msg.collection)
      comparator = Manifests::ManifestComparator.new(cm_filename:)
      sfs_status, sfs_diff = comparator.fixity_diff(ingest: ingest_manifest, fixity: sfs_manifest)
      s3_status, s3_diff = comparator.fixity_diff(ingest: ingest_manifest, fixity: s3_manifest)

      raise IngestException, "Ingest and SFS manifests do not match: #{sfs_diff}" unless sfs_status

      raise IngestException, "Ingest and S3 manifests do not match: #{s3_diff}" unless s3_status

      true
    end

    def periodic?
      false
    end

    def _name
      'Manifest Comparator'
    end

    def retrieve_manifests(msg)
      s3_manifest = retrieve_manifest(msg, Workers::TYPE_S3)
      sfs_manifest = retrieve_manifest(msg, Workers::TYPE_SFS)
      ingest_manifest = retrieve_manifest(msg, Workers::TYPE_INGEST)
      [ingest_manifest, sfs_manifest, s3_manifest]
    end

    def retrieve_manifest(msg, suffix)
      manifest_name = s3_manager.manifest_key(msg.job_id, suffix)
      manifest_file = s3_manager.retrieve_file(manifest_name)
      Manifests.read_manifest_io(json_io: manifest_file)
    end

    # Put a file with ingest id as its name and content to a temporary s3 bucket
    # A cronjob will run every night to pick up all ingest id,
    # find ingest id, merge ingest manifests to storage manifest,
    # and deploy to proper location.
    def deploy_manifest_if_m2m(msg:)
      return true unless msg.type == IngestMessage::TYPE_M2M

      now = Date.today
      month = now.strftime('%m')
      day = now.strftime('%d')
      upload_date = "#{now.year}#{month}#{day}"
      s3_key = ".m2m/ingest_manifest/#{msg.depositor}/#{msg.collection}/#{upload_date}/#{msg.job_id}"
      s3_manager.upload_string(s3_key, msg.job_id)
    end
  end

  class PeriodicFixityComparator < ManifestComparator
    attr_reader :manifest_dir, :manifest_of_manifests, :periodic_fixity_root, :sfs_root, :relay_queue_name

    # It downloads the collection manifest from S3 to manifest_dir.
    # manifest_dir must be specified by the caller and the periodic fixity executable uses
    # /cul/app/archival_storage_ingest/manifests
    #
    # man_of_mans is the absolute path and must be specified.
    # The periodic fixity executable uses
    # /cul/app/archival_storage_ingest/manifest_of_manifests/manifest_of_manifests.json
    #
    # relay_queue_name is the destination queue for next collection check.
    # It should be (DEV) QUEUE_PERIODIC_FIXITY.
    def initialize(named_params)
      super(named_params.fetch(:application_logger), named_params.fetch(:s3_manager, nil))
      @manifest_dir = named_params.fetch(:manifest_dir)
      @manifest_of_manifests = named_params.fetch(:man_of_mans)
      @periodic_fixity_root = named_params.fetch(:periodic_fixity_root)
      @sfs_root = named_params.fetch(:sfs_root)
      @relay_queue_name = named_params.fetch(:relay_queue_name)
    end

    def periodic?
      true
    end

    def _name
      'Periodic Manifest Comparator'
    end

    def retrieve_manifests(msg)
      # s3_manifest = retrieve_manifest(msg, Workers::TYPE_S3)
      sfs_manifest = retrieve_manifest(msg, Workers::TYPE_SFS)
      ingest_manifest = retrieve_manifest(msg, Workers::TYPE_INGEST)
      [ingest_manifest, sfs_manifest]
    end

    def compare_fixity_report(msg)
      ingest_manifest, sfs_manifest = retrieve_manifests(msg)

      cm_filename = Manifests.collection_manifest_filename(depositor: msg.depositor, collection: msg.collection)
      comparator = Manifests::ManifestComparator.new(cm_filename:)
      sfs_status, sfs_diff = comparator.fixity_diff(ingest: ingest_manifest, fixity: sfs_manifest)
      # s3_status, s3_diff = comparator.fixity_diff(ingest: ingest_manifest, fixity: s3_manifest)

      raise IngestException, "Ingest and SFS manifests do not match: #{sfs_diff}" unless sfs_status

      # raise IngestException, "Ingest and S3 manifests do not match: #{s3_diff}" unless s3_status

      true
    end

    def _work(msg)
      return false unless super(msg)

      next_work_msg = queue_next_collection(msg)
      if next_work_msg
        log_doc = { job_id: next_work_msg.job_id,
                    log: "Periodic fixity for #{next_work_msg.depositor}/#{next_work_msg.collection} has started." }
        @application_logger.log(log_doc)
      end

      remove_collection_manifest_in_temp(job_id: msg.job_id)

      true
    end

    def retrieve_manifest(msg, suffix)
      manifest_name = s3_manager.manifest_key(msg.job_id, suffix)
      manifest_file = s3_manager.retrieve_file(manifest_name)
      Manifests.read_manifest_io(json_io: manifest_file)
    end

    def cm_file_entry(msg:, filepath:)
      im_key = s3_manager.manifest_key(msg.job_id, Workers::TYPE_INGEST)
      (sha1, size) = s3_manager.calculate_checksum(im_key)
      Manifests::FileEntry.new(file: { filepath:, sha1:, size: })
    end

    # Sometimes, when the things to check are very small, both s3 and sfs return at around the same time.
    # When this happens, it ends up queueing next collection twice as comparison worker will pick up both messages
    # and both manifests will be available both times.
    #
    # Collection manifests are stored in temporary space in s3 as s3://bucket/.manifest/job_id_ingest_manifest.json
    # Delete it when the fixity comparison is successful.
    # Doing so will make the second run not be able to find the collection manifest and skip.
    def remove_collection_manifest_in_temp(job_id:)
      manifest_name = s3_manager.manifest_key(job_id, Workers::TYPE_INGEST)
      s3_manager.delete_object(s3_key: manifest_name)
    end

    # We invoke the same workflow to queue next collection as manual queuing.
    #
    # Specifically, it uses periodic fixity env initializer to generate the config file
    # and all the other file structures to queue up the next fixity check.
    #
    # This way, if something goes wrong, developers can inspect the periodic_fixity_root
    # to see what periodic fixity configuration was used.
    def queue_next_collection(msg)
      manifest_def = next_manifest_definition(msg)
      return if manifest_def.nil?

      cm = collection_manifest(manifest_def:)
      env_initializer = Preingest::PeriodicFixityEnvInitializer.new(periodic_fixity_root:,
                                                                    sfs_root:)
      env_initializer.initialize_periodic_fixity_env(cmf: cm, sfs_location: manifest_def.sfs, ticket_id: msg.ticket_id,
                                                     relay_queue_name: @relay_queue_name)
      queuer = WorkQueuer::PeriodicFixityQueuer.new(confirm: false)
      fixity_config = YAML.load_file(env_initializer.config_path)
      queuer.queue_periodic_fixity_check(fixity_config)
    end

    def next_manifest_definition(msg)
      mom = Manifests::ManifestOfManifests.new(manifest_of_manifests)
      mom.next_manifest_definition(depositor: msg.depositor, collection: msg.collection)
    end

    def collection_manifest(manifest_def:)
      cm_filename = Manifests.collection_manifest_filename(depositor: manifest_def.depositor,
                                                           collection: manifest_def.collection)
      dest_path = File.join(manifest_dir, cm_filename)
      @s3_manager.download_file(s3_key: manifest_def.s3_key, dest_path:)
      dest_path
    end
  end
end
