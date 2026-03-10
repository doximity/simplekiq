# frozen_string_literal: true

require "sidekiq/testing"

RSpec.describe Simplekiq::OrchestrationJob do
  let!(:job) do
    stub_const("FakeOrchestration", Class.new do
      include Simplekiq::OrchestrationJob

      def perform_orchestration(first, second)
        run OrcTest::JobA, first
        run OrcTest::JobB, second
      end
    end)

    FakeOrchestration.new
  end

  before do
    stub_const("OrcTest::JobA", Class.new)
    stub_const("OrcTest::JobB", Class.new)
    stub_const("OrcTest::JobC", Class.new)
  end

  def perform
    job.perform("some", "args")
  end

  describe "on_complete" do
    let!(:job) do
      Class.new do
        include Simplekiq::OrchestrationJob

        def self.on_complete_called(args)
        end

        def perform_orchestration
        end

        def on_complete(_, options)
          self.class.on_complete_called(options["args"])
        end
      end
    end

    before do
      Sidekiq::Testing.inline!
      stub_batches
    end

    it "runs the on_complete callback even if no jobs are run", sidekiq: :fake do
      expect(job).to receive(:on_complete_called).with([])

      job.new.perform
      run_all_jobs_and_batches
    end
  end

  it "adds a new job to the sequence with #run" do
    expect(Simplekiq::OrchestrationExecutor).to receive(:execute).with(
      args: ["some", "args"],
      job: job,
      workflow: [
        {"klass" => "OrcTest::JobA", "args" => ["some"]},
        {"klass" => "OrcTest::JobB", "args" => ["args"]}
      ]
    )

    perform
  end

  it "enables composition of orchestrations by re-opening the parent batch" do
    batch_double = instance_double(Sidekiq::Batch)

    batch_stack_depth = 0 # to keep track of how deeply nested within batches we are
    allow(batch_double).to receive(:jobs) do |&block|
      batch_stack_depth += 1
      block.call
      batch_stack_depth -= 1
    end

    allow(job).to receive(:batch).and_return(batch_double)

    expect(Simplekiq::OrchestrationExecutor).to receive(:execute) do
      expect(batch_stack_depth).to eq 1
    end

    perform
  end

  context "with jobs specified in_parallel" do
    let!(:job) do
      stub_const("FakeOrchestration", Class.new do
        include Simplekiq::OrchestrationJob

        def perform_orchestration(first, second)
          run OrcTest::JobA, first
          in_parallel do
            run OrcTest::JobB, first
            run OrcTest::JobC, second
          end
        end
      end)

      FakeOrchestration.new
    end

    it "adds a new jobs in parallel form to the workflow" do
      expect(Simplekiq::OrchestrationExecutor).to receive(:execute).with(
        args: ["some", "args"],
        job: job,
        workflow: [
          {"klass" => "OrcTest::JobA", "args" => ["some"]},
          {"jobs" => [
            {"klass" => "OrcTest::JobB", "args" => ["some"]},
            {"klass" => "OrcTest::JobC", "args" => ["args"]}
          ]}
        ]
      )

      perform
    end
  end
end
