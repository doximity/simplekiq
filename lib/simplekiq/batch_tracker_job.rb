# frozen_string_literal: true

# This job serves two purposes:
# * TODO: It provides a convenient way to track top-level orchestration batches
# * The top-level orchestration batch would otherwise be empty (aside from
#   child-batches) and all sidekiq-pro batches must have at least 1 job

module Simplekiq
  class BatchTrackerJob
    include Sidekiq::Worker

    def perform(klass_name, bid, args)
      # In the future, this will likely surface the toplevel batch to a callback method on the
      # orchestration job. We're holding off on this until we have time to design a comprehensive
      # plan for providing simplekiq-wide instrumentation, ideally while being backwards compatible
      # for in-flight orchestrations.

      # For now, it's just satisfying the all-batches-must-have-jobs limitation in sidekiq-pro
      # described at the head of the file.
    end
  end
end
