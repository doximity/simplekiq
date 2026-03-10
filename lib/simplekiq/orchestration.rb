# frozen_string_literal: true

module Simplekiq
  class Orchestration
    attr_accessor :serial_workflow, :parallel_workflow
    def initialize
      @serial_workflow = []
    end

    def run(*step, description: nil)
      workflow = parallel_workflow || serial_workflow
      workflow << {step: step, description: description}
    end

    def in_parallel(description: nil)
      @parallel_workflow = []
      yield
      serial_workflow << {parallel: @parallel_workflow, description: description} if @parallel_workflow.any?
    ensure
      @parallel_workflow = nil
      serial_workflow
    end

    def serialized_workflow
      @serialized_workflow ||= serial_workflow.map do |item|
        if item[:parallel]
          jobs = item[:parallel].map do |entry|
            job, *args = entry[:step]
            {"klass" => job.name, "args" => args}
          end
          result = {"jobs" => jobs}
          result["description"] = item[:description] if item[:description]
          result
        else
          job, *args = item[:step]
          result = {"klass" => job.name, "args" => args}
          result["description"] = item[:description] if item[:description]
          result
        end
      end
    end
  end
end
