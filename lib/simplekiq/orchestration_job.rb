# frozen_string_literal: true

require "forwardable"

module Simplekiq
  module OrchestrationJob
    include Sidekiq::Worker

    extend Forwardable
    def_delegators :orchestration, :run, :in_parallel

    def perform(*args)
      perform_orchestration(*args)
      orchestration.execute(batch)
    end

    def workflow_plan(*args)
      perform_orchestration(*args)
      orchestration.serialized_workflow
    end

    private

    def orchestration
      @orchestration ||= Orchestration.new
    end
  end
end
