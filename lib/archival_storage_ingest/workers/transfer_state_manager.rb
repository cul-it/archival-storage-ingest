# frozen_string_literal: true

require 'archival_storage_ingest/workers/parameter_store'
require 'aws-sdk-ssm'
require 'pg'

module StateManager
  TRANSFER_STATE_IN_PROGRESS = 'in_progress'
  TRANSFER_STATE_COMPLETE = 'complete'

  class BaseStateManager
    def transfer_complete?(_job_id:)
      raise 'Not implemented'
    end
  end

  class TransferStateManager < BaseStateManager
    attr_reader :host, :port, :dbname, :user, :password

    # Do we need to make it truely dynamic?
    # For now, we will initialize db params at the initialization time.
    def initialize(parameter_store:)
      super
      names = ['ingest/rds/dbhost', 'ingest/rds/dbport', 'ingest/rds/dbname', 'ingest/rds/dbuser']
      params = parameter_store.get_parameters(names:, with_decryption: true)
      @host = params[0]
      @port = params[1]
      @dbname = params[2]
      @user = params[3]
      @password = parameter_store.get_parameter("ingest/rds/#{@user}/dbpassword")
    end

    def connect
      PGconn.connect(hostaddr: host, port:, dbname:, user:, password:)
    end

    def transfer_complete?(job_id:)
      conn = connect
      query = 'SELECT * FROM transfer_state WHERE job_id = $1 and state = $2'
      complete = false
      conn.transaction do |trans|
        complete = trans.exec_params(query, [job_id, TRANSFER_STATE_IN_PROGRESS]).num_tuples.zero?
      end
      conn.close
      complete
    end

    def set_transfer_state(job_id:, platform:, state:)
      query = 'UPDATE transfer_state SET state = $1 WHERE job_id = $2 and platform = $3'
      trans_execute(query:, job_id:, platform:, state:)
    end

    def add_transfer_state(job_id:, platform:, state:)
      query = 'INSERT INTO transfer_state (job_id, platform, state) VALUES ($1, $2, $3)'
      trans_execute(query:, job_id:, platform:, state:)
    end

    def trans_execute(query:, job_id:, platform:, state:)
      conn = connect
      conn.transaction do |trans|
        trans.exec_params(query, [job_id, platform, state])
      end
      conn.close
    end
  end
end

# Path: archival-storage-ingest/lib/archival_storage_ingest/workers/transfer_state_manager.rb
