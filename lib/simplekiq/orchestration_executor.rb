# frozen_string_literal: true

module Simplekiq
  class OrchestrationExecutor
    def self.execute(args:, job:, workflow:)
      if workflow.empty?
        Simplekiq.run_empty_callbacks(job, args: args)
        return
      end

      orchestration_batch = Sidekiq::Batch.new
      orchestration_batch.description = "#{job.class.name} Simplekiq orchestration"
      Simplekiq.auto_define_callbacks(orchestration_batch, args: args, job: job)

      new.run_step(orchestration_batch, workflow, 0)
    end

    def run_step(orchestration_batch, workflow, step)
      *jobs = workflow.at(step)
      # This will never be empty because Orchestration#serialized_workflow skips inserting
      # a new step for in_parallel if there were no inner jobs specified.

      orchestration_batch.jobs do
        step_batch = Sidekiq::Batch.new
        step_batch.on(
          "success",
          self.class,
          { "orchestration_workflow" => workflow, "step" => step + 1 }
        )

        step_batch.jobs do
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
