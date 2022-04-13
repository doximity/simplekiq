# frozen_string_literal: true

module OrcTest
  JobA = Class.new
  JobB = Class.new
  JobC = Class.new
end

RSpec.describe Simplekiq::OrchestrationJob do
  it "adds a new job to the sequence with #run" do
    allow(Simplekiq::OrchestrationExecutor).to receive(:execute)
    klass = Class.new do
      include Simplekiq::OrchestrationJob
      def perform_orchestration
        run OrcTest::JobA, 1
        run OrcTest::JobB
      end
    end

    klass.new.perform

    expect(Simplekiq::OrchestrationExecutor)
      .to have_received(:execute).with({
        workflow: [
          {"klass" => "OrcTest::JobA", "args" => [1]},
          {"klass" => "OrcTest::JobB", "args" => []}
        ],
        parent_batch: nil
      })
  end

  it "adds a new jobs in parallel with #in_parallel" do
    allow(Simplekiq::OrchestrationExecutor).to receive(:execute)
    klass = Class.new do
      include Simplekiq::OrchestrationJob

      def perform_orchestration
        run OrcTest::JobA
        in_parallel do
          run OrcTest::JobB
          run OrcTest::JobC
        end
      end
    end

    klass.new.perform

    expect(Simplekiq::OrchestrationExecutor)
      .to have_received(:execute).with({
        workflow: [
          {"klass" => "OrcTest::JobA", "args" => []},
          [
            {"klass" => "OrcTest::JobB", "args" => []},
            {"klass" => "OrcTest::JobC", "args" => []}

          ]
        ],
        parent_batch: nil
      })
  end

  it "enables composition of orchestrations by re-opening the parent batch" do
    allow(Simplekiq::OrchestrationExecutor).to receive(:execute)
    batch_double = instance_double(Sidekiq::Batch)
    allow(batch_double).to receive(:jobs).and_yield

    job = Class.new do
      include Simplekiq::OrchestrationJob
      def perform_orchestration
        run OrcTest::JobA
      end
    end.new

    allow(job).to receive(:batch).and_return(batch_double)

    job.perform

    expect(Simplekiq::OrchestrationExecutor)
      .to have_received(:execute).with(
        {
          workflow: [{"klass" => "OrcTest::JobA", "args" => []}],
          parent_batch: batch_double
        }
      )
  end
end
