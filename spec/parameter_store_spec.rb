require 'rspec'
require_relative '../lib/archival_storage_ingest/workers/parameter_store'

RSpec.describe ParameterStore::SSMParameterStore do
  let(:parameter_store) { described_class.new }

  describe '#get_parameter' do
    it 'returns the value of the parameter' do
      # Add your test code here
    end
  end

  describe '#get_parameters' do
    it 'returns an array of parameter values' do
      # Add your test code here
    end
  end
end

RSpec.describe ParameterStore::TestParameterStore do
  let(:parameter_store) { described_class.new }

  describe '#add_parameter' do
    it 'adds a parameter to the store' do
      # Add your test code here
    end
  end

  describe '#get_parameter' do
    it 'returns the value of the parameter' do
      # Add your test code here
    end
  end

  describe '#get_parameters' do
    it 'returns an array of parameter values' do
      # Add your test code here
    end
  end
end
