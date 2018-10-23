# frozen_string_literal: true

module Workers
  # Base class for specific workers
  class Worker
    def start(on_success:, on_fail:)
      yield
    rescue StandardError
      on_fail.call
    else
      on_success.call
    end

    def status;
    end
  end
end
