# frozen_string_literal: true

module Workers
  TYPE_S3 = 's3'
  TYPE_SFS = 'sfs'

  # Base class for specific workers
  class Worker
    def work(msg) end
  end
end
