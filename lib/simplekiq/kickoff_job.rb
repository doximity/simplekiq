# frozen_string_literal: true

# Per documentation here https://github.com/sidekiq/sidekiq/wiki/Really-Complex-Workflows-with-Batches
# All batches must have a job. Batches that have child batches must have those child batches
# *initialized* by a job. So this job is dedicated to running the first step of every orchestration
# while inside the orchestration level batch.

module Simplekiq
  class KickoffJob
    include Sidekiq::Worker

    def perform(workflow)
      OrchestrationExecutor.new.run_step(workflow, 0)
    end
  end
end
