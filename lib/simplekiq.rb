# frozen_string_literal: true

require "sidekiq"
require "sidekiq-pro"

require "simplekiq/orchestration_executor"
require "simplekiq/orchestration"
require "simplekiq/orchestration_job"
require "simplekiq/batching_job"
require "simplekiq/kickoff_job"

module Simplekiq
  class << self
    # Empty batches with no jobs will never invoke callbacks, so handle
    # that case by immediately manually invoking :complete & :success.
    def run_empty_callbacks(job, args:)
      job.on_complete(nil, {"args" => args}) if job.respond_to?(:on_complete)
      job.on_success(nil, {"args" => args}) if job.respond_to?(:on_success)
    end

    def auto_define_callbacks(batch, args:, job:)
      batch.on("death", job.class, "args" => args) if job.respond_to?(:on_death)
      batch.on("complete", job.class, "args" => args) if job.respond_to?(:on_complete)
      batch.on("success", job.class, "args" => args) if job.respond_to?(:on_success)
    end
  end
end
