# frozen_string_literal: true

require 'archival_storage_ingest/workers/parameter_store'
require 'aws-sdk-ssm'
require 'pg'

module TransferStateManager
  TRANSFER_STATE_IN_PROGRESS = 'in_progress'
  TRANSFER_STATE_COMPLETE = 'complete'

  class BaseTransferStateManager
    def add_transfer_state(job_id:, platform:, state:)
      raise "Not implemented add_transfer_state(#{job_id}, #{platform}, #{state})"
    end

    def set_transfer_state(job_id:, platform:, state:)
      raise "Not implemented set_transfer_state(#{job_id}, #{platform}, #{state})"
    end

    def transfer_complete?(job_id:)
      raise "Not implemented transfer_complete?(#{job_id})"
    end
  end

  class DBTransferStateManager < BaseTransferStateManager
    attr_reader :host, :port, :dbname, :user, :password

    # Do we need to make it truely dynamic?
    # For now, we will initialize db params at the initialization time.
    def initialize(parameter_store:)
      super()
      # Why does get_parameters return random order?
      # names = ['ingest/rds/dbhost', 'ingest/rds/dbport', 'ingest/rds/dbname', 'ingest/rds/dbuser']
      # params = parameter_store.get_parameters(names:, with_decryption: false)
      @host = parameter_store.get_parameter(name: 'ingest/rds/dbhost', with_decryption: true)
      @port = parameter_store.get_parameter(name: 'ingest/rds/dbport', with_decryption: true)
      @dbname = parameter_store.get_parameter(name: 'ingest/rds/dbname', with_decryption: true)
      @user = parameter_store.get_parameter(name: 'ingest/rds/dbuser', with_decryption: true)
      @password = parameter_store.get_parameter(name: "ingest/rds/#{@user}/dbpassword", with_decryption: true)
    end

    def connect
      PG::Connection.new(host:, port:, dbname:, user:, password:)
    end

    def add_transfer_state(job_id:, platform:, state:)
      query = 'INSERT INTO transfer_state (job_id, platform, state) VALUES ($1, $2, $3) ' \
              'ON CONFLICT (job_id, platform) DO UPDATE SET state = $3'
      trans_execute(query:, params: [job_id, platform, state])
    end

    def set_transfer_state(job_id:, platform:, state:)
      query = 'UPDATE transfer_state SET state = $1 WHERE job_id = $2 and platform = $3'
      trans_execute(query:, params: [state, job_id, platform])
    end

    def trans_execute(query:, params:)
      conn = connect
      conn.transaction do |trans|
        trans.exec_params(query, params)
      end
      conn.close
    end

    def transfer_complete?(job_id:)
      conn = connect
      query = 'SELECT * FROM transfer_state WHERE job_id = $1 and state = $2'
      complete = false
      conn.transaction do |trans|
        complete = trans.exec_params(query, [job_id, TransferStateManager::TRANSFER_STATE_IN_PROGRESS]).num_tuples.zero?
      end
      conn.close
      complete
    end
  end

  class TestTransferStateManager < BaseTransferStateManager
    attr_reader :state

    def initialize
      super()
      @state = {}
    end

    def add_transfer_state(job_id:, platform:, state:)
      @state[job_id] = {} unless @state[job_id]
      @state[job_id][platform] = state
    end

    def set_transfer_state(job_id:, platform:, state:)
      @state[job_id][platform] = state
    end

    def transfer_complete?(job_id:)
      @state[job_id].values.all? { |v| v == TransferStateManager::TRANSFER_STATE_COMPLETE }
    end

    def get_transfer_state(job_id:, platform:)
      return nil unless @state[job_id]

      @state[job_id][platform]
    end
  end
end

# Path: archival-storage-ingest/lib/archival_storage_ingest/workers/transfer_state_manager.rb
