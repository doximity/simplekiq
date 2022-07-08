# frozen_string_literal: true

module Simplekiq
  class OrchestrationExecutor
    def self.execute(classname:, workflow:)
      orchestration_batch = Sidekiq::Batch.new
      orchestration_batch.description = "#{classname} Simplekiq orchestration"

      orchestration_batch.jobs do
        new.run_step(orchestration_batch, workflow, 0)
      end
    end

    def run_step(orchestration_batch, workflow, step)
      return if workflow.empty?

      orchestration_batch.jobs do
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

    def on_success(status, options)
      return if options["step"] == options["orchestration_workflow"].length

      orchestration_batch = Sidekiq::Batch.new(status.parent_bid)
      run_step(orchestration_batch, options["orchestration_workflow"], options["step"])
    end
  end
end
