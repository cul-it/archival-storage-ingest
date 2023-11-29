# frozen_string_literal: true

require 'rspec'
require 'archival_storage_ingest/options/command_parser'

RSpec.describe 'Command Parser' do
  describe 'IngestCommandParser' do
    let(:ingest_config) { File.join(File.dirname(__FILE__), 'resources', 'manifests', 'arXiv.json') }
    let(:ic_option_parser) { CommandParser::IngestCommandParser.new }

    context 'when given valid ingest config file' do
      let(:argv_valid) { ['-i', ingest_config] }

      it 'returns ingest config pointing to the passed file' do
        ic_option_parser.parse!(argv_valid)
        expect(ic_option_parser.ingest_config).to eq(ingest_config)
      end
    end

    context 'when given invalid ingest config file' do
      let(:argv_invalid) { %w[-i bogus.json] }

      it 'raises error' do
        expect do
          ic_option_parser.parse!(argv_invalid)
        end.to raise_error(IngestException, 'bogus.json is not a valid file')
      end
    end
  end

  describe 'MoveMessageCommandParser' do
    let(:mm_option_parser) { CommandParser::MoveMessageCommandParser.new }

    context 'when parsing move message options' do
      let(:mm_argv) { %w[-s q1 -t q2] }

      it 'gets source and target queue names' do
        mm_option_parser.parse!(mm_argv)
        expect(mm_option_parser.config[:source]).to eq('q1')
        expect(mm_option_parser.config[:target]).to eq('q2')
      end
    end
  end
end
