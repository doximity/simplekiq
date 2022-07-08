# frozen_string_literal: true

RSpec.describe Simplekiq::OrchestrationJob do
  before do
    stub_const("OrcTest::JobA", Class.new)
    stub_const("OrcTest::JobB", Class.new)
    stub_const("OrcTest::JobC", Class.new)
  end

  it "adds a new job to the sequence with #run" do
    allow(Simplekiq::OrchestrationExecutor).to receive(:execute)
    stub_const("FakeOrchestration", Class.new do
      include Simplekiq::OrchestrationJob
      def perform_orchestration
        run OrcTest::JobA, 1
        run OrcTest::JobB
      end
    end)

    FakeOrchestration.new.perform

    expect(Simplekiq::OrchestrationExecutor)
      .to have_received(:execute).with({
        workflow: [
          {"klass" => "OrcTest::JobA", "args" => [1]},
          {"klass" => "OrcTest::JobB", "args" => []}
        ],
        classname: "FakeOrchestration"
      })
  end

  it "adds a new jobs in parallel with #in_parallel" do
    allow(Simplekiq::OrchestrationExecutor).to receive(:execute)
    stub_const("FakeOrchestration", Class.new do
      include Simplekiq::OrchestrationJob

      def perform_orchestration
        run OrcTest::JobA
        in_parallel do
          run OrcTest::JobB
          run OrcTest::JobC
        end
      end
    end)

    FakeOrchestration.new.perform

    expect(Simplekiq::OrchestrationExecutor)
      .to have_received(:execute).with({
        workflow: [
          {"klass" => "OrcTest::JobA", "args" => []},
          [
            {"klass" => "OrcTest::JobB", "args" => []},
            {"klass" => "OrcTest::JobC", "args" => []}

          ]
        ],
        classname: "FakeOrchestration"
      })
  end

  it "enables composition of orchestrations by re-opening the parent batch" do
    batch_double = instance_double(Sidekiq::Batch)

    batch_stack_depth = 0 # to keep track of how deeply nested within batches we are
    allow(batch_double).to receive(:jobs) do |&block|
      batch_stack_depth += 1
      block.call
      batch_stack_depth -= 1
    end

    stub_const("FakeOrchestration", Class.new do
      include Simplekiq::OrchestrationJob
      def perform_orchestration
        run OrcTest::JobA
      end
    end)

    job = FakeOrchestration.new

    allow(job).to receive(:batch).and_return(batch_double)

    allow(Simplekiq::OrchestrationExecutor).to receive(:execute) do
      expect(batch_stack_depth).to eq 1
    end

    job.perform

    expect(Simplekiq::OrchestrationExecutor)
      .to have_received(:execute).with(
        {
          workflow: [{"klass" => "OrcTest::JobA", "args" => []}],
          classname: "FakeOrchestration"
        }
      )
  end
end
