# frozen_string_literal: true

module Workers
  # Base class for specific workers
  class Worker
    def work(msg) end
  end
end
