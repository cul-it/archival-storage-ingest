# frozen_string_literal: true

require 'aws-sdk-ssm'

module ParameterStore
  class BaseParameterStore
    attr_reader :stage

    def initialize(stage:)
      @stage = stage
    end

    def full_param_name(name:)
      "/cular/archivalstorage/#{stage}/#{name}"
    end

    def get_parameter(_name:, _with_decryption:)
      raise 'Not implemented'
    end

    def get_parameters(_names:, _with_decryption:)
      raise 'Not implemented'
    end
  end

  class SSMParameterStore < BaseParameterStore
    def initialize(stage:)
      super(stage:)
      @ssm = Aws::SSM::Client.new
    end

    def get_parameter(name:, with_decryption:)
      resp = @ssm.get_parameter(name: full_param_name(name:), with_decryption:)
      resp.parameter.value
    end

    def get_parameters(names:, with_decryption:)
      resp = @ssm.get_parameters(names: names.map { |name| full_param_name(name:) }, with_decryption:)
      resp.parameters.map(&:value)
    end
  end

  class TestParameterStore < BaseParameterStore
    def initialize(stage:)
      super(stage:)
      @store = {}
    end

    def key(name:, with_decryption:)
      "#{name}_#{with_decryption}"
    end

    def add_parameter(name:, value:, with_decryption:)
      @store[key(name:, with_decryption:)] = value
    end

    def get_parameter(name:, with_decryption:)
      @store[key(name:, with_decryption:)]
    end

    def get_parameters(names:, with_decryption:)
      names.map do |name|
        @store[key(name:, with_decryption:)]
      end
    end
  end
end

# Path: archival-storage-ingest/lib/archival_storage_ingest/workers/parameter_store.rb
