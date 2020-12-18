# frozen_string_literal: true

require "simplekiq/orchestration_step_job"

module Simplekiq
  class Orchestration
    attr_accessor :serial_workflow, :parallel_workflow
    def initialize(&block)
      @serial_workflow = []
    end

    def run(*step)
      workflow = parallel_workflow || serial_workflow
      workflow << step
    end

    def in_parallel
      @parallel_workflow = []
      yield
      serial_workflow << @parallel_workflow if @parallel_workflow.any?
      @parallel_workflow = nil
      serial_workflow
    end

    def kickoff
      serialized_workflow = serial_workflow.map do |step|
        case step[0]
        when Array
          step.map do |(job, *args)|
            { "klass" => job.name, "args" => args }
          end
        when Class
          job, *args = step
          { "klass" => job.name, "args" => args }
        end
      end

      orchestration_batch = Sidekiq::Batch.new
      orchestration_batch.jobs do
        OrchestrationStepJob.perform_async(serialized_workflow, 0)
      end
    end
  end
end
