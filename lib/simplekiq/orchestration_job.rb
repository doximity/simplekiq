# frozen_string_literal: true

require "forwardable"

module Simplekiq
  module OrchestrationJob
    include Sidekiq::Worker

    extend Forwardable
    def_delegators :orchestration, :run, :in_parallel

    def perform(*args)
      perform_orchestration(*args)

      # This makes it so that if there is a parent batch which this orchestration is run under, then the layered batches will be:
      # parent_batch( orchestration_batch( batch_of_first_step_of_the_orchestration ) )
      # If there is no parent batch, then it will simply be:
      # orchestration_batch( batch_of_first_step_of_the_orchestration )
      conditionally_within_parent_batch do
        OrchestrationExecutor.execute(classname: self.class.name, workflow: orchestration.serialized_workflow)
      end
    end

    def workflow_plan(*args)
      perform_orchestration(*args)
      orchestration.serialized_workflow
    end

    private

    def conditionally_within_parent_batch
      if batch
        batch.jobs do
          yield
        end
      else
        yield
      end
    end

    def orchestration
      @orchestration ||= Orchestration.new
    end
  end
end
