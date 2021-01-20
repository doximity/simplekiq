# frozen_string_literal: true

module Simplekiq
  class OrchestrationExecutor
    def self.execute(workflow:, parent_batch:)
      new.run_step(parent_batch, workflow, 0)
    end

    def run_step(parent_batch, workflow, step)
      nest_under(parent_batch) do
        *jobs = workflow.at(step)
        sidekiq_batch = Sidekiq::Batch.new
        sidekiq_batch.on(
          :success,
          self.class,
          "orchestration_workflow" => workflow, "step" => step + 1
        )

        sidekiq_batch.jobs do
          jobs.each do |job|
            Object.const_get(job["klass"]).perform_async(*job["args"])
          end
        end
      end
    end

    def nest_under(parent_batch)
      if parent_batch
        parent_batch.jobs do
          yield
        end
      else
        yield
      end
    end

    def on_success(status, options)
      return if options["step"] == options["orchestration_workflow"].length

      parent_batch = Sidekiq::Batch.new(status.parent_bid)
      run_step(parent_batch, options["orchestration_workflow"], options["step"])
    end
  end
end
