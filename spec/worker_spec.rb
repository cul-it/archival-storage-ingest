require 'spec_helper'

RSpec.describe 'invoke-workers' do


  worker = Workers::Worker.new

  it 'does something successfully' do
    result = "didn't do anything"
    work_done = 'no work done'
    worker.start(on_success: -> {result = 'succeeded'},
                 on_fail: -> {result = 'failed'}) do
      work_done = 'work done'
    end

    expect(work_done).to eq('work done')
    expect(result).to eq('succeeded')
  end

  it 'fails gracefully' do
    result = "didn't do anything"
    work_done = 'no work done'
    worker.start(on_success: -> {result = 'succeeded'},
                 on_fail: -> {result = 'failed'}) do
      raise
    end

    expect(work_done).to eq('no work done')
    expect(result).to eq('failed')
  end
end