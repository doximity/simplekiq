# frozen_string_literal: true

RSpec.describe Simplekiq::OrchestrationExecutor do
  let(:workflow) do
    [
      {"klass" => "OrcTest::JobA", "args" => [1]}
    ]
  end

  let(:classname) { "FakeOrchestration" }

  describe ".execute" do
    def execute
      described_class.execute(classname: classname, workflow: workflow)
    end

    it "kicks off the first step within a new batch" do
      batch_double = instance_double(Sidekiq::Batch)

      batch_stack_depth = 0 # to keep track of how deeply nested within batches we are
      allow(batch_double).to receive(:jobs) do |&block|
        batch_stack_depth+= 1
        block.call
        batch_stack_depth-= 1
      end

      allow(Sidekiq::Batch).to receive(:new).and_return(batch_double)

      called_yet = false
      allow_any_instance_of(Simplekiq::OrchestrationExecutor).to receive(:run_step) do |_receiver, orchestration_batch, workflow, step|
        called_yet = true
        expect(batch_stack_depth).to eq 1

        expect(orchestration_batch).to eq batch_double
        expect(workflow).to eq workflow
        expect(step).to eq 0
      end

      expect(batch_double).to receive(:description=).with("FakeOrchestration Simplekiq orchestration")

      expect { execute }.to change { called_yet }.to(true)
    end
  end
end
